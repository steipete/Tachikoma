import Testing
@testable import Tachikoma

@Suite("LanguageModel enums")
struct LanguageModelCoverageTests {
    @Test("OpenAI enum exposes properties")
    func openAIProperties() {
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

    @Test("Anthropic enum exposes properties")
    func anthropicProperties() {
        for model in LanguageModel.Anthropic.allCases {
            #expect(!model.modelId.isEmpty)
            _ = model.supportsVision
            _ = model.supportsTools
        }
    }

    @Test("Remaining provider enums expose properties")
    func otherProviders() {
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

    @Test("LanguageModel top level switches")
    func languageModelDescriptions() {
        let baseModels: [LanguageModel] = [
            .openai(.gpt51),
            .anthropic(.opus45),
            .google(.gemini25Flash),
            .mistral(.large2),
            .groq(.mixtral8x7b),
            .grok(.grok4),
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
    var modelId: String { "dummy" }
    var baseURL: String? { nil }
    var apiKey: String? { nil }
    var capabilities: ModelCapabilities { .init() }

    func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
        .init(text: "dummy")
    }

    func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
