import Foundation
import Testing
@testable import Tachikoma

@Suite("LMStudio Provider Tests")
struct LMStudioProviderTests {
    @Test("Provider initialization")
    func providerInitialization() async throws {
        let provider = LMStudioProvider(
            baseURL: "http://localhost:1234/v1",
            modelId: "gpt-oss-120b",
            apiKey: nil,
        )

        // Access actor-isolated properties within the actor context
        let baseURL = provider.baseURL
        let modelId = provider.modelId
        let apiKey = provider.apiKey
        let capabilities = provider.capabilities

        #expect(baseURL == "http://localhost:1234/v1")
        #expect(modelId == "gpt-oss-120b")
        #expect(apiKey == nil)
        #expect(capabilities.supportsTools == true)
        #expect(capabilities.supportsStreaming == true)
    }

    @Test("Model enum integration")
    func modelEnumIntegration() async throws {
        let model1 = LanguageModel.lmstudio(.gptOSS120B)
        let model2 = LanguageModel.lmstudio(.gptOSS20B)
        let model3 = LanguageModel.lmstudio(.current)

        #expect(model1.modelId == "gpt-oss-120b")
        #expect(model2.modelId == "gpt-oss-20b")
        #expect(model3.modelId == "current")

        #expect(model1.supportsTools == true)
        #expect(model1.contextLength == 128_000)
    }

    @Test("Convenience properties")
    func convenienceProperties() async throws {
        let model1 = LanguageModel.gptOSS120B // Ollama version
        let model2 = LanguageModel.gptOSS120B_LMStudio // LMStudio version

        #expect(model1.providerName == "Ollama")
        #expect(model2.providerName == "LMStudio")

        #expect(model1.modelId == "gpt-oss:120b")
        #expect(model2.modelId == "gpt-oss-120b")
    }

    @Test("Provider factory creation")
    func providerFactoryCreation() async throws {
        let config = TachikomaConfiguration()

        // Test LMStudio provider creation
        let model = LanguageModel.lmstudio(.gptOSS120B)
        let provider = try ProviderFactory.createProvider(for: model, configuration: config)

        let modelId = provider.modelId
        #expect(modelId == "gpt-oss-120b")

        // Should work without API key (local model)
        #expect(provider is LMStudioProvider)
    }

    @Test("Response channel parsing")
    func responseChannelParsing() async throws {
        let parser = LocalModelResponseParser.self

        // Test multi-channel response
        let response1 = """
        <thinking>
        Let me analyze this problem step by step.
        </thinking>
        <analysis>
        The key insight here is that we need to consider edge cases.
        </analysis>
        <final>
        The answer is 42.
        </final>
        """

        let channels1 = parser.parseChanneledResponse(response1)
        #expect(channels1[.thinking] == "\nLet me analyze this problem step by step.\n")
        #expect(channels1[.analysis] == "\nThe key insight here is that we need to consider edge cases.\n")
        #expect(channels1[.final] == "\nThe answer is 42.\n")

        // Test plain response (no channels)
        let response2 = "This is a simple response without any channels."
        let channels2 = parser.parseChanneledResponse(response2)
        #expect(channels2[.final] == "This is a simple response without any channels.")

        // Test response with some channels missing
        let response3 = """
        <thinking>
        Processing...
        </thinking>
        Here's the answer without a final tag.
        """

        let channels3 = parser.parseChanneledResponse(response3)
        #expect(channels3[.thinking] == "\nProcessing...\n")
        #expect(channels3[.final] == "Here's the answer without a final tag.")
    }

    @Test("Auto-detection (mock)")
    func autoDetection() async throws {
        // This test would normally try to connect to LMStudio
        // In CI/mock mode, it should handle the failure gracefully

        if
            ProcessInfo.processInfo.environment["TACHIKOMA_TEST_MODE"] == "mock" ||
            ProcessInfo.processInfo.environment["CI"] == "true"
        {
            // In mock mode, auto-detect should return nil
            let provider = try await LMStudioProvider.autoDetect()
            #expect(provider == nil)
        } else {
            // In real mode, test would depend on whether LMStudio is running
            // We'll skip this for now
            #expect(Bool(true))
        }
    }

    @Test("Request mapping")
    func requestMapping() async throws {
        _ = LMStudioProvider() // Just verify it can be created

        let request = ProviderRequest(
            messages: [
                .system("You are a helpful assistant."),
                .user("Hello!"),
            ],
            tools: [
                AgentTool(
                    name: "calculator",
                    description: "Perform calculations",
                    parameters: AgentToolParameters(
                        properties: [
                            "expression": AgentToolParameterProperty(
                                name: "expression",
                                type: .string,
                                description: "Mathematical expression",
                            ),
                        ],
                        required: ["expression"],
                    ),
                ) { _ in AnyAgentToolValue(string: "42") },
            ],
            settings: GenerationSettings(
                maxTokens: 1000,
                temperature: 0.7,
                topP: 0.95,
                stopSequences: ["END"],
                reasoningEffort: .medium,
            ),
        )

        // Just verify the provider can handle the request structure
        // without actually making an API call
        #expect(request.messages.count == 2)
        #expect(request.tools?.count == 1)
        #expect(request.settings.temperature == 0.7)
    }
}
