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

            // Convert response to AnyAgentToolValue
            return self.convertResponse(response)
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

    /// Convert MCP ToolResponse to AnyAgentToolValue
    private static func convertResponse(_ response: ToolResponse) -> AnyAgentToolValue {
        if response.isError {
            let errorMessage = response.content.compactMap { content -> String? in
                if case let .text(text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")

            return AnyAgentToolValue(string: "Error: \(errorMessage)")
        }

        let contentValue: AnyAgentToolValue = if response.content.isEmpty {
            AnyAgentToolValue(null: ())
        } else if response.content.count == 1 {
            self.convertContent(response.content[0])
        } else {
            AnyAgentToolValue(array: response.content.map { self.convertContent($0) })
        }

        guard let meta = response.meta else {
            return contentValue
        }

        var payload: [String: AnyAgentToolValue] = [
            "result": contentValue,
            "meta": convertMetaValue(meta),
        ]

        if let text = contentValue.stringValue {
            payload["text"] = AnyAgentToolValue(string: text)
        }

        return AnyAgentToolValue(object: payload)
    }

    private static func convertMetaValue(_ value: Value) -> AnyAgentToolValue {
        switch value {
        case let .string(str):
            return AnyAgentToolValue(string: str)
        case let .int(num):
            return AnyAgentToolValue(int: num)
        case let .double(num):
            return AnyAgentToolValue(double: num)
        case let .bool(flag):
            return AnyAgentToolValue(bool: flag)
        case let .array(values):
            return AnyAgentToolValue(array: values.map { self.convertMetaValue($0) })
        case let .object(dict):
            var converted: [String: AnyAgentToolValue] = [:]
            for (key, entry) in dict {
                converted[key] = self.convertMetaValue(entry)
            }
            return AnyAgentToolValue(object: converted)
        case .null:
            return AnyAgentToolValue(null: ())
        case let .data(mime, data):
            return AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "data"),
                "mimeType": AnyAgentToolValue(string: mime ?? "application/octet-stream"),
                "size": AnyAgentToolValue(int: data.count),
            ])
        }
    }

    /// Convert MCP Tool.Content to AnyAgentToolValue
    private static func convertContent(_ content: MCP.Tool.Content) -> AnyAgentToolValue {
        // Convert MCP Tool.Content to AnyAgentToolValue
        switch content {
        case let .text(text):
            return AnyAgentToolValue(string: text)
        case let .image(data, mimeType, _):
            return AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "image"),
                "mimeType": AnyAgentToolValue(string: mimeType),
                "data": AnyAgentToolValue(string: data),
            ])
        case let .resource(uri, mimeType, text):
            var resourceDict: [String: AnyAgentToolValue] = [
                "type": AnyAgentToolValue(string: "resource"),
                "uri": AnyAgentToolValue(string: uri),
                "mimeType": AnyAgentToolValue(string: mimeType),
            ]
            if let text {
                resourceDict["text"] = AnyAgentToolValue(string: text)
            } else {
                resourceDict["text"] = AnyAgentToolValue(null: ())
            }
            return AnyAgentToolValue(object: resourceDict)
        case let .audio(data, mimeType):
            return AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "audio"),
                "mimeType": AnyAgentToolValue(string: mimeType),
                "data": AnyAgentToolValue(string: data),
            ])
        }
    }
}
