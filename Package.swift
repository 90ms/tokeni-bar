// swift-tools-version: 6.2
import PackageDescription

var products: [Product] = [
    .library(name: "TokeniCore", targets: ["TokeniCore"]),
    .library(name: "TokeniApplication", targets: ["TokeniApplication"]),
]

var targets: [Target] = [
    .target(
        name: "TokeniCore",
        resources: [.copy("Resources")],
        swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]),
    .target(
        name: "TokeniApplication",
        dependencies: ["TokeniCore"],
        swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]),
    .testTarget(
        name: "TokeniCoreTests",
        dependencies: ["TokeniCore"],
        resources: [.copy("Fixtures")],
        swiftSettings: [
            .enableUpcomingFeature("StrictConcurrency"),
        ]),
    .testTarget(
        name: "TokeniApplicationTests",
        dependencies: ["TokeniApplication", "TokeniCore"],
        swiftSettings: [
            .enableUpcomingFeature("StrictConcurrency"),
        ]),
]

#if os(macOS)
products.append(.executable(name: "TokeniBar", targets: ["TokeniBar"]))
targets.insert(
    .executableTarget(
        name: "TokeniBar",
        dependencies: ["TokeniCore", "TokeniApplication"],
        exclude: ["Resources"],
        resources: [
            .copy("BrandIcons"),
            .copy("CompanionAssets"),
        ],
        swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]),
    at: 1)
#endif

let package = Package(
    name: "TokeniBar",
    platforms: [
        .macOS(.v14),
    ],
    products: products,
    targets: targets)
