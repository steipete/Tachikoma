import Foundation
import Testing
@testable import Tachikoma

@Suite(.serialized)
struct ProviderSystemTests {
    // MARK: - Provider Factory Tests

    @Test
    func `Provider Factory - OpenAI Provider Creation`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            let model = Model.openai(.gpt55)
            let provider = try ProviderFactory.createProvider(for: model, configuration: config)

            #expect(provider.modelId == "gpt-5.5")
            #expect(provider.capabilities.supportsVision == true)
            #expect(provider.capabilities.supportsTools == true)
            #expect(provider.capabilities.supportsStreaming == true)
        }
    }

    @Test
    func `Provider Factory - Anthropic Provider Creation`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["anthropic": "test-key"]) { config in
            let model = Model.anthropic(.fable5)
            let provider = try ProviderFactory.createProvider(for: model, configuration: config)

            #expect(provider.modelId == "claude-fable-5")
            #expect(provider.capabilities.supportsVision == true)
            #expect(provider.capabilities.supportsTools == true)
            #expect(provider.capabilities.supportsStreaming == false)
            #expect(provider.capabilities.contextLength == 1_000_000)
            #expect(provider.capabilities.maxOutputTokens == 128_000)
        }
    }

    @Test
    func `Provider Factory - MiniMax Provider Creation`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["minimax": "test-key"]) { config in
            let model = Model.minimax(.m27)
            let provider = try ProviderFactory.createProvider(for: model, configuration: config)

            #expect(provider.modelId == "MiniMax-M2.7")
            #expect(provider.capabilities.supportsVision == false)
            #expect(provider.capabilities.supportsTools == true)
            #expect(provider.capabilities.supportsStreaming == true)
        }
    }

    @Test
    func `Provider Factory - Grok Provider Creation`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["grok": "test-key"]) { config in
            let model = Model.grok(.grok43)
            let provider = try ProviderFactory.createProvider(for: model, configuration: config)

            #expect(provider.modelId == "grok-4.3")
            #expect(provider.capabilities.supportsTools == true)
            #expect(provider.capabilities.supportsStreaming == true)
        }
    }

    @Test
    func `Provider Factory - Grok catalog coverage`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["grok": "test-key"]) { config in
            for grokModel in Model.Grok.allCases {
                let model = Model.grok(grokModel)
                let provider = try ProviderFactory.createProvider(for: model, configuration: config)
                #expect(provider.modelId == grokModel.modelId)
            }
        }
    }

    @Test
    func `Provider Factory - Ollama Provider Creation`() throws {
        // No API key needed for Ollama
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        let model = Model.ollama(.llama33)
        let provider = try ProviderFactory.createProvider(for: model, configuration: config)

        #expect(provider.modelId == "llama3.3")
        #expect(provider.capabilities.supportsTools == true)
        #expect(provider.capabilities.supportsStreaming == true)
    }

    @Test
    func `Provider Factory - Missing API Key Error`() async {
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
            let previousMiniMax = getenv("MINIMAX_API_KEY").flatMap { String(cString: $0) }
            let previousAnthropicCompatible = getenv("ANTHROPIC_COMPATIBLE_API_KEY").flatMap { String(cString: $0) }
            let previousGeneric = getenv("API_KEY").flatMap { String(cString: $0) }
            unsetenv("OPENAI_API_KEY")
            unsetenv("ANTHROPIC_API_KEY")
            unsetenv("MINIMAX_API_KEY")
            setenv("ANTHROPIC_COMPATIBLE_API_KEY", "generic-compatible-key", 1)
            setenv("API_KEY", "generic-key", 1)
            defer {
                if let previousOpenAI { setenv("OPENAI_API_KEY", previousOpenAI, 1) }
                if let previousAnthropic { setenv("ANTHROPIC_API_KEY", previousAnthropic, 1) }
                // swiftlint:disable:next statement_position
                if let previousMiniMax { setenv("MINIMAX_API_KEY", previousMiniMax, 1) }
                else { unsetenv("MINIMAX_API_KEY") }
                if let previousAnthropicCompatible {
                    setenv("ANTHROPIC_COMPATIBLE_API_KEY", previousAnthropicCompatible, 1)
                } else {
                    unsetenv("ANTHROPIC_COMPATIBLE_API_KEY")
                }
                if let previousGeneric { setenv("API_KEY", previousGeneric, 1) } else { unsetenv("API_KEY") }
            }

            #expect(throws: TachikomaError.self) {
                try OpenAIProvider(model: .gpt55, configuration: config)
            }

            #expect(throws: TachikomaError.self) {
                try AnthropicProvider(model: .opus4, configuration: config)
            }

            #expect(throws: TachikomaError.self) {
                try ProviderFactory.createProvider(for: .minimax(.m27), configuration: config)
            }
        }
    }

    // MARK: - Model Capabilities Tests

    @Test
    func `Model Capabilities - Vision Support`() {
        #expect(Model.openai(.gpt55).supportsVision == true)
        #expect(Model.openai(.gpt5Mini).supportsVision == true)
        #expect(Model.openai(.custom("text-only-openai")).supportsVision == false)

        #expect(Model.anthropic(.fable5).supportsVision == true)
        #expect(Model.anthropic(.opus4).supportsVision == true)
        #expect(Model.anthropic(.sonnet46).supportsVision == true)

        #expect(Model.grok(.grok43).supportsVision == true)

        #expect(Model.ollama(.llava).supportsVision == true)
        #expect(Model.ollama(.llama33).supportsVision == false)
        #expect(Model.ollama(.custom("qwen2.5vl:latest")).supportsVision == true)
    }

    @Test
    func `Model Capabilities - Tool Support`() {
        #expect(Model.openai(.gpt55).supportsTools == true)
        #expect(Model.openai(.gpt55).supportsTools == true)

        #expect(Model.anthropic(.fable5).supportsTools == true)
        #expect(Model.anthropic(.opus4).supportsTools == true)
        #expect(Model.anthropic(.sonnet46).supportsTools == true)

        #expect(Model.grok(.grok43).supportsTools == true)

        #expect(Model.ollama(.llama33).supportsTools == true)
        #expect(Model.ollama(.llava).supportsTools == false) // Vision models don't support tools
        #expect(Model.ollama(.custom("qwen2.5vl:latest")).supportsTools == false)
    }

    @Test
    func `Model Capabilities - Streaming Support`() {
        #expect(Model.openai(.gpt55).supportsStreaming == true)
        #expect(Model.anthropic(.opus4).supportsStreaming == true)
        #expect(Model.anthropic(.opus47).supportsStreaming == true)
        #expect(Model.anthropic(.opus48).supportsStreaming == false)
        #expect(Model.anthropic(.fable5).supportsStreaming == false)
        #expect(Model.openRouter(modelId: "anthropic/claude-fable-5").supportsStreaming == false)
        #expect(Model.openRouter(modelId: "fable5").supportsStreaming == false)
        #expect(Model.openRouter(modelId: "anthropic/claude-opus-4-8").supportsStreaming == false)
        #expect(Model.together(modelId: "claude-fable-5").supportsStreaming == false)
        #expect(Model.openaiCompatible(
            modelId: "anthropic/claude-fable-5",
            baseURL: "https://example.test",
        ).supportsStreaming == false)
        #expect(Model.openaiCompatible(
            modelId: "fable5",
            baseURL: "https://example.test",
        ).supportsStreaming == false)
        #expect(Model.openaiCompatible(
            modelId: "sonnet4-local",
            baseURL: "https://example.test",
        ).supportsStreaming == true)
        #expect(Model.grok(.grok43).supportsStreaming == true)
        #expect(Model.ollama(.llama33).supportsStreaming == true)
    }

    // MARK: - Generation Request Tests

    @Test
    func `Generation Request Basic Creation`() {
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

    @Test
    func `Generation Request With Images`() {
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

    @Test
    func `Stream Token Types`() {
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

    @Test
    func `Usage Statistics`() {
        let usage = Usage(inputTokens: 100, outputTokens: 50)

        #expect(usage.inputTokens == 100)
        #expect(usage.outputTokens == 50)
        #expect(usage.totalTokens == 150)
    }

    // MARK: - Finish Reason Tests

    @Test
    func `Finish Reason Cases`() {
        #expect(FinishReason.stop.rawValue == "stop")
        #expect(FinishReason.length.rawValue == "length")
        #expect(FinishReason.toolCalls.rawValue == "tool_calls")
        #expect(FinishReason.contentFilter.rawValue == "content_filter")
        #expect(FinishReason.other.rawValue == "other")
    }
}
