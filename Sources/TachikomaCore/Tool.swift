import Foundation

// MARK: - Helper Types

/// Box type to handle recursive structures
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class Box<T>: Sendable, Codable where T: Codable & Sendable {
    public let value: T
    
    public init(_ value: T) {
        self.value = value
    }
    
    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        self.value = try T(from: decoder)
    }
}

// MARK: - Tool System

// MARK: - Generic Tool System (Primary)

/// A tool that AI models can call to perform actions
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

// MARK: - Non-Generic Tool for Core API

/// Non-generic tool for simple use cases
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct SimpleTool: Sendable {
    public let name: String
    public let description: String
    public let parameters: ToolParameters
    public let execute: @Sendable (ToolArguments) async throws -> ToolArgument
    
    public init(
        name: String,
        description: String,
        parameters: ToolParameters,
        execute: @escaping @Sendable (ToolArguments) async throws -> ToolArgument
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.execute = execute
    }
}

/// Tool parameter definitions following JSON Schema patterns
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ToolParameters: Sendable, Codable {
    public let type: String
    public let properties: [String: ToolParameterProperty]
    public let required: [String]
    public let additionalProperties: Bool
    
    public init(
        properties: [String: ToolParameterProperty],
        required: [String] = [],
        additionalProperties: Bool = false
    ) {
        self.type = "object"
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
    }
}

/// Individual tool parameter property
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ToolParameterProperty: Sendable, Codable {
    public let type: ParameterType
    public let description: String?
    public let enumValues: [String]?
    public let items: Box<ToolParameterProperty>?
    public let properties: [String: ToolParameterProperty]?
    public let required: [String]?
    public let defaultValue: ToolArgument?
    public let minimum: Double?
    public let maximum: Double?
    public let minLength: Int?
    public let maxLength: Int?
    
    public enum ParameterType: String, Sendable, Codable {
        case string
        case number
        case integer
        case boolean
        case array
        case object
        case null
    }
    
    public init(
        type: ParameterType,
        description: String? = nil,
        enumValues: [String]? = nil,
        items: ToolParameterProperty? = nil,
        properties: [String: ToolParameterProperty]? = nil,
        required: [String]? = nil,
        defaultValue: ToolArgument? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil
    ) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
        self.items = items.map { Box($0) }
        self.properties = properties
        self.required = required
        self.defaultValue = defaultValue
        self.minimum = minimum
        self.maximum = maximum
        self.minLength = minLength
        self.maxLength = maxLength
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, description, items, properties, required
        case enumValues = "enum"
        case defaultValue = "default"
        case minimum, maximum, minLength, maxLength
    }
}

/// Type-safe tool arguments wrapper
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ToolArguments: Sendable {
    private let arguments: [String: ToolArgument]
    
    public init(_ arguments: [String: ToolArgument]) {
        self.arguments = arguments
    }
    
    public subscript(key: String) -> ToolArgument? {
        return arguments[key]
    }
    
    public func get<T>(_ key: String, as type: T.Type) throws -> T {
        guard let value = arguments[key] else {
            throw TachikomaError.invalidInput("Missing required parameter: \(key)")
        }
        
        switch (value, type) {
        case (.string(let str), _ as String.Type):
            return str as! T
        case (.int(let int), _ as Int.Type):
            return int as! T
        case (.double(let double), _ as Double.Type):
            return double as! T
        case (.bool(let bool), _ as Bool.Type):
            return bool as! T
        case (.array(let array), _ as [ToolArgument].Type):
            return array as! T
        case (.object(let object), _ as [String: ToolArgument].Type):
            return object as! T
        case (.null, _):
            throw TachikomaError.invalidInput("Parameter \(key) is null")
        default:
            throw TachikomaError.invalidInput("Parameter \(key) type mismatch: expected \(type), got \(value)")
        }
    }
    
    public func getString(_ key: String) throws -> String {
        return try get(key, as: String.self)
    }
    
    public func getInt(_ key: String) throws -> Int {
        return try get(key, as: Int.self)
    }
    
    public func getDouble(_ key: String) throws -> Double {
        return try get(key, as: Double.self)
    }
    
    public func getBool(_ key: String) throws -> Bool {
        return try get(key, as: Bool.self)
    }
    
    public func getArray(_ key: String) throws -> [ToolArgument] {
        return try get(key, as: [ToolArgument].self)
    }
    
    public func getObject(_ key: String) throws -> [String: ToolArgument] {
        return try get(key, as: [String: ToolArgument].self)
    }
    
    // Optional variants
    public func getStringOptional(_ key: String) -> String? {
        return try? getString(key)
    }
    
    public func getIntOptional(_ key: String) -> Int? {
        return try? getInt(key)
    }
    
    public func getDoubleOptional(_ key: String) -> Double? {
        return try? getDouble(key)
    }
    
    public func getBoolOptional(_ key: String) -> Bool? {
        return try? getBool(key)
    }
    
    public func getArrayOptional(_ key: String) -> [ToolArgument]? {
        return try? getArray(key)
    }
    
    public func getObjectOptional(_ key: String) -> [String: ToolArgument]? {
        return try? getObject(key)
    }
}

