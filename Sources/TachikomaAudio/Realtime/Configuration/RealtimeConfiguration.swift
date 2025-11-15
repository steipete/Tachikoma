import Foundation
import Tachikoma

// MARK: - Turn Detection Configuration

/// Configuration for server-side Voice Activity Detection (VAD)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct RealtimeTurnDetection: Sendable, Codable {
    /// Type of turn detection
    public let type: TurnDetectionType

    /// Activation threshold for VAD (0.0 to 1.0)
    public let threshold: Float?

    /// Amount of silence (in milliseconds) before ending turn
    public let silenceDurationMs: Int?

    /// Prefix padding duration in milliseconds
    public let prefixPaddingMs: Int?

    /// Create VAD for interruption handling
    public let createResponse: Bool?

    public enum TurnDetectionType: String, Sendable, Codable {
        case serverVad = "server_vad"
        case none
    }

    public init(
        type: TurnDetectionType = .serverVad,
        threshold: Float? = 0.5,
        silenceDurationMs: Int? = 200,
        prefixPaddingMs: Int? = 300,
        createResponse: Bool? = true,
    ) {
        self.type = type
        self.threshold = threshold
        self.silenceDurationMs = silenceDurationMs
        self.prefixPaddingMs = prefixPaddingMs
        self.createResponse = createResponse
    }

    /// Default server VAD configuration
    public static let serverVAD = RealtimeTurnDetection(
        type: .serverVad,
        threshold: 0.5,
        silenceDurationMs: 200,
        prefixPaddingMs: 300,
        createResponse: true,
    )

    /// Disable turn detection
    public static let disabled = RealtimeTurnDetection(
        type: .none,
        threshold: nil,
        silenceDurationMs: nil,
        prefixPaddingMs: nil,
        createResponse: false,
    )
}

// MARK: - Response Modalities

/// Control which modalities are used in responses
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ResponseModality: OptionSet, Sendable, Codable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Text responses
    public static let text = ResponseModality(rawValue: 1 << 0)

    /// Audio responses
    public static let audio = ResponseModality(rawValue: 1 << 1)

    /// Both text and audio
    public static let all: ResponseModality = [.text, .audio]

    /// Convert to API array format
    public var toArray: [String] {
        var result: [String] = []
        if contains(.text) {
            result.append("text")
        }
        if contains(.audio) {
            result.append("audio")
        }
        return result
    }

    /// Create from API array format
    public init(from array: [String]) {
        var modality = ResponseModality()
        if array.contains("text") {
            modality.insert(.text)
        }
        if array.contains("audio") {
            modality.insert(.audio)
        }
        self = modality
    }
}

// MARK: - Input Audio Transcription

/// Configuration for input audio transcription
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct InputAudioTranscription: Sendable, Codable {
    /// Model to use for transcription (e.g., "whisper-1")
    public let model: String?

    public init(model: String? = "whisper-1") {
        self.model = model
    }

    /// Default transcription with Whisper
    public static let whisper = InputAudioTranscription(model: "whisper-1")

    /// No transcription
    public static let none = InputAudioTranscription(model: nil)
}

// MARK: - Session Configuration

