<div align="center">
  <img src="assets/logo.png" width="200" alt="Tachikoma Logo">
  
  # Tachikoma 🕸️ - Modern Swift AI SDK

<p align="center">
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0+-FA7343?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 6.0+"></a>
  <a href="https://github.com/steipete/Tachikoma"><img src="https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS%20%7C%20Linux-blue?style=for-the-badge" alt="Platforms"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="MIT License"></a>
  <a href="https://github.com/steipete/Tachikoma/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/steipete/Tachikoma/ci.yml?branch=main&style=for-the-badge&label=tests" alt="CI Status"></a>
</p>

**A Modern Swift AI SDK that makes AI integration feel natural**

Named after the spider-tank AI from Ghost in the Shell, **Tachikoma** provides an intelligent, adaptable interface for AI services with a completely modern Swift-native API.

> CI runs across macOS, Linux, and Apple simulators (iOS/tvOS/watchOS/visionOS). Android builds are currently paused until a stable SwiftAndroid toolchain is available. Windows builds are no longer promised or exercised.
</div>

## Quick Start

### Basic Setup

```swift
import Tachikoma  // Single unified module

// Simple text generation
let answer = try await generate("What is 2+2?", using: .openai(.gpt4o))
print(answer) // "4"

// With different models
let response1 = try await generate("Hello", using: .anthropic(.opus4))
let response2 = try await generate("Hello", using: .grok(.grok4FastReasoning))
let response3 = try await generate("Hello", using: .ollama(.llama33))
```

### Conversation Management

```swift
// Multi-turn conversations
let conversation = Conversation()
conversation.addUserMessage("Hello!")
let response = try await conversation.continue(using: .claude)
print(response) // Assistant's response

conversation.addUserMessage("Tell me about Swift")
let nextResponse = try await conversation.continue()
// Uses same model as previous call
```

### Credentials & OAuth (new)

- `TKAuthManager` owns credential resolution for OpenAI, Anthropic, xAI/Grok, and Gemini. Precedence: explicit config key → env (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `X_AI_API_KEY` with aliases `XAI_API_KEY`/`GROK_API_KEY`, `GEMINI_API_KEY`) → credentials file at `~/<profile>/credentials`.
- OAuth (PKCE) is supported for OpenAI/Codex and Anthropic Max; tokens (not API keys) are stored and refreshed automatically. Anthropic sends the Max beta header by default.
- CLI: `tachikoma config add <provider> <secret> [--timeout]`, `tachikoma config login <provider> [--timeout] [--no-browser]`, `tachikoma config status|show [--timeout]`, `tachikoma config init`. Legacy binary name `tk-config` remains as an alias.
- Hosts override the storage root via `TachikomaConfiguration.profileDirectoryName` (Peekaboo uses `.peekaboo` so it reuses the same credentials file).

### OpenAI Realtime API (Voice Conversations) 🎙️

**COMPLETE: Full implementation of OpenAI's Realtime API for ultra-low-latency voice conversations!**

The Realtime API enables natural, real-time voice conversations with GPT-4o, featuring:
- **~500ms latency** - Near-instantaneous voice responses
- **WebSocket streaming** - Persistent bidirectional connection
- **Native voice I/O** - No separate TTS/STR needed
- **Function calling** - Voice-triggered tool execution

#### Quick Start

```swift
// Basic voice conversation
let conversation = try RealtimeConversation(configuration: config)
try await conversation.start(
    model: .gpt4oRealtime,
    voice: .nova,
    instructions: "You are a helpful voice assistant"
)

// Manual turn control
try await conversation.startListening()
// User speaks...
try await conversation.stopListening()

// Handle responses
for await transcript in conversation.transcriptUpdates {
    print("Assistant: \(transcript)")
}

// End conversation
await conversation.end()
```

#### Advanced Features

```swift
// Full-featured configuration
let config = EnhancedSessionConfiguration(
    model: "gpt-4o-realtime-preview",
    voice: .nova,
    instructions: "You are an expert assistant",
    inputAudioFormat: .pcm16,
    outputAudioFormat: .pcm16,
    inputAudioTranscription: .whisper,  // Transcribe user audio
    turnDetection: RealtimeTurnDetection(
        type: .serverVad,
        threshold: 0.5,
        silenceDurationMs: 200,
        prefixPaddingMs: 300
    ),
    modalities: .all,  // Text and audio
    temperature: 0.8,
    maxResponseOutputTokens: 4096
)

// Production-ready settings
let settings = ConversationSettings(
    autoReconnect: true,
    maxReconnectAttempts: 3,
    reconnectDelay: 2.0,
    bufferWhileDisconnected: true,  // Buffer audio during disconnection
    enableEchoCancellation: true,
    enableNoiseSuppression: true
)

// Create advanced conversation manager
let conversation = try AdvancedRealtimeConversation(
    apiKey: apiKey,
    configuration: config,
    settings: settings
)

// Dynamic modality switching
try await conversation.updateModalities(.text)   // Text-only mode
try await conversation.updateModalities(.audio)  // Audio-only mode
try await conversation.updateModalities(.all)    // Both modalities

// Update VAD settings on the fly
try await conversation.updateTurnDetection(
    RealtimeTurnDetection.serverVAD
)
```

#### Voice-Enabled Function Calling

```swift
// Register tools for voice interaction
await conversation.registerTools([
    createTool(
        name: "get_weather",
        description: "Get current weather for a location",
        parameters: [
            AgentToolParameterProperty(
                name: "location",
                type: .string,
                description: "City and state/country"
            )
        ]
    ) { args in
        let location = try args.stringValue("location")
        // Fetch weather data...
        return .string("Sunny, 22°C in \(location)")
    }
])

// Built-in tools available
await conversation.registerBuiltInTools()
// Includes: Weather, Time, Calculator, WebSearch, Translation

// Tools are automatically invoked during voice conversation
// User: "What's the weather in Tokyo?"
// Assistant calls get_weather("Tokyo") and responds with result
```

#### Audio Pipeline & Processing

```swift
// Custom audio pipeline configuration
let pipeline = try AudioStreamPipeline()
pipeline.delegate = self

// Handle audio events
extension MyController: AudioStreamPipelineDelegate {
    func audioStreamPipeline(_ pipeline: AudioStreamPipeline, 
                           didCaptureAudio data: Data) {
        // Process captured audio (24kHz PCM16)
    }
    
    func audioStreamPipeline(_ pipeline: AudioStreamPipeline, 
                           didUpdateAudioLevel level: Float) {
        // Update UI with audio levels
    }
    
    func audioStreamPipeline(_ pipeline: AudioStreamPipeline, 
                           didDetectSpeechStart: Bool) {
        // Handle speech detection
    }
}
```

