import Foundation
@testable import Tachikoma

/// Test helper functions for creating configured Tachikoma instances in test environments
enum TestHelpers {
    /// Create a test configuration with specific API keys
    static func createTestConfiguration(apiKeys: [String: String] = [:]) -> TachikomaConfiguration {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        for (provider, key) in apiKeys {
            config.setAPIKey(key, for: provider)
        }
        return config
    }

    /// Standard test API keys for consistent testing
    static let standardTestKeys: [String: String] = [
        "openai": "test-key",
        "anthropic": "test-key",
        "grok": "test-key",
        "groq": "test-key",
        "mistral": "test-key",
        "google": "test-key",
    ]

    /// Create a configuration with standard test API keys
    static func createStandardTestConfiguration() -> TachikomaConfiguration {
        self.createTestConfiguration(apiKeys: self.standardTestKeys)
    }

    /// Create a configuration with no API keys (for testing missing key scenarios)
    static func createEmptyTestConfiguration() -> TachikomaConfiguration {
        self.createTestConfiguration(apiKeys: [:])
    }

    /// Create a configuration with specific API keys present and others missing
    static func createSelectiveTestConfiguration(present: [String]) -> TachikomaConfiguration {
        let keys = present.reduce(into: [String: String]()) { result, provider in
            result[provider] = "test-key"
        }
        return self.createTestConfiguration(apiKeys: keys)
    }

    /// Execute a test block with a specific configuration
    /// Returns both the result and the configuration used
    static func withTestConfiguration<T>(
        apiKeys: [String: String] = [:],
        _ body: (TachikomaConfiguration) async throws -> T
    ) async rethrows
    -> T {
        let config = self.createTestConfiguration(apiKeys: apiKeys)
        return try await body(config)
    }

    /// Execute a test with standard test API keys
    static func withStandardTestConfiguration<T>(
        _ body: (TachikomaConfiguration) async throws -> T
    ) async rethrows
    -> T {
        let config = self.createStandardTestConfiguration()
        return try await body(config)
    }

    /// Execute a test with no API keys (for testing missing key scenarios)
    static func withEmptyTestConfiguration<T>(
        _ body: (TachikomaConfiguration) async throws -> T
    ) async rethrows
    -> T {
        let config = self.createEmptyTestConfiguration()
        return try await body(config)
    }

    /// Execute a test with specific API keys present and others missing
    static func withSelectiveTestConfiguration<T>(
        present: [String],
        _ body: (TachikomaConfiguration) async throws -> T
    ) async rethrows
    -> T {
        let config = self.createSelectiveTestConfiguration(present: present)
        return try await body(config)
    }
}
