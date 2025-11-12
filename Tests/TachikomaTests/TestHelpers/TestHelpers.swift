import Foundation
@testable import Tachikoma
@testable import TachikomaAudio

/// Test helper functions for creating configured Tachikoma instances in test environments
enum TestHelpers {
    /// Create a test configuration with specific API keys
    static func createTestConfiguration(
        apiKeys: [String: String] = [:],
        enableMockOverride: Bool = true,
    )
    -> TachikomaConfiguration {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        for (provider, key) in apiKeys {
            let resolved = self.resolve(provider: provider, provided: key)
            config.setAPIKey(resolved, for: provider)
        }
        if enableMockOverride {
            self.configureTestBehavior(for: config, apiKeys: apiKeys)
        }
        return config
    }

    /// Standard test API keys for consistent testing
    static let standardTestKeys: [String: String] = Self.makeStandardTestKeys()

    /// Create a configuration with standard test API keys
    static func createStandardTestConfiguration() -> TachikomaConfiguration {
        self.createTestConfiguration(apiKeys: self.standardTestKeys)
    }

    /// Create a configuration with no API keys (for testing missing key scenarios)
    static func createEmptyTestConfiguration() -> TachikomaConfiguration {
        self.createTestConfiguration(apiKeys: [:], enableMockOverride: false)
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
    @discardableResult
    static func withTestConfiguration<T>(
        apiKeys: [String: String] = [:],
        _ body: (TachikomaConfiguration) async throws -> T,
    ) async rethrows
    -> T {
        let config = self.createTestConfiguration(apiKeys: apiKeys)
        return try await body(config)
    }

    /// Execute a test with standard test API keys
    @discardableResult
    static func withStandardTestConfiguration<T>(
        _ body: (TachikomaConfiguration) async throws -> T,
    ) async rethrows
    -> T {
        let config = self.createStandardTestConfiguration()
        return try await body(config)
    }

    /// Execute a test with no API keys (for testing missing key scenarios)
    @discardableResult
    static func withEmptyTestConfiguration<T>(
        _ body: (TachikomaConfiguration) async throws -> T,
    ) async rethrows
    -> T {
        let config = self.createEmptyTestConfiguration()
        return try await body(config)
    }

    /// Execute a test with specific API keys present and others missing
    @discardableResult
    static func withSelectiveTestConfiguration<T>(
        present: [String],
        _ body: (TachikomaConfiguration) async throws -> T,
    ) async rethrows
    -> T {
        let config = self.createSelectiveTestConfiguration(present: present)
        return try await body(config)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    static func sampleAudioData(
        configuration: TachikomaConfiguration,
        format: AudioFormat = .mp3,
    )
    -> AudioData {
        // Use deterministic stub audio data for unit tests to avoid network calls.
        let stub = Data([0x01, 0x02, 0x03, 0x04])
        return AudioData(data: stub, format: format)
    }

    /// Execute a test while temporarily forcing mock provider mode
    static func withMockProviderEnvironment<T>(
        _ body: () async throws -> T,
    ) async rethrows
    -> T {
        let previous = getenv("TACHIKOMA_TEST_MODE").flatMap { String(cString: $0) }
        setenv("TACHIKOMA_TEST_MODE", "mock", 1)
        defer {
            if let previous {
                setenv("TACHIKOMA_TEST_MODE", previous, 1)
            } else {
                unsetenv("TACHIKOMA_TEST_MODE")
            }
        }
        return try await body()
    }

    private static func makeStandardTestKeys() -> [String: String] {
        [
            "openai": self.resolve(provider: "openai", provided: "test-key"),
            "anthropic": self.resolve(provider: "anthropic", provided: "test-key"),
            "grok": self.resolve(provider: "grok", provided: "test-key"),
            "groq": self.resolve(provider: "groq", provided: "test-key"),
            "mistral": self.resolve(provider: "mistral", provided: "test-key"),
            "google": self.resolve(provider: "google", provided: "test-key"),
        ]
    }

    /// Determine whether a resolved API key represents the mock placeholder
    static func isMockAPIKey(_ key: String?) -> Bool {
        guard let key, !key.isEmpty else { return true }
        return key == "test-key"
    }

    private static func resolve(provider: String, provided: String) -> String {
        if provided != "test-key" {
            return provided
        }

        let env = ProcessInfo.processInfo.environment
        for name in self.environmentVariables(for: provider) {
            if let value = env[name], !value.isEmpty {
                return value
            }
        }
        return provided
    }

    private static func environmentVariables(for provider: String) -> [String] {
        switch provider.lowercased() {
        case "openai":
            ["OPENAI_API_KEY"]
        case "anthropic":
            ["ANTHROPIC_API_KEY"]
        case "grok":
            ["XAI_API_KEY", "X_AI_API_KEY"]
        case "groq":
            ["GROQ_API_KEY"]
        case "mistral":
            ["MISTRAL_API_KEY"]
        case "google":
            ["GEMINI_API_KEY", "GOOGLE_API_KEY", "GOOGLE_APPLICATION_CREDENTIALS"]
        default:
            []
        }
    }

    private static func configureTestBehavior(for config: TachikomaConfiguration, apiKeys: [String: String]) {
        guard self.shouldUseMockProviders(apiKeys: apiKeys) else { return }
        config.setProviderFactoryOverride { model, _ in
            MockProvider(model: model)
        }
    }

    private static func shouldUseMockProviders(apiKeys: [String: String]) -> Bool {
        let env = ProcessInfo.processInfo.environment
        if env["TACHIKOMA_DISABLE_API_TESTS"] == "true" {
            return true
        }
        if let mode = env["TACHIKOMA_TEST_MODE"], mode.lowercased() == "mock" {
            return true
        }
        return apiKeys.values.contains { Self.isMockAPIKey($0) }
    }
}
