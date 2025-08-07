# AgentToolValue Protocol System Migration Guide

## Overview

Tachikoma has migrated from an enum-based type erasure system (`AgentToolArgument`) to a protocol-based type-safe system (`AgentToolValue`). This provides better compile-time safety, clearer APIs, and eliminates many runtime errors.

## Key Changes

### 1. AgentToolArgument Enum → AgentToolValue Protocol

**Before:**
```swift
public enum AgentToolArgument {
    case string(String)
    case number(Double)
    case integer(Int)
    case boolean(Bool)
    case null
    case array([AgentToolArgument])
    case object([String: AgentToolArgument])
}
```

**After:**
```swift
public protocol AgentToolValue: Sendable, Codable {
    static var agentValueType: AgentValueType { get }
    func toJSON() throws -> Any
    static func fromJSON(_ json: Any) throws -> Self
}

// All standard types conform to AgentToolValue
extension String: AgentToolValue { }
extension Int: AgentToolValue { }
extension Double: AgentToolValue { }
extension Bool: AgentToolValue { }
extension Array: AgentToolValue where Element: AgentToolValue { }
extension Dictionary: AgentToolValue where Key == String, Value: AgentToolValue { }
```

### 2. Type-Erased Wrapper: AnyAgentToolValue

For dynamic scenarios where the exact type isn't known at compile time:

```swift
public struct AnyAgentToolValue: AgentToolValue {
    // Convenient initializers
    public init(string: String)
    public init(int: Int)
    public init(double: Double)
    public init(bool: Bool)
    public init(null: Void)
    public init(array: [AnyAgentToolValue])
    public init(object: [String: AnyAgentToolValue])
    
    // Type-safe accessors
    public var stringValue: String? { get }
    public var intValue: Int? { get }
    public var doubleValue: Double? { get }
    public var boolValue: Bool? { get }
    public var isNull: Bool { get }
    public var arrayValue: [AnyAgentToolValue]? { get }
    public var objectValue: [String: AnyAgentToolValue]? { get }
}
```

## Migration Examples

### Tool Definition

**Before:**
```swift
let tool = AgentTool(
    name: "search",
    description: "Search the web",
    parameters: params
) { args in
    let query = try args.stringValue("query")
    // Return AgentToolArgument
    return .string("Results for: \(query)")
}
```

**After:**
```swift
let tool = AgentTool(
    name: "search",
    description: "Search the web",
    parameters: params
) { args in
    let query = try args.stringValue("query")
    // Return AnyAgentToolValue
    return AnyAgentToolValue(string: "Results for: \(query)")
}
```

### Tool Results

**Before:**
```swift
AgentToolResult.success(
    toolCallId: "123",
    result: .object([
        "status": .string("success"),
        "count": .integer(42)
    ])
)
```

**After:**
```swift
AgentToolResult.success(
    toolCallId: "123",
    result: AnyAgentToolValue(object: [
        "status": AnyAgentToolValue(string: "success"),
        "count": AnyAgentToolValue(int: 42)
    ])
)
```

### JSON Conversion

**Before:**
```swift
// Manual conversion with switch statements
switch argument {
case .string(let s): return s
case .number(let n): return n
// ... etc
}
```

**After:**
```swift
// Automatic conversion
let value = try AnyAgentToolValue.fromJSON(jsonData)
let json = try value.toJSON()
```

## Type-Safe Tool Protocol

For maximum type safety, use the new `AgentToolProtocol`:

```swift
struct CalculatorTool: AgentToolProtocol {
    struct Input: AgentToolValue {
        let expression: String
        
        static var agentValueType: AgentValueType { .object }
        
        func toJSON() throws -> Any {
            ["expression": expression]
        }
        
        static func fromJSON(_ json: Any) throws -> Input {
            guard let dict = json as? [String: Any],
                  let expression = dict["expression"] as? String else {
                throw TachikomaError.invalidInput("Missing expression")
            }
            return Input(expression: expression)
        }
    }
    
    struct Output: AgentToolValue {
        let result: Double
        
        static var agentValueType: AgentValueType { .object }
        
        func toJSON() throws -> Any {
            ["result": result]
        }
        
        static func fromJSON(_ json: Any) throws -> Output {
            guard let dict = json as? [String: Any],
                  let result = dict["result"] as? Double else {
                throw TachikomaError.invalidInput("Invalid result")
            }
            return Output(result: result)
        }
    }
    
    var name: String { "calculate" }
    var description: String { "Perform calculations" }
    var schema: AgentToolSchema {
        AgentToolSchema(
            properties: [
                "expression": AgentPropertySchema(
                    type: .string,
                    description: "Mathematical expression"
                )
            ],
            required: ["expression"]
        )
    }
    
    func execute(_ input: Input, context: ToolExecutionContext) async throws -> Output {
        // Calculate result
        let result = evaluateExpression(input.expression)
        return Output(result: result)
    }
}
```

## Benefits of the New System

1. **Compile-Time Safety**: Protocol conformance ensures type correctness at compile time
2. **Better Performance**: No enum allocation overhead for basic types
3. **Clearer APIs**: Direct type conformance instead of wrapper enums
4. **Extensibility**: Custom types can conform to `AgentToolValue`
5. **JSON Interoperability**: Built-in JSON conversion without boilerplate
6. **Backwards Compatibility**: Legacy initializers available for smooth migration

## Quick Reference

| Old (AgentToolArgument) | New (AnyAgentToolValue) |
|------------------------|-------------------------|
| `.string("hello")` | `AnyAgentToolValue(string: "hello")` |
| `.integer(42)` | `AnyAgentToolValue(int: 42)` |
| `.number(3.14)` | `AnyAgentToolValue(double: 3.14)` |
| `.boolean(true)` | `AnyAgentToolValue(bool: true)` |
| `.null` | `AnyAgentToolValue(null: ())` |
| `.array([...])` | `AnyAgentToolValue(array: [...])` |
| `.object([...])` | `AnyAgentToolValue(object: [...])` |

## Breaking Changes

1. Tool execute methods must now return `AnyAgentToolValue` instead of `AgentToolArgument`
2. `AgentToolCall.arguments` is now `[String: AnyAgentToolValue]` instead of `[String: AgentToolArgument]`
3. `AgentToolResult.result` is now `AnyAgentToolValue` instead of `AgentToolArgument`
4. JSON conversion methods have changed signatures

## Gradual Migration

The system includes backwards-compatible initializers to ease migration:

```swift
// Legacy init still works (temporarily)
let toolCall = try AgentToolCall(
    id: "123",
    name: "search",
    arguments: ["query": "Swift"] // [String: Any] still accepted
)

// But prefer the new approach
let toolCall = AgentToolCall(
    id: "123", 
    name: "search",
    arguments: ["query": AnyAgentToolValue(string: "Swift")]
)
```

These legacy initializers will be removed in a future version, so please migrate to the new API as soon as possible.