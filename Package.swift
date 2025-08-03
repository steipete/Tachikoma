// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tachikoma",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v17)
    ],
    products: [
        // Main unified library that exports all modules
        .library(
            name: "Tachikoma",
            targets: ["Tachikoma"]
        ),
        // Individual modules for selective imports
        .library(
            name: "TachikomaCore",
            targets: ["TachikomaCore"]
        ),
        .library(
            name: "TachikomaBuilders",
            targets: ["TachikomaBuilders"]
        ),
        .library(
            name: "TachikomaUI",
            targets: ["TachikomaUI"]
        ),
        .library(
            name: "TachikomaCLI",
            targets: ["TachikomaCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        // Core module - fundamental types and generation functions
        .target(
            name: "TachikomaCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/TachikomaCore",
            swiftSettings: commonSwiftSettings
        ),
        
        // Builders module - result builders and DSL patterns  
        .target(
            name: "TachikomaBuilders",
            dependencies: [
                "TachikomaCore"
            ],
            path: "Sources/TachikomaBuilders",
            swiftSettings: commonSwiftSettings
        ),
        
        // UI module - SwiftUI integration and property wrappers
        .target(
            name: "TachikomaUI",
            dependencies: [
                "TachikomaCore",
                "TachikomaBuilders"
            ],
            path: "Sources/TachikomaUI",
            swiftSettings: commonSwiftSettings
        ),
        
        // CLI module - command-line utilities and model selection
        .target(
            name: "TachikomaCLI",
            dependencies: [
                "TachikomaCore"
            ],
            path: "Sources/TachikomaCLI",
            swiftSettings: commonSwiftSettings
        ),
        
        // Main umbrella module that re-exports everything
        .target(
            name: "Tachikoma",
            dependencies: [
                "TachikomaCore",
                "TachikomaBuilders", 
                "TachikomaUI",
                "TachikomaCLI"
            ],
            path: "Sources/Tachikoma",
            swiftSettings: commonSwiftSettings
        ),
        
        // Test targets
        .testTarget(
            name: "TachikomatCoreTests",
            dependencies: [
                "TachikomaCore",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Tests/TachikomaCoreTests",
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "TachikomatBuildersTests",
            dependencies: [
                "TachikomaBuilders",
                "TachikomaCore",
            ],
            path: "Tests/TachikomaBuildersTests",
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "TachikomatUITests",
            dependencies: [
                "TachikomaUI",
                "TachikomaCore",
                "TachikomaBuilders",
            ],
            path: "Tests/TachikomaUITests",
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "TachikomaCLITests",
            dependencies: [
                "TachikomaCLI",
                "TachikomaCore",
            ],
            path: "Tests/TachikomaCLITests",
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "TachikomaTests",
            dependencies: [
                "Tachikoma",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Tests/TachikomaTests",
            swiftSettings: commonSwiftSettings
        ),
    ]
)

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