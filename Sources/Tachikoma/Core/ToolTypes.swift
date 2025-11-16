import Foundation

// MARK: - Core Tool Types

// These types are in Core to allow TachikomaMCP to use them without depending on TachikomaAgent

/// Protocol for values that can be used as tool arguments or results
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol AgentToolValue: Sendable, Codable {
    static var agentValueType: AgentValueType { get }
    func toJSON() throws -> Any
    static func fromJSON(_ json: Any) throws -> Self
}

/// Type descriptor for runtime type checking
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum AgentValueType: String, Sendable, Codable, CaseIterable {
    case string
    case number
    case integer
    case boolean
    case array
    case object
    case null
}

// MARK: - Built-in Type Conformances

extension String: AgentToolValue {
    public static var agentValueType: AgentValueType { .string }

    public func toJSON() throws -> Any { self }

    public static func fromJSON(_ json: Any) throws -> Self {
        guard let string = json as? String else {
            throw TachikomaError.invalidInput("Expected String, got \(type(of: json))")
        }
        return string
    }
}

extension Int: AgentToolValue {
    public static var agentValueType: AgentValueType { .integer }

    public func toJSON() throws -> Any { self }

    public static func fromJSON(_ json: Any) throws -> Self {
        if let int = json as? Int {
            return int
        } else if let double = json as? Double {
            return Int(double)
        } else {
            throw TachikomaError.invalidInput("Expected Int, got \(type(of: json))")
        }
    }
}

extension Double: AgentToolValue {
    public static var agentValueType: AgentValueType { .number }

    public func toJSON() throws -> Any { self }

    public static func fromJSON(_ json: Any) throws -> Self {
        if let double = json as? Double {
            return double
        } else if let int = json as? Int {
            return Double(int)
        } else {
            throw TachikomaError.invalidInput("Expected Double, got \(type(of: json))")
        }
    }
}

extension Bool: AgentToolValue {
    public static var agentValueType: AgentValueType { .boolean }

    public func toJSON() throws -> Any { self }

    public static func fromJSON(_ json: Any) throws -> Self {
        guard let bool = json as? Bool else {
            throw TachikomaError.invalidInput("Expected Bool, got \(type(of: json))")
        }
        return bool
    }
}

/// Null value type
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentNullValue: AgentToolValue, Equatable {
    public static var agentValueType: AgentValueType { .null }

    public init() {}

    public func toJSON() throws -> Any { NSNull() }

    public static func fromJSON(_ json: Any) throws -> Self {
        if json is NSNull {
            return AgentNullValue()
        }
        throw TachikomaError.invalidInput("Expected null, got \(type(of: json))")
    }
}

/// Array conformance
extension Array: AgentToolValue where Element: AgentToolValue {
    public static var agentValueType: AgentValueType { .array }

    public func toJSON() throws -> Any {
        try map { try $0.toJSON() }
    }

    public static func fromJSON(_ json: Any) throws -> Self {
        guard let array = json as? [Any] else {
            throw TachikomaError.invalidInput("Expected Array, got \(type(of: json))")
        }
        return try array.map { try Element.fromJSON($0) }
    }
}

/// Dictionary conformance
extension Dictionary: AgentToolValue where Key == String, Value: AgentToolValue {
    public static var agentValueType: AgentValueType { .object }

    public func toJSON() throws -> Any {
        var result: [String: Any] = [:]
        for (key, value) in self {
            result[key] = try value.toJSON()
        }
        return result
    }

    public static func fromJSON(_ json: Any) throws -> Self {
        guard let dict = json as? [String: Any] else {
            throw TachikomaError.invalidInput("Expected Dictionary, got \(type(of: json))")
        }
        var result: [String: Value] = [:]
        for (key, val) in dict {
            result[key] = try Value.fromJSON(val)
        }
        return result
    }
}

// MARK: - Type-Erased Wrapper

