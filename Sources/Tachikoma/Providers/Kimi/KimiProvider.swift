import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provider for Kimi models hosted by Moonshot AI.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class KimiProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    private let session: URLSession

    public init(
        model: LanguageModel.Kimi,
        configuration: TachikomaConfiguration,
        session: URLSession = .shared,
    ) throws {
        self.modelId = model.modelId
        self.baseURL = configuration.getBaseURL(for: .kimi) ?? Provider.kimi.defaultBaseURL
        self.session = session

        guard let apiKey = configuration.getAPIKey(for: .kimi) else {
            throw TachikomaError.authenticationFailed("MOONSHOT_API_KEY not found")
        }
        self.apiKey = apiKey
        self.capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            contextLength: model.contextLength,
            maxOutputTokens: 32768,
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        try await OpenAICompatibleHelper.generateText(
            request: request,
            modelId: self.modelId,
            baseURL: self.baseURL!,
            apiKey: self.apiKey!,
            providerName: "Kimi",
            session: self.session,
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        try await OpenAICompatibleHelper.streamText(
            request: request,
            modelId: self.modelId,
            baseURL: self.baseURL!,
            apiKey: self.apiKey!,
            providerName: "Kimi",
            session: self.session,
        )
    }
}
