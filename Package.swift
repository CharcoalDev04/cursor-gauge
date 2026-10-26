// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CursorBar",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "CursorBar",
            path: "Sources/CursorBar",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
    ]
)
