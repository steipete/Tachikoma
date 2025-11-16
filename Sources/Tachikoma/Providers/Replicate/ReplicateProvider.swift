import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provider for Replicate models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class ReplicateProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    private let session: URLSession

    public init(
        modelId: String,
        configuration: TachikomaConfiguration,
        session: URLSession = .shared,
    ) throws {
        self.modelId = modelId
        self.baseURL = configuration.getBaseURL(for: .custom("replicate")) ?? "https://api.replicate.com/v1"
        self.session = session

        if let key = configuration.getAPIKey(for: .custom("replicate")) {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("REPLICATE_API_TOKEN not found")
        }

        self.capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTools: false, // Most Replicate models don't support tools
            supportsStreaming: true,
            contextLength: 32000,
            maxOutputTokens: 4096,
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        guard let baseURL, let apiKey else {
            throw TachikomaError.invalidConfiguration("Replicate provider missing base URL or API key")
        }

        var headers = [String: String]()
        if ProcessInfo.processInfo.environment["REPLICATE_PREFERRED_OUTPUT"] == "turbo" {
            headers["Prefer"] = "wait=false"
        }

        return try await OpenAICompatibleHelper.generateText(
            request: request,
            modelId: self.modelId,
            baseURL: baseURL,
            apiKey: apiKey,
            providerName: "Replicate",
            additionalHeaders: headers,
            session: self.session,
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        guard let baseURL, let apiKey else {
            throw TachikomaError.invalidConfiguration("Replicate provider missing base URL or API key")
        }

        return try await OpenAICompatibleHelper.streamText(
            request: request,
            modelId: self.modelId,
            baseURL: baseURL,
            apiKey: apiKey,
            providerName: "Replicate",
            session: self.session,
        )
    }
}
