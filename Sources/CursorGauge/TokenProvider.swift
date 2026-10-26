import CommonCrypto
import Foundation
import Security
import SQLite3

enum TokenProviderError: Error, LocalizedError {
    case databaseNotFound
    case tokenNotFound
    case invalidToken
    case keychainDenied

    var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            "Cursor database not found. Is Cursor installed and logged in?"
        case .tokenNotFound:
            "No auth token found. Please log in to Cursor."
        case .invalidToken:
            "Could not parse auth token."
        case .keychainDenied:
            "Cursor locked the login token. Allow Cursor Gauge to read “Cursor Safe Storage” in Keychain, then refresh."
        }
    }
}

struct SessionCredentials: Sendable {
    let cookieValue: String
}

enum TokenProvider {
    static let databasePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")

    private static let sealedPrefix = "cursor-safe-storage:v1:"

    static func loadSessionCredentials() throws -> SessionCredentials {
        guard FileManager.default.fileExists(atPath: databasePath.path) else {
            throw TokenProviderError.databaseNotFound
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(databasePath.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw TokenProviderError.databaseNotFound
        }
        defer { sqlite3_close(database) }

        let query = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken'"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw TokenProviderError.tokenNotFound
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW,
              let cString = sqlite3_column_text(statement, 0)
        else {
            throw TokenProviderError.tokenNotFound
        }

        let accessToken = try plaintextToken(from: String(cString: cString))
        let userID = try extractUserID(from: accessToken)
        let cookieValue = "\(userID)%3A%3A\(accessToken)"
        return SessionCredentials(cookieValue: cookieValue)
    }

    static func selfCheck() {
        let encoded = "djEwa41lTh/t8QyUrhsa/qCvaR4nHu97hECPuVRWp7F6jDTJfGKwtduim0RmDPAFwcq4qktFiLtBSMP0SVmqIxDJ5K2GPQxi9DBIEaLTlFIR7ts="
        let plain = decryptSafeStorage(encoded, password: Data("gauge-test".utf8))
        precondition(plain == "eyJhbGciOiJub25lIn0.eyJzdWIiOiJnb29nbGUtb2F1dGgyfHVzZXJfdGVzdCJ9.eA")
        precondition((try? extractUserID(from: plain ?? "")) == "user_test")
        precondition((try? plaintextToken(from: plain ?? "")) == plain)
    }

    /// Newer Cursor builds seal `cursorAuth/accessToken` with Electron safeStorage.
    /// Older builds still store the JWT in the clear.
    private static func plaintextToken(from stored: String) throws -> String {
        guard stored.hasPrefix(sealedPrefix) else { return stored }
        guard let plain = decryptSafeStorage(
            String(stored.dropFirst(sealedPrefix.count)),
            password: try safeStoragePassword()
        ) else {
            throw TokenProviderError.invalidToken
        }
        return plain
    }

    private static func safeStoragePassword() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Cursor Safe Storage",
            kSecAttrAccount as String: "Cursor Key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data, !data.isEmpty {
            return data
        }
        if status == errSecUserCanceled || status == errSecAuthFailed || status == errSecInteractionNotAllowed {
            throw TokenProviderError.keychainDenied
        }
        throw TokenProviderError.invalidToken
    }

    /// Chromium OSCrypt on macOS: PBKDF2-HMAC-SHA1 (`saltysalt`, 1003 rounds) then AES-128-CBC.
    /// The IV is sixteen spaces. Ciphertext is `v10` or `v11` plus PKCS7 bytes, standard-base64.
    private static func decryptSafeStorage(_ encoded: String, password: Data) -> String? {
        guard let blob = Data(base64Encoded: encoded), blob.count > 3 else { return nil }
        let tag = blob.prefix(3)
        guard tag == Data("v10".utf8) || tag == Data("v11".utf8) else { return nil }

        let salt = Array("saltysalt".utf8)
        var key = [UInt8](repeating: 0, count: kCCKeySizeAES128)
        let derived: CCStatus = password.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                    password.count,
                    saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                    1003,
                    &key,
                    key.count
                )
            }
        }
        guard derived == kCCSuccess else { return nil }

        let cipher = Data(blob.dropFirst(3))
        guard !cipher.isEmpty, cipher.count.isMultiple(of: kCCBlockSizeAES128) else { return nil }
        var iv = [UInt8](repeating: 0x20, count: kCCBlockSizeAES128)
        var out = [UInt8](repeating: 0, count: cipher.count)
        var outLen = 0
        let decrypted: CCStatus = key.withUnsafeBytes { keyBytes in
            cipher.withUnsafeBytes { cipherBytes in
                CCCrypt(
                    CCOperation(kCCDecrypt),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCOptions(kCCOptionPKCS7Padding),
                    keyBytes.baseAddress,
                    key.count,
                    &iv,
                    cipherBytes.baseAddress,
                    cipher.count,
                    &out,
                    out.count,
                    &outLen
                )
            }
        }
        guard decrypted == kCCSuccess else { return nil }
        return String(bytes: out.prefix(outLen), encoding: .utf8)
    }

    private static func extractUserID(from jwt: String) throws -> String {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else {
            throw TokenProviderError.invalidToken
        }

        var payload = String(parts[1])
        let padding = payload.count % 4
        if padding > 0 {
            payload += String(repeating: "=", count: 4 - padding)
        }
        payload = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subject = json["sub"] as? String
        else {
            throw TokenProviderError.invalidToken
        }

        if let separatorIndex = subject.lastIndex(of: "|") {
            return String(subject[subject.index(after: separatorIndex)...])
        }
        return subject
    }
}
