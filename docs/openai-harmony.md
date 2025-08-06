# OpenAI Harmony (Realtime API) Integration for Tachikoma

## Implementation Status: Phase 5 Complete ✅

**Current Progress**: Advanced Features complete, Function Calling complete, Audio Infrastructure complete, Core Infrastructure complete

## Executive Summary
Add full support for OpenAI's Realtime API ("Harmony") to enable low-latency, bidirectional voice conversations with GPT-4o, including real-time audio streaming, function calling, and session management through WebSocket connections.

## Overview

OpenAI's Realtime API enables:
- **WebSocket connections** for persistent, low-latency communication
- **Voice input/output** - native speech-to-speech without separate TTS/STT
- **Real-time interruptions** - interrupt the model mid-response
- **Function calling** - execute tools via voice commands
- **~500ms latency** - near-instant responses for natural conversation

## Architecture Overview

### Core Components

1. **WebSocket Transport Layer** - Manages persistent connection lifecycle
2. **Event System** - Type-safe bidirectional event protocol (37 event types)
3. **Session Management** - Stateful conversation tracking
4. **Audio Pipeline** - Real-time audio capture, conversion, and playback
5. **Tool Integration** - Voice-triggered function execution

### Integration Strategy

The Realtime API will be integrated as an additive feature, maintaining full backwards compatibility:

```swift
// Existing API continues unchanged
let response = try await generateText(model: .openai(.gpt4o), messages: messages)

// New Realtime API alongside
let conversation = try await startRealtimeConversation(model: .openai(.gpt4oRealtime))
```

## Completed Implementation

### Phase 1: Core Infrastructure ✅

#### Files Created:
- `Sources/Tachikoma/Realtime/WebSocketTransport.swift` - WebSocket transport with reconnection
- `Sources/Tachikoma/Realtime/RealtimeEvents.swift` - All 37 event types as Sendable structs
- `Sources/Tachikoma/Realtime/RealtimeSession.swift` - Session lifecycle management
- `Sources/Tachikoma/Realtime/RealtimeConversation.swift` - High-level conversation API
- `Examples/RealtimeExample.swift` - Complete usage examples

#### Key Achievements:
- Type-safe event system with full Sendable conformance
- WebSocket transport with automatic reconnection
- Session configuration and management
- Integration with existing Tachikoma patterns
- Model support for `gpt4oRealtime` with pricing

### Phase 2: Audio Infrastructure ✅

#### Files Created:
- `Sources/Tachikoma/Realtime/Audio/AudioProcessor.swift` - Audio format conversion and processing
- `Sources/Tachikoma/Realtime/Audio/AudioManager.swift` - Audio capture and playback management
- `Sources/Tachikoma/Realtime/Audio/AudioFormats.swift` - Format utilities and extensions
- `Sources/Tachikoma/Realtime/Audio/AudioStreamPipeline.swift` - Complete streaming pipeline

#### Key Features:
- 48kHz to 24kHz PCM16 conversion for API compatibility
- G.711 µ-law and A-law encoding/decoding support
- Voice Activity Detection (VAD) implementation
- Echo cancellation and noise suppression
- Platform-specific audio session management
- Audio level monitoring for UI feedback
- Stream buffering with configurable chunk sizes

### Phase 3: Enhanced High-Level API ✅

#### Files Created:
- `Sources/Tachikoma/Realtime/RealtimeConversationEnhanced.swift` - Enhanced conversation with full features
- `Sources/Tachikoma/Realtime/UI/RealtimeConversationView.swift` - SwiftUI view for voice conversations
- `Sources/Tachikoma/Realtime/UI/RealtimeConversationViewModel.swift` - Observable view model

#### Key Features:
- **Audio Pipeline Integration**: Seamless integration with AudioStreamPipeline
- **Session Persistence**: Save and restore conversation state
- **SwiftUI Support**: Complete UI components with @Published properties
- **Connection Management**: Auto-reconnect with status tracking
- **Voice Activity Detection**: Automatic recording start/stop
- **Tool Execution**: Framework for voice-triggered function calls
- **Observable State**: Full Combine/SwiftUI integration
- **Convenience Methods**: quickStart(), exportAsText(), etc.