/// Session configuration with all options
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct SessionConfiguration: Sendable, Codable {
    /// Model to use (e.g., "gpt-4o-realtime-preview")
    public var model: String

    /// Voice for audio responses
    public var voice: RealtimeVoice

    /// System instructions
    public var instructions: String?

    /// Input audio format
    public var inputAudioFormat: RealtimeAudioFormat

    /// Output audio format
    public var outputAudioFormat: RealtimeAudioFormat

    /// Input audio transcription configuration
    public var inputAudioTranscription: InputAudioTranscription?

    /// Turn detection configuration
    public var turnDetection: RealtimeTurnDetection?

    /// Tools available for function calling
    public var tools: [RealtimeTool]?

    /// Tool choice strategy
    public var toolChoice: ToolChoice?

    /// Temperature for response generation
    public var temperature: Double?

    /// Maximum response tokens for text responses
    public var maxResponseOutputTokens: Int?

    /// Response modalities to use
    public var modalities: ResponseModality?

    public enum ToolChoice: Sendable, Codable, Equatable {
        case auto
        case none
        case required
        case function(name: String)

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .auto:
                try container.encode("auto")
            case .none:
                try container.encode("none")
            case .required:
                try container.encode("required")
            case let .function(name):
                try container.encode(["type": "function", "name": name])
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                switch string {
                case "auto":
                    self = .auto
                case "none":
                    self = .none
                case "required":
                    self = .required
                default:
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Unknown tool choice: \(string)",
                    )
                }
            } else if
                let dict = try? container.decode([String: String].self),
                dict["type"] == "function",
                let name = dict["name"]
            {
                self = .function(name: name)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid tool choice format")
            }
        }
    }

    public init(
        model: String = "gpt-4o-realtime-preview",
        voice: RealtimeVoice = .alloy,
        instructions: String? = nil,
        inputAudioFormat: RealtimeAudioFormat = .pcm16,
        outputAudioFormat: RealtimeAudioFormat = .pcm16,
        inputAudioTranscription: InputAudioTranscription? = nil,
        turnDetection: RealtimeTurnDetection? = nil,
        tools: [RealtimeTool]? = nil,
        toolChoice: ToolChoice? = nil,
        temperature: Double? = 0.8,
        maxResponseOutputTokens: Int? = nil,
        modalities: ResponseModality? = .all,
    ) {
        self.model = model
        self.voice = voice
        self.instructions = instructions
        self.inputAudioFormat = inputAudioFormat
        self.outputAudioFormat = outputAudioFormat
        self.inputAudioTranscription = inputAudioTranscription
        self.turnDetection = turnDetection
        self.tools = tools
        self.toolChoice = toolChoice
        self.temperature = temperature
        self.maxResponseOutputTokens = maxResponseOutputTokens
        self.modalities = modalities
    }

    /// Create a default configuration for voice conversations
    public static func voiceConversation(
        model: String = "gpt-4o-realtime-preview",
        voice: RealtimeVoice = .alloy,
    )
        -> SessionConfiguration
    {
        // Create a default configuration for voice conversations
        SessionConfiguration(
            model: model,
            voice: voice,
            turnDetection: .serverVAD,
            modalities: .all,
        )
    }

    /// Create a configuration for text-only interactions
    public static func textOnly(
        model: String = "gpt-4o-realtime-preview",
    )
        -> SessionConfiguration
    {
        // Create a configuration for text-only interactions
        SessionConfiguration(
            model: model,
            voice: .alloy,
            turnDetection: .disabled,
            modalities: .text,
        )
    }

    /// Create a configuration with tools
    public static func withTools(
        model: String = "gpt-4o-realtime-preview",
        voice: RealtimeVoice = .alloy,
        tools: [RealtimeTool],
    )
        -> SessionConfiguration
    {
        // Create a configuration with tools
        SessionConfiguration(
            model: model,
            voice: voice,
            turnDetection: .serverVAD,
            tools: tools,
            toolChoice: .auto,
            modalities: .all,
        )
    }
}

// MARK: - Advanced Conversation Settings

/// Advanced settings for conversation behavior
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ConversationSettings: Sendable {
    /// Whether to automatically reconnect on disconnection
    public let autoReconnect: Bool

    /// Maximum number of reconnection attempts
    public let maxReconnectAttempts: Int

    /// Delay between reconnection attempts in seconds
    public let reconnectDelay: TimeInterval

    /// Whether to buffer audio while disconnected
    public let bufferWhileDisconnected: Bool

    /// Maximum audio buffer size in bytes
    public let maxAudioBufferSize: Int

    /// Whether to enable local echo cancellation
    public let enableEchoCancellation: Bool

    /// Whether to enable noise suppression
    public let enableNoiseSuppression: Bool

    /// Audio level threshold for local VAD (if used)
    public let localVADThreshold: Float

    /// Whether to show audio level visualization
    public let showAudioLevels: Bool

    /// Whether to persist conversation to disk
    public let persistConversation: Bool

    /// Path for conversation persistence
    public let persistencePath: URL?

    public init(
        autoReconnect: Bool = true,
        maxReconnectAttempts: Int = 3,
        reconnectDelay: TimeInterval = 2.0,
        bufferWhileDisconnected: Bool = true,
        maxAudioBufferSize: Int = 1024 * 1024, // 1MB
        enableEchoCancellation: Bool = true,
        enableNoiseSuppression: Bool = true,
        localVADThreshold: Float = 0.3,
        showAudioLevels: Bool = true,
        persistConversation: Bool = false,
        persistencePath: URL? = nil,
    ) {
        self.autoReconnect = autoReconnect
        self.maxReconnectAttempts = maxReconnectAttempts
        self.reconnectDelay = reconnectDelay
        self.bufferWhileDisconnected = bufferWhileDisconnected
        self.maxAudioBufferSize = maxAudioBufferSize
        self.enableEchoCancellation = enableEchoCancellation
        self.enableNoiseSuppression = enableNoiseSuppression
        self.localVADThreshold = localVADThreshold
        self.showAudioLevels = showAudioLevels
        self.persistConversation = persistConversation
        self.persistencePath = persistencePath
    }

    /// Default settings for production use
    public static let production = ConversationSettings(
        autoReconnect: true,
        maxReconnectAttempts: 3,
        reconnectDelay: 2.0,
        bufferWhileDisconnected: true,
        enableEchoCancellation: true,
        enableNoiseSuppression: true,
    )

    /// Settings for development/testing
    public static let development = ConversationSettings(
        autoReconnect: false,
        maxReconnectAttempts: 1,
        reconnectDelay: 1.0,
        bufferWhileDisconnected: false,
        enableEchoCancellation: false,
        enableNoiseSuppression: false,
        showAudioLevels: true,
    )
}
