// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Namensschild",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "BadgeKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "badgectl",
            dependencies: ["BadgeKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "NamensschildApp",
            dependencies: ["BadgeKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "BadgeKitTests",
            dependencies: ["BadgeKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
