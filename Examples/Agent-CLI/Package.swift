// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Agent-CLI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "agent-cli",
            targets: ["Agent-CLI"]
        )
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "Agent-CLI",
            dependencies: [
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "TachikomaAgent", package: "Tachikoma"),
                .product(name: "TachikomaMCP", package: "Tachikoma"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)