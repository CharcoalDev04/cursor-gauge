// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CursorGauge",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "CursorGauge",
            path: "Sources/CursorGauge",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
    ]
)
