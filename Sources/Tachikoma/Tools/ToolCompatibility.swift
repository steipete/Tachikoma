//  
//  ToolCompatibility.swift
//  Tachikoma
//

import Foundation

// MARK: - Convenience Functions

public extension SimpleTool {
    /// Convert to a ToolDefinition for external APIs
    var definition: ToolDefinition {
        return ToolDefinition(
            name: name,
            description: description,
            parameters: parameters
        )
    }
}

// MARK: - Common Tools

/// Built-in calculator tool
public let calculatorTool = createTool(
    name: "calculate",
    description: "Perform mathematical calculations",
    parameters: [
        ToolParameterProperty(
            name: "expression",
            type: .string,
            description: "Mathematical expression to evaluate (e.g., '2 + 2', 'sqrt(16)', 'sin(pi/2)')"
        )
    ],
    required: ["expression"]
) { args in
    let expression = try args.stringValue("expression")
    
    // Basic math evaluation using NSExpression
    let nsExpression = NSExpression(format: expression)
    guard let result = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber else {
        throw ToolError.executionFailed("Invalid mathematical expression: \(expression)")
    }
    
    return .string("Result: \(result.doubleValue)")
}

/// Built-in time tool
public let timeTool = createTool(
    name: "get_current_time",
    description: "Get the current date and time",
    parameters: [],
    required: []
) { _ in
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    formatter.timeStyle = .full
    let timeString = formatter.string(from: Date())
    return .string(timeString)
}

/// Built-in weather tool (mock implementation)
public let weatherTool = createTool(
    name: "get_weather",
    description: "Get weather information for a location",
    parameters: [
        ToolParameterProperty(
            name: "location",
            type: .string,
            description: "The city or location to get weather for"
        )
    ],
    required: ["location"]
) { args in
    let location = try args.stringValue("location")
    // This is a mock implementation - replace with real weather API
    return .string("Weather in \(location): Sunny, 22°C")
}

// MARK: - Helper Functions

/// Convert ToolParameters to JSON schema format
public func toolParametersToJSON(_ parameters: ToolParameters) throws -> [String: Any] {
    var schema: [String: Any] = [
        "type": "object",
        "properties": [:],
        "required": parameters.required
    ]
    
    var properties: [String: Any] = [:]
    for (propertyName, property) in parameters.properties {
        var propSchema: [String: Any] = [
            "type": property.type.rawValue,
            "description": property.description
        ]
        
        if let enumValues = property.enumValues {
            propSchema["enum"] = enumValues
        }
        
        properties[propertyName] = propSchema
    }
    
    schema["properties"] = properties
    return schema
}

/// Convert JSON arguments to ToolArguments
public func jsonToToolArguments(_ json: [String: Any]) -> ToolArguments {
    var arguments: [String: ToolArgument] = [:]
    
    for (key, value) in json {
        arguments[key] = jsonValueToToolArgument(value)
    }
    
    return ToolArguments(arguments)
}

/// Convert a JSON value to ToolArgument
public func jsonValueToToolArgument(_ value: Any) -> ToolArgument {
    if let string = value as? String {
        return .string(string)
    } else if let number = value as? Double {
        return .double(number)
    } else if let number = value as? Int {
        return .int(number)
    } else if let bool = value as? Bool {
        return .bool(bool)
    } else if let array = value as? [Any] {
        return .array(array.map(jsonValueToToolArgument))
    } else if let dict = value as? [String: Any] {
        var objectArgs: [String: ToolArgument] = [:]
        for (key, val) in dict {
            objectArgs[key] = jsonValueToToolArgument(val)
        }
        return .object(objectArgs)
    } else {
        return .string(String(describing: value))
    }
}

// MARK: - Vendor-Style Tool (for TachikomaBuilders Compatibility)

/// Legacy Tool struct for compatibility with TachikomaBuilders
public struct Tool<Context: Sendable>: Sendable {
    public let name: String
    public let description: String
    public let execute: @Sendable (ToolInput, Context) async throws -> ToolOutput

    public init(
        name: String,
        description: String,
        _ execute: @escaping @Sendable (ToolInput, Context) async throws -> ToolOutput
    ) {
        self.name = name
        self.description = description
        self.execute = execute
    }

    /// Convert to SimpleTool by wrapping the context
    public func toSimpleTool(context: Context) -> SimpleTool {
        return SimpleTool(
            name: name,
            description: description,
            parameters: ToolParameters(properties: [], required: []),
            execute: { args in
                let input = ToolInput(args)
                let output = try await execute(input, context)
                return try .string(output.toJSONString())
            }
        )
    }
}

