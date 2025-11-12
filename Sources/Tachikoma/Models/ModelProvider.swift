import Foundation

// MARK: - Model Provider Protocol

/// Protocol for AI model providers
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol ModelProvider: Sendable {
    var modelId: String { get }
    var baseURL: String? { get }
    var apiKey: String? { get }
    var capabilities: ModelCapabilities { get }

    /// Execute a single-shot generation request against the provider.
    func generateText(request: ProviderRequest) async throws -> ProviderResponse
    /// Stream partial responses for providers that support incremental output.
    func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error>
}

/// Model capabilities
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ModelCapabilities: Sendable {
    public let supportsVision: Bool
    public let supportsTools: Bool
    public let supportsStreaming: Bool
    public let supportsAudioInput: Bool
    public let supportsAudioOutput: Bool
    public let contextLength: Int
    public let maxOutputTokens: Int
    public let costPerToken: (input: Double, output: Double)?

    public init(
        supportsVision: Bool = false,
        supportsTools: Bool = true,
        supportsStreaming: Bool = true,
        supportsAudioInput: Bool = false,
        supportsAudioOutput: Bool = false,
        contextLength: Int = 128_000,
        maxOutputTokens: Int = 4096,
        costPerToken: (input: Double, output: Double)? = nil,
    ) {
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.supportsStreaming = supportsStreaming
        self.supportsAudioInput = supportsAudioInput
        self.supportsAudioOutput = supportsAudioOutput
        self.contextLength = contextLength
        self.maxOutputTokens = maxOutputTokens
        self.costPerToken = costPerToken
    }
}

// MARK: - Provider Request/Response Types

/// Request to a model provider
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ProviderRequest: Sendable {
    public let messages: [ModelMessage]
    public let tools: [AgentTool]?
    public let settings: GenerationSettings
    public let outputFormat: OutputFormat?

    public enum OutputFormat: Sendable {
        case text
        case json
    }

    public init(
        messages: [ModelMessage],
        tools: [AgentTool]? = nil,
        settings: GenerationSettings = .default,
        outputFormat: OutputFormat? = nil,
    ) {
        self.messages = messages
        self.tools = tools
        self.settings = settings
        self.outputFormat = outputFormat
    }
}

/// Response from a model provider
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ProviderResponse: Sendable {
    public let text: String
    public let usage: Usage?
    public let finishReason: FinishReason?
    public let toolCalls: [AgentToolCall]?

    public init(
        text: String,
        usage: Usage? = nil,
        finishReason: FinishReason? = nil,
        toolCalls: [AgentToolCall]? = nil,
    ) {
        self.text = text
        self.usage = usage
        self.finishReason = finishReason
        self.toolCalls = toolCalls
    }
}