### Phase 4: Function Calling ✅

#### Files Created:
- `Sources/Tachikoma/Realtime/Tools/RealtimeToolExecutor.swift` - Tool execution with timeout support
- `Sources/Tachikoma/Realtime/Tools/AgentToolWrapper.swift` - Adapter for AgentTool compatibility
- `Sources/Tachikoma/Realtime/Tools/BuiltInTools.swift` - Built-in tools (weather, time, calculator, web search, translation)
- `Tests/TachikomaTests/Realtime/FunctionCallingTests.swift` - Comprehensive test suite

#### Key Features:
- **Type-safe tool execution**: RealtimeToolArgument enum for strong typing
- **Tool registry**: Dynamic tool registration and discovery
- **Built-in tools**: Weather, time, calculator, web search, translation
- **AgentTool integration**: Seamless integration with existing tool system
- **Execution history**: Track all tool calls and results
- **Timeout support**: Configurable timeouts for tool execution
- **JSON argument parsing**: Convert JSON strings to typed arguments

### Phase 5: Advanced Features ✅

#### Files Created:
- `Sources/Tachikoma/Realtime/Configuration/RealtimeConfiguration.swift` - Enhanced configuration with VAD and modalities
- `Sources/Tachikoma/Realtime/RealtimeSessionEnhanced.swift` - Enhanced session with auto-reconnect and buffering
- `Sources/Tachikoma/Realtime/AdvancedRealtimeConversation.swift` - Full-featured conversation manager
- `Tests/TachikomaTests/Realtime/AdvancedFeaturesTests.swift` - Test suite for advanced features

#### Key Features:
- **Server VAD**: Configurable Voice Activity Detection with thresholds and timing
- **Response Modalities**: Control text/audio/both response types dynamically
- **Turn Detection**: Automatic turn-taking with server-side detection
- **Input Transcription**: Optional Whisper transcription for input audio
- **Tool Choice**: Auto/none/required/specific function selection
- **Auto-Reconnect**: Automatic reconnection with exponential backoff
- **Audio Buffering**: Buffer audio while disconnected for seamless recovery
- **Conversation Settings**: Production/development presets with full customization

### Implementation Summary

The OpenAI Realtime API (Harmony) integration for Tachikoma now has:

1. **Complete Infrastructure**: WebSocket transport, event system, session management
2. **Full Audio Support**: Format conversion, capture/playback, VAD, streaming pipeline
3. **Production-Ready API**: Enhanced conversation API with persistence, UI components
4. **Function Calling**: Type-safe tool execution with built-in and custom tools
5. **Advanced Features**: Server VAD, response modalities, turn management, auto-reconnect
6. **Type Safety Throughout**: No [String: Any], full Sendable conformance
7. **Platform Support**: macOS 13.0+, iOS 16.0+, watchOS 9.0+, tvOS 16.0+

### Usage Example

```swift
// Simple usage
let conversation = try await startRealtimeConversation(
    model: .gpt4oRealtime,
    voice: .nova
)

// Enhanced usage with UI
let enhanced = try EnhancedRealtimeConversation(apiKey: apiKey)
try await enhanced.quickStart()

// SwiftUI integration
RealtimeConversationView(apiKey: apiKey)
```

## Original Plan

## Phase 1: Core Infrastructure (Week 1-2)

### WebSocket Transport Layer

```swift
// Sources/Tachikoma/Realtime/WebSocketTransport.swift
public protocol RealtimeTransport: Sendable {
    func connect(url: URL, headers: [String: String]) async throws
    func send(_ event: RealtimeEvent) async throws
    func receive() -> AsyncThrowingStream<RealtimeEvent, Error>
    func disconnect() async
}
```

**Key Features:**
- URLSessionWebSocketTask for native WebSocket support
- Automatic reconnection with exponential backoff
- Connection state management
- Error recovery and graceful degradation

### Event System Architecture

The API defines 9 client events and 28 server events:

