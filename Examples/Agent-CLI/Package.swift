// swift-tools-version: 6.2

import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .defaultIsolation(MainActor.self),
]

let package = Package(
    name: "Agent-CLI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "agent-cli",
            targets: ["Agent-CLI"],
        ),
    ],
    dependencies: [
        .package(path: "../.."),
        .package(path: "../../../../Commander"),
    ],
    targets: [
        .executableTarget(
            name: "Agent-CLI",
            dependencies: [
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "TachikomaAgent", package: "Tachikoma"),
                .product(name: "TachikomaMCP", package: "Tachikoma"),
                .product(name: "Commander", package: "Commander"),
            ],
            swiftSettings: approachableConcurrencySettings,
        ),
    ],
)
