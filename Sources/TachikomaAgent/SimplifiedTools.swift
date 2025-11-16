import Foundation
import Tachikoma

// MARK: - Simplified Tool Definition

/// Simplified tool builder following AI SDK patterns
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct SimplifiedToolBuilder {
    /// Create a tool with simplified definition pattern
    public static func tool<Input: Codable & Sendable>(
        _ name: String,
        description: String,
        inputSchema _: Input.Type,
        execute: @escaping @Sendable (Input) async throws -> some Codable & Sendable,
    )
        -> AgentTool
    {
        // Create a tool with simplified definition pattern
        let parameters = self.generateParameters(from: Input.self)

        return AgentTool(
            name: name,
            description: description,
            parameters: parameters,
        ) { arguments in
            // Convert arguments to Input type
            let jsonData = try JSONSerialization.data(withJSONObject: arguments.toDictionary())
            let input = try JSONDecoder().decode(Input.self, from: jsonData)

            // Execute and convert output
            let output = try await execute(input)
            let outputData = try JSONEncoder().encode(output)
            let outputJson = try JSONSerialization.jsonObject(with: outputData)

            return try AnyAgentToolValue.fromJSON(outputJson)
        }
    }

    /// Create a tool with context support
    public static func toolWithContext<Input: Codable & Sendable>(
        _ name: String,
        description: String,
        inputSchema _: Input.Type,
        execute: @escaping @Sendable (Input, ToolExecutionContext) async throws -> some Codable & Sendable,
    )
        -> AgentTool
    {
        // Create a tool with context support
        let parameters = self.generateParameters(from: Input.self)

        return AgentTool(
            name: name,
            description: description,
            parameters: parameters,
        ) { arguments, context in
            // Convert arguments to Input type
            let jsonData = try JSONSerialization.data(withJSONObject: arguments.toDictionary())
            let input = try JSONDecoder().decode(Input.self, from: jsonData)

            // Execute with context and convert output
            let output = try await execute(input, context)
            let outputData = try JSONEncoder().encode(output)
            let outputJson = try JSONSerialization.jsonObject(with: outputData)

            return try AnyAgentToolValue.fromJSON(outputJson)
        }
    }

    /// Create a simple tool without structured input
    public static func simpleTool(
        _ name: String,
        description: String,
        parameters: [String: String] = [:], // parameter name -> description
        execute: @escaping @Sendable ([String: Any]) async throws -> Any,
    )
        -> AgentTool
    {
        // Create a simple tool without structured input
        var props: [String: AgentToolParameterProperty] = [:]
        for (key, desc) in parameters {
            props[key] = AgentToolParameterProperty(
                name: key,
                type: .string,
                description: desc,
            )
        }

        let toolParams = AgentToolParameters(
            properties: props,
            required: Array(parameters.keys),
        )

        return AgentTool(
            name: name,
            description: description,
            parameters: toolParams,
        ) { arguments in
            let dict = arguments.toDictionary()
            let result = try await execute(dict)
            return try AnyAgentToolValue.fromJSON(result)
        }
    }

    /// Generate parameters from Codable type using Mirror reflection
    private static func generateParameters(from _: (some Codable).Type) -> AgentToolParameters {
        // This is a simplified version - in production, we'd use more sophisticated reflection
        // or code generation to extract the actual property types and descriptions

        // For now, return a basic object schema
        AgentToolParameters(
            properties: [:],
            required: [],
        )
    }
}

// MARK: - Tool Schema Builder

