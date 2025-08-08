import Foundation

// MARK: - Provider Factory

/// Factory for creating model providers from LanguageModel enum
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@MainActor
public struct ProviderFactory {
    /// Create a provider for the specified language model
    public static func createProvider(for model: LanguageModel, configuration: TachikomaConfiguration) async throws -> any ModelProvider {
        switch model {
        case let .openai(openaiModel):
            // Use Responses API for reasoning models (o3, o4) only
            // GPT-5 uses regular Chat Completions API
            switch openaiModel {
            case .o3, .o3Mini, .o3Pro, .o4Mini:
                return try OpenAIResponsesProvider(model: openaiModel, configuration: configuration)
            default:
                return try OpenAIProvider(model: openaiModel, configuration: configuration)
            }

        case let .anthropic(anthropicModel):
            return try AnthropicProvider(model: anthropicModel, configuration: configuration)

        case let .google(googleModel):
            return try GoogleProvider(model: googleModel, configuration: configuration)

        case let .mistral(mistralModel):
            return try MistralProvider(model: mistralModel, configuration: configuration)

        case let .groq(groqModel):
            return try GroqProvider(model: groqModel, configuration: configuration)

        case let .grok(grokModel):
            return try GrokProvider(model: grokModel, configuration: configuration)

        case let .ollama(ollamaModel):
            return try OllamaProvider(model: ollamaModel, configuration: configuration)

        case let .lmstudio(lmstudioModel):
            // LMStudio doesn't need API key, just use default configuration
            let baseURL = configuration.getBaseURL(for: "lmstudio") ?? "http://localhost:1234/v1"
            return LMStudioProvider(
                baseURL: baseURL,
                modelId: lmstudioModel.modelId
            )

        case let .openRouter(modelId):
            return try OpenRouterProvider(modelId: modelId, configuration: configuration)

        case let .together(modelId):
            return try TogetherProvider(modelId: modelId, configuration: configuration)

        case let .replicate(modelId):
            return try ReplicateProvider(modelId: modelId, configuration: configuration)

        case let .openaiCompatible(modelId, baseURL):
            return try OpenAICompatibleProvider(modelId: modelId, baseURL: baseURL, configuration: configuration)

        case let .anthropicCompatible(modelId, baseURL):
            return try AnthropicCompatibleProvider(modelId: modelId, baseURL: baseURL, configuration: configuration)

        case let .custom(provider):
            // If the custom provider is a dynamic selection string (providerId/model),
            // attempt to resolve via CustomProviderRegistry first.
            if let parsed = ProviderParser.parse(provider.modelId) {
                if let custom = CustomProviderRegistry.shared.get(parsed.provider) {
                    switch custom.kind {
                    case .openai:
                        return try OpenAICompatibleProvider(modelId: parsed.model, baseURL: custom.baseURL, configuration: configuration)
                    case .anthropic:
                        return try AnthropicCompatibleProvider(modelId: parsed.model, baseURL: custom.baseURL, configuration: configuration)
                    }
                }
            }
            return provider
        }
    }
}

// MARK: - Third-Party Aggregators




// MARK: - Compatible Providers



// MARK: - Mock Provider for Testing

