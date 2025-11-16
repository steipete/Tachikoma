import Foundation
import Tachikoma

// MARK: - Tool Builder

/// Result builder for declarative tool creation
@resultBuilder
public struct ToolBuilder {
    public static func buildBlock(_ tools: AgentTool...) -> [AgentTool] {
        tools
    }

    public static func buildArray(_ tools: [AgentTool]) -> [AgentTool] {
        tools
    }

    public static func buildOptional(_ tool: AgentTool?) -> [AgentTool] {
        tool.map { [$0] } ?? []
    }

    public static func buildEither(first tool: AgentTool) -> [AgentTool] {
        [tool]
    }

    public static func buildEither(second tool: AgentTool) -> [AgentTool] {
        [tool]
    }

    public static func buildExpression(_ tool: AgentTool) -> AgentTool {
        tool
    }
}

/// Creates a tool using a simplified API similar to Vercel AI SDK
///
/// Example:
/// ```swift
/// let weatherTool = tool(
///     description: "Get the weather for a location",
///     parameters: [
///         "location": .string(description: "The city name"),
///         "units": .enum(["celsius", "fahrenheit"], description: "Temperature units")
///     ],
///     execute: { args in
///         let location = try args.stringValue("location")
///         let units = try args.stringValue("units")
///         return .string("Weather in \(location): 22°\(units == "celsius" ? "C" : "F")")
///     }
/// )
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func tool(
    _ name: String? = nil,
    description: String,
    parameters: [String: ParameterDefinition] = [:],
    execute: @escaping @Sendable (AgentToolArguments) async throws -> AnyAgentToolValue,
)
    -> AgentTool
{
    // Convert parameter definitions to AgentToolParameterProperty
    var properties: [String: AgentToolParameterProperty] = [:]
    var required: [String] = []

    for (key, definition) in parameters {
        properties[key] = definition.toProperty(name: key)
        if definition.isRequired {
            required.append(key)
        }
    }

    // Generate name from description if not provided
    let toolName = name ?? description
        .lowercased()
        .replacingOccurrences(of: " ", with: "_")
        .replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression)
        .prefix(50)
        .trimmingCharacters(in: .init(charactersIn: "_"))

    return AgentTool(
        name: String(toolName),
        description: description,
        parameters: AgentToolParameters(properties: properties, required: required),
        execute: execute,
    )
}

/// Simplified parameter definition for tool creation
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ParameterDefinition {
    let type: AgentToolParameterProperty.ParameterType
    let description: String
    let isRequired: Bool
    let enumValues: [String]?

    public static func string(description: String, required: Bool = true) -> ParameterDefinition {
        ParameterDefinition(type: .string, description: description, isRequired: required, enumValues: nil)
    }

    public static func number(description: String, required: Bool = true) -> ParameterDefinition {
        ParameterDefinition(type: .number, description: description, isRequired: required, enumValues: nil)
    }

    public static func boolean(description: String, required: Bool = true) -> ParameterDefinition {
        ParameterDefinition(type: .boolean, description: description, isRequired: required, enumValues: nil)
    }

    public static func array(description: String, required: Bool = true) -> ParameterDefinition {
        ParameterDefinition(type: .array, description: description, isRequired: required, enumValues: nil)
    }

    public static func object(description: String, required: Bool = true) -> ParameterDefinition {
        ParameterDefinition(type: .object, description: description, isRequired: required, enumValues: nil)
    }

    public static func `enum`(_ values: [String], description: String, required: Bool = true) -> ParameterDefinition {
        ParameterDefinition(type: .string, description: description, isRequired: required, enumValues: values)
    }

    func toProperty(name: String) -> AgentToolParameterProperty {
        AgentToolParameterProperty(
            name: name,
            type: self.type,
            description: self.description,
            enumValues: self.enumValues,
        )
    }
}

/// Creates a simple tool with basic parameters (legacy API)
public func createTool(
    name: String,
    description: String,
    parameters: [AgentToolParameterProperty] = [],
    required: [String] = [],
    execute: @escaping @Sendable (AgentToolArguments) async throws -> AnyAgentToolValue,
)
    -> AgentTool
{
    // Convert array of properties to dictionary keyed by name
    var properties: [String: AgentToolParameterProperty] = [:]
    for param in parameters {
        properties[param.name] = param
    }

    return AgentTool(
        name: name,
        description: description,
        parameters: AgentToolParameters(properties: properties, required: required),
        execute: execute,
    )
}

