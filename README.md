<div align="center">
  <img src="assets/logo.png" width="200" alt="Tachikoma Logo">
  
  # Tachikoma - Modern Swift AI SDK

<p align="center">
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0+-FA7343?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 6.0+"></a>
  <a href="https://github.com/steipete/Tachikoma"><img src="https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-blue?style=for-the-badge" alt="Platforms"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="MIT License"></a>
  <a href="#testing"><img src="https://img.shields.io/badge/tests-passing-brightgreen?style=for-the-badge" alt="Tests"></a>
</p>

**A Modern Swift AI SDK that makes AI integration feel natural**

Named after the spider-tank AI from Ghost in the Shell, **Tachikoma** provides an intelligent, adaptable interface for AI services with a completely modern Swift-native API.
</div>

## Quick Start

### Basic Setup

```swift
import Tachikoma  // Imports all modules
// Or import individually:
// import TachikomaCore, TachikomaBuilders

// Simple text generation
let answer = try await generate("What is 2+2?", using: .openai(.gpt4o))
print(answer) // "4"

// With different models
let response1 = try await generate("Hello", using: .anthropic(.opus4))
let response2 = try await generate("Hello", using: .grok(.grok4))
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

### Tool Integration

```swift
// Define tools using the ToolKit protocol
struct WeatherTools: ToolKit {
    var tools: [Tool<WeatherTools>] {
        [
            createTool(
                name: "get_weather",
                description: "Get current weather for a location"
            ) { input, context in
                let location = try input.stringValue("location")
                return try await context.getWeather(location: location)
            }
        ]
    }
    
    func getWeather(location: String) async throws -> String {
        // Your weather API integration here
        return "Sunny, 22°C in \(location)"
    }
}

// Use tools with AI models
let toolkit = WeatherTools()
let result = try await generateText(
    model: .claude,
    messages: [.user("What's the weather in Tokyo?")],
    tools: toolkit.tools.map { $0.toSimpleTool() }
)
print(result.text)
```

## Core Features

### Type-Safe Model Selection

Compile-time safety with provider-specific enums and full autocomplete support:

```swift
// Provider-specific models with compile-time checking
.openai(.gpt4o, .gpt41, .o3, .o3Mini, .custom("ft:gpt-4o:org:abc"))
.anthropic(.opus4, .sonnet4, .haiku35, .opus4Thinking)
.grok(.grok4, .grok40709, .grok2Vision1212)
.ollama(.llama33, .llama32, .llava, .codellama)
.google(.gemini2Flash, .gemini15Pro)
.mistral(.large2, .nemo)
.groq(.llama3170b, .mixtral8x7b)

// Third-party aggregators
.openRouter(modelId: "anthropic/claude-3.5-sonnet")
.together(modelId: "meta-llama/Llama-2-70b-chat-hf")
.replicate(modelId: "meta/llama-2-70b-chat")

// Custom endpoints
.openaiCompatible(modelId: "gpt-4", baseURL: "https://api.azure.com")
.anthropicCompatible(modelId: "claude-3-opus", baseURL: "https://api.custom.ai")
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
    tools: [SimpleTool]? = nil,
    settings: GenerationSettings = .default,
    maxSteps: Int = 1
) async throws -> GenerateTextResult
```

### Conversation Management

Fluent conversation API with SwiftUI integration:

```swift
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

### Tool System with ToolKit Protocol

Type-safe function calling with structured tool definitions:

```swift
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
    tools: toolkit.tools.map { $0.toSimpleTool() }
)
```

## Architecture

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
  │    .grok(.grok4) • .ollama(.llama33) • .google(.gemini2Flash) │
  └─────────────────────────────────────────────────────────────────┘
                                     |
  ┌─────────────────────────────────────────────────────────────────┐
  │                  Provider Implementations                      │
  │  OpenAI • Anthropic • Grok (xAI) • Ollama • Google • Mistral  │
  │  Groq • OpenRouter • Together • Replicate • Custom Endpoints  │
  └─────────────────────────────────────────────────────────────────┘
