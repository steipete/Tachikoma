import Foundation

/// Provider for OpenAI-compatible APIs
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class OpenAICompatibleProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    public init(modelId: String, baseURL: String, configuration: TachikomaConfiguration) throws {
        self.modelId = modelId
        self.baseURL = baseURL

        // Try to get API key from configuration, otherwise try common environment variable patterns
        if let key = configuration.getAPIKey(for: .custom("openai_compatible")) {
            self.apiKey = key
        } else if
            let key = ProcessInfo.processInfo.environment["OPENAI_COMPATIBLE_API_KEY"] ??
            ProcessInfo.processInfo.environment["API_KEY"]
        {
            self.apiKey = key
        } else {
            self.apiKey = nil // Some compatible APIs don't require keys
        }

        self.capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTools: true,
            supportsStreaming: true,
            contextLength: 128_000,
            maxOutputTokens: 4096,
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
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        // Use OpenAI-compatible streaming implementation
        try await OpenAICompatibleHelper.streamText(
            request: request,
            modelId: self.modelId,
            baseURL: self.baseURL!,
            apiKey: self.apiKey ?? "",
            providerName: "OpenAICompatible",
        )
    }
}
