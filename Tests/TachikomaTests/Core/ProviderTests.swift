import Foundation
import Testing
@testable import Tachikoma

@Suite("Provider Enum Tests")
struct ProviderTests {
    @Suite("Provider Properties Tests")
    struct ProviderPropertiesTests {
        @Test("Standard providers have correct identifiers")
        func standardProviderIdentifiers() {
            #expect(Provider.openai.identifier == "openai")
            #expect(Provider.anthropic.identifier == "anthropic")
            #expect(Provider.grok.identifier == "grok")
            #expect(Provider.groq.identifier == "groq")
            #expect(Provider.mistral.identifier == "mistral")
            #expect(Provider.google.identifier == "google")
            #expect(Provider.ollama.identifier == "ollama")
            #expect(Provider.azureOpenAI.identifier == "azure-openai")
        }

        @Test("Custom provider has correct identifier")
        func customProviderIdentifier() {
            let customProvider = Provider.custom("my-custom-provider")
            #expect(customProvider.identifier == "my-custom-provider")
        }

        @Test("Display names are human-readable")
        func displayNames() {
            #expect(Provider.openai.displayName == "OpenAI")
            #expect(Provider.anthropic.displayName == "Anthropic")
            #expect(Provider.grok.displayName == "Grok")
            #expect(Provider.groq.displayName == "Groq")
            #expect(Provider.mistral.displayName == "Mistral")
            #expect(Provider.google.displayName == "Google")
            #expect(Provider.ollama.displayName == "Ollama")
            #expect(Provider.azureOpenAI.displayName == "Azure OpenAI")
            #expect(Provider.custom("test").displayName == "Test")
        }

        @Test("Environment variables are correct")
        func environmentVariables() {
            #expect(Provider.openai.environmentVariable == "OPENAI_API_KEY")
            #expect(Provider.anthropic.environmentVariable == "ANTHROPIC_API_KEY")
            #expect(Provider.grok.environmentVariable == "X_AI_API_KEY")
            #expect(Provider.groq.environmentVariable == "GROQ_API_KEY")
            #expect(Provider.mistral.environmentVariable == "MISTRAL_API_KEY")
            #expect(Provider.google.environmentVariable == "GEMINI_API_KEY")
            #expect(Provider.ollama.environmentVariable == "OLLAMA_API_KEY")
            #expect(Provider.azureOpenAI.environmentVariable == "AZURE_OPENAI_API_KEY")
            #expect(Provider.custom("test").environmentVariable.isEmpty)
        }

