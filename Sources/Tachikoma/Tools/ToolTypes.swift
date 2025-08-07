//
//  ToolTypes.swift
//  Tachikoma
//

import Foundation

// MARK: - Helper Types

/// Context passed to tool execution containing conversation and model information
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ToolExecutionContext: Sendable {
    public let messages: [ModelMessage]
    public let model: LanguageModel?
    public let settings: GenerationSettings?
    public let sessionId: String
    public let stepIndex: Int
    public let metadata: [String: String]
    
    public init(
        messages: [ModelMessage] = [],
        model: LanguageModel? = nil,
        settings: GenerationSettings? = nil,
        sessionId: String = UUID().uuidString,
        stepIndex: Int = 0,
        metadata: [String: String] = [:]
    ) {
        self.messages = messages
        self.model = model
        self.settings = settings
        self.sessionId = sessionId
        self.stepIndex = stepIndex
        self.metadata = metadata
    }
}

public typealias ToolMethod = @Sendable (AgentToolArguments) async throws -> AnyAgentToolValue
public typealias ContextualToolMethod = @Sendable (AgentToolArguments, ToolExecutionContext) async throws -> AnyAgentToolValue
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

// MARK: - Tool System

// MARK: - Core Tool for API

/// Core AgentTool struct used by generation APIs
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentTool: Sendable {
    public let name: String
    public let description: String
    public let parameters: AgentToolParameters
    public let namespace: String?
    public let recipient: String?
    private let simpleExecute: ToolMethod?
    private let contextualExecute: ContextualToolMethod?
    
    /// Execute the tool with context
    public func execute(_ arguments: AgentToolArguments, context: ToolExecutionContext? = nil) async throws -> AnyAgentToolValue {
        if let contextualExecute = contextualExecute {
            return try await contextualExecute(arguments, context ?? ToolExecutionContext())
        } else if let simpleExecute = simpleExecute {
            return try await simpleExecute(arguments)
        } else {
            throw TachikomaError.toolCallFailed("No execution method available for tool \(name)")
        }
    }
    
    /// Legacy execute method for backwards compatibility
    public func execute(_ arguments: AgentToolArguments) async throws -> AnyAgentToolValue {
        return try await execute(arguments, context: nil)
    }

    /// Initialize with simple execution (backwards compatible)
    public init(
        name: String,
        description: String,
        parameters: AgentToolParameters,
        namespace: String? = nil,
        recipient: String? = nil,
        execute: @escaping @Sendable (AgentToolArguments) async throws -> AnyAgentToolValue
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.namespace = namespace
        self.recipient = recipient
        self.simpleExecute = execute
        self.contextualExecute = nil
    }
    
    /// Initialize with contextual execution
    public init(
        name: String,
        description: String,
        parameters: AgentToolParameters,
        namespace: String? = nil,
        recipient: String? = nil,
        executeWithContext: @escaping @Sendable (AgentToolArguments, ToolExecutionContext) async throws -> AnyAgentToolValue
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.namespace = namespace
        self.recipient = recipient
        self.simpleExecute = nil
        self.contextualExecute = executeWithContext
    }
}

/// Parameters for a tool definition
public struct AgentToolParameters: Sendable, Codable {
    public let type: String
    public let properties: [String: AgentToolParameterProperty]
    public let required: [String]

    public init(properties: [AgentToolParameterProperty], required: [String] = []) {
        self.type = "object"
        var propsDict: [String: AgentToolParameterProperty] = [:]
        for prop in properties {
            propsDict[prop.name] = prop
        }
        self.properties = propsDict
        self.required = required
    }
    
    public init(properties: [String: AgentToolParameterProperty], required: [String] = []) {
        self.type = "object"
        self.properties = properties
        self.required = required
    }
}

/// Items definition for array parameters
public struct AgentToolParameterItems: Sendable, Codable {
    public let type: AgentToolParameterProperty.ParameterType
    public let enumValues: [String]?
    
    public init(type: AgentToolParameterProperty.ParameterType, enumValues: [String]? = nil) {
        self.type = type
        self.enumValues = enumValues
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case enumValues = "enum"
    }
}

/// Individual parameter property for a tool
public struct AgentToolParameterProperty: Sendable, Codable {
    public let name: String
    public let type: ParameterType
    public let description: String
    public let enumValues: [String]?
    public let items: AgentToolParameterItems?

    public init(
        name: String,
        type: ParameterType,
        description: String,
        enumValues: [String]? = nil,
        items: AgentToolParameterItems? = nil,
        required: Bool = false
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.enumValues = enumValues
        self.items = items
    }

    public enum ParameterType: String, Sendable, Codable {
        case string
        case number
        case integer
        case boolean
        case array
        case object
        case null
    }

    private enum CodingKeys: String, CodingKey {
        case name, type, description
        case enumValues = "enum"
        case items
    }
    
    // Custom encoding to ensure items is always included for array types
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(enumValues, forKey: .enumValues)
        
