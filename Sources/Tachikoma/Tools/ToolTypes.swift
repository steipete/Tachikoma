//
//  ToolTypes.swift
//  Tachikoma
//

import Foundation

// MARK: - Helper Types

public typealias ToolMethod = @Sendable (AgentToolArguments) async throws -> AgentToolArgument
public typealias ToolMethodCreator = @Sendable (String, String, AgentToolParameters, ToolMethod) -> AgentTool

/// Context that gets passed to tool execution
public protocol ToolContext: Sendable {
    // Tool contexts should be sendable and contain necessary context
    // for executing tools (like authentication tokens, settings, etc.)
}

// MARK: - Core Tool Argument Types
// Note: AgentToolArgument is defined in Core/Types.swift and imported automatically

// MARK: - Tool System

// MARK: - Core Tool for API

/// Core AgentTool struct used by generation APIs
public struct AgentTool: Sendable {
    public let name: String
    public let description: String
    public let parameters: AgentToolParameters
    public let namespace: String?
    public let recipient: String?
    public let execute: @Sendable (AgentToolArguments) async throws -> AgentToolArgument

    public init(
        name: String,
        description: String,
        parameters: AgentToolParameters,
        namespace: String? = nil,
        recipient: String? = nil,
        execute: @escaping @Sendable (AgentToolArguments) async throws -> AgentToolArgument
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.namespace = namespace
        self.recipient = recipient
        self.execute = execute
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

/// Individual parameter property for a tool
public struct AgentToolParameterProperty: Sendable, Codable {
    public let name: String
    public let type: ParameterType
    public let description: String
    public let enumValues: [String]?

    public init(
        name: String,
        type: ParameterType,
        description: String,
        enumValues: [String]? = nil,
        required: Bool = false
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.enumValues = enumValues
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

/// Arguments passed to tool execution
public struct AgentToolArguments: Sendable {
    private let arguments: [String: AgentToolArgument]

    public init(_ arguments: [String: AgentToolArgument]) {
        self.arguments = arguments
    }

    public func stringValue(_ key: String) throws -> String {
        guard let argument = arguments[key] else {
            throw AgentToolError.missingParameter(key)
        }
        switch argument {
        case .string(let value):
            return value
        default:
            throw AgentToolError.invalidParameterType(key, expected: "string", actual: argument)
        }
    }

    public func numberValue(_ key: String) throws -> Double {
        guard let argument = arguments[key] else {
            throw AgentToolError.missingParameter(key)
        }
        switch argument {
        case .double(let value):
            return value
        case .int(let value):
            return Double(value)
        default:
            throw AgentToolError.invalidParameterType(key, expected: "number", actual: argument)
        }
    }

    public func integerValue(_ key: String) throws -> Int {
        guard let argument = arguments[key] else {
            throw AgentToolError.missingParameter(key)
        }
        switch argument {
        case .int(let value):
            return value
        case .double(let value):
            return Int(value)
        default:
            throw AgentToolError.invalidParameterType(key, expected: "integer", actual: argument)
        }
    }

    public func booleanValue(_ key: String) throws -> Bool {
        guard let argument = arguments[key] else {
            throw AgentToolError.missingParameter(key)
        }
        switch argument {
        case .bool(let value):
            return value
        default:
            throw AgentToolError.invalidParameterType(key, expected: "boolean", actual: argument)
        }
    }

    public func arrayValue<T>(_ key: String, transform: (AgentToolArgument) throws -> T) throws -> [T] {
        guard let argument = arguments[key] else {
            throw AgentToolError.missingParameter(key)
        }
        switch argument {
        case .array(let value):
            return try value.map(transform)
        default:
            throw AgentToolError.invalidParameterType(key, expected: "array", actual: argument)
        }
    }

    public func objectValue(_ key: String) throws -> [String: AgentToolArgument] {
        guard let argument = arguments[key] else {
            throw AgentToolError.missingParameter(key)
        }
        switch argument {
        case .object(let value):
            return value
        default:
            throw AgentToolError.invalidParameterType(key, expected: "object", actual: argument)
        }
    }

    public func optionalStringValue(_ key: String) -> String? {
        guard let argument = arguments[key] else { return nil }
        switch argument {
        case .string(let value):
            return value
        default:
            return nil
        }
    }

    public func optionalNumberValue(_ key: String) -> Double? {
        guard let argument = arguments[key] else { return nil }
        switch argument {
        case .double(let value):
            return value
        case .int(let value):
            return Double(value)
        default:
            return nil
        }
    }

    public func optionalIntegerValue(_ key: String) -> Int? {
        guard let argument = arguments[key] else { return nil }
        switch argument {
        case .int(let value):
            return value
        case .double(let value):
            return Int(value)
        default:
            return nil
        }
    }

    public func optionalBooleanValue(_ key: String) -> Bool? {
        guard let argument = arguments[key] else { return nil }
        switch argument {
        case .bool(let value):
            return value
        default:
            return nil
        }
    }

    public subscript(key: String) -> AgentToolArgument? {
        return arguments[key]
    }

    public var keys: Dictionary<String, AgentToolArgument>.Keys {
        return arguments.keys
    }

    public var values: Dictionary<String, AgentToolArgument>.Values {
        return arguments.values
    }
}

/// Errors that can occur during tool execution
public enum AgentToolError: Error, LocalizedError, Sendable {
    case missingParameter(String)
    case invalidParameterType(String, expected: String, actual: AgentToolArgument)
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