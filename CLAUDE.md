# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tachikoma is a modern Swift AI integration library with a unified single-module architecture. Everything is accessible via `import Tachikoma`. The library provides type-safe, Swift-native APIs for multiple AI providers including OpenAI, Anthropic, Grok, Google, Mistral, Groq, and Ollama.

## Build Commands

```bash
# Build the package
swift build

# Run all tests
swift test

# Run specific test suite
swift test --filter "GenerationTests"

# Build in release mode
swift build -c release

# Resolve dependencies
swift package resolve
```

## Architecture & Key Design Patterns

### Single Module Architecture
- Migrated from 4-module to 1-module structure
- All functionality in `Sources/Tachikoma/`
- No complex import hierarchies

### Swift-Native APIs
```swift
// Simple one-liner
let answer = try await generate("What is 2+2?", using: .openai(.gpt4o))

// Advanced usage
let response = try await generateText(
    model: .anthropic(.opus4),
    messages: conversation.messages,
    tools: myTools,
    settings: .init(temperature: 0.7)
)
```

### Type-Safe Model Selection
Models use hierarchical enums with provider-specific sub-enums:
```swift
.openai(.gpt4o, .gpt41, .o3)
.anthropic(.opus4, .sonnet4, .haiku35) // opus4 is now Opus 4.1
.grok(.grok4, .grok2Vision)
.ollama(.llama3)
```

### Tool System
Tools use result builders (transitioning to macros):
```swift
@ToolKit
struct MyTools {
    func calculate(expression: String) async throws -> Double {
        // Implementation
    }
}
```

## Core Components

- **Generation.swift**: Global functions (`generateText`, `streamText`, `generateObject`)
- **Model.swift**: Type-safe model system with capability detection
- **ToolKit.swift**: Tool system with result builders
- **Types.swift**: Message types, streaming events, all `Sendable`
- **Provider files**: Individual implementations (OpenAI, Anthropic, etc.)

## Testing

Uses Swift Testing framework (`@Test`, `#expect`):
```bash
# Run tests
swift test

# Test with environment variables
OPENAI_API_KEY=sk-... swift test --filter "OpenAIProviderTests"
```

## Important Implementation Details

### Concurrency
- Swift 6.0 strict concurrency
- All public APIs are `Sendable`
- Actor-safe design where appropriate

### Provider Details
- **OpenAI**: Dual API support (Chat Completions + Responses API for o3/o4)
- **Anthropic**: Native implementation, default model is Claude Opus 4.1
- **Ollama**: Requires longer timeouts (5+ minutes) for model loading

### Environment Variables
- `OPENAI_API_KEY`: For OpenAI provider
- `ANTHROPIC_API_KEY`: For Anthropic provider
- `GROQ_API_KEY`: For Groq provider
- `MISTRAL_API_KEY`: For Mistral provider
- `GOOGLE_API_KEY`: For Google provider
- `X_AI_API_KEY` or `XAI_API_KEY`: For Grok provider

### No Backwards Compatibility
- Targets Swift 6.0+ exclusively
- macOS 14.0+, iOS 17.0+, watchOS 10.0+, tvOS 17.0+
- Free to break APIs for better design

## Development Philosophy

- **No "Enhanced", "Advanced", "Modern" or Version Suffixes**: When refactoring, NEVER use names like "Enhanced", "Advanced", "Modern", "New", "V2", etc. Simply refactor the existing implementations in place. If we're doing a refactor, we want to replace the old implementation completely, not create parallel versions. Use the idiomatic name that the API should have.
  - ❌ `EnhancedResponseCache` → ✅ `ResponseCache`
  - ❌ `AdvancedRealtimeConversation` → ✅ `RealtimeConversation`
  - ❌ `ModernAPI` → ✅ `API`
  - ❌ `NewToolSystem` → ✅ `ToolSystem`
  
- **No Dates in Model Enum Names**: Model enum cases should NEVER include dates or version numbers. Use clean, stable enum names that won't break API compatibility when model versions change. The actual model ID strings can have dates, but the enum cases should not.
  - ✅ `.grok4` (maps to "grok-4-0709" internally)
  - ❌ `.grok40709`
  - ✅ `.grok2Image` (maps to "grok-2-image-1212" internally)
  - ❌ `.grok2Image1212`
  - This applies to ALL model providers - keep enum names stable and clean
- **Type Safety Above All**: ALWAYS prefer type-safe implementations over `[String: Any]` or type erasure
  - Use proper structs/enums for data structures
  - Create specific types even for simple dictionaries
  - Only use `Any` when absolutely unavoidable (and document why)
  - Example: Use `AgentToolParameters` instead of `[String: Any]` for tool definitions
- **Swift-Native**: Global functions, enums, async/await
- **Performance**: Streaming, lazy loading, minimal overhead
- **Modern Swift**: Result builders, property wrappers, experimental features enabled
- **Sendable Everywhere**: Maintain Sendable conformance for all public types
- **No Cross-Reference Comments**: Never add comments like "// Note: X is now defined in Y". Simply remove duplicates without explanatory comments