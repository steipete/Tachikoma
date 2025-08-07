//
//  DynamicTools.swift
//  Tachikoma
//

import Foundation

// MARK: - Dynamic Tool System

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
        recipient: String? = nil
    ) {
        self.name = name
        self.description = description
        self.schema = schema
        self.namespace = namespace
        self.recipient = recipient
    }
    
    /// Convert to a static AgentTool with the provided executor
    public func toAgentTool(executor: @escaping @Sendable (AgentToolArguments) async throws -> AnyAgentToolValue) -> AgentTool {
        AgentTool(
            name: name,
            description: description,
            parameters: schema.toAgentToolParameters(),
            namespace: namespace,
            recipient: recipient,
            execute: executor
        )
    }
}

/// Dynamic schema that can be created at runtime
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct DynamicSchema: Sendable, Codable {
    public let type: SchemaType
    public let properties: [String: SchemaProperty]?
    public let required: [String]?
    public let items: SchemaProperty?
    public let enumValues: [String]?
    public let format: String?
    public let minimum: Double?
    public let maximum: Double?
    public let minLength: Int?
    public let maxLength: Int?
    
    public enum SchemaType: String, Sendable, Codable {
        case object
        case array
        case string
        case number
        case integer
        case boolean
        case null
    }
    
    public init(
        type: SchemaType,
        properties: [String: SchemaProperty]? = nil,
        required: [String]? = nil,
        items: SchemaProperty? = nil,
        enumValues: [String]? = nil,
        format: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.items = items
        self.enumValues = enumValues
        self.format = format
        self.minimum = minimum
        self.maximum = maximum
        self.minLength = minLength
        self.maxLength = maxLength
    }
    
    /// Convert to AgentToolParameters
    public func toAgentToolParameters() -> AgentToolParameters {
        guard type == .object, let properties else {
            // For non-object types, wrap in an object with a single property
            let prop = AgentToolParameterProperty(
                name: "value",
                type: schemaTypeToParameterType(type),
                description: "Value parameter"
            )
            return AgentToolParameters(properties: [prop], required: ["value"])
        }
        
        var agentProps: [String: AgentToolParameterProperty] = [:]
        for (key, value) in properties {
            agentProps[key] = value.toAgentToolParameterProperty(name: key)
        }
        
        return AgentToolParameters(
            properties: agentProps,
            required: required ?? []
        )
    }
    
    private func schemaTypeToParameterType(_ type: SchemaType) -> AgentToolParameterProperty.ParameterType {
        switch type {
        case .string: return .string
        case .number: return .number
        case .integer: return .integer
        case .boolean: return .boolean
        case .array: return .array
        case .object: return .object
        case .null: return .string // Fallback for null type
        }
    }
}

/// Property within a dynamic schema
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct SchemaProperty: Sendable, Codable {
    public let type: DynamicSchema.SchemaType
    public let description: String?
    public let enumValues: [String]?
    public let items: Box<SchemaProperty>? // Box for indirect recursion
    public let properties: [String: SchemaProperty]?
    public let required: [String]?
    public let format: String?
    public let minimum: Double?
    public let maximum: Double?
    
    public init(
        type: DynamicSchema.SchemaType,
        description: String? = nil,
        enumValues: [String]? = nil,
        items: SchemaProperty? = nil,
        properties: [String: SchemaProperty]? = nil,
        required: [String]? = nil,
        format: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil
    ) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
        self.items = items.map(Box.init)
        self.properties = properties
        self.required = required
        self.format = format
        self.minimum = minimum
        self.maximum = maximum
    }
    
    /// Convert to AgentToolParameterProperty
    func toAgentToolParameterProperty(name: String) -> AgentToolParameterProperty {
        let paramType: AgentToolParameterProperty.ParameterType = switch type {
        case .string: .string
        case .number: .number
        case .integer: .integer
        case .boolean: .boolean
        case .array: .array
        case .object: .object
        case .null: .string
        }
        
        return AgentToolParameterProperty(
            name: name,
            type: paramType,
            description: description ?? "",
            enumValues: enumValues
        )
    }
}

