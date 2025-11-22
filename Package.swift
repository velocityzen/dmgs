// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "dmgs",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "dmgs",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "DMGBuilder",
            ]
        ),
        .target(
            name: "DMGBuilder"
        ),
        .testTarget(
            name: "DMGBuilderTests",
            dependencies: ["DMGBuilder"],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ]
)