/// Type-erased wrapper for dynamic tool values
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AnyAgentToolValue: AgentToolValue, Equatable, Codable {
    private let storage: Storage

    private enum Storage: Equatable, Codable {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case array([AnyAgentToolValue])
        case object([String: AnyAgentToolValue])
    }

    public static var agentValueType: AgentValueType { .object } // Generic type

    public init(_ value: some AgentToolValue) throws {
        let json = try value.toJSON()
        self = try Self.fromJSON(json)
    }

    public init(null _: ()) {
        self.storage = .null
    }

    public init(bool: Bool) {
        self.storage = .bool(bool)
    }

    public init(int: Int) {
        self.storage = .int(int)
    }

    public init(double: Double) {
        self.storage = .double(double)
    }

    public init(string: String) {
        self.storage = .string(string)
    }

    public init(array: [AnyAgentToolValue]) {
        self.storage = .array(array)
    }

    public init(object: [String: AnyAgentToolValue]) {
        self.storage = .object(object)
    }

    public func toJSON() throws -> Any {
        switch self.storage {
        case .null:
            return NSNull()
        case let .bool(value):
            return value
        case let .int(value):
            return value
        case let .double(value):
            return value
        case let .string(value):
            return value
        case let .array(values):
            return try values.map { try $0.toJSON() }
        case let .object(dict):
            var result: [String: Any] = [:]
            for (key, value) in dict {
                result[key] = try value.toJSON()
            }
            return result
        }
    }

    public static func fromJSON(_ json: Any) throws -> Self {
        if json is NSNull {
            return AnyAgentToolValue(null: ())
        } else if let bool = json as? Bool {
            return AnyAgentToolValue(bool: bool)
        } else if let int = json as? Int {
            return AnyAgentToolValue(int: int)
        } else if let double = json as? Double {
            // Check if it's actually an integer
            if double.truncatingRemainder(dividingBy: 1) == 0, double >= Double(Int.min), double <= Double(Int.max) {
                return AnyAgentToolValue(int: Int(double))
            }
            return AnyAgentToolValue(double: double)
        } else if let string = json as? String {
            return AnyAgentToolValue(string: string)
        } else if let array = json as? [Any] {
            let values = try array.map { try AnyAgentToolValue.fromJSON($0) }
            return AnyAgentToolValue(array: values)
        } else if let dict = json as? [String: Any] {
            var result: [String: AnyAgentToolValue] = [:]
            for (key, val) in dict {
                result[key] = try AnyAgentToolValue.fromJSON(val)
            }
            return AnyAgentToolValue(object: result)
        } else {
            throw TachikomaError.invalidInput("Unsupported JSON type: \(type(of: json))")
        }
    }

    /// Create from dictionary for tool arguments
    public static func fromDictionary(_ dict: [String: Any]) throws -> AnyAgentToolValue {
        // Create from dictionary for tool arguments
        try self.fromJSON(dict)
    }

    /// Create from Any value
    public static func from(_ value: Any) -> AnyAgentToolValue {
        // Create from Any value
        (try? self.fromJSON(value)) ?? AnyAgentToolValue(string: "\(value)")
    }

    /// Convenience accessors
    public var stringValue: String? {
        if case let .string(value) = storage { return value }
        return nil
    }

    public var intValue: Int? {
        if case let .int(value) = storage { return value }
        return nil
    }

    public var doubleValue: Double? {
        switch self.storage {
        case let .double(value): value
        case let .int(value): Double(value)
        default: nil
        }
    }

    public var boolValue: Bool? {
        if case let .bool(value) = storage { return value }
        return nil
    }

    public var arrayValue: [AnyAgentToolValue]? {
        if case let .array(value) = storage { return value }
        return nil
    }

    public var objectValue: [String: AnyAgentToolValue]? {
        if case let .object(value) = storage { return value }
        return nil
    }

    public var isNull: Bool {
        if case .null = self.storage { return true }
        return false
    }

    // MARK: - Codable Conformance

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.storage = .null
        } else if let bool = try? container.decode(Bool.self) {
            self.storage = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self.storage = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self.storage = .double(double)
        } else if let string = try? container.decode(String.self) {
            self.storage = .string(string)
        } else if let array = try? container.decode([AnyAgentToolValue].self) {
            self.storage = .array(array)
        } else if let object = try? container.decode([String: AnyAgentToolValue].self) {
            self.storage = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyAgentToolValue")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self.storage {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}

// MARK: - Tool Call and Result Types

/// A tool call made by the AI model
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentToolCall: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let arguments: [String: AnyAgentToolValue]
    public let namespace: String?
    public let recipient: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        arguments: [String: AnyAgentToolValue],
        namespace: String? = nil,
        recipient: String? = nil,
    ) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.namespace = namespace
        self.recipient = recipient
    }

    /// Legacy init for migration
    public init(
        id: String = UUID().uuidString,
        name: String,
        arguments: [String: Any],
        namespace: String? = nil,
        recipient: String? = nil,
    ) throws {
        self.id = id
        self.name = name
        var convertedArgs: [String: AnyAgentToolValue] = [:]
        for (key, value) in arguments {
            convertedArgs[key] = try AnyAgentToolValue.fromJSON(value)
        }
        self.arguments = convertedArgs
        self.namespace = namespace
        self.recipient = recipient
    }
}

