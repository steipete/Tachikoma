import Foundation
import Testing
@testable import Tachikoma

@Suite("Provider System Tests", .serialized)
struct ProviderSystemTests {
    // MARK: - Provider Factory Tests

    @Test("Provider Factory - OpenAI Provider Creation")
    func providerFactoryOpenAI() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            let model = Model.openai(.gpt4o)
            let provider = try ProviderFactory.createProvider(for: model, configuration: config)

            #expect(provider.modelId == "gpt-4o")
            #expect(provider.capabilities.supportsVision == true)
            #expect(provider.capabilities.supportsTools == true)
            #expect(provider.capabilities.supportsStreaming == true)
        }
    }

    @Test("Provider Factory - Anthropic Provider Creation")
    func providerFactoryAnthropic() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["anthropic": "test-key"]) { config in
            let model = Model.anthropic(.opus4)
            let provider = try ProviderFactory.createProvider(for: model, configuration: config)

            #expect(provider.modelId == "claude-opus-4-1-20250805")
            #expect(provider.capabilities.supportsVision == true)
            #expect(provider.capabilities.supportsTools == true)
            #expect(provider.capabilities.supportsStreaming == true)
        }
    }

    @Test("Provider Factory - Grok Provider Creation")
    func providerFactoryGrok() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["grok": "test-key"]) { config in
            let model = Model.grok(.grok4FastReasoning)
            let provider = try ProviderFactory.createProvider(for: model, configuration: config)

            #expect(provider.modelId == "grok-4-fast-reasoning")
            #expect(provider.capabilities.supportsTools == true)
            #expect(provider.capabilities.supportsStreaming == true)
        }
    }

    @Test("Provider Factory - Grok catalog coverage")
    func providerFactoryGrokCatalog() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["grok": "test-key"]) { config in
            for grokModel in Model.Grok.allCases {
                let model = Model.grok(grokModel)
                let provider = try ProviderFactory.createProvider(for: model, configuration: config)
                #expect(provider.modelId == grokModel.modelId)
            }
        }
    }

    @Test("Provider Factory - Ollama Provider Creation")
    func providerFactoryOllama() async throws {
        // No API key needed for Ollama
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        let model = Model.ollama(.llama33)
        let provider = try ProviderFactory.createProvider(for: model, configuration: config)

        #expect(provider.modelId == "llama3.3")
        #expect(provider.capabilities.supportsTools == true)
        #expect(provider.capabilities.supportsStreaming == true)
    }

    @Test("Provider Factory - Missing API Key Error")
    func providerFactoryMissingAPIKey() async throws {
        await TestHelpers.withEmptyTestConfiguration { config in
            // Test the actual provider constructors directly since ProviderFactory
            // uses MockProvider in test mode to avoid hitting real APIs

            // Ensure no credentials leak in from prior tests
            let profile = ".tachikoma-tests-missing-\(UUID().uuidString)"
            TachikomaConfiguration.profileDirectoryName = profile
            let credentialsPath = NSString(string: "~/\(profile)/credentials").expandingTildeInPath
            try? FileManager.default.removeItem(atPath: credentialsPath)

            let previousOpenAI = getenv("OPENAI_API_KEY").flatMap { String(cString: $0) }
            let previousAnthropic = getenv("ANTHROPIC_API_KEY").flatMap { String(cString: $0) }
            unsetenv("OPENAI_API_KEY")
            unsetenv("ANTHROPIC_API_KEY")
            defer {
                if let previousOpenAI { setenv("OPENAI_API_KEY", previousOpenAI, 1) }
                if let previousAnthropic { setenv("ANTHROPIC_API_KEY", previousAnthropic, 1) }
            }

            #expect(throws: TachikomaError.self) {
                try OpenAIProvider(model: .gpt4o, configuration: config)
            }

            #expect(throws: TachikomaError.self) {
                try AnthropicProvider(model: .opus4, configuration: config)
            }
        }
    }

    // MARK: - Model Capabilities Tests

    @Test("Model Capabilities - Vision Support")
    func modelCapabilitiesVision() {
        #expect(Model.openai(.gpt4o).supportsVision == true)
        #expect(Model.openai(.gpt4oMini).supportsVision == true)
        #expect(Model.openai(.gpt41).supportsVision == false)

        #expect(Model.anthropic(.opus4).supportsVision == true)
        #expect(Model.anthropic(.sonnet4).supportsVision == true)

        #expect(Model.grok(.grok2Vision).supportsVision == true)
        #expect(Model.grok(.grok2Image).supportsVision == true)
        #expect(Model.grok(.grok2).supportsVision == false)
        #expect(Model.grok(.grok4).supportsVision == false)

        #expect(Model.ollama(.llava).supportsVision == true)
        #expect(Model.ollama(.llama33).supportsVision == false)
        #expect(Model.ollama(.custom("qwen2.5vl:latest")).supportsVision == true)
    }

    @Test("Model Capabilities - Tool Support")
    func modelCapabilitiesTools() {
        #expect(Model.openai(.gpt4o).supportsTools == true)
        #expect(Model.openai(.gpt41).supportsTools == true)

        #expect(Model.anthropic(.opus4).supportsTools == true)
        #expect(Model.anthropic(.sonnet4).supportsTools == true)

        #expect(Model.grok(.grok4).supportsTools == true)

        #expect(Model.ollama(.llama33).supportsTools == true)
        #expect(Model.ollama(.llava).supportsTools == false) // Vision models don't support tools
        #expect(Model.ollama(.custom("qwen2.5vl:latest")).supportsTools == false)
    }

    @Test("Model Capabilities - Streaming Support")
    func modelCapabilitiesStreaming() {
        #expect(Model.openai(.gpt4o).supportsStreaming == true)
        #expect(Model.anthropic(.opus4).supportsStreaming == true)
        #expect(Model.grok(.grok4).supportsStreaming == true)
        #expect(Model.ollama(.llama33).supportsStreaming == true)
    }

    // MARK: - Generation Request Tests

    @Test("Generation Request Basic Creation")
    func generationRequestBasic() {
        let request = ProviderRequest(
            messages: [ModelMessage(role: .user, content: [.text("Hello world")])],
            tools: nil,
            settings: GenerationSettings(maxTokens: 100, temperature: 0.7),
        )

        #expect(request.messages.count == 1)
        #expect(request.messages[0].role == .user)
        #expect(request.tools == nil)
        #expect(request.settings.maxTokens == 100)
        #expect(request.settings.temperature == 0.7)
        #expect(request.outputFormat == nil)
    }

    @Test("Generation Request With Images")
    func generationRequestWithImages() {
        let imageContent = ModelMessage.ContentPart.ImageContent(data: "test-base64-data")
        let request = ProviderRequest(
            messages: [
                ModelMessage(role: .user, content: [
                    .text("Describe this image"),
                    .image(imageContent),
                ]),
            ],
            tools: nil,
            settings: .default,
        )

        #expect(request.messages.count == 1)
        #expect(request.messages[0].content.count == 2)

        if case let .image(img) = request.messages[0].content[1] {
            #expect(img.data == "test-base64-data")
        } else {
            Issue.record("Expected image content")
        }
    }

    // MARK: - Stream Token Tests

    @Test("Stream Token Types")
    func streamTokenTypes() {
        let textToken = TextStreamDelta(type: .textDelta, content: "hello")
        #expect(textToken.content == "hello")
        #expect(textToken.type == .textDelta)

        let completeToken = TextStreamDelta(type: .done, content: nil)
        #expect(completeToken.content == nil)
        #expect(completeToken.type == .done)

        let toolCallToken = TextStreamDelta(type: .toolCall, content: nil)
        #expect(toolCallToken.type == .toolCall)

        let toolResultToken = TextStreamDelta(type: .toolResult, content: nil)
        #expect(toolResultToken.type == .toolResult)
    }

    // MARK: - Usage Statistics Tests

    @Test("Usage Statistics")
    func usageStatistics() {
        let usage = Usage(inputTokens: 100, outputTokens: 50)

        #expect(usage.inputTokens == 100)
        #expect(usage.outputTokens == 50)
        #expect(usage.totalTokens == 150)
    }

    // MARK: - Finish Reason Tests

    @Test("Finish Reason Cases")
    func finishReasonCases() {
        #expect(FinishReason.stop.rawValue == "stop")
        #expect(FinishReason.length.rawValue == "length")
        #expect(FinishReason.toolCalls.rawValue == "tool_calls")
        #expect(FinishReason.contentFilter.rawValue == "content_filter")
        #expect(FinishReason.other.rawValue == "other")
    }
}
