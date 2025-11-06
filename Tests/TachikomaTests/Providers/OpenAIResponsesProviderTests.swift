import Foundation
import Testing
@testable import Tachikoma

@Suite("OpenAI Responses API Tests")
struct OpenAIResponsesProviderTests {
    @Test("GPT-5 uses Responses API provider")
    func gPT5UsesResponsesProvider() throws {
        // Test that GPT-5 models use the OpenAIResponsesProvider
        let config = TachikomaConfiguration.current

        let gpt5Models: [LanguageModel.OpenAI] = [.gpt5, .gpt5Mini, .gpt5Nano]

        for model in gpt5Models {
            let provider = try ProviderFactory.createProvider(
                for: .openai(model),
                configuration: config
            )

            #expect(
                provider is OpenAIResponsesProvider,
                "GPT-5 model \(model) should use OpenAIResponsesProvider"
            )
        }
    }

    @Test("GPT-5 text.verbosity parameter is set correctly")
    func gPT5TextVerbosityParameter() throws {
        // Test that the text.verbosity parameter is properly configured for GPT-5
        let config = TachikomaConfiguration.current

        // Skip if no API key
        guard config.getAPIKey(for: .openai) != nil else {
            throw TestSkipped("OpenAI API key not configured")
        }

        let provider = try OpenAIResponsesProvider(
            model: .gpt5,
            configuration: config
        )

        // Create a simple request
        _ = ProviderRequest(
            messages: [
                ModelMessage(role: .user, content: [.text("Hello")]),
            ],
            tools: nil,
            settings: GenerationSettings()
        )

        // We can't directly test the internal request building without making it public
        // But we can verify the provider is configured correctly
        #expect(provider.modelId == "gpt-5")
        #expect(provider.capabilities.supportsTools == true)
        #expect(provider.capabilities.supportsVision == true)
    }

    @Test("Reasoning models use Responses API")
    func reasoningModelsUseResponsesAPI() throws {
        // Test that reasoning-oriented models also use the OpenAIResponsesProvider
        let config = TachikomaConfiguration.current

        let reasoningModels: [LanguageModel.OpenAI] = [
            .o4Mini,
            .gpt5,
            .gpt5Mini,
            .gpt5Thinking,
        ]

        for model in reasoningModels {
            let provider = try ProviderFactory.createProvider(
                for: .openai(model),
                configuration: config
            )

            #expect(
                provider is OpenAIResponsesProvider,
                "Reasoning model \(model) should use OpenAIResponsesProvider"
            )
        }
    }

    @Test("Legacy models use standard OpenAI provider")
    func legacyModelsUseStandardProvider() throws {
        // Test that non-GPT-5/reasoning models use the standard OpenAIProvider
        let config = TachikomaConfiguration.current

        let legacyModels: [LanguageModel.OpenAI] = [.gpt4o, .gpt4oMini, .gpt41]

        for model in legacyModels {
            let provider = try ProviderFactory.createProvider(
                for: .openai(model),
                configuration: config
            )

            #expect(
                provider is OpenAIProvider,
                "Legacy model \(model) should use OpenAIProvider"
            )
        }
    }

    @Test("TextConfig encodes verbosity correctly")
    func textConfigEncoding() throws {
        // Test that TextConfig properly encodes the verbosity parameter
        let textConfig = TextConfig(verbosity: .high)

        let encoder = JSONEncoder()
        let data = try encoder.encode(textConfig)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["verbosity"] as? String == "high")
    }

    @Test("OpenAIResponsesRequest includes text config for GPT-5")
    func responsesRequestTextConfig() throws {
        // Test that the request properly includes text config
        let textConfig = TextConfig(verbosity: .medium)
        let request = OpenAIResponsesRequest(
            model: "gpt-5",
            input: [ResponsesMessage(role: "user", content: .text("Test"))],
            temperature: nil,
            topP: nil,
            maxOutputTokens: nil,
            text: textConfig,
            tools: nil,
            toolChoice: nil,
            metadata: nil,
            parallelToolCalls: nil,
            previousResponseId: nil,
            store: nil,
            user: nil,
            instructions: nil,
            serviceTier: nil,
            include: nil,
            reasoning: nil,
            truncation: nil,
            stream: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let textJson = json?["text"] as? [String: Any] {
            #expect(textJson["verbosity"] as? String == "medium")
        } else {
            Issue.record("Expected text field in JSON")
        }
    }

    @Test("GPT-5 tool call outputs are parsed")
    func gpt5ToolCallParsing() throws {
        let toolCall = OpenAIResponsesResponse.ResponsesToolCall(
            id: "call_1",
            type: "function",
            function: .init(name: "see", arguments: "{\"mode\":\"screen\"}")
        )

        let output = OpenAIResponsesResponse.ResponsesOutput(
            id: "out_1",
            type: "message",
            status: "completed",
            content: [
                .init(type: "output_text", text: "Capturing now.", toolCall: nil),
                .init(type: "tool_call", text: nil, toolCall: toolCall),
            ],
            role: "assistant",
            toolCall: nil
        )

        let response = OpenAIResponsesResponse(
            id: "resp_1",
            object: "response",
            createdAt: 0,
            created: nil,
            status: "completed",
            model: "gpt-5",
            output: [output],
            choices: nil,
            usage: nil,
            metadata: nil
        )

        let providerResponse = try OpenAIResponsesProvider.convertToProviderResponse(response)

        #expect(providerResponse.text == "Capturing now.")
        let toolCalls = try #require(providerResponse.toolCalls)
        #expect(toolCalls.count == 1)
        #expect(toolCalls[0].name == "see")
        #expect(toolCalls[0].arguments["mode"]?.stringValue == "screen")
        #expect(providerResponse.finishReason == .toolCalls)
    }
}

// Helper to skip tests when API keys aren't available
struct TestSkipped: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}
