import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provider for OpenAI-compatible APIs
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class OpenAICompatibleProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let additionalHeaders: [String: String]
    public let capabilities: ModelCapabilities
    private let session: URLSession

    public init(
        modelId: String,
        baseURL: String,
        configuration: TachikomaConfiguration,
        apiKey: String? = nil,
        additionalHeaders: [String: String] = [:],
        session: URLSession = .shared,
    ) throws {
        self.modelId = modelId
        self.baseURL = baseURL
        self.additionalHeaders = additionalHeaders
        self.session = session

        // Try explicit provider key, then configuration, then common environment variable patterns.
        if let key = apiKey {
            self.apiKey = key
        } else if let key = configuration.getAPIKey(for: .custom("openai_compatible")) {
            self.apiKey = key
        } else if
            let key = ProcessInfo.processInfo.environment["OPENAI_COMPATIBLE_API_KEY"] ??
            ProcessInfo.processInfo.environment["API_KEY"]
        {
            self.apiKey = key
        } else {
            self.apiKey = nil // Some compatible APIs don't require keys
        }

        let isFable = LanguageModel.Anthropic.isFable(modelId: modelId)
        self.capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTools: true,
            supportsStreaming: !LanguageModel.Anthropic.hasStreamingRefusalRisk(modelId: modelId),
            contextLength: isFable ? 1_000_000 : 128_000,
            maxOutputTokens: isFable ? 128_000 : 4096,
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        // Use OpenAI-compatible implementation
        try await OpenAICompatibleHelper.generateText(
            request: request,
            modelId: self.modelId,
            baseURL: self.baseURL!,
            apiKey: self.apiKey ?? "",
            providerName: "OpenAICompatible",
            additionalHeaders: self.additionalHeaders,
            session: self.session,
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        guard !LanguageModel.Anthropic.hasStreamingRefusalRisk(modelId: self.modelId) else {
            throw TachikomaError.invalidConfiguration("\(self.modelId) does not support streaming")
        }

        // Use OpenAI-compatible streaming implementation
        return try await OpenAICompatibleHelper.streamText(
            request: request,
            modelId: self.modelId,
            baseURL: self.baseURL!,
            apiKey: self.apiKey ?? "",
            providerName: "OpenAICompatible",
            additionalHeaders: self.additionalHeaders,
            session: self.session,
        )
    }
}
