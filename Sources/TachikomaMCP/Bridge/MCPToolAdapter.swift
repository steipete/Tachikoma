//
//  MCPToolAdapter.swift
//  TachikomaMCP
//

import Foundation
import MCP
import Tachikoma

/// Adapter to convert MCP tools to Tachikoma's AgentTool format
public struct MCPToolAdapter {
    
    /// Convert an MCP Tool to Tachikoma's AgentTool
    public static func toAgentTool(from mcpTool: Tool, client: MCPClient) -> AgentTool {
        // Convert MCP schema to Tachikoma's AgentToolParameters
        let parameters = convertSchema(mcpTool.inputSchema)
        
        return AgentTool(
            name: mcpTool.name,
            description: mcpTool.description,
            parameters: parameters,
            execute: { arguments in
                // Execute the tool via MCP client
                let response = try await client.executeTool(
                    name: mcpTool.name,
                    arguments: convertArguments(arguments)
                )
                
                // Convert response to AgentToolArgument
                return convertResponse(response)
            }
        )
    }
    
    /// Convert MCP Value schema to AgentToolParameters
    private static func convertSchema(_ schema: Value?) -> AgentToolParameters {
        guard let schema = schema else {
            return AgentToolParameters(
                properties: [:],
                required: []
            )
        }
        
        // Extract properties from MCP schema
        var properties: [String: AgentToolParameterProperty] = [:]
        var required: [String] = []
        
        if case let .object(schemaDict) = schema {
            // Get properties
            if let propsValue = schemaDict["properties"],
               case let .object(propsDict) = propsValue {
                for (key, propValue) in propsDict {
                    properties[key] = convertParameter(key, propValue)
                }
            }
            
            // Get required fields
            if let reqValue = schemaDict["required"],
               case let .array(reqArray) = reqValue {
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
            required: required
        )
    }
    
    /// Convert a single parameter schema
    private static func convertParameter(_ name: String, _ value: Value) -> AgentToolParameterProperty {
        guard case let .object(dict) = value else {
            return AgentToolParameterProperty(
                name: name,
                type: .string,
                description: "String parameter"
            )
        }
        
        var paramType: AgentToolParameterProperty.ParameterType = .string
        var description = "Parameter"
        var enumValues: [String]?
        
        // Extract type
        if let typeValue = dict["type"],
           case let .string(typeStr) = typeValue {
            paramType = AgentToolParameterProperty.ParameterType(rawValue: typeStr) ?? .string
        }
        
        // Extract description
        if let descValue = dict["description"],
           case let .string(descStr) = descValue {
            description = descStr
        }
        
        // Extract enum values
        if let enumValue = dict["enum"],
           case let .array(enumArray) = enumValue {
            enumValues = enumArray.compactMap { val in
                if case let .string(str) = val {
                    return str
                }
                return nil
            }
        }
        
        return AgentToolParameterProperty(
            name: name,
            type: paramType,
            description: description,
            enumValues: enumValues
        )
    }
    
    /// Convert Tachikoma arguments to MCP format
    private static func convertArguments(_ arguments: AgentToolArguments) -> [String: Any] {
        var result: [String: Any] = [:]
        
        for key in arguments.keys {
            if let value = arguments[key] {
                result[key] = convertArgument(value)
            }
        }
        
        return result
    }
    
    /// Convert a single AgentToolArgument to Any
    private static func convertArgument(_ argument: AgentToolArgument) -> Any {
        switch argument {
        case .string(let str):
            return str
        case .int(let num):
            return num
        case .double(let num):
            return num
        case .bool(let bool):
            return bool
        case .array(let array):
            return array.map { convertArgument($0) }
        case .object(let dict):
            return dict.mapValues { convertArgument($0) }
        case .null:
            return NSNull()
        }
    }
    
    /// Convert MCP ToolResponse to AgentToolArgument
    private static func convertResponse(_ response: ToolResponse) -> AgentToolArgument {
        // If there's an error, return it as a string
        if response.isError {
            let errorMessage = response.content.compactMap { content -> String? in
                if case .text(let text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")
            
            return .string("Error: \(errorMessage)")
        }
        
        // Convert content to appropriate format
        if response.content.count == 1 {
            // Single content item
            return convertContent(response.content[0])
        } else if response.content.isEmpty {
            // No content
            return .null
        } else {
            // Multiple content items - return as array
            return .array(response.content.map { convertContent($0) })
        }
    }
    
    /// Convert MCP Tool.Content to AgentToolArgument
    private static func convertContent(_ content: MCP.Tool.Content) -> AgentToolArgument {
        switch content {
        case .text(let text):
            return .string(text)
        case .image(let data, let mimeType, _):
            return .object([
                "type": .string("image"),
                "mimeType": .string(mimeType),
                "data": .string(data)
            ])
        case .resource(let uri, let mimeType, let text):
            var resourceDict: [String: AgentToolArgument] = [
                "type": .string("resource"),
                "uri": .string(uri),
                "mimeType": .string(mimeType)
            ]
            if let text = text {
                resourceDict["text"] = .string(text)
            } else {
                resourceDict["text"] = .null
            }
            return .object(resourceDict)
        case .audio(let data, let mimeType):
            return .object([
                "type": .string("audio"),
                "mimeType": .string(mimeType),
                "data": .string(data)
            ])
        }
    }
}