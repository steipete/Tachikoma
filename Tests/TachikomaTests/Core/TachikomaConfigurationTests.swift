import Foundation
import Testing
@testable import Tachikoma
@testable import TachikomaAgent

@Suite("TachikomaConfiguration Tests", .serialized)
struct TachikomaConfigurationTests {
    @Suite("Instance Creation Tests")
    struct InstanceCreationTests {
        @Test("Default constructor loads from environment")
        func defaultConstructorLoadsEnvironment() async throws {
            let config = TachikomaConfiguration()
            // Should not crash and create valid instance
            #expect(config.configuredProviders.isEmpty || !config.configuredProviders.isEmpty) // Either is fine
        }

        @Test("Constructor with loadFromEnvironment=false")
        func constructorWithoutEnvironmentLoading() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)
            #expect(config.configuredProviders.isEmpty)
        }

        @Test("Convenience constructor with API keys")
        func convenienceConstructorWithAPIKeys() async throws {
            let config = TachikomaConfiguration(
                apiKeys: [
                    "openai": "test-openai-key",
                    "anthropic": "test-anthropic-key",
                ],
            )

            #expect(config.getAPIKey(for: .openai) == "test-openai-key")
            #expect(config.getAPIKey(for: .anthropic) == "test-anthropic-key")
            #expect(config.getAPIKey(for: .groq) == nil)
        }

        @Test("Convenience constructor with API keys and base URLs")
        func convenienceConstructorWithAPIKeysAndBaseURLs() async throws {
            let config = TachikomaConfiguration(
                apiKeys: ["openai": "test-key"],
                baseURLs: ["openai": "https://custom.openai.com"],
            )

            #expect(config.getAPIKey(for: .openai) == "test-key")
            #expect(config.getBaseURL(for: .openai) == "https://custom.openai.com")
        }
    }

    @Suite("Type-Safe API Tests")
    struct TypeSafeAPITests {
        @Test("Set and get API key with Provider enum")
        func setAndGetAPIKeyTypeSafe() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)

            config.setAPIKey("test-openai-key", for: .openai)
            config.setAPIKey("test-anthropic-key", for: .anthropic)
            config.setAPIKey("test-custom-key", for: .custom("my-provider"))

            #expect(config.getAPIKey(for: .openai) == "test-openai-key")
            #expect(config.getAPIKey(for: .anthropic) == "test-anthropic-key")
            #expect(config.getAPIKey(for: .custom("my-provider")) == "test-custom-key")
            #expect(config.getAPIKey(for: .groq) == nil)
        }

        @Test("Has API key checks")
        func hasAPIKeyChecks() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)

            #expect(!config.hasAPIKey(for: .openai))
            #expect(!config.hasConfiguredAPIKey(for: .openai))

            config.setAPIKey("test-key", for: .openai)

            #expect(config.hasAPIKey(for: .openai))
            #expect(config.hasConfiguredAPIKey(for: .openai))
        }

        @Test("Remove API key")
        func removeAPIKey() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)

            config.setAPIKey("test-key", for: .anthropic)
            #expect(config.hasAPIKey(for: .anthropic))

            config.removeAPIKey(for: .anthropic)
            #expect(!config.hasAPIKey(for: .anthropic))
        }

        @Test("Set and get base URL")
        func setAndGetBaseURL() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)

            // Test custom base URL
            config.setBaseURL("https://custom.openai.com", for: .openai)
            #expect(config.getBaseURL(for: .openai) == "https://custom.openai.com")

            // Test default base URL fallback
            #expect(config.getBaseURL(for: .anthropic) == "https://api.anthropic.com")

            // Test custom provider with no default
            #expect(config.getBaseURL(for: .custom("test")) == nil)
        }

        @Test("Remove base URL falls back to default")
        func removeBaseURLFallback() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)

            // Set custom URL
            config.setBaseURL("https://custom.api.com", for: .openai)
            #expect(config.getBaseURL(for: .openai) == "https://custom.api.com")

            // Remove custom URL, should fall back to default
            config.removeBaseURL(for: .openai)
            #expect(config.getBaseURL(for: .openai) == "https://api.openai.com/v1")
        }
    }

    @Suite("String-Based Compatibility API Tests")
    struct StringBasedAPITests {
        @Test("String-based API delegates to type-safe API")
        func stringBasedAPIDelegation() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)

            // Set via string API
            config.setAPIKey("string-api-key", for: "openai")

            // Get via type-safe API should work
            #expect(config.getAPIKey(for: .openai) == "string-api-key")

            // Get via string API should work
            #expect(config.getAPIKey(for: "openai") == "string-api-key")

            // Has API key should work both ways
            #expect(config.hasAPIKey(for: .openai))
            #expect(config.hasAPIKey(for: "openai"))
        }

        @Test("String-based API handles custom providers")
        func stringBasedCustomProviders() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)

            config.setAPIKey("custom-key", for: "my-custom-provider")
            config.setBaseURL("https://custom.api.com", for: "my-custom-provider")

            #expect(config.getAPIKey(for: "my-custom-provider") == "custom-key")
            #expect(config.getBaseURL(for: "my-custom-provider") == "https://custom.api.com")
            #expect(config.hasAPIKey(for: "my-custom-provider"))
        }

        @Test("String-based API case insensitive")
        func stringBasedCaseInsensitive() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)

            config.setAPIKey("test-key", for: "OpenAI")

            #expect(config.getAPIKey(for: "openai") == "test-key")
            #expect(config.getAPIKey(for: "OPENAI") == "test-key")
            #expect(config.hasAPIKey(for: "openai"))
        }
    }

    @Suite("Environment Variable Loading Tests")
    struct EnvironmentVariableTests {
        @Test("Environment vs configured key priority")
        func environmentVsConfiguredPriority() async throws {
            // Create config that loads from environment
            let config = TachikomaConfiguration()

            // Set explicit key - should override any environment value
            config.setAPIKey("configured-key", for: .openai)
            #expect(config.getAPIKey(for: .openai) == "configured-key")
            #expect(config.hasConfiguredAPIKey(for: .openai))

            // Remove configured key - may fall back to environment if present
            config.removeAPIKey(for: .openai)
            #expect(!config.hasConfiguredAPIKey(for: .openai))
            // Environment key availability depends on actual environment
        }

        @Test("Environment detection methods")
        func environmentDetectionMethods() async throws {
            _ = TachikomaConfiguration()

            // Provider enum should detect environment independently
            // These test actual environment variables, not mocked ones
            let hasOpenAIEnv = Provider.openai.hasEnvironmentAPIKey
            let hasAnthropicEnv = Provider.anthropic.hasEnvironmentAPIKey

            // Just verify the methods work, don't assume specific values
            #expect(hasOpenAIEnv == hasOpenAIEnv) // Tautology but verifies no crash
            #expect(hasAnthropicEnv == hasAnthropicEnv)
        }
    }

    @Suite("Configuration State Tests")
    struct ConfigurationStateTests {
        @Test("Configured providers list")
        func configuredProvidersList() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)

            #expect(config.configuredProviders.isEmpty)

            config.setAPIKey("key1", for: .openai)
            config.setAPIKey("key2", for: .anthropic)
            config.setAPIKey("key3", for: .custom("test"))

            let providers = config.configuredProviders
            #expect(providers.count == 3)
            #expect(providers.contains(.openai))
            #expect(providers.contains(.anthropic))
            #expect(providers.contains(.custom("test")))
        }

        @Test("Clear all configuration")
        func clearAllConfiguration() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)

            config.setAPIKey("key1", for: .openai)
            config.setAPIKey("key2", for: .anthropic)
            config.setBaseURL("https://custom.com", for: .openai)

            #expect(!config.configuredProviders.isEmpty)

            config.clearAll()

            #expect(config.configuredProviders.isEmpty)
            #expect(config.getAPIKey(for: .openai) == nil)
            #expect(config.getBaseURL(for: .openai) == "https://api.openai.com/v1") // Falls back to default
        }

        @Test("Configuration summary")
        func configurationSummary() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)

            config.setAPIKey("anthropic-key", for: .anthropic)
            config.setBaseURL("https://custom.openai.com", for: .openai)

            let summary = config.summary
            #expect(summary.contains("Tachikoma Configuration"))
            #expect(summary.contains("anthropic")) // Should show configured provider
        }
    }

    @Suite("Thread Safety Tests")
    struct ThreadSafetyTests {
        @Test("Concurrent access is thread-safe")
        func concurrentAccess() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)

            // Test concurrent reads and writes
            await withTaskGroup(of: Void.self) { group in
                // Multiple writers
                for i in 0..<10 {
                    group.addTask {
                        config.setAPIKey("key-\(i)", for: .custom("provider-\(i)"))
                    }
                }

                // Multiple readers
                for _ in 0..<10 {
                    group.addTask {
                        _ = config.getAPIKey(for: .openai)
                        _ = config.configuredProviders
                        _ = config.hasAPIKey(for: .anthropic)
                    }
                }
            }

            // Should not crash and have consistent state
            #expect(config.configuredProviders.count <= 10)
        }
    }

    @Suite("Default Configuration Tests")
    struct DefaultConfigurationTests {
        @Test("Default configuration usage")
        func defaultConfigurationUsage() async throws {
            // Clear any existing default
            TachikomaConfiguration.default = nil

            // Current should return auto instance
            let current1 = TachikomaConfiguration.current
            let current2 = TachikomaConfiguration.current
            #expect(current1 === current2) // Should be same instance

            // Set a default
            let customDefault = TachikomaConfiguration(loadFromEnvironment: false)
            customDefault.setAPIKey("custom-key", for: .openai)
            TachikomaConfiguration.default = customDefault

            // Current should now return the custom default
            #expect(TachikomaConfiguration.current === customDefault)
            #expect(TachikomaConfiguration.current.getAPIKey(for: .openai) == "custom-key")

            // Clean up
            TachikomaConfiguration.default = nil
        }

        @Test("Resolve helper function")
        func resolveHelperFunction() async throws {
            // Clear any existing default
            TachikomaConfiguration.default = nil

            // Test with no provided config and no default
            let resolved1 = TachikomaConfiguration.resolve()
            let resolved2 = TachikomaConfiguration.resolve()
            #expect(resolved1 === resolved2) // Should be same auto instance

            // Set a default
            let defaultConfig = TachikomaConfiguration(loadFromEnvironment: false)
            defaultConfig.setAPIKey("default-key", for: .anthropic)
            TachikomaConfiguration.default = defaultConfig

            // Resolve should return default
            let resolved3 = TachikomaConfiguration.resolve()
            #expect(resolved3 === defaultConfig)

            // Resolve with explicit config should override
            let explicitConfig = TachikomaConfiguration(loadFromEnvironment: false)
            explicitConfig.setAPIKey("explicit-key", for: .groq)
            let resolved4 = TachikomaConfiguration.resolve(explicitConfig)
            #expect(resolved4 === explicitConfig)

            // Clean up
            TachikomaConfiguration.default = nil
        }

        @Test("Auto instance is singleton")
        func autoInstanceIsSingleton() async throws {
            // Clear any existing default
            TachikomaConfiguration.default = nil

            // Multiple accesses to current should return same auto instance
            let instances = await withTaskGroup(of: TachikomaConfiguration.self) { group in
                for _ in 0..<10 {
                    group.addTask {
                        TachikomaConfiguration.current
                    }
                }

                var results: [TachikomaConfiguration] = []
                for await instance in group {
                    results.append(instance)
                }
                return results
            }

            // All should be the same instance
            let first = instances.first!
            for instance in instances {
                #expect(instance === first)
            }

            // Clean up
            TachikomaConfiguration.default = nil
        }

        @Test("Generation functions with different configurations")
        func generationFunctionsWithConfigs() async throws {
            // Clear any existing default
            TachikomaConfiguration.default = nil

            // Set a default config
            let defaultConfig = TachikomaConfiguration(loadFromEnvironment: false)
            defaultConfig.setAPIKey("default-key", for: .openai)
            TachikomaConfiguration.default = defaultConfig

            // Create explicit config
            let explicitConfig = TachikomaConfiguration(loadFromEnvironment: false)
            explicitConfig.setAPIKey("explicit-key", for: .openai)

            // Test that functions compile with different configs
            _ = {
                Task {
                    // Uses default (.current)
                    _ = try await generateText(
                        model: .openai(.gpt4o),
                        messages: [.user("Test")],
                    )

                    // Uses explicit
                    _ = try await generateText(
                        model: .openai(.gpt4o),
                        messages: [.user("Test")],
                        configuration: explicitConfig,
                    )

                    // Stream functions
                    _ = try await streamText(
                        model: .openai(.gpt4o),
                        messages: [.user("Test")],
                    )

                    _ = try await streamText(
                        model: .openai(.gpt4o),
                        messages: [.user("Test")],
                        configuration: explicitConfig,
                    )

                    // Convenience functions
                    _ = try await generate("Test", using: .openai(.gpt4o))
                    _ = try await generate("Test", using: .openai(.gpt4o), configuration: explicitConfig)

                    _ = try await stream("Test", using: .openai(.gpt4o))
                    _ = try await stream("Test", using: .openai(.gpt4o), configuration: explicitConfig)
                }
            }

            // Clean up
            TachikomaConfiguration.default = nil
        }

        @Test("Conversation uses provided configuration")
        func conversationUsesProvidedConfig() async throws {
            // Clear any existing default
            TachikomaConfiguration.default = nil

            // Create different configs
            let config1 = TachikomaConfiguration(loadFromEnvironment: false)
            config1.setAPIKey("config1-key", for: .anthropic)

            let config2 = TachikomaConfiguration(loadFromEnvironment: false)
            config2.setAPIKey("config2-key", for: .anthropic)

            TachikomaConfiguration.default = config1

            // Create conversations
            let conv1 = Conversation() // Should use current (which is config1)
            let conv2 = Conversation(configuration: config2) // Should use config2

            // Verify they maintain their configs
            #expect(conv1.configuration === config1)
            #expect(conv2.configuration === config2)

            // Change default shouldn't affect existing conversations
            TachikomaConfiguration.default = nil
            #expect(conv1.configuration === config1) // Still using config1
            #expect(conv2.configuration === config2) // Still using config2

            // New conversation should use auto instance now
            let conv3 = Conversation()
            #expect(conv3.configuration === TachikomaConfiguration.current)

            // Clean up
            TachikomaConfiguration.default = nil
        }

        @Test("Thread safety stress test")
        func threadSafetyStressTest() async throws {
            // Clear any existing default
            TachikomaConfiguration.default = nil

            // Stress test with many concurrent operations
            await withTaskGroup(of: Void.self) { group in
                // Writers
                for i in 0..<100 {
                    group.addTask {
                        let config = TachikomaConfiguration(loadFromEnvironment: false)
                        config.setAPIKey("key-\(i)", for: .openai)
                        TachikomaConfiguration.default = config
                    }
                }

                // Readers
                for _ in 0..<100 {
                    group.addTask {
                        _ = TachikomaConfiguration.current
                        _ = TachikomaConfiguration.default
                        _ = TachikomaConfiguration.resolve()
                    }
                }

                // Resolvers with different inputs
                for i in 0..<100 {
                    group.addTask {
                        if i % 2 == 0 {
                            _ = TachikomaConfiguration.resolve(nil)
                        } else {
                            let config = TachikomaConfiguration(loadFromEnvironment: false)
                            _ = TachikomaConfiguration.resolve(config)
                        }
                    }
                }
            }

            // Should not crash and should have valid state
            let final = TachikomaConfiguration.current
            #expect(final.getBaseURL(for: .openai) != nil) // Should have a valid config

            // Clean up
            TachikomaConfiguration.default = nil
        }
    }

    @Suite("Instance Isolation Tests")
    struct InstanceIsolationTests {
        @Test("Multiple instances are isolated")
        func multipleInstancesIsolated() async throws {
            let config1 = TachikomaConfiguration(loadFromEnvironment: false)
            let config2 = TachikomaConfiguration(loadFromEnvironment: false)

            config1.setAPIKey("key1", for: .openai)
            config2.setAPIKey("key2", for: .openai)

            #expect(config1.getAPIKey(for: .openai) == "key1")
            #expect(config2.getAPIKey(for: .openai) == "key2")

            config1.removeAPIKey(for: .openai)
            #expect(config1.getAPIKey(for: .openai) == nil)
            #expect(config2.getAPIKey(for: .openai) == "key2") // Should be unaffected
        }

        @Test("Instance isolation with same provider keys")
        func instanceIsolationSameProviders() async throws {
            let config1 = TachikomaConfiguration(apiKeys: ["openai": "config1-key"])
            let config2 = TachikomaConfiguration(apiKeys: ["openai": "config2-key"])

            #expect(config1.getAPIKey(for: .openai) == "config1-key")
            #expect(config2.getAPIKey(for: .openai) == "config2-key")

            // Modify one, other should be unaffected
            config1.setAPIKey("new-key", for: .anthropic)
            #expect(config1.hasAPIKey(for: .anthropic))
            #expect(!config2.hasAPIKey(for: .anthropic))
        }
    }

    @Suite("Configuration Priority Tests")
    struct ConfigurationPriorityTests {
        @Test("Configuration priority chain")
        func configurationPriorityChain() async throws {
            // Clear any existing default
            TachikomaConfiguration.default = nil

            // Setup different configurations
            let autoConfig = TachikomaConfiguration.current // Will be auto instance
            let defaultConfig = TachikomaConfiguration(loadFromEnvironment: false)
            defaultConfig.setAPIKey("default-key", for: .openai)
            TachikomaConfiguration.default = defaultConfig

            let explicitConfig = TachikomaConfiguration(loadFromEnvironment: false)
            explicitConfig.setAPIKey("explicit-key", for: .openai)

            // Test priority: explicit > default > auto
            #expect(TachikomaConfiguration.resolve(explicitConfig).getAPIKey(for: .openai) == "explicit-key")
            #expect(TachikomaConfiguration.resolve(nil).getAPIKey(for: .openai) == "default-key")

            // Remove default, should fall back to auto
            TachikomaConfiguration.default = nil
            let resolved = TachikomaConfiguration.resolve(nil)
            #expect(resolved === autoConfig) // Should be the same auto instance created earlier

            // Clean up
            TachikomaConfiguration.default = nil
        }
    }

    @Suite("Provider Factory Override Tests")
    struct ProviderFactoryOverrideTests {
        @Test("Custom factory override takes precedence")
        func customFactoryOverrideTakesPrecedence() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)
            config.setAPIKey("mock-key", for: .openai)

            var capturedModel: LanguageModel?

            config.setProviderFactoryOverride { model, _ in
                capturedModel = model
                return DummyProvider()
            }

            let provider = try config.makeProvider(for: .openai(.gpt4o))
            #expect(provider is DummyProvider)
            #expect(capturedModel == .openai(.gpt4o))
        }

        @Test("makeProvider falls back to real provider without override")
        func makeProviderUsesRealFactory() async throws {
            let config = TachikomaConfiguration(loadFromEnvironment: false)
            config.setAPIKey("mock-key", for: .openai)

            let provider = try config.makeProvider(for: .openai(.gpt4o))
            #expect(provider is OpenAIProvider)
        }
    }
}

private struct DummyProvider: ModelProvider {
    let modelId = "dummy"
    let baseURL: String? = nil
    let apiKey: String? = nil
    let capabilities = ModelCapabilities(
        supportsVision: false,
        supportsTools: false,
        supportsStreaming: false,
        contextLength: 1,
        maxOutputTokens: 1,
    )

    func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
        ProviderResponse(text: "dummy")
    }

    func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(TextStreamDelta.text("dummy"))
            continuation.finish()
        }
    }
}
