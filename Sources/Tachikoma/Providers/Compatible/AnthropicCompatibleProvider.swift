import Foundation

/// Provider for Anthropic-compatible APIs
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class AnthropicCompatibleProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let additionalHeaders: [String: String]
    public let capabilities: ModelCapabilities
    private let configuration: TachikomaConfiguration
    private let auth: TKAuthValue?
    private let reasoningProvider: String
    private let reasoningBaseURL: String?

    public init(
        modelId: String,
        baseURL: String,
        configuration: TachikomaConfiguration,
        apiKey: String? = nil,
        additionalHeaders: [String: String] = [:],
        auth: TKAuthValue? = nil,
        capabilities: ModelCapabilities? = nil,
        reasoningProvider: String = "anthropic-compatible",
        reasoningBaseURL: String? = nil,
        includeReasoningBaseURL: Bool = true,
    ) throws {
        self.modelId = modelId
        self.baseURL = baseURL
        self.configuration = configuration
        self.additionalHeaders = additionalHeaders
        self.reasoningProvider = reasoningProvider
        self.reasoningBaseURL = includeReasoningBaseURL ? (reasoningBaseURL ?? baseURL) : nil

        // Try explicit provider key, then configuration, then common environment variable patterns.
        if let key = apiKey {
            self.apiKey = key
            self.auth = auth ?? .apiKey(key)
        } else if let key = configuration.getAPIKey(for: .custom("anthropic_compatible")) {
            self.apiKey = key
            self.auth = auth ?? .apiKey(key)
        } else if
            let key = ProcessInfo.processInfo.environment["ANTHROPIC_COMPATIBLE_API_KEY"] ??
            ProcessInfo.processInfo.environment["API_KEY"]
        {
            self.apiKey = key
            self.auth = auth ?? .apiKey(key)
        } else if let auth {
            self.auth = auth
            switch auth {
            case let .apiKey(key):
                self.apiKey = key
            case let .bearer(token, _):
                self.apiKey = token
            }
        } else {
            self.apiKey = nil
            self.auth = nil
        }

        let isFable = LanguageModel.Anthropic.isFable(modelId: modelId)
        let supportsSafeStreaming = !LanguageModel.Anthropic.hasStreamingRefusalRisk(modelId: modelId)
        let baseCapabilities = capabilities ?? ModelCapabilities(
            supportsVision: true,
            supportsTools: true,
            supportsStreaming: supportsSafeStreaming,
            contextLength: isFable ? 1_000_000 : 200_000,
            maxOutputTokens: isFable ? 128_000 : 8192,
        )
        self.capabilities = supportsSafeStreaming ? baseCapabilities : ModelCapabilities(
            supportsVision: baseCapabilities.supportsVision,
            supportsTools: baseCapabilities.supportsTools,
            supportsStreaming: false,
            supportsAudioInput: baseCapabilities.supportsAudioInput,
            supportsAudioOutput: baseCapabilities.supportsAudioOutput,
            contextLength: baseCapabilities.contextLength,
            maxOutputTokens: baseCapabilities.maxOutputTokens,
            costPerToken: baseCapabilities.costPerToken,
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        let provider = try makeAnthropicProvider()
        return try await provider.generateText(request: request)
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        let provider = try makeAnthropicProvider()
        return try await provider.streamText(request: request)
    }

    private func makeAnthropicProvider() throws -> AnthropicProvider {
        guard let apiKey else {
            throw TachikomaError.authenticationFailed("ANTHROPIC_COMPATIBLE_API_KEY not found")
        }

        let compatConfig = TachikomaConfiguration(loadFromEnvironment: false)
        compatConfig.setAPIKey(apiKey, for: .anthropic)
        if let baseURL {
            compatConfig.setBaseURL(baseURL, for: .anthropic)
        }

        // Propagate verbose flag/settings from original configuration if set
        compatConfig.setVerbose(self.configuration.verbose)

        return try AnthropicProvider(
            model: .custom(self.modelId),
            configuration: compatConfig,
            additionalHeaders: self.additionalHeaders,
            authOverride: self.auth,
            reasoningProvider: self.reasoningProvider,
            reasoningModelId: self.modelId,
            reasoningBaseURL: self.reasoningBaseURL,
        )
    }
}