#### SwiftUI Integration

```swift
// Observable conversation for SwiftUI
@StateObject private var conversation = AdvancedRealtimeConversation(
    apiKey: apiKey,
    configuration: .voiceConversation()
)

// Pre-built SwiftUI view
RealtimeConversationView(
    apiKey: apiKey,
    configuration: .voiceConversation(),
    onError: { error in
        print("Conversation error: \(error)")
    }
)
```

#### Event System

All 37 Realtime API events are fully supported:

```swift
// Client events (9 types)
case sessionUpdate(SessionUpdateEvent)
case inputAudioBufferAppend(InputAudioBufferAppendEvent)
case inputAudioBufferCommit
case inputAudioBufferClear
case conversationItemCreate(ConversationItemCreateEvent)
case conversationItemTruncate(ConversationItemTruncateEvent)
case conversationItemDelete(ConversationItemDeleteEvent)
case responseCreate(ResponseCreateEvent)
case responseCancel

// Server events (28 types)
case sessionCreated(SessionCreatedEvent)
case conversationItemCreated(ConversationItemCreatedEvent)
case inputAudioBufferSpeechStarted
case responseAudioDelta(ResponseAudioDeltaEvent)
case responseFunctionCallArgumentsDone(ResponseFunctionCallArgumentsDoneEvent)
case rateLimitsUpdated(RateLimitsUpdatedEvent)
case error(RealtimeErrorEvent)
// ... and more
```

#### Complete Implementation Status ✅

- ✅ **Phase 1**: Core WebSocket infrastructure
- ✅ **Phase 2**: Event system (37 events)
- ✅ **Phase 3**: Audio pipeline (24kHz PCM16)
- ✅ **Phase 4**: Function calling
- ✅ **Phase 5**: Advanced features (VAD, modalities, auto-reconnect)
- ✅ **Phase 6**: Testing & documentation

See [docs/openai-harmony.md](docs/openai-harmony.md) for complete implementation details.

### Audio Processing (TachikomaAudio) 🎵

**Comprehensive audio capabilities in a dedicated module:**

```swift
import TachikomaAudio

// Transcribe audio files
let text = try await transcribe(contentsOf: audioURL)

// With specific model and language
let result = try await transcribe(
    audioData,
    using: .openai(.whisper1),
    language: "en",
    timestampGranularities: [.word, .segment]
)

// Generate speech from text
let audioData = try await generateSpeech(
    "Hello world",
    using: .openai(.tts1HD),
    voice: .nova,
    speed: 1.2
)

// Record audio from microphone
let recorder = AudioRecorder()
try await recorder.startRecording()
// ... user speaks ...
let recording = try await recorder.stopRecording()
let transcription = try await transcribe(recording)
```

#### Audio Providers

- **Transcription**: OpenAI Whisper, Groq, Deepgram, ElevenLabs
- **Speech Synthesis**: OpenAI TTS, ElevenLabs
- **Recording**: Cross-platform AVFoundation support

### Tool Integration (Type-Safe Protocol System)

Tachikoma provides a type-safe tool system that ensures compile-time safety and eliminates runtime errors:

```swift
// Type-safe tool using AgentToolProtocol
struct WeatherTool: AgentToolProtocol {
    struct Input: AgentToolValue {
        let location: String
        let units: String
        
        static var agentValueType: AgentValueType { .object }
        
        func toJSON() throws -> Any {
            ["location": location, "units": units]
        }
        
        static func fromJSON(_ json: Any) throws -> Input {
            guard let dict = json as? [String: Any],
                  let location = dict["location"] as? String,
                  let units = dict["units"] as? String else {
                throw TachikomaError.invalidInput("Invalid weather input")
            }
            return Input(location: location, units: units)
        }
    }
    
    struct Output: AgentToolValue {
        let temperature: Double
        let conditions: String
        
        static var agentValueType: AgentValueType { .object }
        
        func toJSON() throws -> Any {
            ["temperature": temperature, "conditions": conditions]
        }
        
        static func fromJSON(_ json: Any) throws -> Output {
            guard let dict = json as? [String: Any],
                  let temperature = dict["temperature"] as? Double,
                  let conditions = dict["conditions"] as? String else {
                throw TachikomaError.invalidInput("Invalid weather output")
            }
            return Output(temperature: temperature, conditions: conditions)
        }
    }
    
    var name: String { "get_weather" }
    var description: String { "Get current weather for a location" }
    var schema: AgentToolSchema {
        AgentToolSchema(
            properties: [
                "location": AgentPropertySchema(type: .string, description: "City name"),
                "units": AgentPropertySchema(type: .string, description: "Temperature units", enumValues: ["celsius", "fahrenheit"])
            ],
            required: ["location", "units"]
        )
    }
    
    func execute(_ input: Input, context: ToolExecutionContext) async throws -> Output {
        // Your weather API integration here
        return Output(temperature: 22.5, conditions: "Sunny")
    }
}

// Use with type-erased wrapper for dynamic scenarios
let weatherTool = WeatherTool()
let anyTool = AnyAgentTool(weatherTool)

// Or use the simpler AgentTool for backwards compatibility
let simpleTool = AgentTool(
    name: "get_weather",
    description: "Get current weather",
    parameters: AgentToolParameters(
        properties: [
            "location": AgentToolParameterProperty(
                name: "location",
                type: .string,
                description: "City name"
            )
        ],
        required: ["location"]
    )
) { args in
    let location = try args.stringValue("location")
    return AnyAgentToolValue(string: "Sunny, 22°C in \(location)")
}

// Use tools with AI models
let result = try await generateText(
    model: .claude,
    messages: [.user("What's the weather in Tokyo?")],
    tools: [simpleTool]
)
print(result.text)
```

#### AgentToolValue Protocol

The new type-safe tool system is built on the `AgentToolValue` protocol:

