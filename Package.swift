// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SmartRemindMac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SmartRemindMac",
            path: "SmartRemindMac",
            exclude: [
                "Resources/Info.plist"
            ],
            resources: [
                .process("Resources/SmartRemindMac.entitlements")
            ]
        )
    ]
)
