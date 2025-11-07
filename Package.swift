// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tachikoma",
    platforms: [
        .macOS(.v14),
        .iOS(.v16),
        .watchOS(.v9),
        .tvOS(.v16),
    ],
    products: [
        // Core Tachikoma library (lightweight, no MCP or Agent)
        .library(
            name: "Tachikoma",
            targets: ["Tachikoma"]),
        
        // Agent system module (Agent class, sessions, agent-specific features)
        .library(
            name: "TachikomaAgent",
            targets: ["TachikomaAgent"]),
        
        // Audio processing module (transcription, TTS, recording)
        .library(
            name: "TachikomaAudio",
            targets: ["TachikomaAudio"]),
        
        // Optional MCP extension module
        .library(
            name: "TachikomaMCP",
            targets: ["TachikomaMCP"]),
        
        // GPT-5 CLI executable
        .executable(
            name: "gpt5cli",
            targets: ["GPT5CLI"]),
        
        // Universal AI CLI executable
        .executable(
            name: "ai-cli",
            targets: ["AICLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.4"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.15.1"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.2"),
        .package(url: "https://github.com/apple/swift-configuration", .upToNextMinor(from: "0.2.0")),
    ],
    targets: [
        // Core Tachikoma module (no MCP dependencies)
        .target(
            name: "Tachikoma",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Configuration", package: "swift-configuration"),
            ],
            path: "Sources/Tachikoma",
            swiftSettings: mainActorSwiftSettings),

        // Agent system module
        .target(
            name: "TachikomaAgent",
            dependencies: [
                "Tachikoma",  // For core types and utilities
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/TachikomaAgent",
            swiftSettings: mainActorSwiftSettings),

        // Audio processing module
        .target(
            name: "TachikomaAudio",
            dependencies: [
                "Tachikoma",  // For core types and utilities
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/TachikomaAudio",
            swiftSettings: mainActorSwiftSettings),

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
            swiftSettings: mainActorSwiftSettings),

        // Core tests
        .testTarget(
            name: "TachikomaTests",
            dependencies: [
                "Tachikoma",
                "TachikomaAgent",
                "TachikomaAudio",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Tests/TachikomaTests",
            swiftSettings: mainActorSwiftSettings),

        // MCP tests
        .testTarget(
            name: "TachikomaMCPTests",
            dependencies: [
                "TachikomaMCP",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Tests/TachikomaMCPTests",
            swiftSettings: mainActorSwiftSettings),
        
        // GPT-5 CLI executable target
        .executableTarget(
            name: "GPT5CLI",
            dependencies: ["Tachikoma"],
            path: "Examples",
            exclude: [
                "Advanced",
                "Agent-CLI",
                "AI-CLI",
                "Demos",
                "HarmonyFeatures.swift",
                "RealtimeAPIDemo.swift",
                "RealtimeExample.swift",
                "RealtimeQuickTest.swift",
                "RealtimeUsageExamples.swift",
                "RealtimeVoiceAssistant.swift",
            ],
            sources: ["GPT5CLI.swift"],
            swiftSettings: mainActorSwiftSettings),
        
        // Universal AI CLI executable target
        .executableTarget(
            name: "AICLI",
            dependencies: ["Tachikoma"],
            path: "Examples/AI-CLI",
            exclude: [
                "README.md",
            ],
            sources: ["Sources/AI-CLI.swift"],
            swiftSettings: mainActorSwiftSettings),
    ])

// Common Swift settings for all targets
let commonSwiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let mainActorSwiftSettings = commonSwiftSettings + [
    .defaultIsolation(MainActor.self)
]