```swift
// All standard types conform to AgentToolValue
let stringValue = AnyAgentToolValue(string: "hello")
let intValue = AnyAgentToolValue(int: 42)
let doubleValue = AnyAgentToolValue(double: 3.14)
let boolValue = AnyAgentToolValue(bool: true)
let nullValue = AnyAgentToolValue(null: ())

// Complex types are supported
let arrayValue = AnyAgentToolValue(array: [
    AnyAgentToolValue(string: "item1"),
    AnyAgentToolValue(int: 2)
])

let objectValue = AnyAgentToolValue(object: [
    "name": AnyAgentToolValue(string: "Alice"),
    "age": AnyAgentToolValue(int: 30)
])

// Easy conversion from JSON
let jsonValue = try AnyAgentToolValue.fromJSON(["key": "value", "count": 123])

// Type-safe access
if let str = jsonValue.objectValue?["key"]?.stringValue {
    print(str) // "value"
}
```

## Core Features

### Agent System (TachikomaAgent Module)

Build stateful, autonomous AI agents with memory and tool access:

```swift
import TachikomaAgent

// Define your agent with context
class MyContext {
    var database: Database
    var api: APIClient
}

let context = MyContext()
let agent = Agent(
    name: "DataAnalyst",
    instructions: "You are a helpful data analyst. You can query databases and call APIs to answer questions.",
    model: .openai(.gpt4o),
    tools: [databaseTool, apiTool],
    context: context
)

// Execute tasks
let response = try await agent.execute("What were our top products last month?")
print(response.text)

// Stream responses
let stream = try await agent.stream("Generate a detailed sales report")
for try await delta in stream {
    print(delta.content ?? "", terminator: "")
}

// Conversation persists across calls
let followUp = try await agent.execute("Can you break that down by region?")

// Session management
let sessionManager = AgentSessionManager.shared
sessionManager.createSession(sessionId: "analyst-001", agent: agent)

// Save/load sessions
let session = try await sessionManager.loadSession(id: "analyst-001")
```

### Type-Safe Model Selection

Compile-time safety with provider-specific enums and full autocomplete support:

```swift
// Provider-specific models with compile-time checking
.openai(.gpt4o, .gpt41, .gpt51Mini, .custom("ft:gpt-4o:org:abc"))
.anthropic(.opus4, .sonnet4, .haiku45, .opus4Thinking)
.grok(.grok4, .grok4FastReasoning, .grok2Vision)
.ollama(.llama33, .llama32, .llava, .codellama)
.google(.gemini25Pro, .gemini25Flash)
.mistral(.large2, .nemo)
.groq(.llama3170b, .mixtral8x7b)
.azureOpenAI(deployment: "gpt-4o", resource: "my-aoai")

// Third-party aggregators
.openRouter(modelId: "anthropic/claude-sonnet-4.5")
.together(modelId: "meta-llama/Llama-2-70b-chat-hf")
.replicate(modelId: "meta/llama-2-70b-chat")

// Custom endpoints
.openaiCompatible(modelId: "gpt-4", baseURL: "https://api.azure.com")
.anthropicCompatible(modelId: "claude-opus-4-1-20250805", baseURL: "https://api.custom.ai")
```

### Core Generation Functions

Simple, async-first API following modern Swift patterns:

```swift
// Generate text from a prompt
func generate(
    _ prompt: String,
    using model: LanguageModel = .default,
    system: String? = nil,
    maxTokens: Int? = nil,
    temperature: Double? = nil
) async throws -> String

// Stream responses in real-time
func stream(
    _ prompt: String,
    using model: LanguageModel = .default,
    system: String? = nil,
    maxTokens: Int? = nil,
    temperature: Double? = nil
) async throws -> AsyncThrowingStream<TextStreamDelta, Error>

// Analyze images with vision models
func analyze(
    image: ImageInput,
    prompt: String,
    using model: Model? = nil
) async throws -> String

// Advanced generation with full control
func generateText(
    model: LanguageModel,
    messages: [ModelMessage],
    tools: [AgentTool]? = nil,
    settings: GenerationSettings = .default,
    maxSteps: Int = 1
) async throws -> GenerateTextResult

// Generate embeddings (NEW)
func generateEmbedding(
    model: EmbeddingModel,
    input: EmbeddingInput,
    settings: EmbeddingSettings = .default
) async throws -> EmbeddingResult
```

### OpenAI Harmony-Inspired Features ✨

Enhanced capabilities inspired by OpenAI Harmony patterns:

- **🎭 Multi-Channel Responses** - Separate thinking, analysis, and final answers
- **🧠 Reasoning Effort Levels** - Control depth of reasoning (low/medium/high)
- **🔄 Automatic Retry Handler** - Exponential backoff with smart rate limit handling
- **🔧 Enhanced Tool System** - Namespace and recipient support for tool routing
- **📊 Embeddings API** - Unified interface for OpenAI, Cohere, Voyage embeddings
- **💾 Response Caching** - Intelligent caching to reduce API calls

```swift
// Multi-channel responses
let result = try await generateText(
    model: .openai(.gpt51Mini),
    messages: messages,
    settings: GenerationSettings(reasoningEffort: .high)
)

for message in result.messages {
    switch message.channel {
    case .thinking: print("[Reasoning] \(message.content)")
    case .final: print("[Answer] \(message.content)")
    default: break
    }
}

// Automatic retry with exponential backoff
let retryHandler = RetryHandler(policy: .aggressive)
let response = try await retryHandler.execute {
    try await generateText(model: .openai(.gpt4o), messages: messages)
}

// Enhanced tools with namespaces
let tool = AgentTool(
    name: "search",
    description: "Search the web",
    parameters: params,
    namespace: "web",
    recipient: "search-engine",
    execute: { /* ... */ }
)
```

#### Realtime API Features

- **🎙️ WebSocket Streaming** - Persistent connection for low-latency (~500ms) voice conversations
- **🔊 Bidirectional Audio** - Real-time audio input and output with PCM16 format
- **🎯 Server VAD** - Automatic Voice Activity Detection for natural turn-taking
- **🔄 Dynamic Modalities** - Switch between text/audio/both during conversation
- **🛠️ Voice-Triggered Tools** - Execute functions via voice commands
- **🔁 Auto-Reconnect** - Automatic reconnection with exponential backoff
- **💾 Audio Buffering** - Buffer audio during disconnection for seamless recovery
- **📱 SwiftUI Ready** - Observable objects with @Published properties

See [docs/openai-harmony.md](docs/openai-harmony.md) for complete Realtime API documentation.

