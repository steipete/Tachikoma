import Foundation
@testable import Tachikoma

/// Test helper functions for configuring Tachikoma in test environments
enum TestHelpers {
    /// Configure test environment with specific API keys
    /// This replaces the need for setenv() calls in tests
    static func configureTestEnvironment(apiKeys: [String: String]) {
        TachikomaConfiguration.shared.setTestMode(true, overrides: apiKeys)
    }

    /// Reset test environment back to normal configuration
    static func resetTestEnvironment() {
        TachikomaConfiguration.shared.setTestMode(false)
    }

    /// Execute a test block with specific API key overrides
    /// Automatically resets the environment after the test
    static func withTestEnvironment<T>(
        apiKeys: [String: String],
        _ body: () async throws -> T
    ) async rethrows
    -> T {
        self.configureTestEnvironment(apiKeys: apiKeys)
        defer { resetTestEnvironment() }
        return try await body()
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

    /// Execute a test with standard test API keys
    static func withStandardTestKeys<T>(
        _ body: () async throws -> T
    ) async rethrows
    -> T {
        try await self.withTestEnvironment(apiKeys: self.standardTestKeys, body)
    }

    /// Execute a test with no API keys (for testing missing key scenarios)
    static func withNoAPIKeys<T>(
        _ body: () async throws -> T
    ) async rethrows
    -> T {
        try await self.withTestEnvironment(apiKeys: [:], body)
    }

    /// Execute a test with specific API keys present and others missing
    static func withSelectiveAPIKeys<T>(
        present: [String],
        _ body: () async throws -> T
    ) async rethrows
    -> T {
        let keys = present.reduce(into: [String: String]()) { result, provider in
            result[provider] = "test-key"
        }
        return try await self.withTestEnvironment(apiKeys: keys, body)
    }
}