**Client Events:**
- `session.update` - Configure session parameters
- `input_audio_buffer.append` - Stream audio to server
- `input_audio_buffer.commit` - Finalize audio input
- `conversation.item.create` - Add conversation items
- `response.create` - Generate AI response
- `response.cancel` - Interrupt ongoing response

**Server Events:**
- `session.created/updated` - Session lifecycle
- `conversation.item.created` - New conversation items
- `response.audio.delta` - Streaming audio chunks
- `response.text.delta` - Streaming text
- `response.function_call_arguments.done` - Tool execution
- `error` - Error handling

### Session Management

```swift
@MainActor
public final class RealtimeSession {
    public struct SessionConfiguration {
        public var model: String = "gpt-4o-realtime-preview"
        public var voice: Voice = .alloy
        public var instructions: String?
        public var inputAudioFormat: AudioFormat = .pcm16
        public var outputAudioFormat: AudioFormat = .pcm16
        public var turnDetection: TurnDetection?
        public var tools: [RealtimeTool]?
    }
}
```

## Phase 2: Audio Infrastructure (Week 2-3)

### Audio Processing Pipeline

**Requirements:**
- Input: 48kHz from device microphone
- API: 24kHz PCM16 format
- Real-time conversion with minimal latency
- Audio level monitoring for UI feedback

```swift
public final class RealtimeAudioProcessor {
    private let inputFormat: AVAudioFormat  // 48kHz from mic
    private let outputFormat: AVAudioFormat // 24kHz for API
    
    public func processInput(_ buffer: AVAudioPCMBuffer) -> Data
    public func processOutput(_ data: Data) -> AVAudioPCMBuffer
}
```

### Audio Formats

Supported formats:
- **pcm16**: 16-bit PCM @ 24kHz (recommended)
- **g711_ulaw**: 8-bit G.711 µ-law @ 8kHz
- **g711_alaw**: 8-bit G.711 A-law @ 8kHz

## Phase 3: High-Level API (Week 3-4)

### Conversation Manager

```swift
public final class RealtimeConversation {
    // Simple API matching Tachikoma patterns
    public func start(
        model: LanguageModel.OpenAI = .gpt4oRealtime,
        voice: Voice = .alloy,
        instructions: String? = nil,
        tools: [RealtimeTool]? = nil
    ) async throws
    
    // Control methods
    public func startListening() async throws
    public func stopListening() async throws
    public func sendText(_ text: String) async throws
    public func interrupt() async throws
}
```

### Integration with Generation API

```swift
// New global function following Tachikoma patterns
public func startRealtimeConversation(
    model: LanguageModel.OpenAI = .gpt4oRealtime,
    voice: RealtimeVoice = .alloy,
    instructions: String? = nil,
    tools: [AgentTool]? = nil
) async throws -> RealtimeConversation
```

## Phase 4: Function Calling (Week 4)

### Tool System Integration

The Realtime API supports function calling, enabling voice-triggered actions:

```swift
public struct RealtimeTool: Sendable, Codable {
    public let name: String
    public let description: String
    public let parameters: ToolParameters
    
    // Convert from existing AgentTool
    public init(from agentTool: AgentTool)
}
```

**Voice-Triggered Examples:**
- "Check the weather in San Francisco"
- "Calculate the square root of 144"
- "Send an email to John"

## Phase 5: Advanced Features (Week 5)

### Server VAD (Voice Activity Detection)

Server-side VAD automatically detects speech and manages turn-taking:

```swift
public struct TurnDetection {
    public let type: TurnDetectionType = .serverVad
    public let threshold: Float = 0.5
    public let silenceDurationMs: Int = 200
}
```

### Response Modalities

Control whether responses include text, audio, or both:

```swift
public struct ResponseModality: OptionSet {
    public static let text = ResponseModality(rawValue: 1 << 0)
    public static let audio = ResponseModality(rawValue: 1 << 1)
    public static let all: ResponseModality = [.text, .audio]
}
```

## Phase 6: Testing & Examples (Week 5-6)

### Testing Strategy

**Unit Tests:**
- Event serialization/deserialization
- Audio format conversion
- Session state management
- Tool execution