/// Creates a Tool with typed context
public func createTool<Context: Sendable>(
    name: String,
    description: String,
    _ handler: @escaping @Sendable (ToolInput, Context) async throws -> String
) -> Tool<Context> {
    return Tool(
        name: name,
        description: description
    ) { input, context in
        let result = try await handler(input, context)
        return .string(result)
    }
}

// MARK: - ToolKit Protocol for TachikomaBuilders Compatibility

/// Protocol for grouping related tools with shared context
public protocol ToolKit: Sendable {
    associatedtype Context: Sendable = Self
    var tools: [Tool<Context>] { get }
}

/// Default implementation for ToolKit where Context == Self
extension ToolKit where Context == Self {
    public var simpleTools: [SimpleTool] {
        return tools.map { $0.toSimpleTool(context: self) }
    }
}

/// Extension to convert ToolKit to provider tools
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension ToolKit {
    /// Convert tools to provider tool format
    public func toProviderTools() throws -> [ProviderTool] {
        tools.map { tool in
            // Create basic parameters structure for the provider tool
            let parameters = ToolParameters(
                properties: [
                    "input": ToolParameterProperty(
                        name: "input",
                        type: .string,
                        description: "Tool input parameters"
                    )
                ],
                required: []
            )
            
            return ProviderTool(
                name: tool.name,
                description: tool.description,
                parameters: parameters
            )
        }
    }
}

/// Empty tool kit for testing
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct EmptyToolKit: ToolKit {
    public let tools: [Tool<EmptyToolKit>] = []

    public init() {}
}

/// Provider tool definition for compatibility
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ProviderTool: Sendable {
    public let name: String
    public let description: String
    public let parameters: ToolParameters

    public init(name: String, description: String, parameters: ToolParameters) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Example ToolKit implementation
public struct ExampleToolKit: ToolKit {
    public var tools: [Tool<ExampleToolKit>] {
        [
            createTool(
                name: "example_tool",
                description: "An example tool for demonstration"
            ) { input, context in
                return "Example tool executed with context"
            }
        ]
    }
    
    public init() {}
}

// MARK: - ToolInput/ToolOutput Compatibility Types

/// Input wrapper for compatibility with TachikomaBuilders
public struct ToolInput: Sendable {
    private let arguments: ToolArguments
    
    public init(_ arguments: ToolArguments) {
        self.arguments = arguments
    }
    
    public init(_ dict: [String: ToolArgument]) {
        self.arguments = ToolArguments(dict)
    }
    
    public init(jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw TachikomaError.invalidInput("Invalid UTF-8 JSON string")
        }
        
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = jsonObject as? [String: Any] else {
            throw TachikomaError.invalidInput("JSON must be a dictionary")
        }
        
        var toolArgs: [String: ToolArgument] = [:]
        for (key, value) in dict {
            if let stringValue = value as? String {
                toolArgs[key] = .string(stringValue)
            } else if let numberValue = value as? Double {
                toolArgs[key] = .double(numberValue)
            } else if let intValue = value as? Int {
                toolArgs[key] = .double(Double(intValue))
            } else if let boolValue = value as? Bool {
                toolArgs[key] = .bool(boolValue)
            } else if value is NSNull {
                // Skip null values
                continue
            } else if let arrayValue = value as? [Any] {
                toolArgs[key] = .array(arrayValue.compactMap { element in
                    if let str = element as? String {
                        return .string(str)
                    } else if let num = element as? Double {
                        return .double(num)
                    } else if let int = element as? Int {
                        return .double(Double(int))
                    } else if let bool = element as? Bool {
                        return .bool(bool)
                    }
                    return nil
                })
            }
        }
        
        self.arguments = ToolArguments(toolArgs)
    }
    
    public func stringValue(_ key: String) throws -> String {
        return try arguments.stringValue(key)
    }
    
    public func numberValue(_ key: String) throws -> Double {
        return try arguments.numberValue(key)
    }
    
    public func integerValue(_ key: String) throws -> Int {
        return try arguments.integerValue(key)
    }
    
    public func booleanValue(_ key: String) throws -> Bool {
        return try arguments.booleanValue(key)
    }
    
    public func arrayValue<T>(_ key: String, transform: (ToolArgument) throws -> T) throws -> [T] {
        return try arguments.arrayValue(key, transform: transform)
    }
    
    public func objectValue(_ key: String) throws -> [String: ToolArgument] {
        return try arguments.objectValue(key)
    }
    
    public func optionalStringValue(_ key: String) -> String? {
        return arguments.optionalStringValue(key)
    }
    
    public func optionalNumberValue(_ key: String) -> Double? {
        return arguments.optionalNumberValue(key)
    }
    
    public func optionalIntegerValue(_ key: String) -> Int? {
        return arguments.optionalIntegerValue(key)
    }
    
    public func optionalBooleanValue(_ key: String) -> Bool? {
        return arguments.optionalBooleanValue(key)
    }
    
    public subscript(key: String) -> ToolArgument? {
        return arguments[key]
    }
    
    // Convenience methods with default parameters
    public func stringValue(_ key: String, default defaultValue: String) -> String {
        return (try? stringValue(key)) ?? defaultValue
    }
    
    public func stringValue(_ key: String, default defaultValue: String?) -> String? {
        if let result = try? stringValue(key) {
            return result
        }
        return defaultValue
    }
    
    public func intValue(_ key: String) throws -> Int {
        return try integerValue(key)
    }
    
    public func intValue(_ key: String, default defaultValue: Int) -> Int {
        return (try? integerValue(key)) ?? defaultValue
    }
    
    public func intValue(_ key: String, default defaultValue: Int?) -> Int? {
        if let result = try? integerValue(key) {
            return result
        }
        return defaultValue
    }
    
    public func doubleValue(_ key: String) throws -> Double {
        return try numberValue(key)
    }
    
    public func doubleValue(_ key: String, default defaultValue: Double) -> Double {
        return (try? numberValue(key)) ?? defaultValue
    }
    
    public func boolValue(_ key: String) throws -> Bool {
        return try booleanValue(key)
    }
    
    public func boolValue(_ key: String, default defaultValue: Bool) -> Bool {
        return (try? booleanValue(key)) ?? defaultValue
    }
}

