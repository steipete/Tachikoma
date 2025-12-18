import Foundation

// MARK: - Provider Factory

/// Factory for creating model providers from LanguageModel enum
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ProviderFactory {
    /// Create a provider for the specified language model
    public static func createProvider(
        for model: LanguageModel,
        configuration: TachikomaConfiguration,
    ) throws
        -> any ModelProvider
    {
        // Create a provider for the specified language model
        switch model {
        case let .openai(openaiModel):
            // Use Responses API for reasoning models (o4) and GPT-5 family
            switch openaiModel {
            case .o4Mini,
                 .gpt52,
                 .gpt51,
                 .gpt5,
                 .gpt5Pro,
                 .gpt5Mini,
                 .gpt5Nano,
                 .gpt5Thinking,
                 .gpt5ThinkingMini,
                 .gpt5ThinkingNano,
                 .gpt5ChatLatest:
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
                modelId: lmstudioModel.modelId,
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

        case let .azureOpenAI(deployment, resource, apiVersion, endpoint):
            return try AzureOpenAIProvider(
                deploymentId: deployment,
                resource: resource,
                apiVersion: apiVersion,
                endpoint: endpoint,
                configuration: configuration,
            )

        case let .custom(provider):
            // If the custom provider is a dynamic selection string (providerId/model),
            // attempt to resolve via CustomProviderRegistry first.
            if let parsed = ProviderParser.parse(provider.modelId) {
                if let custom = CustomProviderRegistry.shared.get(parsed.provider) {
                    switch custom.kind {
                    case .openai:
                        return try OpenAICompatibleProvider(
                            modelId: parsed.model,
                            baseURL: custom.baseURL,
                            configuration: configuration,
                        )
                    case .anthropic:
                        return try AnthropicCompatibleProvider(
                            modelId: parsed.model,
                            baseURL: custom.baseURL,
                            configuration: configuration,
                        )
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