// MARK: - Tool Builder

/// Fluent builder for creating tools with type safety
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public class ToolBuilder {
    private var name: String
    private var description: String
    private var properties: [String: ToolParameterProperty] = [:]
    private var required: [String] = []
    private var executeFunction: (@Sendable (ToolArguments) async throws -> ToolArgument)?
    
    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
    
    @discardableResult
    public func parameter(
        _ name: String,
        type: ToolParameterProperty.ParameterType,
        description: String,
        required: Bool = false,
        enumValues: [String]? = nil,
        defaultValue: ToolArgument? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil
    ) -> ToolBuilder {
        properties[name] = ToolParameterProperty(
            type: type,
            description: description,
            enumValues: enumValues,
            defaultValue: defaultValue,
            minimum: minimum,
            maximum: maximum,
            minLength: minLength,
            maxLength: maxLength
        )
        
        if required {
            self.required.append(name)
        }
        
        return self
    }
    
    @discardableResult
    public func stringParameter(
        _ name: String,
        description: String,
        required: Bool = false,
        enumValues: [String]? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil
    ) -> ToolBuilder {
        return parameter(
            name,
            type: .string,
            description: description,
            required: required,
            enumValues: enumValues,
            minLength: minLength,
            maxLength: maxLength
        )
    }
    
    @discardableResult
    public func intParameter(
        _ name: String,
        description: String,
        required: Bool = false,
        minimum: Double? = nil,
        maximum: Double? = nil
    ) -> ToolBuilder {
        return parameter(
            name,
            type: .integer,
            description: description,
            required: required,
            minimum: minimum,
            maximum: maximum
        )
    }
    
    @discardableResult
    public func doubleParameter(
        _ name: String,
        description: String,
        required: Bool = false,
        minimum: Double? = nil,
        maximum: Double? = nil
    ) -> ToolBuilder {
        return parameter(
            name,
            type: .number,
            description: description,
            required: required,
            minimum: minimum,
            maximum: maximum
        )
    }
    
    @discardableResult
    public func boolParameter(
        _ name: String,
        description: String,
        required: Bool = false
    ) -> ToolBuilder {
        return parameter(
            name,
            type: .boolean,
            description: description,
            required: required
        )
    }
    
    @discardableResult
    public func execute(_ function: @escaping @Sendable (ToolArguments) async throws -> ToolArgument) -> ToolBuilder {
        self.executeFunction = function
        return self
    }
    
    public func build() throws -> SimpleTool {
        guard let executeFunction = executeFunction else {
            throw TachikomaError.invalidConfiguration("Tool \(name) missing execute function")
        }
        
        let parameters = ToolParameters(
            properties: properties,
            required: required
        )
        
        return SimpleTool(
            name: name,
            description: description,
            parameters: parameters,
            execute: executeFunction
        )
    }
}

// MARK: - Convenience Functions

/// Create a tool using the fluent builder pattern
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func tool(
    name: String,
    description: String,
    _ configure: (ToolBuilder) throws -> ToolBuilder
) throws -> SimpleTool {
    let builder = ToolBuilder(name: name, description: description)
    return try configure(builder).build()
}

// MARK: - Common Tools