/// Tool output type for TachikomaBuilders compatibility
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ToolOutput: Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([ToolOutput])
    case object([String: ToolOutput])
    case null

    /// Create an error output
    public static func error(message: String) -> ToolOutput {
        .string("Error: \(message)")
    }

    /// Create a successful output
    public static func success(_ message: String) -> ToolOutput {
        .string(message)
    }

    /// Create a failure output
    public static func failure(_ error: Error) -> ToolOutput {
        .string("Error: \(error.localizedDescription)")
    }

    /// Convert to JSON string representation
    public func toJSONString() throws -> String {
        switch self {
        case let .string(str):
            return str
        case let .int(int):
            return String(int)
        case let .double(double):
            return String(double)
        case let .bool(bool):
            return String(bool)
        case .null:
            return "null"
        case let .array(array):
            let items = try array.map { try $0.toJSONString() }
            return "[\(items.joined(separator: ", "))]"
        case let .object(dict):
            let pairs = try dict.map { key, value in
                try "\"\(key)\": \(value.toJSONString())"
            }
            return "{\(pairs.joined(separator: ", "))}"
        }
    }
}

// MARK: - ToolError for TachikomaBuilders Compatibility

/// Extended ToolError with additional compatibility cases
extension ToolError {
    public static func invalidJSON(_ message: String) -> ToolError {
        return .invalidInput("Invalid JSON: \(message)")
    }
    
    public static func networkError(_ message: String) -> ToolError {
        return .executionFailed("Network error: \(message)")
    }
    
    public static func authenticationError(_ message: String) -> ToolError {
        return .executionFailed("Authentication error: \(message)")
    }
    
    public static func toolNotFound(_ toolName: String) -> ToolError {
        return .invalidInput("Tool not found: \(toolName)")
    }
}

// MARK: - Parameter Schema for TachikomaBuilders Compatibility

/// Helper for creating parameter schemas
public struct ParameterSchema {
    public static func string(
        name: String,
        description: String,
        required: Bool = false,
        enumValues: [String]? = nil
    ) -> ToolParameterProperty {
        return ToolParameterProperty(
            name: name,
            type: .string,
            description: description,
            enumValues: enumValues,
            required: required
        )
    }
    
    public static func number(
        name: String,
        description: String,
        required: Bool = false
    ) -> ToolParameterProperty {
        return ToolParameterProperty(
            name: name,
            type: .number,
            description: description,
            required: required
        )
    }
    
    public static func integer(
        name: String,
        description: String,
        required: Bool = false
    ) -> ToolParameterProperty {
        return ToolParameterProperty(
            name: name,
            type: .integer,
            description: description,
            required: required
        )
    }
    
    public static func boolean(
        name: String,
        description: String,
        required: Bool = false
    ) -> ToolParameterProperty {
        return ToolParameterProperty(
            name: name,
            type: .boolean,
            description: description,
            required: required
        )
    }
    
    public static func array(
        name: String,
        description: String,
        required: Bool = false
    ) -> ToolParameterProperty {
        return ToolParameterProperty(
            name: name,
            type: .array,
            description: description,
            required: required
        )
    }
    
    public static func object(
        name: String,
        description: String,
        required: Bool = false
    ) -> ToolParameterProperty {
        return ToolParameterProperty(
            name: name,
            type: .object,
            description: description,
            required: required
        )
    }
}