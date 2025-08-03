#!/usr/bin/env swift

// MARK: - Standalone Tachikoma SDK Examples
//
// This demonstrates the Tachikoma SDK API patterns without requiring imports
// Shows the type-safe, modern Swift interface design
// Run with: swift standalone_examples.swift

import Foundation

print("🕷️ TACHIKOMA SWIFT AI SDK - COMPREHENSIVE API DEMONSTRATION")
print("=" * 60)

// MARK: - 🎯 Model System Examples

print("\n🎯 === Type-Safe Model System ===")

// This shows the actual API design - enum-based model selection
let exampleModels = """
// OpenAI Models
.openai(.o3)              // Advanced reasoning model
.openai(.o3Mini)          // Smaller reasoning model  
.openai(.gpt4_1)          // Latest GPT-4.1 with 1M context
.openai(.gpt4o)           // Multimodal model
.openai(.custom("ft:...")) // Fine-tuned model

// Anthropic Models  
.anthropic(.opus4)        // Flagship model (DEFAULT)
.anthropic(.opus4Thinking) // Extended thinking mode
.anthropic(.sonnet4)      // Cost-optimized
.anthropic(.haiku3_5)     // Fast, cost-effective

// Grok Models (xAI)
.grok(.grok4)             // Latest Grok 4
.grok(.grok2Vision_1212)  // Vision-capable model

// Ollama Models (Local)
.ollama(.llama33)         // Best overall (recommended)
.ollama(.llava)           // Vision model (no tool support)
.ollama(.codellama)       // Code-specialized

// Custom Endpoints
.openRouter(modelId: "anthropic/claude-3.5-sonnet")
.openaiCompatible(modelId: "gpt-4", baseURL: "https://api.azure.com")
"""

print("✅ Model Types Available:")
print(exampleModels)

// MARK: - 🎨 Generation Functions

print("\n🎨 === Global Generation Functions ===")

let generationExamples = """
// Simple text generation
let answer = try await generate("What is Swift?")

// With specific model
let response = try await generate(
    "Explain async/await", 
    using: .anthropic(.sonnet4)
)

// With system prompt and parameters
let creative = try await generate(
    "Write a haiku about programming",
    using: .openai(.gpt4o),
    system: "You are a poetic programming expert",
    maxTokens: 100,
    temperature: 0.8
)

// Image analysis
let analysis = try await analyze(
    image: .filePath("/path/to/image.png"),
    prompt: "What do you see?",
    using: .openai(.gpt4o)  // Vision-capable model
)

// Streaming responses
let stream = try await stream("Tell me about Swift concurrency")
for try await delta in stream {
    switch delta.type {
    case .textDelta:
        print(delta.content ?? "")
    case .done:
        break
    default:
        continue
    }
}
"""

print("✅ Generation API Examples:")
print(generationExamples)

// MARK: - 💬 Conversation Management

print("\n💬 === Conversation Management ===")

let conversationExamples = """
// Create conversation
let conversation = Conversation()

// Add messages
conversation.addSystemMessage("You are a Swift expert")
conversation.addUserMessage("How do I use actors?")

// Continue conversation (makes API call)
let response = try await conversation.continueConversation(
    using: .anthropic(.opus4)
)

// Messages are automatically tracked
print("Messages: \\(conversation.messages.count)")
"""

print("✅ Conversation API Examples:")
print(conversationExamples)

// MARK: - 🔧 ToolKit System

print("\n🔧 === @ToolKit Result Builder System ===")

let toolkitExamples = """
// Define custom tools with @ToolKit
@ToolKit
struct FileOperations {
    func readFile(path: String) async throws -> String {
        return try String(contentsOfFile: path)
    }
    
    func writeFile(path: String, content: String) async throws -> Void {
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    func listDirectory(path: String) async throws -> [String] {
        return try FileManager.default.contentsOfDirectory(atPath: path)
    }
}

// Use with AI generation
let result = try await generate(
    "List the files in /Users/example/Documents",
    using: .claude,
    tools: FileOperations()
)

// Built-in example toolkits
let weatherTools = WeatherToolKit()
let mathTools = MathToolKit()

// Tool execution
let weather = try await weatherTools.execute(
    toolNamed: "get_weather",
    jsonInput: "{\\"location\\": \\"Tokyo\\"}"
)
"""

print("✅ ToolKit System Examples:")
print(toolkitExamples)

// MARK: - ⚙️ Configuration & Error Handling

print("\n⚙️ === Configuration & Error Handling ===")

let configExamples = """
// Generation settings
let settings = GenerationSettings(
    maxTokens: 500,
    temperature: 0.7,
    topP: 0.9,
    stopSequences: ["END"]
)

// Model capabilities
let model = LanguageModel.openai(.gpt4o)
print("Supports Vision: \\(model.supportsVision)")
print("Supports Tools: \\(model.supportsTools)")
print("Context Length: \\(model.contextLength)")

// Error handling
do {
    let result = try await generate("Hello", using: .ollama(.llava))
} catch TachikomaError.unsupportedOperation(let op) {
    print("Unsupported: \\(op)")
} catch TachikomaError.modelNotFound(let model) {
    print("Model not found: \\(model)")
} catch TachikomaError.rateLimited(let retryAfter) {
    print("Rate limited, retry after: \\(retryAfter ?? 0)s")
}

// Image input types
.base64("base64-encoded-image-data")
.url("https://example.com/image.jpg")  
.filePath("/path/to/local/image.png")
"""

print("✅ Configuration Examples:")
print(configExamples)

// MARK: - 📊 Usage Tracking

print("\n📊 === Usage Tracking ===")

