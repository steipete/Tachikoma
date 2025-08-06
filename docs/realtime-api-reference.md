# Tachikoma Realtime API Reference

Complete API reference for OpenAI Realtime (Harmony) integration in Tachikoma.

## Table of Contents

- [Core Components](#core-components)
- [Session Management](#session-management)
- [Audio Processing](#audio-processing)
- [Conversation Management](#conversation-management)
- [Configuration](#configuration)
- [Event System](#event-system)
- [Tool Integration](#tool-integration)
- [Error Handling](#error-handling)

## Core Components

### RealtimeConversation

Main conversation manager for basic Realtime API usage.

```swift
@MainActor
public final class RealtimeConversation {
    // Initialization
    public init(configuration: TachikomaConfiguration) throws
    
    // Lifecycle
    public func start(
        model: LanguageModel.OpenAI = .gpt4oRealtime,
        voice: RealtimeVoice = .alloy,
        instructions: String? = nil,
        tools: [RealtimeTool]? = nil
    ) async throws
    
    public func end() async
    
    // Audio Control
    public func startListening() async throws
    public func stopListening() async throws
    public func sendAudio(_ data: Data) async throws
    
    // Text Interaction
    public func sendText(_ text: String) async throws
    public func interrupt() async throws
    
    // Tool Management
    public func registerTools(_ tools: [AgentTool]) async
    public func registerBuiltInTools() async
    
    // Properties
    public private(set) var state: ConversationState
    public private(set) var items: [ConversationItem]
    public private(set) var isRecording: Bool
    public private(set) var isPlaying: Bool
    
    // Event Streams
    public var transcriptUpdates: AsyncStream<String>
    public var audioLevelUpdates: AsyncStream<Float>
    public var stateChanges: AsyncStream<ConversationState>
}
```

### AdvancedRealtimeConversation

Enhanced conversation manager with full feature support.

```swift
@MainActor
public final class AdvancedRealtimeConversation: ObservableObject {
    // Published Properties
    @Published public private(set) var state: ConversationState
    @Published public private(set) var isConnected: Bool
    @Published public private(set) var audioLevel: Float
    @Published public private(set) var isSpeaking: Bool
    @Published public private(set) var isListening: Bool
    @Published public private(set) var transcript: String
    @Published public private(set) var items: [ConversationItem]
    @Published public private(set) var turnActive: Bool
    @Published public private(set) var modalities: ResponseModality
    
    // Initialization
    public init(
        apiKey: String,
        configuration: EnhancedSessionConfiguration = .voiceConversation(),
        settings: ConversationSettings = .production
    ) throws
    
    // Advanced Features
    public func updateModalities(_ modalities: ResponseModality) async throws
    public func updateTurnDetection(_ turnDetection: EnhancedTurnDetection) async throws
    public func clearConversation() async throws
    public func truncateAt(itemId: String) async throws
}
```

## Session Management

### RealtimeSession

Basic session management for WebSocket connection.

```swift
public actor RealtimeSession {
    public init(
        apiKey: String,
        configuration: SessionConfiguration
    )
    
    public func connect() async throws
    public func disconnect() async
    public func update(_ configuration: SessionConfiguration) async throws
    
    // Audio Management
    public func appendAudio(_ data: Data) async throws
    public func commitAudio() async throws
    public func clearAudioBuffer() async throws
    
    // Conversation Management
    public func createItem(_ item: ConversationItem) async throws
    public func createResponse() async throws
    public func cancelResponse() async throws
    
    // Event Stream
    public func eventStream() -> AsyncThrowingStream<RealtimeServerEvent, Error>
}
```

### EnhancedRealtimeSession

Enhanced session with auto-reconnect and buffering.

```swift
public actor EnhancedRealtimeSession {
    public init(
        apiKey: String,
        configuration: EnhancedSessionConfiguration,
        settings: ConversationSettings = .production
    )
    
    // Enhanced Features
    public func onConnectionStateChange(_ handler: @escaping (Bool) -> Void)
    public func onError(_ handler: @escaping (Error) -> Void)
    
    // Conversation Control
    public func truncateConversation(itemId: String) async throws
    public func deleteItem(itemId: String) async throws
    
    // Modality Control
    public func createResponse(modalities: ResponseModality? = nil) async throws
}
```

## Audio Processing

### RealtimeAudioProcessor

Handles audio format conversion and processing.

```swift
public final class RealtimeAudioProcessor: @unchecked Sendable {
    public init() throws
    
    // Format Conversion
    public func processAudioData(
        _ data: Data,
        from inputRate: Int,
        to outputRate: Int
    ) -> Data
    
    // Encoding/Decoding
    public func encodeToBase64(_ audioData: Data) -> String
    public func decodeFromBase64(_ base64String: String) -> Data?
    
    // G.711 Support
    public func encodeULaw(_ pcmData: Data) -> Data
    public func decodeULaw(_ ulawData: Data) -> Data
    public func encodeALaw(_ pcmData: Data) -> Data
    public func decodeALaw(_ alawData: Data) -> Data
}
```

### RealtimeAudioManager

Manages audio capture and playback.

```swift
@MainActor
public final class RealtimeAudioManager: NSObject {
    public init() throws
    
    // Audio Control
    public func startCapture() async
    public func stopCapture() async
    public func startPlayback() async
    public func stopPlayback() async
    
    // Audio Data
    public func playAudioData(_ data: Data) async
    public func captureAudioData() -> AsyncStream<Data>
    
    // Audio Levels
    public func getInputLevel() -> Float
    public func getOutputLevel() -> Float
}
```

### AudioStreamPipeline

Complete audio streaming pipeline.

```swift
@MainActor
public final class AudioStreamPipeline {
    public weak var delegate: AudioStreamPipelineDelegate?
    
    public init(
        audioManager: RealtimeAudioManager,
        processor: RealtimeAudioProcessor,
        enableVAD: Bool = false,
        enableEchoCancellation: Bool = false,
        enableNoiseSuppression: Bool = false
    )
    
    public func start() async throws
    public func stop() async
    public func updateSettings(_ settings: AudioPipelineSettings) async
}

public protocol AudioStreamPipelineDelegate: AnyObject {
    func audioStreamPipeline(_ pipeline: AudioStreamPipeline, didCaptureAudio data: Data)
    func audioStreamPipeline(_ pipeline: AudioStreamPipeline, didUpdateAudioLevel level: Float)
    func audioStreamPipeline(_ pipeline: AudioStreamPipeline, didDetectSpeechStart: Bool)
    func audioStreamPipeline(_ pipeline: AudioStreamPipeline, didDetectSpeechEnd: Bool)
    func audioStreamPipeline(_ pipeline: AudioStreamPipeline, didEncounterError error: Error)
}
```

## Configuration

### EnhancedSessionConfiguration

Complete session configuration options.

```swift
public struct EnhancedSessionConfiguration: Sendable, Codable {
    public var model: String
    public var voice: RealtimeVoice
    public var instructions: String?
    public var inputAudioFormat: RealtimeAudioFormat
    public var outputAudioFormat: RealtimeAudioFormat
    public var inputAudioTranscription: InputAudioTranscription?
    public var turnDetection: EnhancedTurnDetection?
    public var tools: [RealtimeTool]?
    public var toolChoice: ToolChoice?
    public var temperature: Double?
    public var maxResponseOutputTokens: Int?
    public var modalities: ResponseModality?
    
    // Presets
    public static func voiceConversation(
        model: String = "gpt-4o-realtime-preview",
        voice: RealtimeVoice = .alloy
    ) -> EnhancedSessionConfiguration
    
    public static func textOnly(
        model: String = "gpt-4o-realtime-preview"
    ) -> EnhancedSessionConfiguration
    
    public static func withTools(
        model: String = "gpt-4o-realtime-preview",
        voice: RealtimeVoice = .alloy,
        tools: [RealtimeTool]
    ) -> EnhancedSessionConfiguration
}
```

### ConversationSettings

Runtime settings for conversation behavior.

```swift
public struct ConversationSettings: Sendable {
    public let autoReconnect: Bool
    public let maxReconnectAttempts: Int
    public let reconnectDelay: TimeInterval
    public let bufferWhileDisconnected: Bool
    public let maxAudioBufferSize: Int
    public let enableEchoCancellation: Bool
    public let enableNoiseSuppression: Bool
    public let localVADThreshold: Float
    public let showAudioLevels: Bool
    public let persistConversation: Bool
    public let persistencePath: URL?
    
    // Presets
    public static let production: ConversationSettings
    public static let development: ConversationSettings
}
```

### EnhancedTurnDetection

Voice Activity Detection configuration.

```swift
public struct EnhancedTurnDetection: Sendable, Codable {
    public let type: TurnDetectionType
    public let threshold: Float?
    public let silenceDurationMs: Int?
    public let prefixPaddingMs: Int?
    public let createResponse: Bool?
    
    public enum TurnDetectionType: String, Sendable, Codable {
        case serverVad = "server_vad"
        case none = "none"
    }
    
    // Presets
    public static let serverVAD: EnhancedTurnDetection
    public static let disabled: EnhancedTurnDetection
}
```

### ResponseModality

Control response modalities.

```swift
public struct ResponseModality: OptionSet, Sendable, Codable {
    public static let text = ResponseModality(rawValue: 1 << 0)
    public static let audio = ResponseModality(rawValue: 1 << 1)
    public static let all: ResponseModality = [.text, .audio]
    
    public var toArray: [String]
    public init(from array: [String])
}
```

## Event System

### RealtimeClientEvent

Events sent from client to server.

```swift
public enum RealtimeClientEvent {
    case sessionUpdate(SessionUpdateEvent)
    case inputAudioBufferAppend(InputAudioBufferAppendEvent)
    case inputAudioBufferCommit
    case inputAudioBufferClear
    case conversationItemCreate(ConversationItemCreateEvent)
    case conversationItemTruncate(ConversationItemTruncateEvent)
    case conversationItemDelete(ConversationItemDeleteEvent)
    case responseCreate(ResponseCreateEvent)
    case responseCancel
}
```

### RealtimeServerEvent

Events received from server.

```swift
public enum RealtimeServerEvent {
    // Session Events
    case sessionCreated(SessionCreatedEvent)
    case sessionUpdated(SessionUpdatedEvent)
    
    // Conversation Events
    case conversationCreated(ConversationCreatedEvent)
    case conversationItemCreated(ConversationItemCreatedEvent)
    case conversationItemDeleted(ConversationItemDeletedEvent)
    case conversationItemTruncated(ConversationItemTruncatedEvent)
    
    // Input Audio Events
    case inputAudioBufferCommitted(InputAudioBufferCommittedEvent)
    case inputAudioBufferCleared(InputAudioBufferClearedEvent)
    case inputAudioBufferSpeechStarted(InputAudioBufferSpeechStartedEvent)
    case inputAudioBufferSpeechStopped(InputAudioBufferSpeechStoppedEvent)
    
    // Response Events
    case responseCreated(ResponseCreatedEvent)
    case responseDone(ResponseDoneEvent)
    case responseTextDelta(ResponseTextDeltaEvent)
    case responseTextDone(ResponseTextDoneEvent)
    case responseAudioDelta(ResponseAudioDeltaEvent)
    case responseAudioDone(ResponseAudioDoneEvent)
    case responseAudioTranscriptDelta(ResponseAudioTranscriptDeltaEvent)
    case responseAudioTranscriptDone(ResponseAudioTranscriptDoneEvent)
    case responseFunctionCallArgumentsDelta(ResponseFunctionCallArgumentsDeltaEvent)
    case responseFunctionCallArgumentsDone(ResponseFunctionCallArgumentsDoneEvent)
    
    // Rate Limits
    case rateLimitsUpdated(RateLimitsUpdatedEvent)
    
    // Errors
    case error(RealtimeErrorEvent)
}
```

## Tool Integration

### RealtimeToolExecutor

Executes tools with timeout support.

```swift
public actor RealtimeToolExecutor {
    public init()
    
    // Tool Registration
    public func register<T: RealtimeExecutableTool>(_ tool: T)
    public func registerTools<T: RealtimeExecutableTool>(_ tools: [T])
    public func unregister(toolName: String)
    
    // Tool Execution
    public func execute(
        toolName: String,
        arguments: String,
        timeout: TimeInterval = 30
    ) async -> ToolExecution
    
    public func executeSimple(
        toolName: String,
        arguments: String,
        timeout: TimeInterval = 30
    ) async -> String
    
    // Tool Discovery
    public func availableTools() -> [ToolMetadata]
    public func getToolMetadata(name: String) -> ToolMetadata?
    
    // History
    public func getHistory(limit: Int? = nil) -> [ToolExecution]
    public func clearHistory()
}
```

### RealtimeExecutableTool Protocol

Protocol for tools that can be executed.

```swift
public protocol RealtimeExecutableTool: Sendable {
    var metadata: RealtimeToolExecutor.ToolMetadata { get }
    func execute(_ arguments: RealtimeToolArguments) async -> String
}
```

### Built-in Tools

```swift
public struct BuiltInTools {
    public static func all() -> [any RealtimeExecutableTool]
}

// Available tools:
- WeatherTool      // Get weather information
- TimeTool         // Get current time in timezone
- CalculatorTool   // Perform calculations
- WebSearchTool    // Search the web
- TranslationTool  // Translate text
```

## Error Handling

### TachikomaError

Main error types for Realtime API.

```swift
public enum TachikomaError: Error {
    case authenticationFailed(String)
    case networkError(Error)
    case apiError(String)
    case invalidInput(String)
    case unsupportedOperation(String)
    case timeout
    case cancelled
}
```

### Error Recovery

```swift
// Automatic reconnection
let settings = ConversationSettings(
    autoReconnect: true,
    maxReconnectAttempts: 3,
    reconnectDelay: 2.0
)

// Manual retry
do {
    try await conversation.sendText("Hello")
} catch TachikomaError.networkError {
    // Wait and retry
    try await Task.sleep(nanoseconds: 2_000_000_000)
    try await conversation.sendText("Hello")
}
```

## SwiftUI Integration

### RealtimeConversationView

Pre-built SwiftUI view for conversations.

```swift
@available(macOS 14.0, iOS 17.0, *)
public struct RealtimeConversationView: View {
    public init(
        apiKey: String,
        configuration: EnhancedSessionConfiguration = .voiceConversation(),
        onError: ((Error) -> Void)? = nil
    )
}
```

### RealtimeConversationViewModel

Observable view model for custom UIs.

```swift
@available(macOS 13.0, iOS 16.0, *)
@MainActor
public final class RealtimeConversationViewModel: ObservableObject {
    @Published public private(set) var state: ConversationState
    @Published public private(set) var transcript: String
    @Published public private(set) var isConnected: Bool
    @Published public private(set) var audioLevel: Float
    @Published public private(set) var messages: [ConversationMessage]
    
    public func initialize(
        apiKey: String,
        configuration: EnhancedSessionConfiguration
    ) async throws
    
    public func updateModalities(_ modalities: ResponseModality) async throws
}
```

## Platform Requirements

- macOS 13.0+ / iOS 16.0+ / watchOS 9.0+ / tvOS 16.0+
- Swift 6.0+
- OpenAI API key with Realtime API access
- Models: `gpt-4o-realtime-preview`, `gpt-4o-realtime-preview-2024-10-01`

## Best Practices

1. **Always handle disconnections**: Use auto-reconnect in production
2. **Buffer audio during interruptions**: Enable `bufferWhileDisconnected`
3. **Use Server VAD for natural conversations**: Better than client-side detection
4. **Monitor rate limits**: Handle `rateLimitsUpdated` events
5. **Clean up resources**: Always call `end()` when done
6. **Use appropriate modalities**: Switch based on network conditions
7. **Implement proper error handling**: Network issues are common
8. **Test with different voices**: Each has different characteristics
9. **Use tool namespaces**: Organize tools logically
10. **Monitor audio levels**: Provide visual feedback to users