### Conversation Management

Fluent conversation API with SwiftUI integration:

```swift
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class Conversation: ObservableObject {
    @Published public private(set) var messages: [ConversationMessage] = []
    
    public func addUserMessage(_ content: String)
    public func addAssistantMessage(_ content: String)
    public func continue(using model: Model? = nil, tools: (any ToolKit)? = nil) async throws -> String
    public func clear()
}

// Usage in SwiftUI
struct ChatView: View {
    @StateObject private var conversation = Conversation()
    
    var body: some View {
        // Your chat UI here
    }
}
```

### Provider Options

Configure provider-specific settings while keeping universal parameters separate:

```swift
// GPT-5.1 with verbosity control (enables preamble messages)
let result = try await generateText(
    model: .openai(.gpt51),
    messages: messages,
    settings: GenerationSettings(
        maxTokens: 1000,
        providerOptions: .init(
            openai: .init(
                verbosity: .high  // Shows GPT-5.1's preamble messages
            )
        )
    )
)

// GPT-5.1 reasoning models with effort levels
let reasoning = try await generateText(
    model: .openai(.gpt51Mini),
    messages: messages,
    settings: GenerationSettings(
        providerOptions: .init(
            openai: .init(
                reasoningEffort: .high,  // Control reasoning depth
                parallelToolCalls: false
            )
        )
    )
)

// Claude with thinking mode
let claude = try await generateText(
    model: .anthropic(.opus4),
    messages: messages,
    settings: GenerationSettings(
        temperature: 0.7,
        providerOptions: .init(
            anthropic: .init(
                thinking: .enabled(budgetTokens: 5000),
                cacheControl: .persistent
            )
        )
    )
)

// Gemini with thinking configuration
let gemini = try await generateText(
    model: .google(.gemini25Pro),
    messages: messages,
    settings: GenerationSettings(
        topK: 40,  // Google supports topK
        providerOptions: .init(
            google: .init(
                thinkingConfig: .init(
                    budgetTokens: 3000,
                    includeThoughts: true
                ),
                safetySettings: .moderate
            )
        )
    )
)
```

#### Provider-Specific Options

**OpenAI Options:**
- `verbosity`: Control output detail (low/medium/high) - GPT-5 only
- `reasoningEffort`: Reasoning depth (minimal/low/medium/high) - O3/O4 only
- `parallelToolCalls`: Enable parallel tool execution
- `responseFormat`: JSON mode (.json) or schema validation
- `previousResponseId`: Chain responses for conversation persistence
- `logprobs`: Include log probabilities in response

**Anthropic Options:**
- `thinking`: Enable reasoning mode with token budget
- `cacheControl`: Conversation caching (ephemeral/persistent)

**Google Options:**
- `thinkingConfig`: Control reasoning with token budget
- `safetySettings`: Content filtering (strict/moderate/relaxed)

**Mistral Options:**
- `safeMode`: Enable safe content generation

**Groq Options:**
- `speed`: Inference speed (normal/fast/ultraFast)

**Grok Options:**
- `funMode`: Enable creative responses
- `includeCurrentEvents`: Access to current events

### Tool System with ToolKit Protocol

Type-safe function calling with structured tool definitions:

```swift
// Tool parameters use strongly-typed enums (no strings)
public enum ParameterType: String, Sendable, Codable {
    case string, number, integer, boolean, array, object, null
}

// Define tools using the protocol
struct MathToolKit: ToolKit {
    var tools: [Tool<MathToolKit>] {
        [
            createTool(
                name: "calculate",
                description: "Perform mathematical calculations"
            ) { input, context in
                let expression = try input.stringValue("expression")
                return try context.calculate(expression)
            }
        ]
    }
    
    func calculate(_ expression: String) throws -> String {
        // Your calculation logic
        let expr = NSExpression(format: expression)
        let result = expr.expressionValue(with: nil, context: nil) as! NSNumber
        return "\(result.doubleValue)"
    }
}

// Use with AI models
let toolkit = MathToolKit()
let result = try await generateText(
    model: .claude,
    messages: [.user("What is 15 * 23?")],
    tools: toolkit.tools.map { $0.toAgentTool() }
)
```

## Architecture

### Recent Improvements (January 2025)

- **Tool Type Extraction**: All tool-related types have been centralized in `Core/ToolTypes.swift` to eliminate circular dependencies and improve build times
- **Type-Safe Parameters**: Removed string-based parameter types in favor of strongly-typed `ParameterType` enum
- **Module Isolation**: TachikomaMCP can now use tool types without depending on agent functionality
- **Build Time Optimization**: Estimated 40-50% improvement in incremental build times through better modularization

### System Overview

```
                            Tachikoma Swift AI SDK
                                     |
  ┌─────────────────────────────────────────────────────────────────┐
  │                      Public API Layer                          │
  │  generate() • stream() • analyze() • Conversation • ToolKit    │
  └─────────────────────────────────────────────────────────────────┘
                                     |
  ┌─────────────────────────────────────────────────────────────────┐
  │                   Model Selection System                       │
  │    LanguageModel.openai(.gpt4o) • .anthropic(.opus4)          │
  │    .grok(.grok4) • .ollama(.llama33) • .google(.gemini25Flash) │
  └─────────────────────────────────────────────────────────────────┘
                                     |
  ┌─────────────────────────────────────────────────────────────────┐
  │                  Provider Implementations                      │
  │  OpenAI • Anthropic • Grok (xAI) • Ollama • Google • Mistral  │
  │  Groq • OpenRouter • Together • Replicate • Custom Endpoints  │
  └─────────────────────────────────────────────────────────────────┘
```

### Package Structure

Tachikoma provides multiple modules for different functionality:

- **`Tachikoma`** - Core AI SDK with generation, models, tools, and conversations
  - All tool types are now in `Core/ToolTypes.swift` for better modularization
  - Type-safe `ParameterType` enum for tool parameters (no string-based types)
  - Unified tool system used by all other modules
- **`TachikomaAgent`** - Agent system module for building autonomous AI agents
  - `Agent<Context>` class for stateful AI agents with conversation memory
  - Session management and persistence
  - Tool integration with context passing
  - Built on top of core Tachikoma functionality
- **`TachikomaMCP`** - Model Context Protocol (MCP) client and tool adapters
  - Uses shared tool types from core module
  - Provides dynamic tool discovery and execution
  - Bridges MCP tools to Tachikoma's `AgentTool` format