let usageExamples = """
// Automatic usage tracking
let tracker = UsageTracker.shared

// Sessions track token usage and costs
let sessionId = tracker.startSession("my-task")

// Usage is recorded automatically during generation
let response = try await generate("Hello world")

// Get session summary
let summary = tracker.getSessionSummary(sessionId)
print("Total tokens: \\(summary.totalTokens)")
print("Total cost: $\\(summary.totalCost)")

// End session
tracker.endSession(sessionId)

// Global statistics
let stats = tracker.getGlobalStatistics()
print("Average tokens per session: \\(stats.averageTokensPerSession)")
"""

print("✅ Usage Tracking Examples:")
print(usageExamples)

// MARK: - 🧪 Advanced Features

print("\n🧪 === Advanced Features ===")

let advancedExamples = """
// Structured output generation
struct PersonInfo: Codable {
    let name: String
    let age: Int
    let skills: [String]
}

let result = try await generateObject(
    model: .anthropic(.opus4),
    messages: [.user("Generate a person profile")],
    schema: PersonInfo.self
)
print("Generated: \\(result.object)")

// Multi-step tool execution
let result = try await generateText(
    model: .openai(.gpt4_1),
    messages: messages,
    tools: [calculatorTool, weatherTool],
    maxSteps: 3  // Allow up to 3 tool calling steps
)

// Multimodal messages
let message = ModelMessage(
    role: .user,
    content: [
        .text("Analyze this image and data:"),
        .image(ImageContent(data: base64Data, mimeType: "image/png"))
    ]
)

// Streaming with tool calls
let stream = try await streamText(
    model: .anthropic(.sonnet4),
    messages: messages,
    tools: [myToolkit]
)

for try await delta in stream.textStream {
    switch delta.type {
    case .textDelta:
        print(delta.content ?? "", terminator: "")
    case .toolCallStart:
        print("\\n🔧 Calling tool: \\(delta.toolCall?.name ?? "")")
    case .toolResult:
        print("✅ Tool result: \\(delta.toolResult?.result ?? .null)")
    case .done:
        print("\\n✅ Complete")
    default:
        break
    }
}
"""

print("✅ Advanced Features Examples:")
print(advancedExamples)

// MARK: - 🎭 Real-World Integration Patterns

print("\n🎭 === Integration Patterns ===")

let integrationExamples = """
// 1. Code Review Assistant
let codeReviewer = Conversation()
codeReviewer.addSystemMessage("Expert Swift code reviewer")
codeReviewer.addUserMessage("Review: \\(codeSnippet)")
let review = try await codeReviewer.continueConversation(using: .claude)

// 2. Multi-Agent Pipeline
let researcher = generate("Research topic X", using: .anthropic(.opus4))
let analyst = generate("Analyze: \\(researcher)", using: .openai(.gpt4_1))  
let writer = generate("Write summary: \\(analyst)", using: .grok(.grok4))

// 3. Image Processing Pipeline
let imageAnalysis = try await analyze(
    image: .filePath(imagePath),
    prompt: "Describe and extract text",
    using: .openai(.gpt4o)
)

// 4. Streaming Chat Application
class ChatService {
    func streamResponse(_ message: String) -> AsyncThrowingStream<String, Error> {
        return try await stream(message, using: .anthropic(.sonnet4))
    }
}

// 5. Error Recovery with Fallbacks
func generateWithFallback(_ prompt: String) async throws -> String {
    let models: [LanguageModel] = [.claude, .gpt4o, .ollama(.llama33)]
    
    for model in models {
        do {
            return try await generate(prompt, using: model)
        } catch {
            continue  // Try next model
        }
    }
    throw TachikomaError.modelNotFound("All models failed")
}
"""

print("✅ Integration Pattern Examples:")
print(integrationExamples)

// MARK: - 📋 Summary

print("\n📋 === COMPREHENSIVE FEATURE OVERVIEW ===")

let features = [
    ("🎯 Type-Safe Models", "50+ models across 6 providers with compile-time safety"),
    ("🎨 Global Functions", "generate(), stream(), analyze() - simple, powerful API"),
    ("💬 Conversations", "Multi-turn dialogues with automatic message tracking"),
    ("🔧 ToolKit System", "@ToolKit result builder for AI function calling"),
    ("👁️ Vision Analysis", "Image analysis with vision-capable models"),
    ("🌊 Streaming", "Real-time response streaming with delta handling"),
    ("⚙️ Configuration", "Flexible settings, model capabilities, error handling"),
    ("📊 Usage Tracking", "Automatic token counting, cost monitoring, sessions"),
    ("🧪 Advanced Features", "Structured output, multi-step generation, multimodal"),
    ("🎭 Integration Ready", "Production patterns for real-world applications")
]

print("\n📊 FEATURES DEMONSTRATED:")
for (emoji, description) in features {
    print("   \(emoji) \(description)")
}

print("\n🎉 TACHIKOMA SDK - MODERN SWIFT AI INTEGRATION")
print("✅ Type-safe • 🚀 Swift-native • 🔧 Tool-capable • 📊 Usage-tracked")
print("🕷️ Intelligent • Adaptable • Reliable")

print("\n📚 Key Benefits:")
print("   • 60-80% reduction in boilerplate code")
print("   • Full Swift 6.0 compliance with @Sendable")
print("   • Type-safe model selection prevents runtime errors") 
print("   • Global functions work anywhere in your code")
print("   • Built-in usage tracking and cost monitoring")
print("   • Comprehensive error handling with recovery patterns")
print("   • SwiftUI integration with @ObservableObject conversations")

print("\n🚀 Ready for production use!")
print("📖 See README.md and docs/ for full documentation")

// Helper extension for string repetition
extension String {
    static func * (left: String, right: Int) -> String {
        String(repeating: left, count: right)
    }
}