// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tachikoma",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .watchOS(.v9),
        .tvOS(.v16),
    ],
    products: [
        // Core Tachikoma library (lightweight, no MCP)
        .library(
            name: "Tachikoma",
            targets: ["Tachikoma"]),
        
        // Audio processing module (transcription, TTS, recording)
        .library(
            name: "TachikomaAudio",
            targets: ["TachikomaAudio"]),
        
        // Optional MCP extension module
        .library(
            name: "TachikomaMCP",
            targets: ["TachikomaMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        // Use local fork of swift-sdk for SSE client transport
        .package(path: "../../swift-sdk"),
    ],
    targets: [
        // Core Tachikoma module (no MCP dependencies)
        .target(
            name: "Tachikoma",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Sources/Tachikoma",
            swiftSettings: commonSwiftSettings),

        // Audio processing module
        .target(
            name: "TachikomaAudio",
            dependencies: [
                "Tachikoma",  // For core types and utilities
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/TachikomaAudio",
            swiftSettings: commonSwiftSettings),

        // Optional MCP extension module
        .target(
            name: "TachikomaMCP",
            dependencies: [
                "Tachikoma",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/TachikomaMCP",
            exclude: ["README.md"],
            swiftSettings: commonSwiftSettings),

        // Core tests
        .testTarget(
            name: "TachikomaTests",
            dependencies: [
                "Tachikoma",
                "TachikomaAudio",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Tests/TachikomaTests",
            swiftSettings: commonSwiftSettings),

        // MCP tests
        .testTarget(
            name: "TachikomaMCPTests",
            dependencies: [
                "TachikomaMCP",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Tests/TachikomaMCPTests",
            swiftSettings: commonSwiftSettings),
    ])

// Common Swift settings for all targets
let commonSwiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("BareSlashRegexLiterals"),
    .enableUpcomingFeature("ConciseMagicFile"),
    .enableUpcomingFeature("ForwardTrailingClosures"),
    .enableUpcomingFeature("ImportObjcForwardDeclarations"),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("DeprecateApplicationMain"),
    .enableUpcomingFeature("GlobalConcurrency"),
    .enableUpcomingFeature("IsolatedDefaultValues"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]