/// Pre-built common tools
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct CommonTools {
    
    /// Simple calculator tool
    public static func calculator() throws -> SimpleTool {
        return try tool(name: "calculator", description: "Perform basic mathematical calculations") { builder in
            builder
                .stringParameter("expression", description: "Mathematical expression to evaluate", required: true)
                .execute { args in
                    let expression = try args.getString("expression")
                    
                    // Simple expression evaluator (very basic)
                    let result = try evaluateExpression(expression)
                    return .double(result)
                }
        }
    }
    
    /// Get current date/time tool
    public static func getCurrentDateTime() throws -> SimpleTool {
        return try tool(name: "getCurrentDateTime", description: "Get the current date and time") { builder in
            builder
                .stringParameter("format", description: "Date format (iso8601, timestamp, readable)", required: false, enumValues: ["iso8601", "timestamp", "readable"])
                .execute { args in
                    let format = args.getStringOptional("format") ?? "iso8601"
                    let now = Date()
                    
                    let result: String
                    switch format {
                    case "timestamp":
                        result = String(now.timeIntervalSince1970)
                    case "readable":
                        let formatter = DateFormatter()
                        formatter.dateStyle = .full
                        formatter.timeStyle = .full
                        result = formatter.string(from: now)
                    default: // iso8601
                        result = ISO8601DateFormatter().string(from: now)
                    }
                    
                    return .string(result)
                }
        }
    }
}

// MARK: - Helper Functions

private func evaluateExpression(_ expression: String) throws -> Double {
    // Very basic expression evaluator - in production would use NSExpression or similar
    let cleanExpression = expression.replacingOccurrences(of: " ", with: "")
    
    // Handle simple cases
    if let number = Double(cleanExpression) {
        return number
    }
    
    // Basic operations
    if cleanExpression.contains("+") {
        let parts = cleanExpression.components(separatedBy: "+")
        if parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]) {
            return a + b
        }
    }
    
    if cleanExpression.contains("-") {
        let parts = cleanExpression.components(separatedBy: "-")
        if parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]) {
            return a - b
        }
    }
    
    if cleanExpression.contains("*") {
        let parts = cleanExpression.components(separatedBy: "*")
        if parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]) {
            return a * b
        }
    }
    
    if cleanExpression.contains("/") {
        let parts = cleanExpression.components(separatedBy: "/")
        if parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]) {
            if b == 0 {
                throw TachikomaError.invalidInput("Division by zero")
            }
            return a / b
        }
    }
    
    throw TachikomaError.invalidInput("Invalid expression: \(expression)")
}

// MARK: - ToolKit Protocol for TachikomaBuilders Compatibility

