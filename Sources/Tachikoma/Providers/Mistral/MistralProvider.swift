import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provider for Mistral models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class MistralProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    private let model: LanguageModel.Mistral
    private let session: URLSession

    public init(
        model: LanguageModel.Mistral,
        configuration: TachikomaConfiguration,
        session: URLSession = .shared,
    ) throws {
        self.model = model
        self.modelId = model.rawValue
        self.baseURL = configuration.getBaseURL(for: .mistral) ?? "https://api.mistral.ai/v1"
        self.session = session

        if let key = configuration.getAPIKey(for: .mistral) {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("MISTRAL_API_KEY not found")
        }

        self.capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            contextLength: model.contextLength,
            maxOutputTokens: 4096,
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        // Use OpenAI-compatible implementation for Mistral
        try await OpenAICompatibleHelper.generateText(
            request: request,
            modelId: self.modelId,
            baseURL: self.baseURL!,
            apiKey: self.apiKey!,
            providerName: "Mistral",
            session: self.session,
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        // Use OpenAI-compatible streaming for Mistral
        try await OpenAICompatibleHelper.streamText(
            request: request,
            modelId: self.modelId,
            baseURL: self.baseURL!,
            apiKey: self.apiKey!,
            providerName: "Mistral",
            session: self.session,
        )
    }
}
