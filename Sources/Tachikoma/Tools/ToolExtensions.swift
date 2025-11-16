import Foundation

// MARK: - Tool Implementation Types

// Core tool types (AgentTool, AgentToolArguments, etc.) are now in Core/ToolTypes.swift

// Type aliases for tool methods
public typealias ToolMethod = @Sendable (AgentToolArguments) async throws -> AnyAgentToolValue
public typealias ContextualToolMethod = @Sendable (AgentToolArguments, ToolExecutionContext) async throws
    -> AnyAgentToolValue
public typealias ToolMethodCreator = @Sendable (String, String, AgentToolParameters, ToolMethod) -> AgentTool

// MARK: - Tool Protocol System

/// Protocol for type-safe tool definitions
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol AgentToolProtocol: Sendable {
    associatedtype Input: AgentToolValue
    associatedtype Output: AgentToolValue

    var name: String { get }
    var description: String { get }
    var schema: AgentToolSchema { get }

    func execute(_ input: Input, context: ToolExecutionContext) async throws -> Output
}

/// Schema definition for tools
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentToolSchema: Sendable, Codable {
    public let properties: [String: AgentPropertySchema]
    public let required: [String]

    public init(properties: [String: AgentPropertySchema], required: [String] = []) {
        self.properties = properties
        self.required = required
    }
}

/// Property schema for tool parameters
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentPropertySchema: Sendable, Codable {
    public let type: AgentValueType
    public let description: String
    public let enumValues: [String]?

    public init(type: AgentValueType, description: String, enumValues: [String]? = nil) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
    }
}

// MARK: - Parameter Type Extensions

// Extension removed - AgentToolParameterProperty now has built-in Codable conformance in Core/ToolTypes.swift

/// Tool definition for external APIs
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentToolDefinition: Sendable, Codable {
    public let type: AgentToolType
    public let function: AgentFunctionDefinition

    public enum AgentToolType: String, Sendable, Codable {
        case function
    }

    public init(name: String, description: String, parameters: AgentToolParameters) {
        self.type = .function
        self.function = AgentFunctionDefinition(
            name: name,
            description: description,
            parameters: parameters,
        )
    }
}

/// Function definition within a tool
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentFunctionDefinition: Sendable, Codable {
    public let name: String
    public let description: String
    public let parameters: AgentToolParameters

    public init(name: String, description: String, parameters: AgentToolParameters) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Type-erased tool for dynamic usage
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AnyAgentTool: Sendable {
    private let _name: String
    private let _description: String
    private let _schema: AgentToolSchema
    private let _execute: @Sendable (AnyAgentToolValue, ToolExecutionContext) async throws -> AnyAgentToolValue

    public var name: String { self._name }
    public var description: String { self._description }
    public var schema: AgentToolSchema { self._schema }

    public init<T: AgentToolProtocol>(_ tool: T) {
        self._name = tool.name
        self._description = tool.description
        self._schema = tool.schema
        self._execute = { input, context in
            let json = try input.toJSON()
            let typedInput = try T.Input.fromJSON(json)
            let output = try await tool.execute(typedInput, context: context)
            return try AnyAgentToolValue(output)
        }
    }

    public func execute(_ arguments: [String: Any], context: ToolExecutionContext) async throws -> AnyAgentToolValue {
        let input = try AnyAgentToolValue.fromDictionary(arguments)
        return try await self._execute(input, context)
    }

    public func execute(
        _ arguments: AnyAgentToolValue,
        context: ToolExecutionContext,
    ) async throws
        -> AnyAgentToolValue
    {
        try await self._execute(arguments, context)
    }
}

// MARK: - AgentToolArguments Extensions

extension AgentToolArguments {
    public func stringValue(_ key: String) throws -> String {
        guard let value = self[key] else {
            throw AgentToolError.missingParameter(key)
        }
        guard let stringValue = value.stringValue else {
            throw AgentToolError.invalidParameterType(key, expected: "string", actual: String(describing: value))
        }
        return stringValue
    }

    public func numberValue(_ key: String) throws -> Double {
        guard let value = self[key] else {
            throw AgentToolError.missingParameter(key)
        }
        guard let doubleValue = value.doubleValue else {
            throw AgentToolError.invalidParameterType(key, expected: "number", actual: String(describing: value))
        }
        return doubleValue
    }

    public func integerValue(_ key: String) throws -> Int {
        guard let value = self[key] else {
            throw AgentToolError.missingParameter(key)
        }
        if let intValue = value.intValue {
            return intValue
        } else if let doubleValue = value.doubleValue {
            return Int(doubleValue)
        } else {
            throw AgentToolError.invalidParameterType(key, expected: "integer", actual: String(describing: value))
        }
    }

    public func booleanValue(_ key: String) throws -> Bool {
        guard let value = self[key] else {
            throw AgentToolError.missingParameter(key)
        }
        guard let boolValue = value.boolValue else {
            throw AgentToolError.invalidParameterType(key, expected: "boolean", actual: String(describing: value))
        }
        return boolValue
    }

    public func arrayValue<T>(_ key: String, transform: (AnyAgentToolValue) throws -> T) throws -> [T] {
        guard let value = self[key] else {
            throw AgentToolError.missingParameter(key)
        }
        guard let arrayValue = value.arrayValue else {
            throw AgentToolError.invalidParameterType(key, expected: "array", actual: String(describing: value))
        }
        return try arrayValue.map(transform)
    }

    public func objectValue(_ key: String) throws -> [String: AnyAgentToolValue] {
        guard let value = self[key] else {
            throw AgentToolError.missingParameter(key)
        }
        guard let objectValue = value.objectValue else {
            throw AgentToolError.invalidParameterType(key, expected: "object", actual: String(describing: value))
        }
        return objectValue
    }

    public func optionalStringValue(_ key: String) -> String? {
        guard let value = self[key] else { return nil }
        return value.stringValue
    }

    public func optionalNumberValue(_ key: String) -> Double? {
        guard let value = self[key] else { return nil }
        return value.doubleValue
    }

    public func optionalIntegerValue(_ key: String) -> Int? {
        guard let value = self[key] else { return nil }
        if let intValue = value.intValue {
            return intValue
        } else if let doubleValue = value.doubleValue {
            return Int(doubleValue)
        }
        return nil
    }

    public func optionalBooleanValue(_ key: String) -> Bool? {
        guard let value = self[key] else { return nil }
        return value.boolValue
    }

    public func contains(_ key: String) -> Bool {
        self[key] != nil
    }
}

/// Errors that can occur during tool execution
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum AgentToolError: Error, LocalizedError, Sendable {
    case missingParameter(String)
    case invalidParameterType(String, expected: String, actual: String)
    case executionFailed(String)
    case invalidInput(String)

    public var errorDescription: String? {
        switch self {
        case let .missingParameter(param):
            "Missing required parameter: \(param)"
        case let .invalidParameterType(param, expected, actual):
            "Invalid parameter type for '\(param)': expected \(expected), got \(actual)"
        case let .executionFailed(message):
            "Tool execution failed: \(message)"
        case let .invalidInput(message):
            "Invalid input: \(message)"
        }
    }
}
