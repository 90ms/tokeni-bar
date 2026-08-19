// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TokeniBar",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "TokeniCore", targets: ["TokeniCore"]),
        .executable(name: "TokeniBar", targets: ["TokeniBar"]),
    ],
    targets: [
        .target(
            name: "TokeniCore",
            resources: [.copy("Resources")],
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]),
        .executableTarget(
            name: "TokeniBar",
            dependencies: ["TokeniCore"],
            exclude: ["Resources"],
            resources: [
                .copy("BrandIcons"),
                .copy("CompanionAssets"),
            ],
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]),
        .testTarget(
            name: "TokeniCoreTests",
            dependencies: ["TokeniCore"],
            resources: [.copy("Fixtures")],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]),
    ])