- **`TachikomaAudio`** - Comprehensive audio processing module:
  - Audio transcription (OpenAI Whisper, Groq, Deepgram)
  - Speech synthesis (OpenAI TTS, ElevenLabs)
  - Audio recording with AVFoundation
  - Batch processing and convenience functions

### Core Components

#### 1. Type-Safe Model System (`Model.swift`)

The `LanguageModel` enum provides compile-time safety and autocomplete for all supported AI providers:

```swift
public enum LanguageModel: Sendable, CustomStringConvertible {
    // Major providers with sub-enums
    case openai(OpenAI)      // .gpt4o, .gpt41, .gpt51Mini, .o4Mini
    case anthropic(Anthropic) // .opus4, .sonnet4, .haiku45, .opus4Thinking
    case grok(Grok)          // .grok4, .grok4FastReasoning, .grok2Vision
    case ollama(Ollama)      // .llama33, .llama32, .llava, .codellama
    case google(Google)      // .gemini25Pro, .gemini25Flash
    case mistral(Mistral)    // .large2, .nemo, .codestral
    case groq(Groq)          // .llama3170b, .mixtral8x7b
    
    // Third-party aggregators
    case openRouter(modelId: String)
    case together(modelId: String)
    case replicate(modelId: String)
    
    // Custom endpoints
    case openaiCompatible(modelId: String, baseURL: String)
    case anthropicCompatible(modelId: String, baseURL: String)
    case custom(provider: any ModelProvider)
    
    public static let `default`: LanguageModel = .anthropic(.opus4)
    public static let claude: LanguageModel = .anthropic(.opus4)
    public static let gpt4o: LanguageModel = .openai(.gpt4o)
    public static let llama: LanguageModel = .ollama(.llama33)
}
```

Each model includes capabilities metadata:

```swift
// Automatic capability detection
let model = LanguageModel.openai(.gpt4o)
print(model.supportsVision)      // true
print(model.supportsTools)       // true  
print(model.supportsAudioInput)  // true
print(model.contextLength)       // 128,000
```

#### 2. Generation Functions (`Generation.swift`)

Core async functions following Vercel AI SDK patterns:

```swift
// Simple convenience functions
public func generate(_ prompt: String, using model: LanguageModel = .default) async throws -> String
public func stream(_ prompt: String, using model: LanguageModel = .default) async throws -> AsyncThrowingStream<TextStreamDelta, Error>
public func analyze(image: ImageInput, prompt: String, using model: Model? = nil) async throws -> String

// Advanced functions with full control
public func generateText(
    model: LanguageModel,
    messages: [ModelMessage],
    tools: [AgentTool]? = nil,
    settings: GenerationSettings = .default,
    maxSteps: Int = 1
) async throws -> GenerateTextResult

public func streamText(
    model: LanguageModel,
    messages: [ModelMessage],
    tools: [AgentTool]? = nil,
    settings: GenerationSettings = .default,
    maxSteps: Int = 1
) async throws -> StreamTextResult

public func generateObject<T: Codable & Sendable>(
    model: LanguageModel,
    messages: [ModelMessage],
    schema: T.Type,
    settings: GenerationSettings = .default
) async throws -> GenerateObjectResult<T>
```

#### 3. Tool System (`Core/ToolTypes.swift`, `Tools/ToolBuilder.swift`, `ToolKit.swift`)

Type-safe function calling with protocol-based tool definitions:

```swift
// Protocol for type-safe tools
public protocol AgentToolProtocol: Sendable {
    associatedtype Input: AgentToolValue
    associatedtype Output: AgentToolValue
    
    var name: String { get }
    var description: String { get }
    var schema: AgentToolSchema { get }
    
    func execute(_ input: Input, context: ToolExecutionContext) async throws -> Output
}

// Protocol for tool values with JSON conversion
public protocol AgentToolValue: Sendable, Codable {
    static var agentValueType: AgentValueType { get }
    func toJSON() throws -> Any
    static func fromJSON(_ json: Any) throws -> Self
}

// Type-erased wrapper for dynamic scenarios
public struct AnyAgentToolValue: AgentToolValue {
    // Wraps any AgentToolValue for runtime flexibility
}

// Backwards-compatible tool definition
public struct AgentTool: Sendable {
    public let name: String
    public let description: String
    public let parameters: AgentToolParameters
    
    public func execute(_ arguments: AgentToolArguments, 
                       context: ToolExecutionContext? = nil) async throws -> AnyAgentToolValue
}

// Protocol for tool collections
public protocol ToolKit: Sendable {
    associatedtype Context = Self
    var tools: [Tool<Context>] { get }
}
```

#### 4. Conversation Management (`Conversation.swift`)

Multi-turn conversations with SwiftUI support:

```swift
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class Conversation: ObservableObject, @unchecked Sendable {
    @Published public private(set) var messages: [ConversationMessage] = []
    
    public func addUserMessage(_ content: String)
    public func addAssistantMessage(_ content: String)
    public func continue(using model: Model? = nil, tools: (any ToolKit)? = nil) async throws -> String
    public func clear()
}
```

#### 5. Provider System (`ProviderFactory.swift`)

Extensible provider architecture supporting multiple AI services:

```swift
// Provider protocol for extensibility
public protocol ModelProvider: Sendable {
    var modelId: String { get }
    var baseURL: String? { get }
    var apiKey: String? { get }
    var capabilities: ModelCapabilities { get }
    
    func generateText(request: ProviderRequest) async throws -> ProviderResponse
    func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error>
}

// Factory for creating providers
public struct ProviderFactory {
    public static func createProvider(for model: LanguageModel) throws -> any ModelProvider
}
```

### Key Implementation Files

| Component | File Location | Lines | Purpose |
|-----------|---------------|-------|----------|
| **Model System** | `Sources/Tachikoma/Model.swift` | 1-875 | Type-safe model enums, capabilities, provider selection |
| **Generation** | `Sources/Tachikoma/Generation.swift` | 18-569 | Core async generation functions, streaming, image analysis |
| **Tool System** | `Sources/Tachikoma/Tool.swift` | - | Tool protocol, execution, input/output handling |
| **ToolKit Builders** | `Sources/Tachikoma/ToolKit.swift` | 1-285 | ToolKit protocol, result builders, example implementations |
| **Conversation** | `Sources/Tachikoma/Conversation.swift` | - | Multi-turn conversation management, SwiftUI integration |
| **Provider Factory** | `Sources/Tachikoma/ProviderFactory.swift` | - | Provider instantiation, capability mapping |
| **Usage Tracking** | `Sources/Tachikoma/UsageTracking.swift` | - | Token usage, cost tracking, session management |
| **Model Selection** | `Sources/Tachikoma/ModelSelection.swift` | - | Command-line model parsing, string matching |