/// Box type for indirect recursion in Codable structs
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class Box<T: Codable & Sendable>: Codable, Sendable {
    public let value: T
    
    public init(_ value: T) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(T.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Dynamic Tool Registry

/// Registry for managing dynamic tools at runtime
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor DynamicToolRegistry {
    private var providers: [String: DynamicToolProvider] = [:]
    private var tools: [String: DynamicTool] = [:]
    private var executors: [String: @Sendable (AgentToolArguments) async throws -> AnyAgentToolValue] = [:]
    
    public init() {}
    
    /// Register a dynamic tool provider
    public func registerProvider(_ provider: DynamicToolProvider, id: String) {
        providers[id] = provider
    }
    
    /// Register a single dynamic tool with executor
    public func registerTool(
        _ tool: DynamicTool,
        executor: @escaping @Sendable (AgentToolArguments) async throws -> AnyAgentToolValue
    ) {
        tools[tool.name] = tool
        executors[tool.name] = executor
    }
    
    /// Discover and register all tools from providers
    public func discoverTools() async throws {
        for (_, provider) in providers {
            let discoveredTools = try await provider.discoverTools()
            for tool in discoveredTools {
                tools[tool.name] = tool
                // Create executor that delegates to provider
                let capturedProvider = provider
                executors[tool.name] = { arguments in
                    try await capturedProvider.executeTool(name: tool.name, arguments: arguments)
                }
            }
        }
    }
    
    /// Get all available tools as AgentTool instances
    public func getAgentTools() -> [AgentTool] {
        tools.compactMap { name, tool in
            guard let executor = executors[name] else { return nil }
            return tool.toAgentTool(executor: executor)
        }
    }
    
    /// Execute a tool by name
    public func executeTool(name: String, arguments: AgentToolArguments) async throws -> AnyAgentToolValue {
        guard let executor = executors[name] else {
            throw TachikomaError.toolCallFailed("Tool '\(name)' not found in registry")
        }
        return try await executor(arguments)
    }
    
    /// Remove a tool from the registry
    public func unregisterTool(name: String) {
        tools.removeValue(forKey: name)
        executors.removeValue(forKey: name)
    }
    
    /// Clear all tools and providers
    public func clear() {
        providers.removeAll()
        tools.removeAll()
        executors.removeAll()
    }
}

// MARK: - Schema Builder

/// Builder for creating dynamic schemas fluently
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct SchemaBuilder {
    private var type: DynamicSchema.SchemaType
    private var properties: [String: SchemaProperty] = [:]
    private var required: [String] = []
    private var items: SchemaProperty?
    private var enumValues: [String]?
    private var format: String?
    private var minimum: Double?
    private var maximum: Double?
    private var minLength: Int?
    private var maxLength: Int?
    
    public init(type: DynamicSchema.SchemaType) {
        self.type = type
    }
    
    /// Create an object schema
    public static func object() -> SchemaBuilder {
        SchemaBuilder(type: .object)
    }
    
    /// Create an array schema
    public static func array() -> SchemaBuilder {
        SchemaBuilder(type: .array)
    }
    
    /// Create a string schema
    public static func string() -> SchemaBuilder {
        SchemaBuilder(type: .string)
    }
    
    /// Create a number schema
    public static func number() -> SchemaBuilder {
        SchemaBuilder(type: .number)
    }
    
    /// Create an integer schema
    public static func integer() -> SchemaBuilder {
        SchemaBuilder(type: .integer)
    }
    
    /// Create a boolean schema
    public static func boolean() -> SchemaBuilder {
        SchemaBuilder(type: .boolean)
    }
    
    /// Add a property (for object schemas)
    public func property(
        _ name: String,
        type: DynamicSchema.SchemaType,
        description: String? = nil,
        required: Bool = false
    ) -> SchemaBuilder {
        var builder = self
        builder.properties[name] = SchemaProperty(
            type: type,
            description: description
        )
        if required {
            builder.required.append(name)
        }
        return builder
    }
    
    /// Add a property with a schema property
    public func property(_ name: String, _ prop: SchemaProperty, required: Bool = false) -> SchemaBuilder {
        var builder = self
        builder.properties[name] = prop
        if required {
            builder.required.append(name)
        }
        return builder
    }
    
    /// Set array items schema
    public func items(_ itemSchema: SchemaProperty) -> SchemaBuilder {
        var builder = self
        builder.items = itemSchema
        return builder
    }
    
    /// Set enum values
    public func enumValues(_ values: [String]) -> SchemaBuilder {
        var builder = self
        builder.enumValues = values
        return builder
    }
    
    /// Set format
    public func format(_ format: String) -> SchemaBuilder {
        var builder = self
        builder.format = format
        return builder
    }
    
    /// Set minimum value
    public func minimum(_ min: Double) -> SchemaBuilder {
        var builder = self
        builder.minimum = min
        return builder
    }
    
    /// Set maximum value
    public func maximum(_ max: Double) -> SchemaBuilder {
        var builder = self
        builder.maximum = max
        return builder
    }
    
    /// Set minimum length
    public func minLength(_ length: Int) -> SchemaBuilder {
        var builder = self
        builder.minLength = length
        return builder
    }
    
    /// Set maximum length
    public func maxLength(_ length: Int) -> SchemaBuilder {
        var builder = self
        builder.maxLength = length
        return builder
    }
    
    /// Build the schema
    public func build() -> DynamicSchema {
        DynamicSchema(
            type: type,
            properties: properties.isEmpty ? nil : properties,
            required: required.isEmpty ? nil : required,
            items: items,
            enumValues: enumValues,
            format: format,
            minimum: minimum,
            maximum: maximum,
            minLength: minLength,
            maxLength: maxLength
        )
    }
}

// MARK: - MCP-Style Tool Discovery

/// Example implementation of MCP-style tool discovery
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct MCPToolProvider: DynamicToolProvider {
    private let endpoint: URL
    private let apiKey: String?
    
    public init(endpoint: URL, apiKey: String? = nil) {
        self.endpoint = endpoint
        self.apiKey = apiKey
    }
    
    public func discoverTools() async throws -> [DynamicTool] {
        // This would make an actual HTTP request to discover tools
        // For now, return example tools
        [
            DynamicTool(
                name: "search_web",
                description: "Search the web for information",
                schema: SchemaBuilder.object()
                    .property("query", type: .string, description: "Search query", required: true)
                    .property("limit", type: .integer, description: "Maximum results", required: false)
                    .build()
            ),
            DynamicTool(
                name: "get_weather",
                description: "Get current weather for a location",
                schema: SchemaBuilder.object()
                    .property("location", type: .string, description: "City name", required: true)
                    .property("units", type: .string, description: "Temperature units")
                    .build()
            )
        ]
    }
    
    public func executeTool(name: String, arguments: AgentToolArguments) async throws -> AnyAgentToolValue {
        // This would make an actual HTTP request to execute the tool
        // For now, return mock results
        switch name {
        case "search_web":
            return AnyAgentToolValue(string: "Mock search results for: \(String(describing: arguments["query"]))")
        case "get_weather":
            return AnyAgentToolValue(object: [
                "temperature": AnyAgentToolValue(double: 72),
                "condition": AnyAgentToolValue(string: "Sunny"),
                "location": arguments["location"] ?? AnyAgentToolValue(string: "Unknown")
            ])
        default:
            throw TachikomaError.toolCallFailed("Unknown tool: \(name)")
        }
    }
}