**Integration Tests:**
- End-to-end conversation flow
- Interruption handling
- Multi-turn conversations
- Function calling

### Example Usage

```swift
// Simple voice assistant
let conversation = try await startRealtimeConversation(
    model: .openai(.gpt4oRealtime),
    voice: .nova,
    instructions: "You are a helpful voice assistant"
)

// Start listening
try await conversation.startListening()

// Handle transcript updates
for await transcript in conversation.transcriptUpdates {
    print("User: \(transcript)")
}

// Clean up
await conversation.end()
```

### SwiftUI Integration

```swift
struct RealtimeVoiceView: View {
    @StateObject private var viewModel = RealtimeViewModel()
    
    var body: some View {
        VStack {
            AudioWaveformView(level: viewModel.audioLevel)
            TranscriptView(messages: viewModel.messages)
            ControlButtons(viewModel: viewModel)
        }
    }
}
```

## Technical Specifications

### Performance Targets
- **Latency**: <500ms time-to-first-byte
- **Audio Quality**: 24kHz PCM16
- **Memory**: Stream processing, no full buffering
- **CPU**: Hardware acceleration when available

### Error Handling
- Automatic reconnection with exponential backoff
- Graceful audio degradation
- Clear error messages
- Network interruption recovery

### Security & Privacy
- Secure WebSocket (wss://) only
- API keys in Keychain
- No audio persistence by default
- Opt-in recording/logging

## Implementation Timeline

**Week 1-2: Core Infrastructure**
- WebSocket transport
- Event system
- Session management

**Week 2-3: Audio Infrastructure**
- Audio capture/playback
- Format conversion
- Audio processing

**Week 3-4: High-Level API**
- Conversation manager
- API integration
- Basic functionality

**Week 4: Function Calling**
- Tool system integration
- Voice-triggered execution

**Week 5: Advanced Features**
- Server VAD
- Response modalities
- Error recovery

**Week 6: Polish & Documentation**
- Testing suite
- Example apps
- Documentation

## Success Criteria

### Technical Metrics
- [ ] All 37 event types implemented
- [ ] <500ms latency achieved
- [ ] 95% test coverage
- [ ] Zero memory leaks
- [ ] Graceful error handling

### User Experience
- [ ] Simple one-line initialization
- [ ] Intuitive API design
- [ ] Comprehensive examples
- [ ] SwiftUI components
- [ ] Clear documentation

## Dependencies & Requirements

### Platform Requirements
- macOS 14.0+ (URLSessionWebSocketTask)
- iOS 17.0+ (Modern audio APIs)
- Swift 6.0 (Concurrency features)

### API Requirements
- OpenAI API key
- Realtime API access (paid accounts only)
- Models: gpt-4o-realtime-preview

### No External Dependencies
- Native URLSessionWebSocketTask
- AVAudioEngine for audio
- Foundation for networking

## Migration Path

The Realtime API is purely additive:

1. **Existing code unchanged** - All current APIs continue working
2. **New capabilities** - Voice conversations opt-in
3. **Shared tools** - AgentTool works with both APIs
4. **Unified configuration** - TachikomaConfiguration extended

## Future Enhancements

### Planned Features
- WebRTC transport option for lower latency
- Custom voice models
- Fine-tuned audio processing
- Conversation analytics
- Response caching

### Potential Optimizations
- Hardware audio acceleration
- Adaptive bitrate
- Network quality detection
- Predictive buffering
- Edge deployment support

## Conclusion

The Realtime API integration will position Tachikoma as a leading Swift SDK for AI applications, enabling developers to build sophisticated voice-enabled agents with minimal code. The implementation maintains Tachikoma's philosophy of type-safe, Swift-native APIs while adding powerful real-time capabilities.

Key benefits:
- **Natural conversations** - Human-like voice interactions
- **Low latency** - Near-instant responses
- **Tool integration** - Voice-triggered actions
- **Simple API** - One-line initialization
- **Production ready** - Robust error handling

This positions Tachikoma perfectly for the next generation of AI applications where voice interaction is paramount.