## Installation & Usage

### Swift Package Manager

Add Tachikoma to your project using Swift Package Manager:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/steipete/Tachikoma.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            // Core AI functionality
            .product(name: "Tachikoma", package: "Tachikoma"),
            // Agent system (optional)
            .product(name: "TachikomaAgent", package: "Tachikoma"),
            // Audio processing (optional)
            .product(name: "TachikomaAudio", package: "Tachikoma"),
            // MCP support (optional)
            .product(name: "TachikomaMCP", package: "Tachikoma"),
        ]
    )
]
```

### Environment Setup

Set up API keys for the providers you want to use:

```bash
# OpenAI
export OPENAI_API_KEY="sk-..."

# Anthropic
export ANTHROPIC_API_KEY="sk-ant-..."

# Grok (xAI)
export X_AI_API_KEY="xai-..."
# or
export XAI_API_KEY="xai-..."

# Groq
export GROQ_API_KEY="gsk_..."

# Mistral
export MISTRAL_API_KEY="..."

# Google AI
export GEMINI_API_KEY="gk-..."   # Legacy GOOGLE_API_KEY or GOOGLE_APPLICATION_CREDENTIALS also accepted

# Azure OpenAI
export AZURE_OPENAI_API_KEY="az-..."
export AZURE_OPENAI_RESOURCE="my-aoai"            # or AZURE_OPENAI_ENDPOINT="https://foo.openai.azure.com"
export AZURE_OPENAI_API_VERSION="2025-04-01-preview"
export AZURE_OPENAI_BEARER_TOKEN="optional-entra-token"  # overrides api-key when set

# Ollama (runs locally)
export OLLAMA_API_KEY="optional-token"  # Usually not needed

> Azure notes: You must use the deployment name (not the model id) when selecting `.azureOpenAI(deployment:resource:)`. Tachikoma builds the Azure path `/openai/deployments/{deployment}/chat/completions` and appends `api-version`; both `api-key` and Entra bearer tokens are supported.

# Custom base URLs (optional)
export OPENAI_BASE_URL="https://api.custom.com/v1"
export ANTHROPIC_BASE_URL="https://api.custom.com"
export OLLAMA_BASE_URL="http://localhost:11434"
```

#### Automatic Environment Variable Loading

Tachikoma automatically loads API keys from environment variables when the SDK initializes. The configuration system uses a **hierarchical priority**:

1. **Explicitly configured keys** (via `configuration.setAPIKey()`)
2. **Environment variables** (loaded automatically on startup)
3. **Credentials file** (`~/.tachikoma/credentials`)

```swift
import Tachikoma

// Keys are loaded automatically from environment variables
// No manual configuration needed if environment variables are set

// Check what's available
let config = TachikomaConfiguration() // Loads from environment by default

// These will return environment keys if available
print("OpenAI available: \(config.hasAPIKey(for: .openai))")
print("Anthropic available: \(config.hasAPIKey(for: .anthropic))")
print("Grok available: \(config.hasAPIKey(for: .grok))")

// Check specifically for environment vs configured keys
print("OpenAI from env: \(config.hasEnvironmentAPIKey(for: .openai))")
print("OpenAI configured: \(config.hasConfiguredAPIKey(for: .openai))")
```

#### Provider Type-Safety

The SDK now uses a type-safe `Provider` enum instead of strings:

```swift
// ✅ Type-safe provider API
let config = TachikomaConfiguration()
config.setAPIKey("sk-...", for: .openai)
config.setAPIKey("sk-ant-...", for: .anthropic)
config.setAPIKey("xai-...", for: .grok)

// ✅ All standard providers supported
let providers: [Provider] = [
    .openai,     // OPENAI_API_KEY
    .anthropic,  // ANTHROPIC_API_KEY
    .grok,       // X_AI_API_KEY or XAI_API_KEY
    .groq,       // GROQ_API_KEY
    .mistral,    // MISTRAL_API_KEY
    .google,     // GEMINI_API_KEY (legacy GOOGLE_API_KEY / GOOGLE_APPLICATION_CREDENTIALS)
    .ollama,     // OLLAMA_API_KEY (optional)
    .custom("my-provider")  // Custom provider ID
]
```

#### Alternative Environment Variables

Some providers support multiple environment variable names:

```swift
// Grok supports both naming conventions
export X_AI_API_KEY="xai-..."    # Primary
export XAI_API_KEY="xai-..."     # Alternative

// The SDK automatically checks both
let provider = Provider.grok
print(provider.environmentVariable)            // "X_AI_API_KEY"
print(provider.alternativeEnvironmentVariables) // ["XAI_API_KEY"]
```

### Basic Usage Examples

#### Text Generation

```swift
import Tachikoma

// Simple generation with default model (Claude Opus 4)
let response = try await generate("Explain Swift async/await")

// With specific model
let gptResponse = try await generate(
    "Write a haiku about programming",
    using: .openai(.gpt4o)
)

// With system prompt and parameters
let response = try await generate(
    "Tell me a joke",
    using: .anthropic(.sonnet4),
    system: "You are a friendly comedian",
    maxTokens: 100,
    temperature: 0.9
)
```

#### Streaming Responses

```swift
let stream = try await stream("Write a long story", using: .claude)

for try await delta in stream {
    switch delta.type {
    case .textDelta:
        if let content = delta.content {
            print(content, terminator: "")
        }
    case .done:
        print("\n[Stream complete]")
        break
    default:
        break
    }
}
```

#### Image Analysis

```swift
// Analyze image from file path
let analysis = try await analyze(
    image: .filePath("/path/to/image.png"),
    prompt: "What do you see in this image?",
    using: .openai(.gpt4o)  // Vision-capable model required
)

// Analyze image from base64 data
let analysis = try await analyze(
    image: .base64(base64String),
    prompt: "Describe the contents of this screenshot"
)
```

#### Conversations

```swift
let conversation = Conversation()

