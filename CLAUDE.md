# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the Tachikoma AI SDK.

## Development Philosophy

**No Backwards Compatibility**: We never care about backwards compatibility. We prioritize clean, modern code and user experience over maintaining legacy support. Breaking changes are acceptable and expected as the project evolves. This includes removing deprecated code, changing APIs freely, and not supporting legacy formats or approaches.

**No "Modern" or Version Suffixes**: When refactoring, never use names like "Modern", "New", "V2", etc. Simply refactor the existing things in place. If we are doing a refactor, we want to replace the old implementation completely, not create parallel versions. Use the idiomatic name that the API should have.

**Swift-Native Design**: Tachikoma should feel like a natural extension of Swift itself. Prefer:
- Global functions over complex class hierarchies
- Enum-based model selection with autocomplete
- Async/await over completion handlers
- Result builders (@ToolKit) over verbose configuration
- Property wrappers (@AI) for state management

**Type Safety**: Use Swift's type system to prevent errors at compile time:
- Enum-based provider selection
- Generic tool systems with context types
- Sendable conformance throughout
- Strict concurrency compliance

**Minimum Platform Requirements**: 
- Swift 6.0+
- macOS 14.0+ / iOS 17.0+ / watchOS 10.0+ / tvOS 17.0+

## API Design Principles

**Simple by Default, Powerful When Needed**:
```swift
// Simple case (1 line)
let answer = try await generate("What is 2+2?", using: .openai(.gpt4o))

// Complex case (still clean)
let response = try await generateText(
    model: .anthropic(.opus4),
    messages: conversation.messages,
    tools: [weatherTool, calculatorTool],
    settings: .init(temperature: 0.7, maxTokens: 1000)
)
```

**Provider-Specific Model Enums**:
```swift
// Type-safe, autocomplete-friendly
.openai(.gpt4o, .gpt41, .o3)
.anthropic(.opus4, .sonnet4, .haiku35)
.grok(.grok4, .grok2Vision)
```

**Tool System with @ToolKit**:
```swift
@ToolKit
struct MyTools {
    func getWeather(location: String) async throws -> String {
        // Implementation
    }
}
```

## Testing Philosophy

- Prefer Swift Testing (`@Test`) over XCTest
- Test real API integrations with authentication checks
- Use async/await patterns in tests
- Mock complex dependencies only when necessary

## Code Quality

- Never use `Any`, `AnyObject`, or type erasure
- Prefer value types over reference types
- Use `@Sendable` throughout for concurrency safety
- Write self-documenting code with clear names
- Minimal comments - let the types tell the story

## Documentation Standards

- **Professional README**: Avoid excessive emoji usage in README files - looks unprofessional
- Use horizontal lines (`---`) to separate major sections
- Style badges using `style=for-the-badge` for consistency
- Center-align badges and logo for visual balance
- Keep section headers clean and readable without emoji clutter