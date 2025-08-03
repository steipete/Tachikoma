import Foundation

// MARK: - Modern Tool System

/// Protocol for tool collections that can be used with AI models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public protocol ToolKit: Sendable {
    associatedtype Context = Self
    
    /// The tools available in this toolkit
    var tools: [Tool<Context>] { get }
}

/// Default implementation for toolkits that use themselves as context
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public extension ToolKit where Context == Self {
    var tools: [Tool<Self>] { [] }
}

/// A tool that can be executed by an AI model
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct Tool<Context>: Sendable {
    public let name: String
    public let description: String
    public let execute: @Sendable (ToolInput, Context) async throws -> ToolOutput
    
    public init(
        name: String,
        description: String,
        execute: @escaping @Sendable (ToolInput, Context) async throws -> ToolOutput
    ) {
        self.name = name
        self.description = description
        self.execute = execute
    }
}

/// Input parameters for a tool
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ToolInput: Sendable {
    private let jsonString: String
    
    public init(jsonString: String) throws {
        self.jsonString = jsonString.isEmpty ? "{}" : jsonString
        
        // Validate JSON format
        if !jsonString.isEmpty {
            guard let jsonData = jsonString.data(using: .utf8),
                  let _ = try? JSONSerialization.jsonObject(with: jsonData) else {
                throw ToolError.invalidInput("Invalid JSON string")
            }
        }
    }
    
    private var parsedData: [String: Any] {
        guard let data = jsonString.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return parsed
    }
    
    public func stringValue(_ key: String) throws -> String {
        guard let value = parsedData[key] as? String else {
            throw ToolError.invalidInput("Missing or invalid string value for key: \(key)")
        }
        return value
    }
    
    public func stringValue(_ key: String, default defaultValue: String?) -> String? {
        return (parsedData[key] as? String) ?? defaultValue
    }
    
    public func intValue(_ key: String) throws -> Int {
        if let intValue = parsedData[key] as? Int {
            return intValue
        }
        if let doubleValue = parsedData[key] as? Double {
            return Int(doubleValue)
        }
        throw ToolError.invalidInput("Missing or invalid integer value for key: \(key)")
    }
    
    public func intValue(_ key: String, default defaultValue: Int?) -> Int? {
        if let intValue = parsedData[key] as? Int {
            return intValue
        }
        if let doubleValue = parsedData[key] as? Double {
            return Int(doubleValue)
        }
        return defaultValue
    }
    
    public func boolValue(_ key: String, default defaultValue: Bool) -> Bool {
        return (parsedData[key] as? Bool) ?? defaultValue
    }
    
    public func doubleValue(_ key: String) throws -> Double {
        if let doubleValue = parsedData[key] as? Double {
            return doubleValue
        }
        if let intValue = parsedData[key] as? Int {
            return Double(intValue)
        }
        throw ToolError.invalidInput("Missing or invalid double value for key: \(key)")
    }
}

/// Output from a tool execution
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ToolOutput: Sendable {
    case string(String)
    case error(message: String)
    
    public func toJSONString() throws -> String {
        switch self {
        case .string(let str):
            return str
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

/// Errors that can occur during tool operations
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ToolError: Error, LocalizedError {
    case invalidInput(String)
    case executionFailed(String)
    case toolNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid tool input: \(message)"
        case .executionFailed(let message):
            return "Tool execution failed: \(message)"
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        }
    }
}

// MARK: - Tool Builder Functions

/// Create a tool with typed parameters
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func tool<Context>(
    name: String,
    description: String,
    parameters: ParameterSchema = .object(properties: [:]),
    execute: @escaping @Sendable (ToolInput, Context) async throws -> ToolOutput
) -> Tool<Context> {
    Tool(name: name, description: description, execute: execute)
}

/// Parameter schema for tool definitions
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ParameterSchema: Sendable {
    case string(description: String?)
    case integer(description: String?)
    case boolean(description: String?)
    case enumeration([String], description: String?)
    case object(properties: [String: ParameterSchema], required: [String] = [])
    
    // Static methods removed to avoid conflicts with enum cases with the same signatures
}

// MARK: - Empty Tool Kit

/// Empty toolkit for functions that don't need tools
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct EmptyToolKit: ToolKit {
    public init() {}
    public var tools: [Tool<EmptyToolKit>] { [] }
}