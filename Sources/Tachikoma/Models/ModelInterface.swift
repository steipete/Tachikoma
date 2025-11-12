import Foundation

/// Modern model interface for AI providers integrated with the Tachikoma enum-based model system
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol ModelInterface: Sendable {
    /// The language model this interface handles
    var languageModel: LanguageModel { get }

    /// Masked API key for security (shows first 6 and last 2 characters)
    var maskedApiKey: String { get }

    /// Generate text using this model
    func generateText(request: ProviderRequest) async throws -> ProviderResponse

    /// Stream text generation using this model
    func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error>
}

/// Modern streaming types adapted from vendor/Tachikoma
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum StreamingDeltaType: Sendable, Codable {
    // Generate text using this model
    case textStart
    case textDelta
    case textEnd
    case toolCallStart
    case toolCallDelta
    case toolCallEnd
    case stepStart
    case stepEnd
    case done
    case error
}

/// Streaming delta for real-time responses
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct StreamingDelta: Sendable, Codable {
    public let type: StreamingDeltaType
    public let content: String?
    public let toolCall: AgentToolCall?
    public let toolResult: AgentToolResult?
    public let error: String?

    public init(
        type: StreamingDeltaType,
        content: String? = nil,
        toolCall: AgentToolCall? = nil,
        toolResult: AgentToolResult? = nil,
        error: String? = nil,
    ) {
        self.type = type
        self.content = content
        self.toolCall = toolCall
        self.toolResult = toolResult
        self.error = error
    }
}

/// Model settings adapted to work with enum-based models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ModelSettings: Sendable, Codable {
    public let modelName: String
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let frequencyPenalty: Double?
    public let presencePenalty: Double?
    public let stopSequences: [String]?
    public let stream: Bool

    /// Initialize from a LanguageModel and GenerationSettings
    public init(
        model: LanguageModel,
        settings: GenerationSettings = .default,
        stream: Bool = false,
    ) {
        self.modelName = model.modelId
        self.maxTokens = settings.maxTokens
        self.temperature = settings.temperature
        self.topP = settings.topP
        self.topK = settings.topK
        self.frequencyPenalty = settings.frequencyPenalty
        self.presencePenalty = settings.presencePenalty
        self.stopSequences = settings.stopSequences
        self.stream = stream
    }

    /// Legacy initializer for backward compatibility
    public init(
        modelName: String = "gpt-4",
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        stopSequences: [String]? = nil,
        stream: Bool = false,
    ) {
        self.modelName = modelName
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.stopSequences = stopSequences
        self.stream = stream
    }
}

/// Model request adapted to modern system
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ModelRequest: Sendable {
    public let messages: [ModelMessage]
    public let settings: ModelSettings
    public let tools: [AgentTool]?
    public let stream: Bool

    public init(
        messages: [ModelMessage],
        settings: ModelSettings,
        tools: [AgentTool]? = nil,
        stream: Bool = false,
    ) {
        self.messages = messages
        self.settings = settings
        self.tools = tools
        self.stream = stream
    }

    /// Create from modern ProviderRequest
    public init(from providerRequest: ProviderRequest, model: LanguageModel, stream: Bool = false) {
        self.messages = providerRequest.messages
        self.settings = ModelSettings(model: model, settings: providerRequest.settings, stream: stream)
        self.tools = providerRequest.tools
        self.stream = stream
    }
}

/// Model response adapted to modern system
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ModelResponse: Sendable {
    public let text: String
    public let finishReason: FinishReason?
    public let usage: Usage?
    public let toolCalls: [AgentToolCall]?
    public let model: String?

    public init(
        text: String,
        finishReason: FinishReason? = nil,
        usage: Usage? = nil,
        toolCalls: [AgentToolCall]? = nil,
        model: String? = nil,
    ) {
        self.text = text
        self.finishReason = finishReason
        self.usage = usage
        self.toolCalls = toolCalls
        self.model = model
    }

    /// Convert to ProviderResponse
    public func toProviderResponse() -> ProviderResponse {
        // Convert to ProviderResponse
        ProviderResponse(
            text: self.text,
            usage: self.usage,
            finishReason: self.finishReason,
            toolCalls: self.toolCalls,
        )
    }
}

/// Error handling adapted from vendor/Tachikoma
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum ModelError: Error, LocalizedError, Sendable {
    case invalidRequest(String)
    case authenticationFailed(String)
    case rateLimited(retryAfter: TimeInterval?)
    case modelNotFound(String)
    case apiError(statusCode: Int, message: String)
    case networkError(Error)
    case responseParsingError(String)
    case unsupportedFeature(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidRequest(message):
            "Invalid request: \(message)"
        case let .authenticationFailed(message):
            "Authentication failed: \(message)"
        case let .rateLimited(retryAfter):
            if let retryAfter {
                "Rate limited. Retry after \(retryAfter) seconds"
            } else {
                "Rate limited"
            }
        case let .modelNotFound(model):
            "Model not found: \(model)"
        case let .apiError(statusCode, message):
            "API error (\(statusCode)): \(message)"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case let .responseParsingError(message):
            "Response parsing error: \(message)"
        case let .unsupportedFeature(feature):
            "Unsupported feature: \(feature)"
        }
    }

    /// Convert to TachikomaError
    public func toTachikomaError() -> TachikomaError {
        // Convert to TachikomaError
        switch self {
        case let .invalidRequest(message):
            .invalidInput(message)
        case let .authenticationFailed(message):
            .authenticationFailed(message)
        case let .rateLimited(retryAfter):
            .rateLimited(retryAfter: retryAfter)
        case let .modelNotFound(model):
            .modelNotFound(model)
        case let .apiError(_, message):
            .apiError(message)
        case let .networkError(error):
            .networkError(error)
        case let .responseParsingError(message):
            .apiError(message)
        case let .unsupportedFeature(feature):
            .unsupportedOperation(feature)
        }
    }
}
