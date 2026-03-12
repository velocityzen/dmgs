// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "dmgs",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(path: "../DSStore"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.2.0"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.3"),
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
            name: "DMGBuilder",
            dependencies: [
                .product(name: "DSStore", package: "DSStore"),
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .testTarget(
            name: "DMGBuilderTests",
            dependencies: [
                "DMGBuilder",
                .product(name: "DSStore", package: "DSStore"),
                .product(name: "Markdown", package: "swift-markdown"),
            ],
        ),
    ],
    swiftLanguageModes: [.v6],
)
