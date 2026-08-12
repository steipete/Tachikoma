import Foundation
import MCP
import Tachikoma

/// Adapter to convert MCP tools to Tachikoma's AgentTool format
public enum MCPToolAdapter {
    /// Convert an MCP Tool to Tachikoma's AgentTool
    public static func toAgentTool(from mcpTool: Tool, client: MCPClient) -> AgentTool {
        // Convert MCP schema to Tachikoma's AgentToolParameters
        let parameters = self.convertSchema(mcpTool.inputSchema)

        return AgentTool(
            name: mcpTool.name,
            description: mcpTool.description ?? "",
            parameters: parameters,
        ) { arguments in
            // Execute the tool via MCP client
            let response = try await client.executeTool(
                name: mcpTool.name,
                arguments: self.convertArguments(arguments),
            )

            return try response.toAgentToolExecutionValue()
        }
    }

    /// Convert MCP Value schema to AgentToolParameters
    private static func convertSchema(_ schema: Value?) -> AgentToolParameters {
        // Convert MCP Value schema to AgentToolParameters
        guard let schema else {
            return AgentToolParameters(
                properties: [:],
                required: [],
            )
        }

        // Extract properties from MCP schema
        var properties: [String: AgentToolParameterProperty] = [:]
        var required: [String] = []

        if case let .object(schemaDict) = schema {
            // Get properties
            if
                let propsValue = schemaDict["properties"],
                case let .object(propsDict) = propsValue
            {
                for (key, propValue) in propsDict {
                    properties[key] = self.convertParameter(key, propValue)
                }
            }

            // Get required fields
            if
                let reqValue = schemaDict["required"],
                case let .array(reqArray) = reqValue
            {
                required = reqArray.compactMap { value in
                    if case let .string(str) = value {
                        return str
                    }
                    return nil
                }
            }
        }

        return AgentToolParameters(
            properties: properties,
            required: required,
        )
    }

    /// Convert a single parameter schema
    private static func convertParameter(_ name: String, _ value: Value) -> AgentToolParameterProperty {
        // Convert a single parameter schema
        guard case let .object(dict) = value else {
            return AgentToolParameterProperty(
                name: name,
                type: .string,
                description: "String parameter",
            )
        }

        var paramType: AgentToolParameterProperty.ParameterType = .string
        var description = "Parameter"
        var enumValues: [String]?
        var items: AgentToolParameterItems?

        // Extract type
        if
            let typeValue = dict["type"],
            case let .string(typeStr) = typeValue
        {
            paramType = AgentToolParameterProperty.ParameterType(rawValue: typeStr) ?? .string
        }

        // Extract description
        if
            let descValue = dict["description"],
            case let .string(descStr) = descValue
        {
            description = descStr
        }

        // Extract enum values
        if
            let enumValue = dict["enum"],
            case let .array(enumArray) = enumValue
        {
            enumValues = enumArray.compactMap { val in
                if case let .string(str) = val {
                    return str
                }
                return nil
            }
        }

        // Extract items for array types
        if paramType == .array {
            // Check if items field exists
            if
                let itemsValue = dict["items"],
                case let .object(itemsDict) = itemsValue
            {
                var itemType: AgentToolParameterProperty.ParameterType = .string

                // Extract item type
                if
                    let itemTypeValue = itemsDict["type"],
                    case let .string(itemTypeStr) = itemTypeValue
                {
                    itemType = AgentToolParameterProperty.ParameterType(rawValue: itemTypeStr) ?? .string
                }

                // AgentToolParameterItems does not currently support enum metadata
                items = AgentToolParameterItems(
                    type: itemType.rawValue,
                    description: nil,
                )
            } else {
                // If array type but no items specified, default to string items
                items = AgentToolParameterItems(
                    type: AgentToolParameterProperty.ParameterType.string.rawValue,
                    description: nil,
                )
            }
        }

        return AgentToolParameterProperty(
            name: name,
            type: paramType,
            description: description,
            enumValues: enumValues,
            items: items,
        )
    }

    /// Convert Tachikoma arguments to MCP format
    private static func convertArguments(_ arguments: AgentToolArguments) -> [String: Any] {
        // Convert Tachikoma arguments to MCP format
        var result: [String: Any] = [:]

        for key in arguments.keys {
            if let value = arguments[key] {
                result[key] = self.convertArgument(value)
            }
        }

        return result
    }

    /// Convert a single AnyAgentToolValue to Any
    private static func convertArgument(_ argument: AnyAgentToolValue) -> Any {
        do {
            return try argument.toJSON()
        } catch {
            return [
                "serializationError": error.localizedDescription,
                "fallback": String(describing: argument),
            ]
        }
    }
}