/// Fluent builder for tool schemas
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ToolSchemaBuilder {
    private var properties: [AgentToolParameterProperty] = []
    private var required: [String] = []

    public init() {}

    /// Add a string parameter
    public func string(
        _ name: String,
        description: String,
        required: Bool = false,
        enum values: [String]? = nil,
    )
        -> ToolSchemaBuilder
    {
        // Add a string parameter
        var builder = self
        builder.properties.append(AgentToolParameterProperty(
            name: name,
            type: .string,
            description: description,
            enumValues: values,
        ))
        if required {
            builder.required.append(name)
        }
        return builder
    }

    /// Add a number parameter
    public func number(
        _ name: String,
        description: String,
        required: Bool = false,
    )
        -> ToolSchemaBuilder
    {
        // Add a number parameter
        var builder = self
        builder.properties.append(AgentToolParameterProperty(
            name: name,
            type: .number,
            description: description,
        ))
        if required {
            builder.required.append(name)
        }
        return builder
    }

    /// Add an integer parameter
    public func integer(
        _ name: String,
        description: String,
        required: Bool = false,
    )
        -> ToolSchemaBuilder
    {
        // Add an integer parameter
        var builder = self
        builder.properties.append(AgentToolParameterProperty(
            name: name,
            type: .integer,
            description: description,
        ))
        if required {
            builder.required.append(name)
        }
        return builder
    }

    /// Add a boolean parameter
    public func boolean(
        _ name: String,
        description: String,
        required: Bool = false,
    )
        -> ToolSchemaBuilder
    {
        // Add a boolean parameter
        var builder = self
        builder.properties.append(AgentToolParameterProperty(
            name: name,
            type: .boolean,
            description: description,
        ))
        if required {
            builder.required.append(name)
        }
        return builder
    }

    /// Add an array parameter
    public func array(
        _ name: String,
        description: String,
        itemType: AgentToolParameterProperty.ParameterType = .string,
        required: Bool = false,
    )
        -> ToolSchemaBuilder
    {
        // Add an array parameter
        var builder = self
        builder.properties.append(AgentToolParameterProperty(
            name: name,
            type: .array,
            description: description,
            items: AgentToolParameterItems(type: itemType.rawValue),
        ))
        if required {
            builder.required.append(name)
        }
        return builder
    }

    /// Add an object parameter
    public func object(
        _ name: String,
        description: String,
        required: Bool = false,
    )
        -> ToolSchemaBuilder
    {
        // Add an object parameter
        var builder = self
        builder.properties.append(AgentToolParameterProperty(
            name: name,
            type: .object,
            description: description,
        ))
        if required {
            builder.required.append(name)
        }
        return builder
    }

    /// Build the parameters
    public func build() -> AgentToolParameters {
        // Convert array of properties to dictionary keyed by name
        var propertiesDict: [String: AgentToolParameterProperty] = [:]
        for prop in self.properties {
            propertiesDict[prop.name] = prop
        }
        return AgentToolParameters(properties: propertiesDict, required: self.required)
    }
}

// MARK: - Tool Creation Helpers

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension AgentTool {
    /// Create a tool using the schema builder
    public static func create(
        name: String,
        description: String,
        schema: (ToolSchemaBuilder) -> ToolSchemaBuilder,
        execute: @escaping @Sendable (AgentToolArguments) async throws -> AnyAgentToolValue,
    )
        -> AgentTool
    {
        // Create a tool using the schema builder
        let builder = ToolSchemaBuilder()
        let parameters = schema(builder).build()

        return AgentTool(
            name: name,
            description: description,
            parameters: parameters,
            execute: execute,
        )
    }

    /// Create a tool with context using the schema builder
    public static func createWithContext(
        name: String,
        description: String,
        schema: (ToolSchemaBuilder) -> ToolSchemaBuilder,
        execute: @escaping @Sendable (AgentToolArguments, ToolExecutionContext) async throws -> AnyAgentToolValue,
    )
        -> AgentTool
    {
        // Create a tool with context using the schema builder
        let builder = ToolSchemaBuilder()
        let parameters = schema(builder).build()

        return AgentTool(
            name: name,
            description: description,
            parameters: parameters,
            executeWithContext: execute,
        )
    }
}

// MARK: - Convenience Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension AgentToolArguments {
    /// Convert arguments to dictionary for simplified tool execution
    func toDictionary() -> [String: Any] {
        // Convert arguments to dictionary for simplified tool execution
        var dict: [String: Any] = [:]
        for key in keys {
            if let value = self[key] {
                do {
                    dict[key] = try value.toJSON()
                } catch {
                    // If conversion fails, skip this value
                    continue
                }
            }
        }
        return dict
    }
}

// MARK: - Example Usage

/*
 // Example 1: Simple tool with structured input
 struct CalculatorInput: Codable, Sendable {
     let expression: String
 }

 let calculator = SimplifiedToolBuilder.tool(
     "calculate",
     description: "Evaluate a mathematical expression",
     inputSchema: CalculatorInput.self
 ) { input in
     // Evaluate expression and return result
     return ["result": evaluateExpression(input.expression)]
 }

 // Example 2: Tool with schema builder
 let weatherTool = AgentTool.create(
     name: "getWeather",
     description: "Get current weather for a location",
     schema: { builder in
         builder
             .string("location", description: "City name or coordinates", required: true)
             .string("units", description: "Temperature units", enum: ["celsius", "fahrenheit"])
     }
 ) { arguments in
     let location = try arguments.stringValue("location")
     let units = arguments.optionalStringValue("units") ?? "celsius"

     // Fetch weather and return
     let weather = await fetchWeather(location: location, units: units)
     return try AnyAgentToolValue.fromJSON(weather)
 }

 // Example 3: Simple tool without structured types
 let echoTool = SimplifiedToolBuilder.simpleTool(
     "echo",
     description: "Echo back the input message",
     parameters: ["message": "The message to echo"]
 ) { args in
     return ["echoed": args["message"] ?? ""]
 }
 */