// Helper struct for type-safe tool creation (moved outside to avoid nesting in generic function)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
private struct ConcreteAgentTool<I: AgentToolValue, O: AgentToolValue>: AgentToolProtocol {
    typealias Input = I
    typealias Output = O

    let name: String
    let description: String
    let schema: AgentToolSchema
    let executeFunc: @Sendable (I, ToolExecutionContext) async throws -> O

    func execute(_ input: I, context: ToolExecutionContext) async throws -> O {
        try await self.executeFunc(input, context)
    }
}

/// Creates a type-safe tool with protocol conformance
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func agentTool<I: AgentToolValue, O: AgentToolValue>(
    _ name: String,
    description: String,
    input _: I.Type,
    output _: O.Type,
    execute: @escaping @Sendable (I, ToolExecutionContext) async throws -> O,
)
    -> AnyAgentTool
{
    // Generate schema based on input type
    let schema = AgentToolSchema(properties: [:], required: [])

    let concrete = ConcreteAgentTool(
        name: name,
        description: description,
        schema: schema,
        executeFunc: execute,
    )

    return AnyAgentTool(concrete)
}

/// Creates a tool with string parameter
public func stringTool(
    name: String,
    description: String,
    parameter: String,
    parameterDescription: String,
    execute: @escaping @Sendable (String) async throws -> String,
)
    -> AgentTool
{
    // Creates a tool with string parameter
    createTool(
        name: name,
        description: description,
        parameters: [
            AgentToolParameterProperty(
                name: parameter,
                type: .string,
                description: parameterDescription,
            ),
        ],
        required: [parameter],
    ) { args in
        let value = try args.stringValue(parameter)
        let result = try await execute(value)
        return AnyAgentToolValue(string: result)
    }
}

/// Creates a tool with number parameter
public func numberTool(
    name: String,
    description: String,
    parameter: String,
    parameterDescription: String,
    execute: @escaping @Sendable (Double) async throws -> Double,
)
    -> AgentTool
{
    // Creates a tool with number parameter
    createTool(
        name: name,
        description: description,
        parameters: [
            AgentToolParameterProperty(
                name: parameter,
                type: .number,
                description: parameterDescription,
            ),
        ],
        required: [parameter],
    ) { args in
        let value = try args.numberValue(parameter)
        let result = try await execute(value)
        return AnyAgentToolValue(double: result)
    }
}

/// Creates a tool with boolean parameter
public func booleanTool(
    name: String,
    description: String,
    parameter: String,
    parameterDescription: String,
    execute: @escaping @Sendable (Bool) async throws -> Bool,
)
    -> AgentTool
{
    // Creates a tool with boolean parameter
    createTool(
        name: name,
        description: description,
        parameters: [
            AgentToolParameterProperty(
                name: parameter,
                type: .boolean,
                description: parameterDescription,
            ),
        ],
        required: [parameter],
    ) { args in
        let value = try args.booleanValue(parameter)
        let result = try await execute(value)
        return AnyAgentToolValue(bool: result)
    }
}

/// Creates a tool with no parameters
public func noParamTool(
    name: String,
    description: String,
    execute: @escaping @Sendable () async throws -> String,
)
    -> AgentTool
{
    // Creates a tool with no parameters
    createTool(
        name: name,
        description: description,
        parameters: [],
        required: [],
    ) { _ in
        let result = try await execute()
        return AnyAgentToolValue(string: result)
    }
}

/// Creates a tool with multiple string parameters
public func multiStringTool(
    name: String,
    description: String,
    parameters: [(name: String, description: String)],
    required: [String] = [],
    execute: @escaping @Sendable ([String: String]) async throws -> String,
)
    -> AgentTool
{
    // Creates a tool with multiple string parameters
    let toolParams = parameters.map { name, desc in
        AgentToolParameterProperty(name: name, type: .string, description: desc)
    }

    return createTool(
        name: name,
        description: description,
        parameters: toolParams,
        required: required.isEmpty ? parameters.map(\.name) : required,
    ) { args in
        var stringArgs: [String: String] = [:]
        for (paramName, _) in parameters {
            if let value = args.optionalStringValue(paramName) {
                stringArgs[paramName] = value
            }
        }
        let result = try await execute(stringArgs)
        return AnyAgentToolValue(string: result)
    }
}
