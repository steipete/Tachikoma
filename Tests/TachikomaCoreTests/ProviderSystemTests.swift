import Foundation
@testable import TachikomaCore
import Testing

@Suite("Provider System Tests")
struct ProviderSystemTests {
    // MARK: - Provider Factory Tests

    @Test("Provider Factory - OpenAI Provider Creation")
    func providerFactoryOpenAI() async throws {
        try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
            let model = Model.openai(.gpt4o)
            let provider = try ProviderFactory.createProvider(for: model)

            #expect(provider.modelId == "gpt-4o")
            #expect(provider.capabilities.supportsVision == true)
            #expect(provider.capabilities.supportsTools == true)
            #expect(provider.capabilities.supportsStreaming == true)
        }
    }

    @Test("Provider Factory - Anthropic Provider Creation")
    func providerFactoryAnthropic() async throws {
        try await TestHelpers.withTestEnvironment(apiKeys: ["anthropic": "test-key"]) {
            let model = Model.anthropic(.opus4)
            let provider = try ProviderFactory.createProvider(for: model)

            #expect(provider.modelId == "claude-opus-4-20250514")
            #expect(provider.capabilities.supportsVision == true)
            #expect(provider.capabilities.supportsTools == true)
            #expect(provider.capabilities.supportsStreaming == true)
        }
    }

    @Test("Provider Factory - Grok Provider Creation")
    func providerFactoryGrok() async throws {
        try await TestHelpers.withTestEnvironment(apiKeys: ["grok": "test-key"]) {
            let model = Model.grok(.grok4)
            let provider = try ProviderFactory.createProvider(for: model)

            #expect(provider.modelId == "grok-4")
            #expect(provider.capabilities.supportsTools == true)
            #expect(provider.capabilities.supportsStreaming == true)
        }
    }

    @Test("Provider Factory - Ollama Provider Creation")
    func providerFactoryOllama() async throws {
        // No API key needed for Ollama
        let model = Model.ollama(.llama33)
        let provider = try ProviderFactory.createProvider(for: model)

        #expect(provider.modelId == "llama3.3")
        #expect(provider.capabilities.supportsTools == true)
        #expect(provider.capabilities.supportsStreaming == true)
    }

    @Test("Provider Factory - Missing API Key Error")
    func providerFactoryMissingAPIKey() async throws {
        try await TestHelpers.withNoAPIKeys {
            let model = LanguageModel.openai(.gpt4o)

            #expect(throws: TachikomaError.self) {
                try ProviderFactory.createProvider(for: model)
            }

            // Also test Anthropic
            let anthropicModel = LanguageModel.anthropic(.opus4)

            #expect(throws: TachikomaError.self) {
                try ProviderFactory.createProvider(for: anthropicModel)
            }
        }
    }

    // MARK: - Model Capabilities Tests

    @Test("Model Capabilities - Vision Support")
    func modelCapabilitiesVision() {
        #expect(Model.openai(.gpt4o).supportsVision == true)
        #expect(Model.openai(.gpt4oMini).supportsVision == true)
        #expect(Model.openai(.gpt4_1).supportsVision == false)

        #expect(Model.anthropic(.opus4).supportsVision == true)
        #expect(Model.anthropic(.sonnet4).supportsVision == true)

        #expect(Model.grok(.grok2Vision_1212).supportsVision == true)
        #expect(Model.grok(.grok4).supportsVision == false)

        #expect(Model.ollama(.llava).supportsVision == true)
        #expect(Model.ollama(.llama33).supportsVision == false)
    }

    @Test("Model Capabilities - Tool Support")
    func modelCapabilitiesTools() {
        #expect(Model.openai(.gpt4o).supportsTools == true)
        #expect(Model.openai(.gpt4_1).supportsTools == true)

        #expect(Model.anthropic(.opus4).supportsTools == true)
        #expect(Model.anthropic(.sonnet4).supportsTools == true)

        #expect(Model.grok(.grok4).supportsTools == true)

        #expect(Model.ollama(.llama33).supportsTools == true)
        #expect(Model.ollama(.llava).supportsTools == false) // Vision models don't support tools
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
            settings: GenerationSettings(maxTokens: 100, temperature: 0.7)
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
            messages: [ModelMessage(role: .user, content: [
                .text("Describe this image"),
                .image(imageContent),
            ]),],
            tools: nil,
            settings: .default
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

        let errorToken = TextStreamDelta(type: .error, content: nil)
        #expect(errorToken.type == .error)

        let toolToken = TextStreamDelta(type: .toolCallStart, content: nil)
        #expect(toolToken.type == .toolCallStart)
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
