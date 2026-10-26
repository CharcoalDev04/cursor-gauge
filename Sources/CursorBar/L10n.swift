import Foundation

enum L10n {
    static func resolve(_ preference: String) -> String {
        if preference == "th" || preference == "en" { return preference }
        return Locale.current.language.languageCode?.identifier == "th" ? "th" : "en"
    }

    static func t(_ key: String, _ preference: String) -> String {
        let table = resolve(preference) == "th" ? th : en
        return table[key] ?? en[key] ?? key
    }

    static func resets(in days: Int, _ preference: String) -> String {
        if resolve(preference) == "th" {
            return "รีเซ็ตใน \(days) วัน"
        }
        return days == 1 ? "Resets in 1 day" : "Resets in \(days) days"
    }

    static func used(_ used: String, of limit: String, _ preference: String) -> String {
        resolve(preference) == "th" ? "ใช้ไป \(used) จาก \(limit)" : "Used \(used) of \(limit)"
    }

    static func machines(_ local: Int, _ cloud: Int, _ preference: String) -> String {
        resolve(preference) == "th"
            ? "เครื่องนี้ \(local) · คลาวด์ \(cloud)"
            : "Local \(local) · Cloud \(cloud)"
    }

    static func todayInZone(_ zone: String, _ preference: String) -> String {
        resolve(preference) == "th" ? "วันนี้ตาม \(zone)" : "Today · \(zone)"
    }

    static func updateAvailable(_ version: String, _ preference: String) -> String {
        resolve(preference) == "th" ? "มีอัปเดต v\(version)" : "Update available: v\(version)"
    }

    static func httpError(_ code: Int, _ preference: String) -> String {
        resolve(preference) == "th" ? "Cursor ตอบ HTTP \(code)" : "Cursor API returned HTTP \(code)"
    }

    static func message(for error: LoadError, _ preference: String) -> String {
        switch error {
        case .notAuthenticated:
            t("notAuthenticated", preference)
        case .invalidResponse:
            t("invalidResponse", preference)
        case .http(let code):
            httpError(code, preference)
        case .other(let message):
            message
        }
    }

    static func selfCheck() {
        precondition(Set(th.keys) == Set(en.keys))
        precondition(t("settings", "th") == "ตั้งค่า")
        precondition(t("settings", "en") == "Settings")
        precondition(resolve("th") == "th")
        precondition(resolve("en") == "en")
        let system = resolve("system")
        precondition(system == "th" || system == "en")
    }

    private static let en: [String: String] = [
        "settings": "Settings",
        "done": "Done",
        "refresh": "Refresh",
        "quit": "Quit",
        "remaining": "Remaining",
        "unlimited": "Unlimited",
        "today": "Today",
        "composer": "Composer",
        "api": "API",
        "agents": "Agents",
        "models": "Models this cycle",
        "needsInput": "Needs input",
        "updated": "Updated",
        "never": "Never",
        "language": "Language",
        "system": "System",
        "thai": "ไทย",
        "english": "English",
        "showInMenuBar": "Show in menu bar",
        "gauge": "Gauge symbol",
        "quotaPercent": "Quota percent",
        "agentBadge": "Agent badge",
        "dailyPercent": "Today percent",
        "remainingMoney": "Remaining money",
        "overspend": "Overspend",
        "overIncluded": "Over included",
        "onDemand": "On-demand",
        "teamOnDemand": "Team on-demand",
        "onDemandBudget": "On-demand budget",
        "onDemandRemaining": "On-demand remaining",
        "tokens": "Tokens",
        "thisCycle": "This cycle",
        "allTime": "All time",
        "checkUpdates": "Check for updates",
        "updating": "Updating…",
        "update": "Update",
        "allOffHint": "With everything off, only the gauge remains.",
        "cycleUnavailable": "Billing cycle unavailable",
        "unknownPlan": "Unknown",
        "notAuthenticated": "Not authenticated. Please log in to Cursor.",
        "invalidResponse": "Could not parse usage data from Cursor.",
        "openInCursor": "Open in Cursor",
    ]

    private static let th: [String: String] = [
        "settings": "ตั้งค่า",
        "done": "เสร็จ",
        "refresh": "รีเฟรช",
        "quit": "ออก",
        "remaining": "เหลือ",
        "unlimited": "ไม่จำกัด",
        "today": "วันนี้",
        "composer": "Composer",
        "api": "API",
        "agents": "เอเจนต์",
        "models": "โมเดลรอบนี้",
        "needsInput": "รอให้ตอบ",
        "updated": "อัปเดต",
        "never": "ยังไม่เคย",
        "language": "ภาษา",
        "system": "ตามระบบ",
        "thai": "ไทย",
        "english": "English",
        "showInMenuBar": "แสดงบนเมนูบาร์",
        "gauge": "สัญลักษณ์เกจ",
        "quotaPercent": "เปอร์เซ็นต์โควต้า",
        "agentBadge": "ป้ายเอเจนต์",
        "dailyPercent": "เปอร์เซ็นต์วันนี้",
        "remainingMoney": "เงินที่เหลือ",
        "overspend": "ยอดเกิน",
        "overIncluded": "เกินที่รวมมา",
        "onDemand": "จ่ายเพิ่ม",
        "teamOnDemand": "จ่ายเพิ่มของทีม",
        "onDemandBudget": "งบจ่ายเพิ่ม",
        "onDemandRemaining": "จ่ายเพิ่มที่เหลือ",
        "tokens": "โทเคน",
        "thisCycle": "รอบนี้",
        "allTime": "ตลอดชีพ",
        "checkUpdates": "ตรวจอัปเดต",
        "updating": "กำลังอัปเดต…",
        "update": "อัปเดต",
        "allOffHint": "ปิดหมดแล้วเหลือไอคอนเกจอันเดียว",
        "cycleUnavailable": "ไม่พบรอบบิล",
        "unknownPlan": "ไม่ทราบ",
        "notAuthenticated": "ยังไม่ได้เข้าสู่ระบบ Cursor",
        "invalidResponse": "อ่านข้อมูลการใช้งานจาก Cursor ไม่ได้",
        "openInCursor": "เปิดใน Cursor",
    ]
}