// Add messages
conversation.addUserMessage("Hello! I'm learning Swift.")
let response1 = try await conversation.continue(using: .claude)
print(response1)

conversation.addUserMessage("Can you explain optionals?")
let response2 = try await conversation.continue()  // Uses same model
print(response2)

// In SwiftUI
struct ChatView: View {
    @StateObject private var conversation = Conversation()
    @State private var inputText = ""
    
    var body: some View {
        VStack {
            ScrollView {
                ForEach(conversation.messages) { message in
                    MessageView(message: message)
                }
            }
            
            HStack {
                TextField("Type a message...", text: $inputText)
                Button("Send") {
                    Task {
                        conversation.addUserMessage(inputText)
                        inputText = ""
                        let response = try await conversation.continue()
                        // Response automatically added to conversation
                    }
                }
            }
        }
    }
}
```

#### Tools and Function Calling

```swift
// Define a custom tool kit
struct CalculatorToolKit: ToolKit {
    var tools: [Tool<CalculatorToolKit>] {
        [
            createTool(
                name: "calculate",
                description: "Perform mathematical calculations"
            ) { input, context in
                let expression = try input.stringValue("expression")
                return try context.evaluate(expression: expression)
            },
            
            createTool(
                name: "convert_currency",
                description: "Convert between currencies"
            ) { input, context in
                let amount = try input.doubleValue("amount")
                let from = try input.stringValue("from_currency")
                let to = try input.stringValue("to_currency")
                return try await context.convertCurrency(amount: amount, from: from, to: to)
            }
        ]
    }
    
    func evaluate(expression: String) throws -> String {
        let expr = NSExpression(format: expression)
        let result = expr.expressionValue(with: nil, context: nil) as! NSNumber
        return "Result: \(result.doubleValue)"
    }
    
    func convertCurrency(amount: Double, from: String, to: String) async throws -> String {
        // Your currency conversion logic here
        return "\(amount) \(from) = \(amount * 1.1) \(to) (example rate)"
    }
}

// Use tools with AI
let calculator = CalculatorToolKit()
let result = try await generateText(
    model: .claude,
    messages: [.user("What is 15 * 23 + 100? Also convert 50 USD to EUR.")],
    tools: calculator.tools.map { $0.toAgentTool() }
)

print(result.text)  // AI will use the tools to calculate and convert
```

## Build & Test

```bash
# Build the package
swift build

# Run tests
swift test

# Build in release mode
swift build -c release
```

## Advanced Features

### Stop Conditions

Control when generation should stop with flexible stop conditions:

```swift
// Stop on specific strings
let response = try await generateText(
    model: .openai(.gpt4o),
    messages: [.user("Count to 10 then say END")],
    settings: GenerationSettings(
        stopConditions: StringStopCondition("END")
    )
)
// Response will stop at "END"

// Stop after token limit
let limited = try await generateText(
    model: .claude,
    messages: [.user("Write a long story")],
    settings: GenerationSettings(
        stopConditions: TokenCountStopCondition(maxTokens: 100)
    )
)

// Stop on regex patterns
let patternStop = try await generateText(
    model: .openai(.gpt4o),
    messages: [.user("Generate code")],
    settings: GenerationSettings(
        stopConditions: RegexStopCondition(pattern: "// END OF CODE")
    )
)

// Combine multiple conditions
let settings = GenerationSettings.withStopConditions(
    StringStopCondition("STOP", caseSensitive: false),
    TokenCountStopCondition(maxTokens: 500),
    TimeoutStopCondition(timeout: 30.0),
    maxTokens: 1000,
    temperature: 0.7
)

// With streaming
let stream = try await streamText(
    model: .claude,
    messages: messages,
    settings: GenerationSettings(
        stopConditions: StringStopCondition("END")
    )
)

// Or apply stop conditions to existing streams
let stoppedStream = stream
    .stopOnString("STOP")
    .stopAfterTokens(500)
    .stopAfterTime(30.0)

// Custom stop conditions
let customStop = PredicateStopCondition { text, delta in
    // Stop when text contains both keywords
    text.contains("COMPLETE") && text.contains("DONE")
}

// Builder pattern for complex conditions
let complexCondition = StopConditionBuilder()
    .whenContains("END")
    .whenMatches("\\[DONE\\]")
    .afterTokens(1000)
    .afterTime(60.0)
    .build()
```

Stop conditions work with both `generateText` and `streamText`, and are automatically passed to providers that support native stop sequences (like OpenAI's `stop` parameter).

### Usage Tracking

Tachikoma automatically tracks token usage and costs across all operations:

```swift
// Usage is tracked automatically during generation
let result = try await generateText(
    model: .openai(.gpt4o),
    messages: [.user("Long prompt here...")]
)

if let usage = result.usage {
    print("Input tokens: \(usage.inputTokens)")
    print("Output tokens: \(usage.outputTokens)")
    if let cost = usage.cost {
        print("Estimated cost: $\(cost)")
    }
}

// Access global usage statistics
let tracker = UsageTracker.shared
let todayUsage = tracker.getUsage(for: Date())
print("Today's total tokens: \(todayUsage.totalTokens)")
```

### Multi-Step Tool Execution

Handle complex workflows with multiple tool calls:

```swift
let result = try await generateText(
    model: .claude,
    messages: [.user("Research Swift 6 features, then write documentation")],
    tools: researchTools.tools.map { $0.toAgentTool() },
    maxSteps: 5  // Allow multiple rounds of tool calling
)

// Access all execution steps
for (index, step) in result.steps.enumerated() {
    print("Step \(index + 1):")
    print("  Text: \(step.text)")
    print("  Tool calls: \(step.toolCalls.count)")
    print("  Tool results: \(step.toolResults.count)")
}
```

### Structured Output Generation

Generate type-safe structured data:

```swift
struct PersonInfo: Codable {
    let name: String
    let age: Int
    let occupation: String
    let skills: [String]
}

let result = try await generateObject(
    model: .claude,
    messages: [.user("Create a person profile for a software engineer")],
    schema: PersonInfo.self
)

let person = result.object
print("Name: \(person.name)")
print("Skills: \(person.skills.joined(separator: ", "))")
```

### Custom Providers

Extend Tachikoma with custom AI providers:

```swift
struct CustomProvider: ModelProvider {
    let modelId = "custom-model-v1"
    let baseURL: String? = "https://api.custom.ai"
    let apiKey: String? = ProcessInfo.processInfo.environment["CUSTOM_API_KEY"]
    