/// Result of executing a tool
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentToolResult: Sendable, Codable, Equatable {
    public let toolCallId: String
    public let result: AnyAgentToolValue
    public let isError: Bool

    public init(toolCallId: String, result: AnyAgentToolValue, isError: Bool = false) {
        self.toolCallId = toolCallId
        self.result = result
        self.isError = isError
    }

    public static func success(toolCallId: String, result: AnyAgentToolValue) -> AgentToolResult {
        AgentToolResult(toolCallId: toolCallId, result: result, isError: false)
    }

    public static func error(toolCallId: String, error: String) -> AgentToolResult {
        AgentToolResult(toolCallId: toolCallId, result: AnyAgentToolValue(string: error), isError: true)
    }
}

// MARK: - Tool Definition Types

/// Arguments passed to a tool execution
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentToolArguments: Sendable {
    private let storage: [String: AnyAgentToolValue]

    public init(_ dictionary: [String: AnyAgentToolValue] = [:]) {
        self.storage = dictionary
    }

    public init(_ dictionary: [String: Any]) {
        var converted: [String: AnyAgentToolValue] = [:]
        for (key, value) in dictionary {
            converted[key] = AnyAgentToolValue.from(value)
        }
        self.storage = converted
    }

    public subscript(key: String) -> AnyAgentToolValue? {
        self.storage[key]
    }

    public func get<T: AgentToolValue>(_ key: String, as _: T.Type) throws -> T {
        guard let value = storage[key] else {
            throw TachikomaError.invalidInput("Missing required argument: \(key)")
        }
        let json = try value.toJSON()
        return try T.fromJSON(json)
    }

    public func getOptional<T: AgentToolValue>(_ key: String, as _: T.Type) -> T? {
        guard let value = storage[key] else { return nil }
        return try? T.fromJSON(value.toJSON())
    }

    public var keys: Dictionary<String, AnyAgentToolValue>.Keys {
        self.storage.keys
    }

    public var count: Int {
        self.storage.count
    }

    public var isEmpty: Bool {
        self.storage.isEmpty
    }
}

/// Tool parameter schema
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentToolParameters: Sendable, Codable {
    public let type: String
    public let properties: [String: AgentToolParameterProperty]
    public let required: [String]

    public init(properties: [String: AgentToolParameterProperty] = [:], required: [String] = []) {
        self.type = "object"
        self.properties = properties
        self.required = required
    }
}

/// Tool parameter property definition
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentToolParameterProperty: Sendable, Codable {
    public let name: String
    public let type: ParameterType
    public let description: String
    public let enumValues: [String]?
    public let items: AgentToolParameterItems?

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
        name: String,
        type: ParameterType,
        description: String,
        enumValues: [String]? = nil,
        items: AgentToolParameterItems? = nil,
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.enumValues = enumValues
        self.items = items
    }
}

/// Items definition for array parameters
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentToolParameterItems: Sendable, Codable {
    public let type: String
    public let description: String?

    public init(type: String, description: String? = nil) {
        self.type = type
        self.description = description
    }
}

/// Core tool definition
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentTool: Sendable {
    public let name: String
    public let description: String
    public let parameters: AgentToolParameters
    public let namespace: String?
    public let recipient: String?
    public let execute: @Sendable (AgentToolArguments, ToolExecutionContext) async throws -> AnyAgentToolValue

    public init(
        name: String,
        description: String,
        parameters: AgentToolParameters,
        namespace: String? = nil,
        recipient: String? = nil,
        execute: @escaping @Sendable (AgentToolArguments) async throws -> AnyAgentToolValue,
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.namespace = namespace
        self.recipient = recipient
        // Wrap the simple executor to ignore context
        self.execute = { @Sendable args, _ in try await execute(args) }
    }

    public init(
        name: String,
        description: String,
        parameters: AgentToolParameters,
        namespace: String? = nil,
        recipient: String? = nil,
        executeWithContext: @escaping @Sendable (AgentToolArguments, ToolExecutionContext) async throws
            -> AnyAgentToolValue,
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.namespace = namespace
        self.recipient = recipient
        self.execute = executeWithContext
    }

    /// Execute the tool with context
    public func execute(
        _ arguments: AgentToolArguments,
        context: ToolExecutionContext,
    ) async throws
        -> AnyAgentToolValue
    {
        // Execute the tool with context
        try await self.execute(arguments, context)
    }
}

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
        metadata: [String: String] = [:],
    ) {
        self.messages = messages
        self.model = model
        self.settings = settings
        self.sessionId = sessionId
        self.stepIndex = stepIndex
        self.metadata = metadata
    }
}

