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

/// A tool that AI models can call to perform actions
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct Tool: Sendable {
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
    
    public func build() throws -> Tool {
        guard let executeFunction = executeFunction else {
            throw TachikomaError.invalidConfiguration("Tool \(name) missing execute function")
        }
        
        let parameters = ToolParameters(
            properties: properties,
            required: required
        )
        
        return Tool(
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
) throws -> Tool {
    let builder = ToolBuilder(name: name, description: description)
    return try configure(builder).build()
}

// MARK: - Common Tools

/// Pre-built common tools
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct CommonTools {
    
    /// Simple calculator tool
    public static func calculator() throws -> Tool {
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
    public static func getCurrentDateTime() throws -> Tool {
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