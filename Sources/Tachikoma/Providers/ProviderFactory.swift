import Foundation

// MARK: - Provider Factory

/// Factory for creating model providers from LanguageModel enum
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ProviderFactory {
    /// Create a provider for the specified language model
    public static func createProvider(for model: LanguageModel) throws -> any ModelProvider {
        // Check if we're in test mode or if API tests are disabled
        if TachikomaConfiguration.shared.isTestMode ||
           ProcessInfo.processInfo.environment["TACHIKOMA_DISABLE_API_TESTS"] == "true" ||
           ProcessInfo.processInfo.environment["TACHIKOMA_TEST_MODE"] == "mock" {
            return MockProvider(model: model)
        }

        switch model {
        case let .openai(openaiModel):
            return try OpenAIProvider(model: openaiModel)

        case let .anthropic(anthropicModel):
            return try AnthropicProvider(model: anthropicModel)

        case let .google(googleModel):
            return try GoogleProvider(model: googleModel)

        case let .mistral(mistralModel):
            return try MistralProvider(model: mistralModel)

        case let .groq(groqModel):
            return try GroqProvider(model: groqModel)

        case let .grok(grokModel):
            return try GrokProvider(model: grokModel)

        case let .ollama(ollamaModel):
            return try OllamaProvider(model: ollamaModel)

        case let .openRouter(modelId):
            return try OpenRouterProvider(modelId: modelId)

        case let .together(modelId):
            return try TogetherProvider(modelId: modelId)

        case let .replicate(modelId):
            return try ReplicateProvider(modelId: modelId)

        case let .openaiCompatible(modelId, baseURL):
            return try OpenAICompatibleProvider(modelId: modelId, baseURL: baseURL)

        case let .anthropicCompatible(modelId, baseURL):
            return try AnthropicCompatibleProvider(modelId: modelId, baseURL: baseURL)

        case let .custom(provider):
            return provider
        }
    }
}

// MARK: - Third-Party Aggregators




// MARK: - Compatible Providers



// MARK: - Mock Provider for Testing

