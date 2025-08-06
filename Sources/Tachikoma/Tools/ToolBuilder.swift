//
//  ToolBuilder.swift
//  Tachikoma
//

import Foundation

// MARK: - Tool Builder

/// Result builder for declarative tool creation
@resultBuilder
public struct ToolBuilder {
    public static func buildBlock(_ tools: AgentTool...) -> [AgentTool] {
        return tools
    }

    public static func buildArray(_ tools: [AgentTool]) -> [AgentTool] {
        return tools
    }

    public static func buildOptional(_ tool: AgentTool?) -> [AgentTool] {
        return tool.map { [$0] } ?? []
    }

    public static func buildEither(first tool: AgentTool) -> [AgentTool] {
        return [tool]
    }

    public static func buildEither(second tool: AgentTool) -> [AgentTool] {
        return [tool]
    }

    public static func buildExpression(_ tool: AgentTool) -> AgentTool {
        return tool
    }
}

/// Creates a simple tool with basic parameters
public func createTool(
    name: String,
    description: String,
    parameters: [AgentToolParameterProperty] = [],
    required: [String] = [],
    execute: @escaping @Sendable (AgentToolArguments) async throws -> AgentToolArgument
) -> AgentTool {
    return AgentTool(
        name: name,
        description: description,
        parameters: AgentToolParameters(properties: parameters, required: required),
        execute: execute
    )
}

/// Creates a tool with string parameter
public func stringTool(
    name: String,
    description: String,
    parameter: String,
    parameterDescription: String,
    execute: @escaping @Sendable (String) async throws -> String
) -> AgentTool {
    return createTool(
        name: name,
        description: description,
        parameters: [
            AgentToolParameterProperty(
                name: parameter,
                type: .string,
                description: parameterDescription
            )
        ],
        required: [parameter]
    ) { args in
        let value = try args.stringValue(parameter)
        let result = try await execute(value)
        return AgentToolArgument.string(result)
    }
}

/// Creates a tool with number parameter
public func numberTool(
    name: String,
    description: String,
    parameter: String,
    parameterDescription: String,
    execute: @escaping @Sendable (Double) async throws -> Double
) -> AgentTool {
    return createTool(
        name: name,
        description: description,
        parameters: [
            AgentToolParameterProperty(
                name: parameter,
                type: .number,
                description: parameterDescription
            )
        ],
        required: [parameter]
    ) { args in
        let value = try args.numberValue(parameter)
        let result = try await execute(value)
        return AgentToolArgument.double(result)
    }
}

/// Creates a tool with boolean parameter
public func booleanTool(
    name: String,
    description: String,
    parameter: String,
    parameterDescription: String,
    execute: @escaping @Sendable (Bool) async throws -> Bool
) -> AgentTool {
    return createTool(
        name: name,
        description: description,
        parameters: [
            AgentToolParameterProperty(
                name: parameter,
                type: .boolean,
                description: parameterDescription
            )
        ],
        required: [parameter]
    ) { args in
        let value = try args.booleanValue(parameter)
        let result = try await execute(value)
        return AgentToolArgument.bool(result)
    }
}

/// Creates a tool with no parameters
public func noParamTool(
    name: String,
    description: String,
    execute: @escaping @Sendable () async throws -> String
) -> AgentTool {
    return createTool(
        name: name,
        description: description,
        parameters: [],
        required: []
    ) { _ in
        let result = try await execute()
        return AgentToolArgument.string(result)
    }
}

/// Creates a tool with multiple string parameters
public func multiStringTool(
    name: String,
    description: String,
    parameters: [(name: String, description: String)],
    required: [String] = [],
    execute: @escaping @Sendable ([String: String]) async throws -> String
) -> AgentTool {
    let toolParams = parameters.map { (name, desc) in
        AgentToolParameterProperty(name: name, type: .string, description: desc)
    }
    
    return createTool(
        name: name,
        description: description,
        parameters: toolParams,
        required: required.isEmpty ? parameters.map(\.name) : required
    ) { args in
        var stringArgs: [String: String] = [:]
        for (paramName, _) in parameters {
            if let value = args.optionalStringValue(paramName) {
                stringArgs[paramName] = value
            }
        }
        let result = try await execute(stringArgs)
        return AgentToolArgument.string(result)
    }
}