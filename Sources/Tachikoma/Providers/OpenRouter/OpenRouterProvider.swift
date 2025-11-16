import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provider for OpenRouter models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class OpenRouterProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    private let session: URLSession
    private let defaultHeaders: [String: String]

    public init(
        modelId: String,
        configuration: TachikomaConfiguration,
        session: URLSession = .shared,
    ) throws {
        self.modelId = modelId
        self.baseURL = configuration.getBaseURL(for: .custom("openrouter")) ?? "https://openrouter.ai/api/v1"
        self.session = session

        if let key = configuration.getAPIKey(for: .custom("openrouter")) {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("OPENROUTER_API_KEY not found")
        }

        self.capabilities = ModelCapabilities(
            supportsVision: true,
            supportsTools: true,
            supportsStreaming: true,
            contextLength: 128_000,
            maxOutputTokens: 4096,
        )

        self.defaultHeaders = [
            "HTTP-Referer": ProcessInfo.processInfo.environment["OPENROUTER_REFERER"] ?? "https://peekaboo.app",
            "X-Title": ProcessInfo.processInfo.environment["OPENROUTER_TITLE"] ?? "Peekaboo",
        ]
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        guard let baseURL, let apiKey else {
            throw TachikomaError.invalidConfiguration("OpenRouter provider missing base URL or API key")
        }

        return try await OpenAICompatibleHelper.generateText(
            request: request,
            modelId: self.modelId,
            baseURL: baseURL,
            apiKey: apiKey,
            providerName: "OpenRouter",
            additionalHeaders: self.defaultHeaders,
            session: self.session,
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        guard let baseURL, let apiKey else {
            throw TachikomaError.invalidConfiguration("OpenRouter provider missing base URL or API key")
        }

        return try await OpenAICompatibleHelper.streamText(
            request: request,
            modelId: self.modelId,
            baseURL: baseURL,
            apiKey: apiKey,
            providerName: "OpenRouter",
            additionalHeaders: self.defaultHeaders,
            session: self.session,
        )
    }
}
