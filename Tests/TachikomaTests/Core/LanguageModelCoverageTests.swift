import Testing
@testable import Tachikoma

struct LanguageModelCoverageTests {
    @Test
    func `OpenAI enum exposes properties`() {
        let models = LanguageModel.OpenAI.allCases
        #expect(!models.isEmpty)
        for model in models {
            #expect(!model.modelId.isEmpty)
            _ = model.supportsVision
            _ = model.supportsTools
            _ = model.supportsAudioInput
            _ = model.supportsAudioOutput
            _ = model.supportsRealtime
            #expect(model.contextLength > 0)
        }
    }

    @Test
    func `Anthropic enum exposes properties`() {
        for model in LanguageModel.Anthropic.allCases {
            #expect(!model.modelId.isEmpty)
            _ = model.supportsVision
            _ = model.supportsTools
        }
    }

    @Test
    func `Remaining provider enums expose properties`() {
        for model in LanguageModel.Google.allCases {
            #expect(!model.rawValue.isEmpty)
            _ = model.supportsVision
            _ = model.supportsTools
        }

        for model in LanguageModel.Mistral.allCases {
            #expect(!model.rawValue.isEmpty)
            _ = model.supportsVision
            _ = model.supportsTools
        }

        for model in LanguageModel.Groq.allCases {
            #expect(!model.rawValue.isEmpty)
            _ = model.supportsVision
            _ = model.supportsTools
        }

        for model in LanguageModel.Grok.allCases {
            #expect(!model.modelId.isEmpty)
            _ = model.supportsVision
            #expect(model.contextLength > 0)
        }

        for model in LanguageModel.MiniMax.allCases {
            #expect(!model.modelId.isEmpty)
            _ = model.supportsVision
            _ = model.supportsTools
            #expect(model.contextLength > 0)
        }

        for model in LanguageModel.Ollama.allCases {
            #expect(!model.modelId.isEmpty)
            _ = model.supportsVision
            _ = model.supportsTools
        }

        for model in LanguageModel.LMStudio.allCases {
            #expect(!model.modelId.isEmpty)
            _ = model.supportsVision
            _ = model.supportsTools
        }
    }

    @Test
    func `LanguageModel top level switches`() {
        let baseModels: [LanguageModel] = [
            .openai(.gpt55),
            .anthropic(.fable5),
            .google(.gemini35Flash),
            .mistral(.medium35),
            .groq(.llama3370b),
            .grok(.grok43),
            .minimax(.m27),
            .minimaxCN(.m27),
            .ollama(.llama33),
            .lmstudio(.gptOSS20B),
            .openRouter(modelId: "openrouter/alpha"),
            .together(modelId: "together/beta"),
            .replicate(modelId: "replicate/gamma"),
            .openaiCompatible(modelId: "compat", baseURL: "https://example.com"),
            .anthropicCompatible(modelId: "claude-proxy", baseURL: "https://proxy"),
            .custom(provider: DummyProvider()),
        ]

        for model in baseModels {
            #expect(!model.description.isEmpty)
            #expect(!model.modelId.isEmpty)
            _ = model.supportsVision
            _ = model.supportsTools
            _ = model.supportsStreaming
            _ = model.supportsAudioInput
            _ = model.supportsAudioOutput
            _ = model.supportsStreaming
            _ = model.contextLength
        }
    }
}

private struct DummyProvider: ModelProvider {
    var modelId: String {
        "dummy"
    }

    var baseURL: String? {
        nil
    }

    var apiKey: String? {
        nil
    }

    var capabilities: ModelCapabilities {
        .init()
    }

    func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
        .init(text: "dummy")
    }

    func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