        // Always encode items for array types, even if nil (use default string items)
        if type == .array {
            if let items = items {
                try container.encode(items, forKey: .items)
            } else {
                // Default to string items if not specified
                let defaultItems = AgentToolParameterItems(type: .string)
                try container.encode(defaultItems, forKey: .items)
            }
        } else {
            try container.encodeIfPresent(items, forKey: .items)
        }
    }
}

/// Tool definition for external APIs
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
            parameters: parameters
        )
    }
}

/// Function definition within a tool
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
    
    public var name: String { _name }
    public var description: String { _description }
    public var schema: AgentToolSchema { _schema }
    
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
        return try await _execute(input, context)
    }
    
    public func execute(_ arguments: AnyAgentToolValue, context: ToolExecutionContext) async throws -> AnyAgentToolValue {
        return try await _execute(arguments, context)
    }
}

/// Arguments passed to tool execution
public struct AgentToolArguments: Sendable {
    private let arguments: [String: AnyAgentToolValue]

    public init(_ arguments: [String: AnyAgentToolValue]) {
        self.arguments = arguments
    }
    
    /// Legacy init for migration
    public init(_ arguments: [String: Any]) throws {
        var converted: [String: AnyAgentToolValue] = [:]
        for (key, value) in arguments {
            converted[key] = try AnyAgentToolValue.fromJSON(value)
        }
        self.arguments = converted
    }

    public func stringValue(_ key: String) throws -> String {
        guard let argument = arguments[key] else {
            throw AgentToolError.missingParameter(key)
        }
        guard let value = argument.stringValue else {
            throw AgentToolError.invalidParameterType(key, expected: "string", actual: String(describing: argument))
        }
        return value
    }

    public func numberValue(_ key: String) throws -> Double {
        guard let argument = arguments[key] else {
            throw AgentToolError.missingParameter(key)
        }
        guard let value = argument.doubleValue else {
            throw AgentToolError.invalidParameterType(key, expected: "number", actual: String(describing: argument))
        }
        return value
    }

    public func integerValue(_ key: String) throws -> Int {
        guard let argument = arguments[key] else {
            throw AgentToolError.missingParameter(key)
        }
        if let value = argument.intValue {
            return value
        } else if let doubleValue = argument.doubleValue {
            return Int(doubleValue)
        } else {
            throw AgentToolError.invalidParameterType(key, expected: "integer", actual: String(describing: argument))
        }
    }

    public func booleanValue(_ key: String) throws -> Bool {
        guard let argument = arguments[key] else {
            throw AgentToolError.missingParameter(key)
        }
        guard let value = argument.boolValue else {
            throw AgentToolError.invalidParameterType(key, expected: "boolean", actual: String(describing: argument))
        }
        return value
    }

    public func arrayValue<T>(_ key: String, transform: (AnyAgentToolValue) throws -> T) throws -> [T] {
        guard let argument = arguments[key] else {
            throw AgentToolError.missingParameter(key)
        }
        guard let value = argument.arrayValue else {
            throw AgentToolError.invalidParameterType(key, expected: "array", actual: String(describing: argument))
        }
        return try value.map(transform)
    }

    public func objectValue(_ key: String) throws -> [String: AnyAgentToolValue] {
        guard let argument = arguments[key] else {
            throw AgentToolError.missingParameter(key)
        }
        guard let value = argument.objectValue else {
            throw AgentToolError.invalidParameterType(key, expected: "object", actual: String(describing: argument))
        }
        return value
    }

    public func optionalStringValue(_ key: String) -> String? {
        guard let argument = arguments[key] else { return nil }
        return argument.stringValue
    }

    public func optionalNumberValue(_ key: String) -> Double? {
        guard let argument = arguments[key] else { return nil }
        return argument.doubleValue
    }

    public func optionalIntegerValue(_ key: String) -> Int? {
        guard let argument = arguments[key] else { return nil }
        if let intValue = argument.intValue {
            return intValue
        } else if let doubleValue = argument.doubleValue {
            return Int(doubleValue)
        }
        return nil
    }

    public func optionalBooleanValue(_ key: String) -> Bool? {
        guard let argument = arguments[key] else { return nil }
        return argument.boolValue
    }

    public subscript(key: String) -> AnyAgentToolValue? {
        return arguments[key]
    }

    public var keys: Dictionary<String, AnyAgentToolValue>.Keys {
        return arguments.keys
    }

    public var values: Dictionary<String, AnyAgentToolValue>.Values {
        return arguments.values
    }
}

/// Errors that can occur during tool execution
public enum AgentToolError: Error, LocalizedError, Sendable {
    case missingParameter(String)
    case invalidParameterType(String, expected: String, actual: String)
    case executionFailed(String)
    case invalidInput(String)

    public var errorDescription: String? {
        switch self {
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .invalidParameterType(let param, let expected, let actual):
            return "Invalid parameter type for '\(param)': expected \(expected), got \(actual)"
        case .executionFailed(let message):
            return "Tool execution failed: \(message)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        }
    }
}