        @Test("Alternative environment variables")
        func alternativeEnvironmentVariables() {
            #expect(Provider.grok.alternativeEnvironmentVariables == ["XAI_API_KEY"])
            #expect(Provider.google.alternativeEnvironmentVariables == [
                "GOOGLE_API_KEY",
                "GOOGLE_APPLICATION_CREDENTIALS",
            ])
            #expect(Provider.openai.alternativeEnvironmentVariables.isEmpty)
            #expect(Provider.anthropic.alternativeEnvironmentVariables.isEmpty)
            #expect(Provider.azureOpenAI.alternativeEnvironmentVariables == [
                "AZURE_OPENAI_TOKEN",
                "AZURE_OPENAI_BEARER_TOKEN",
            ])
        }

        @Test("Default base URLs")
        func defaultBaseURLs() {
            #expect(Provider.openai.defaultBaseURL == "https://api.openai.com/v1")
            #expect(Provider.anthropic.defaultBaseURL == "https://api.anthropic.com")
            #expect(Provider.grok.defaultBaseURL == "https://api.x.ai/v1")
            #expect(Provider.groq.defaultBaseURL == "https://api.groq.com/openai/v1")
            #expect(Provider.mistral.defaultBaseURL == "https://api.mistral.ai/v1")
            #expect(Provider.google.defaultBaseURL == "https://generativelanguage.googleapis.com/v1beta")
            #expect(Provider.ollama.defaultBaseURL == "http://localhost:11434")
            #expect(Provider.azureOpenAI.defaultBaseURL == nil)
            #expect(Provider.custom("test").defaultBaseURL == nil)
        }

        @Test("API key requirements")
        func apiKeyRequirements() {
            #expect(Provider.openai.requiresAPIKey == true)
            #expect(Provider.anthropic.requiresAPIKey == true)
            #expect(Provider.grok.requiresAPIKey == true)
            #expect(Provider.groq.requiresAPIKey == true)
            #expect(Provider.mistral.requiresAPIKey == true)
            #expect(Provider.google.requiresAPIKey == true)
            #expect(Provider.ollama.requiresAPIKey == false) // Ollama typically doesn't require API key
            #expect(Provider.azureOpenAI.requiresAPIKey == true)
            #expect(Provider.custom("test").requiresAPIKey == true) // Assume custom providers need keys
        }
    }

    @Suite("Provider Factory Tests")
    struct ProviderFactoryTests {
        @Test("Create provider from identifier - standard providers")
        func createStandardProviders() {
            #expect(Provider.from(identifier: "openai") == .openai)
            #expect(Provider.from(identifier: "anthropic") == .anthropic)
            #expect(Provider.from(identifier: "grok") == .grok)
            #expect(Provider.from(identifier: "groq") == .groq)
            #expect(Provider.from(identifier: "mistral") == .mistral)
            #expect(Provider.from(identifier: "google") == .google)
            #expect(Provider.from(identifier: "ollama") == .ollama)
            #expect(Provider.from(identifier: "azure-openai") == .azureOpenAI)
        }

        @Test("Create provider from identifier - case insensitive")
        func createProvidersCase() {
            #expect(Provider.from(identifier: "OpenAI") == .openai)
            #expect(Provider.from(identifier: "ANTHROPIC") == .anthropic)
            #expect(Provider.from(identifier: "Grok") == .grok)
        }

        @Test("Create provider from identifier - custom providers")
        func createCustomProviders() {
            let provider1 = Provider.from(identifier: "custom-provider")
            let provider2 = Provider.from(identifier: "unknown-provider")

            if case let .custom(id1) = provider1 {
                #expect(id1 == "custom-provider")
            } else {
                Issue.record("Expected custom provider")
            }

            if case let .custom(id2) = provider2 {
                #expect(id2 == "unknown-provider")
            } else {
                Issue.record("Expected custom provider")
            }
        }

        @Test("Standard providers list")
        func standardProvidersList() {
            let expected: [Provider] = [
                .openai,
                .anthropic,
                .grok,
                .groq,
                .mistral,
                .google,
                .ollama,
                .azureOpenAI,
            ]
            #expect(Provider.standardProviders == expected)
        }
    }

    @Suite("Environment Variable Loading Tests")
    struct EnvironmentVariableTests {
        @Test("Load API key from primary environment variable")
        func loadFromPrimaryEnvironment() {
            // We can't easily mock ProcessInfo.processInfo.environment in tests,
            // so we'll test the logic indirectly through TachikomaConfiguration
        }

        @Test("Load API key from alternative environment variable")
        func loadFromAlternativeEnvironment() {
            // Test that Grok provider loads from XAI_API_KEY when X_AI_API_KEY is not available
            let provider = Provider.grok
            #expect(provider.environmentVariable == "X_AI_API_KEY")
            #expect(provider.alternativeEnvironmentVariables == ["XAI_API_KEY"])
        }

        @Test("Custom providers don't have environment variables")
        func customProviderNoEnvironment() {
            let customProvider = Provider.custom("test")
            #expect(customProvider.environmentVariable.isEmpty)
            #expect(customProvider.alternativeEnvironmentVariables.isEmpty)
        }
    }

    @Suite("Codable Tests")
    struct CodableTests {
        @Test("Provider encodes to identifier string")
        func providerEncoding() throws {
            let encoder = JSONEncoder()

            let openaiData = try encoder.encode(Provider.openai)
            let openaiString = String(data: openaiData, encoding: .utf8)
            #expect(openaiString == "\"openai\"")

            let customData = try encoder.encode(Provider.custom("my-provider"))
            let customString = String(data: customData, encoding: .utf8)
            #expect(customString == "\"my-provider\"")
        }

        @Test("Provider decodes from identifier string")
        func providerDecoding() throws {
            let decoder = JSONDecoder()

            let openaiData = "\"openai\"".utf8Data()
            let openaiProvider = try decoder.decode(Provider.self, from: openaiData)
            #expect(openaiProvider == .openai)

            let customData = "\"my-provider\"".utf8Data()
            let customProvider = try decoder.decode(Provider.self, from: customData)
            if case let .custom(id) = customProvider {
                #expect(id == "my-provider")
            } else {
                Issue.record("Expected custom provider")
            }
        }
    }

    @Suite("Equality Tests")
    struct EqualityTests {
        @Test("Standard providers equality")
        func standardProvidersEquality() {
            #expect(Provider.openai == Provider.openai)
            #expect(Provider.anthropic == Provider.anthropic)
            #expect(Provider.openai != Provider.anthropic)
        }

        @Test("Custom providers equality")
        func customProvidersEquality() {
            let custom1 = Provider.custom("test")
            let custom2 = Provider.custom("test")
            let custom3 = Provider.custom("different")

            #expect(custom1 == custom2)
            #expect(custom1 != custom3)
            #expect(custom1 != Provider.openai)
        }
    }

    @Suite("Hashable Tests")
    struct HashableTests {
        @Test("Provider hashable implementation")
        func providerHashable() {
            let providers: Set<Provider> = [
                .openai,
                .anthropic,
                .grok,
                .custom("test1"),
                .custom("test2"),
            ]

            #expect(providers.count == 5)
            #expect(providers.contains(.openai))
            #expect(providers.contains(.custom("test1")))
            #expect(!providers.contains(.custom("test3")))
        }
    }
}