```

### Package Structure

Tachikoma is organized into focused, composable modules:

- **`TachikomaCore`** - Core generation functions, model system, conversation management, provider interfaces
- **`TachikomaBuilders`** - Tool system, ToolKit protocol, example implementations, helper functions
- **`TachikomaCLI`** - Command-line utilities, model parsing, configuration management
- **`Tachikoma`** - Umbrella module that re-exports all functionality for convenience

### Core Components

#### 1. Type-Safe Model System (`Model.swift`)

The `LanguageModel` enum provides compile-time safety and autocomplete for all supported AI providers:

```swift
public enum LanguageModel: Sendable, CustomStringConvertible {
    // Major providers with sub-enums
    case openai(OpenAI)      // .gpt4o, .gpt41, .o3, .o3Mini, .o4Mini
    case anthropic(Anthropic) // .opus4, .sonnet4, .haiku35, .opus4Thinking
    case grok(Grok)          // .grok4, .grok40709, .grok2Vision1212
    case ollama(Ollama)      // .llama33, .llama32, .llava, .codellama
    case google(Google)      // .gemini2Flash, .gemini15Pro
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
    tools: [SimpleTool]? = nil,
    settings: GenerationSettings = .default,
    maxSteps: Int = 1
) async throws -> GenerateTextResult

public func streamText(
    model: LanguageModel,
    messages: [ModelMessage],
    tools: [SimpleTool]? = nil,
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

#### 3. Tool System (`Tool.swift`, `ToolKit.swift`)

Type-safe function calling with structured tool definitions:

```swift
// Protocol for tool collections
public protocol ToolKit: Sendable {
    associatedtype Context = Self
    var tools: [Tool<Context>] { get }
}

// Individual tool definition
public struct Tool<Context>: Sendable {
    public let name: String
    public let description: String
    public let execute: @Sendable (ToolInput, Context) async throws -> ToolOutput
}

// Helper functions for tool creation
public func createTool<Context>(
    name: String,
    description: String,
    _ handler: @escaping @Sendable (ToolInput, Context) async throws -> String
) -> Tool<Context>
```

#### 4. Conversation Management (`Conversation.swift`)

Multi-turn conversations with SwiftUI support:

```swift
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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
| **Model System** | `Sources/TachikomaCore/Model.swift` | 1-875 | Type-safe model enums, capabilities, provider selection |
| **Generation** | `Sources/TachikomaCore/Generation.swift` | 18-569 | Core async generation functions, streaming, image analysis |
| **Tool System** | `Sources/TachikomaCore/Tool.swift` | - | Tool protocol, execution, input/output handling |
| **ToolKit Builders** | `Sources/TachikomaBuilders/ToolKit.swift` | 1-285 | ToolKit protocol, result builders, example implementations |
| **Conversation** | `Sources/TachikomaCore/Conversation.swift` | - | Multi-turn conversation management, SwiftUI integration |
| **Provider Factory** | `Sources/TachikomaCore/ProviderFactory.swift` | - | Provider instantiation, capability mapping |
| **Usage Tracking** | `Sources/TachikomaCore/UsageTracking.swift` | - | Token usage, cost tracking, session management |
| **Model Selection** | `Sources/TachikomaCLI/ModelSelection.swift` | - | Command-line model parsing, string matching |

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
            .product(name: "Tachikoma", package: "Tachikoma"),  // All modules
            // Or import individually:
            // .product(name: "TachikomaCore", package: "Tachikoma"),
            // .product(name: "TachikomaBuilders", package: "Tachikoma"),
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

# Google AI
export GOOGLE_AI_API_KEY="AIza..."

# Mistral
export MISTRAL_API_KEY="..."

# For Ollama (runs locally)
# No API key needed - just ensure Ollama is running on localhost:11434
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
    tools: calculator.tools.map { $0.toSimpleTool() }
)

print(result.text)  // AI will use the tools to calculate and convert
```

## Build & Test

```bash
# Build all modules
swift build

# Run tests with specific module
swift test --product TachikomaCoreTests
swift test --product TachikomaBuildersTests
swift test --product TachikomaTests

# Run all tests
swift test

# Build specific module
swift build --product TachikomaCore
swift build --product TachikomaBuilders
swift build --product Tachikoma

# Build in release mode
swift build -c release
```

## Advanced Features

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
    tools: researchTools.tools.map { $0.toSimpleTool() },
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
- **`Sources/TachikomaBuilders/ToolKit.swift`** - WeatherToolKit and MathToolKit implementations (lines 125-224)
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
  - macOS 14.0+ (Sonoma)
  - iOS 17.0+
  - watchOS 10.0+
  - tvOS 17.0+
- **Concurrency**: Full `@Sendable` compliance throughout
- **Dependencies**: 
  - [swift-log](https://github.com/apple/swift-log) for logging

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