// MARK: - Dynamic Tool Types

/// Protocol for dynamic tool providers (e.g., MCP servers)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol DynamicToolProvider: Sendable {
    /// Discover available tools at runtime
    func discoverTools() async throws -> [DynamicTool]

    /// Execute a tool by name with given arguments
    func executeTool(name: String, arguments: AgentToolArguments) async throws -> AnyAgentToolValue
}

/// A dynamically created tool with runtime schema
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct DynamicTool: Sendable {
    // Discover available tools at runtime
    public let name: String
    public let description: String
    public let schema: DynamicSchema
    public let namespace: String?
    public let recipient: String?

    public init(
        name: String,
        description: String,
        schema: DynamicSchema,
        namespace: String? = nil,
        recipient: String? = nil,
    ) {
        self.name = name
        self.description = description
        self.schema = schema
        self.namespace = namespace
        self.recipient = recipient
    }

    /// Convert to a static AgentTool with the provided executor
    public func toAgentTool(executor: @escaping @Sendable (AgentToolArguments) async throws -> AnyAgentToolValue)
        -> AgentTool
    {
        // Convert to a static AgentTool with the provided executor
        AgentTool(
            name: self.name,
            description: self.description,
            parameters: self.schema.toAgentToolParameters(),
            namespace: self.namespace,
            recipient: self.recipient,
            execute: executor,
        )
    }
}

/// Dynamic schema that can be created at runtime
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct DynamicSchema: Sendable, Codable {
    public let type: SchemaType
    public let properties: [String: SchemaProperty]?
    public let required: [String]?
    public let items: SchemaItems?

    public enum SchemaType: String, Sendable, Codable {
        case object
        case array
        case string
        case number
        case integer
        case boolean
        case null
    }

    public struct SchemaProperty: Sendable, Codable {
        public let type: SchemaType
        public let description: String?
        public let enumValues: [String]?
        public let items: SchemaItems?
        public let properties: [String: SchemaProperty]?
        public let required: [String]?
        public let format: String?
        public let minimum: Double?
        public let maximum: Double?
        public let minLength: Int?
        public let maxLength: Int?

        public init(
            type: SchemaType,
            description: String? = nil,
            enumValues: [String]? = nil,
            items: SchemaItems? = nil,
            properties: [String: SchemaProperty]? = nil,
            required: [String]? = nil,
            format: String? = nil,
            minimum: Double? = nil,
            maximum: Double? = nil,
            minLength: Int? = nil,
            maxLength: Int? = nil,
        ) {
            self.type = type
            self.description = description
            self.enumValues = enumValues
            self.items = items
            self.properties = properties
            self.required = required
            self.format = format
            self.minimum = minimum
            self.maximum = maximum
            self.minLength = minLength
            self.maxLength = maxLength
        }
    }

    public struct SchemaItems: Sendable, Codable {
        public let type: SchemaType
        public let description: String?

        public init(type: SchemaType, description: String? = nil) {
            self.type = type
            self.description = description
        }
    }

    public init(
        type: SchemaType,
        properties: [String: SchemaProperty]? = nil,
        required: [String]? = nil,
        items: SchemaItems? = nil,
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.items = items
    }

    /// Convert to AgentToolParameters
    public func toAgentToolParameters() -> AgentToolParameters {
        // Convert to AgentToolParameters
        var props: [String: AgentToolParameterProperty] = [:]

        if let properties {
            for (key, prop) in properties {
                let items = prop.items.map { schemaItems in
                    AgentToolParameterItems(
                        type: schemaItems.type.rawValue,
                        description: schemaItems.description,
                    )
                }

                // Convert SchemaType to ParameterType
                let paramType = AgentToolParameterProperty.ParameterType(rawValue: prop.type.rawValue) ?? .string

                props[key] = AgentToolParameterProperty(
                    name: key,
                    type: paramType,
                    description: prop.description ?? "",
                    enumValues: prop.enumValues,
                    items: items,
                )
            }
        }

        return AgentToolParameters(
            properties: props,
            required: self.required ?? [],
        )
    }
}
