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
    private let auth: TKAuthValue

    public init(
        model: LanguageModel.OpenAI,
        configuration: TachikomaConfiguration,
        session: URLSession = .shared,
    ) throws {
        self.model = model
        self.modelId = model.modelId
        self.baseURL = configuration.getBaseURL(for: .openai) ?? "https://api.openai.com/v1"
        self.session = session

        // Prefer configuration-provided key first (test configs use this)
        if let key = configuration.getAPIKey(for: .openai) {
            self.auth = .bearer(key, betaHeader: nil)
            self.apiKey = key
        } else if let auth = TKAuthManager.shared.resolveAuth(for: .openai) {
            self.auth = auth
            switch auth {
            case let .apiKey(key):
                self.apiKey = key
            case let .bearer(token, _):
                self.apiKey = token
            }
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

        let (authHeaderName, prefix, secret) = self.authHeader()
        // Use shared OpenAI-compatible implementation
        return try await OpenAICompatibleHelper.generateText(
            request: request,
            modelId: self.modelId,
            baseURL: self.baseURL!,
            apiKey: secret,
            providerName: "OpenAI",
            authHeaderName: authHeaderName,
            authHeaderValuePrefix: prefix,
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

        let (authHeaderName, prefix, secret) = self.authHeader()
        // Use shared OpenAI-compatible implementation
        return try await OpenAICompatibleHelper.streamText(
            request: request,
            modelId: self.modelId,
            baseURL: self.baseURL!,
            apiKey: secret,
            providerName: "OpenAI",
            authHeaderName: authHeaderName,
            authHeaderValuePrefix: prefix,
            additionalHeaders: additionalHeaders,
            session: self.session,
        )
    }

    private func authHeader() -> (String, String, String) {
        switch self.auth {
        case let .apiKey(key):
            ("Authorization", "Bearer ", key)
        case let .bearer(token, _):
            ("Authorization", "Bearer ", token)
        }
    }
}