/// Protocol for tool collections used by TachikomaBuilders
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public protocol ToolKit: Sendable {
    associatedtype Context = Self
    var tools: [Tool<Context>] { get }
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

/// Extension to convert ToolKit to provider tools
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension ToolKit {
    /// Convert tools to provider tool format
    public func toProviderTools() throws -> [ProviderTool] {
        return tools.map { tool in
            // Create basic parameters structure for the provider tool
            let parameters = ToolParameters(
                properties: [
                    "input": ToolParameterProperty(
                        type: .string,
                        description: tool.description
                    )
                ],
                required: ["input"]
            )
            
            return ProviderTool(
                name: tool.name,
                description: tool.description,
                parameters: parameters
            )
        }
    }
}


// MARK: - ToolInput/ToolOutput Compatibility Types

/// Tool input type for TachikomaBuilders compatibility
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ToolInput: Sendable {
    private let arguments: [String: ToolArgument]
    
    public init(_ arguments: [String: ToolArgument]) {
        self.arguments = arguments
    }
    
    public init(jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw ToolError.invalidInput("Invalid UTF-8 JSON string")
        }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            guard let dictionary = jsonObject as? [String: Any] else {
                throw ToolError.invalidInput("JSON must be an object")
            }
            
            var arguments: [String: ToolArgument] = [:]
            for (key, value) in dictionary {
                arguments[key] = try ToolArgument.from(any: value)
            }
            
            self.arguments = arguments
        } catch let error as ToolError {
            throw error
        } catch {
            throw ToolError.invalidInput("Invalid JSON: \(error.localizedDescription)")
        }
    }
    
    public func stringValue(_ key: String) throws -> String {
        guard let value = arguments[key] else {
            throw ToolError.invalidInput("Missing required parameter: \(key)")
        }
        switch value {
        case .string(let str):
            return str
        default:
            throw ToolError.invalidInput("Parameter \(key) is not a string")
        }
    }
    
    public func stringValue(_ key: String, default defaultValue: String) -> String {
        return (try? stringValue(key)) ?? defaultValue
    }
    
    public func intValue(_ key: String) throws -> Int {
        guard let value = arguments[key] else {
            throw ToolError.invalidInput("Missing required parameter: \(key)")
        }
        switch value {
        case .int(let int):
            return int
        default:
            throw ToolError.invalidInput("Parameter \(key) is not an integer")
        }
    }
    
    public func intValue(_ key: String, default defaultValue: Int) -> Int {
        return (try? intValue(key)) ?? defaultValue
    }
    
    public func doubleValue(_ key: String) throws -> Double {
        guard let value = arguments[key] else {
            throw ToolError.invalidInput("Missing required parameter: \(key)")
        }
        switch value {
        case .double(let double):
            return double
        case .int(let int):
            return Double(int)
        default:
            throw ToolError.invalidInput("Parameter \(key) is not a number")
        }
    }
    
    public func doubleValue(_ key: String, default defaultValue: Double) -> Double {
        return (try? doubleValue(key)) ?? defaultValue
    }
    
    public func boolValue(_ key: String) throws -> Bool {
        guard let value = arguments[key] else {
            throw ToolError.invalidInput("Missing required parameter: \(key)")
        }
        switch value {
        case .bool(let bool):
            return bool
        default:
            throw ToolError.invalidInput("Parameter \(key) is not a boolean")
        }
    }
    
    public func boolValue(_ key: String, default defaultValue: Bool) -> Bool {
        return (try? boolValue(key)) ?? defaultValue
    }
    
    public func stringValue(_ key: String, default defaultValue: String?) -> String? {
        return (try? stringValue(key)) ?? defaultValue
    }
    
    public func intValue(_ key: String, default defaultValue: Int?) -> Int? {
        return (try? intValue(key)) ?? defaultValue
    }
    
    /// Get array of ToolArguments for the specified key
    public func arrayValue(_ key: String) throws -> [ToolArgument] {
        guard let value = arguments[key] else {
            throw ToolError.invalidInput("Missing required parameter: \(key)")
        }
        switch value {
        case .array(let array):
            return array
        default:
            throw ToolError.invalidInput("Parameter \(key) is not an array")
        }
    }
    
    /// Get array of ToolArguments with default fallback
    public func arrayValue(_ key: String, default defaultValue: [ToolArgument]) -> [ToolArgument] {
        return (try? arrayValue(key)) ?? defaultValue
    }
    
    /// Get array of strings for the specified key
    public func stringArrayValue(_ key: String) throws -> [String] {
        let array = try arrayValue(key)
        return try array.map { item in
            switch item {
            case .string(let str):
                return str
            default:
                throw ToolError.invalidInput("Parameter \(key) array contains non-string values")
            }
        }
    }
    
    /// Get array of strings with default fallback
    public func stringArrayValue(_ key: String, default defaultValue: [String]) -> [String] {
        return (try? stringArrayValue(key)) ?? defaultValue
    }
    
    /// Get array of integers for the specified key
    public func intArrayValue(_ key: String) throws -> [Int] {
        let array = try arrayValue(key)
        return try array.map { item in
            switch item {
            case .int(let int):
                return int
            default:
                throw ToolError.invalidInput("Parameter \(key) array contains non-integer values")
            }
        }
    }
    
    /// Get array of integers with default fallback
    public func intArrayValue(_ key: String, default defaultValue: [Int]) -> [Int] {
        return (try? intArrayValue(key)) ?? defaultValue
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
    
    /// Convert to JSON string representation
    public func toJSONString() throws -> String {
        switch self {
        case .string(let str):
            return str
        case .int(let int):
            return String(int)
        case .double(let double):
            return String(double)
        case .bool(let bool):
            return String(bool)
        case .null:
            return "null"
        case .array(let array):
            let items = try array.map { try $0.toJSONString() }
            return "[\(items.joined(separator: ", "))]"
        case .object(let dict):
            let pairs = try dict.map { key, value in
                "\"\(key)\": \(try value.toJSONString())"
            }
            return "{\(pairs.joined(separator: ", "))}"
        }
    }
}

// MARK: - ToolError for TachikomaBuilders Compatibility

/// Tool execution errors for TachikomaBuilders compatibility
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ToolError: Error, LocalizedError, Sendable {
    case invalidInput(String)
    case toolNotFound(String)
    case executionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid tool input: \(message)"
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .executionFailed(let message):
            return "Tool execution failed: \(message)"
        }
    }
}

// MARK: - Parameter Schema for TachikomaBuilders Compatibility

/// Parameter schema type for TachikomaBuilders compatibility
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ParameterSchema: Sendable {
    case object(properties: [String: ParameterProperty])
    case string
    case integer
    case boolean
    case array(items: ParameterProperty)
}

/// Parameter property type for TachikomaBuilders compatibility
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ParameterProperty: Sendable {
    public let type: String
    public let description: String?
    
    public init(type: String, description: String? = nil) {
        self.type = type
        self.description = description
    }
}