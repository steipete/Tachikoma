import Foundation

/// Provider for Groq models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class GroqProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    private let model: LanguageModel.Groq

    public init(model: LanguageModel.Groq, configuration: TachikomaConfiguration) throws {
        self.model = model
        modelId = model.rawValue
        baseURL = configuration.getBaseURL(for: .groq) ?? "https://api.groq.com/openai/v1"

        if let key = configuration.getAPIKey(for: .groq) {
            apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("GROQ_API_KEY not found")
        }

        capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            contextLength: model.contextLength,
            maxOutputTokens: 4096,
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        // Use OpenAI-compatible implementation for Groq
        try await OpenAICompatibleHelper.generateText(
            request: request,
            modelId: modelId,
            baseURL: baseURL!,
            apiKey: apiKey!,
            providerName: "Groq",
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        // Use OpenAI-compatible streaming for Groq
        try await OpenAICompatibleHelper.streamText(
            request: request,
            modelId: modelId,
            baseURL: baseURL!,
            apiKey: apiKey!,
            providerName: "Groq",
        )
    }
}