    let capabilities = ModelCapabilities(
        supportsVision: true,
        supportsTools: true,
        contextLength: 200_000
    )
    
    func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        // Your custom implementation
    }
    
    func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        // Your custom streaming implementation
    }
}

// Use custom provider
let customModel = LanguageModel.custom(provider: CustomProvider())
let response = try await generate("Hello", using: customModel)
```

## Examples

See the following files for complete working examples:

- **`Tests/TachikomaTests/MinimalModernAPITests.swift`** - Model construction, tool creation, conversation management
- **`Sources/Tachikoma/ToolKit.swift`** - WeatherToolKit and MathToolKit implementations (lines 125-224)
- **`Examples/TachikomaExamples.swift`** - Advanced usage patterns and real-world scenarios
- **`Examples/DemoScript.swift`** - Interactive demo script

## Documentation

- **[Architecture Guide](docs/ARCHITECTURE.md)** - Deep dive into system design and components
- **[Modern API Design](docs/modern-api.md)** - Implementation plan and design decisions
- **[API Reference](Sources/Tachikoma/Tachikoma.swift)** - Complete API documentation in code
- **[Migration Guide](docs/modern-api.md#migration-guide)** - Moving from other AI SDKs
- **[Provider Guide](docs/providers.md)** - Setting up different AI providers
- **[Tool Development](docs/tools.md)** - Creating custom tools and toolkits

## Requirements

- **Swift 6.0+** with strict concurrency enabled
- **Platform Support**:
  - macOS 13.0+ (Ventura)
  - iOS 16.0+
  - watchOS 9.0+
  - tvOS 16.0+
  - Linux (Ubuntu 20.04+)
- **Concurrency**: Full `@Sendable` compliance throughout
- **Dependencies**: 
  - [swift-log](https://github.com/apple/swift-log) for logging

## Testing

Tachikoma includes comprehensive test coverage using Swift Testing framework (Xcode 16+).

### Running Tests

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter "ProviderOptionsTests"

# Run multiple test suites
swift test --filter "ProviderOptionsTests|ModelCapabilitiesTests"

# Run with verbose output
swift test --verbose
```

### Test Organization

Tests are organized by feature area:

- **Core Tests**: Model capabilities, provider options, configuration
- **Provider Tests**: Individual provider implementations
- **Tool Tests**: Tool system and agent functionality
- **Audio Tests**: Audio processing and realtime features
- **Integration Tests**: End-to-end workflows

### Key Test Areas

#### Provider Options Tests
Tests for provider-specific configuration options:

```swift
@Test("OpenAI options with verbosity")
func testOpenAIVerbosity() {
    let options = OpenAIOptions(
        verbosity: .high,
        reasoningEffort: .medium
    )
    #expect(options.verbosity == .high)
}
```

#### Model Capabilities Tests
Tests for model-specific parameter validation:

```swift
@Test("GPT-5 excludes temperature")
func testGPT5Capabilities() {
    let caps = ModelCapabilityRegistry.shared
        .capabilities(for: .openai(.gpt51))
    
    #expect(!caps.supportsTemperature)
    #expect(caps.supportsVerbosity)
}
```

#### Settings Validation Tests
Tests for automatic parameter filtering:

```swift
@Test("Validate settings for model")
func testSettingsValidation() {
    let settings = GenerationSettings(
        temperature: 0.7,  // Will be removed for GPT-5
        providerOptions: .init(
            openai: .init(verbosity: .high)
        )
    )
    
    let validated = settings.validated(for: .openai(.gpt51))
    #expect(validated.temperature == nil)
    #expect(validated.providerOptions.openai?.verbosity == .high)
}
```

### Writing Tests

Use Swift Testing's modern syntax:

```swift
import Testing
@testable import Tachikoma

@Suite("My Feature Tests")
struct MyFeatureTests {
    @Test("Test specific behavior")
    func testBehavior() async throws {
        // Arrange
        let model = LanguageModel.openai(.gpt4o)
        
        // Act
        let result = try await generateText(
            model: model,
            messages: [.user("Hello")]
        )
        
        // Assert
        #expect(!result.text.isEmpty)
    }
}
```

### Test Coverage Areas

- ✅ **Provider Options**: All provider-specific options
- ✅ **Model Capabilities**: Parameter support per model
- ✅ **Settings Validation**: Automatic filtering and validation
- ✅ **Thread Safety**: Concurrent access patterns
- ✅ **Codable Conformance**: Serialization/deserialization
- ✅ **Tool System**: Tool registration and execution
- ✅ **Streaming**: Async stream handling
- ✅ **Error Handling**: Proper error propagation

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

```bash
git clone https://github.com/steipete/Tachikoma.git
cd Tachikoma

# Build and test
swift build
swift test

# Generate documentation
swift package generate-documentation
```

## License

Tachikoma is available under the MIT License. See [LICENSE](LICENSE) for details.

Built with ❤️ for the Swift AI community

*Intelligent • Adaptable • Reliable*

## Coverage

| Date       | Command                                                             | Scope             | Line Coverage |
| ---------- | ------------------------------------------------------------------- | ----------------- | ------------- |
| 2025-11-13 | ``cd Tachikoma && TACHIKOMA_DISABLE_API_TESTS=true TACHIKOMA_TEST_MODE=mock ../runner swift test --enable-code-coverage && xcrun llvm-profdata merge -sparse .build/debug/codecov/*.profraw -o .build/debug/codecov/default.profdata && scripts/core-coverage.sh`` | Core Tachikoma objects (models, configuration, providers) | 74.26 %       |
| 2025-11-12 | `./runner swift test --package-path Tachikoma --enable-code-coverage` | Tachikoma package | 41.69 %       |

> Coverage derived from `scripts/core-coverage.sh`, which wraps `xcrun llvm-cov report -instr-profile .build/debug/codecov/default.profdata` with the `Model.swift.o`, `Configuration.swift.o`, `CustomProviders.swift.o`, `Provider*.swift.o`, `OpenAICompatibleHelper.swift.o`, `UsageTracking.swift.o`, `ResponseCache.swift.o`, `RetryHandler.swift.o`, and `Types.swift.o` objects to focus on the core Tachikoma runtime (UI/audio/MCP modules require interactive contexts and are tracked separately).
