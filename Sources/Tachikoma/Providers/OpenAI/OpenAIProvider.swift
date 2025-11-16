import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provider for OpenAI models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class OpenAIProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    private let model: LanguageModel.OpenAI
    private let session: URLSession

    public init(
        model: LanguageModel.OpenAI,
        configuration: TachikomaConfiguration,
        session: URLSession = .shared,
    ) throws {
        self.model = model
        self.modelId = model.modelId
        self.baseURL = configuration.getBaseURL(for: .openai) ?? "https://api.openai.com/v1"
        self.session = session

        // Get API key from configuration system (environment or credentials)
        if let key = configuration.getAPIKey(for: .openai) {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("OPENAI_API_KEY not found")
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
        // Build OpenAI-specific headers
        var additionalHeaders: [String: String] = [:]
        if let orgId = ProcessInfo.processInfo.environment["OPENAI_ORG_ID"] {
            additionalHeaders["OpenAI-Organization"] = orgId
        }

        // Use shared OpenAI-compatible implementation
        return try await OpenAICompatibleHelper.generateText(
            request: request,
            modelId: self.modelId,
            baseURL: self.baseURL!,
            apiKey: self.apiKey!,
            providerName: "OpenAI",
            additionalHeaders: additionalHeaders,
            session: self.session,
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        // Build OpenAI-specific headers
        var additionalHeaders: [String: String] = [:]
        if let orgId = ProcessInfo.processInfo.environment["OPENAI_ORG_ID"] {
            additionalHeaders["OpenAI-Organization"] = orgId
        }

        // Use shared OpenAI-compatible implementation
        return try await OpenAICompatibleHelper.streamText(
            request: request,
            modelId: self.modelId,
            baseURL: self.baseURL!,
            apiKey: self.apiKey!,
            providerName: "OpenAI",
            additionalHeaders: additionalHeaders,
            session: self.session,
        )
    }
}
