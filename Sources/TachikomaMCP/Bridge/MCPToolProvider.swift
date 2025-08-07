//
//  MCPToolProvider.swift
//  TachikomaMCP
//

import Foundation
import MCP
import Tachikoma
import Logging

/// MCP-based implementation of DynamicToolProvider
public final class MCPToolProvider: DynamicToolProvider {
    private let client: MCPClient
    private let logger: Logger
    
    public init(client: MCPClient) {
        self.client = client
        self.logger = Logger(label: "tachikoma.mcp.provider")
    }
    
    /// Convenience initializer with configuration
    public convenience init(name: String, config: MCPServerConfig) {
        let client = MCPClient(name: name, config: config)
        self.init(client: client)
    }
    
    /// Connect to the MCP server (if not already connected)
    public func connect() async throws {
        if !(await client.isConnected) {
            try await client.connect()
        }
    }
    
    /// Discover available tools from the MCP server
    public func discoverTools() async throws -> [DynamicTool] {
        // Ensure we're connected
        try await connect()
        
        // Get tools from MCP client
        let mcpTools = await client.tools
        
        logger.info("Discovered \(mcpTools.count) tools from MCP server")
        
        // Convert to DynamicTool format
        return mcpTools.map { mcpTool in
            DynamicTool(
                name: mcpTool.name,
                description: mcpTool.description,
                schema: convertSchemaToDynamic(mcpTool.inputSchema)
            )
        }
    }
    
    /// Execute a tool by name
    public func executeTool(
        name: String,
        arguments: AgentToolArguments
    ) async throws -> AgentToolArgument {
        // Convert arguments to MCP format
        var mcpArgs: [String: Any] = [:]
        for key in arguments.keys {
            if let value = arguments[key] {
                mcpArgs[key] = convertToAny(value)
            }
        }
        
        // Execute via MCP client
        let response = try await client.executeTool(
            name: name,
            arguments: mcpArgs
        )
        
        // Convert response back to AgentToolArgument
        return convertResponseToArgument(response)
    }
    
    /// Get all available tools as AgentTools
    public func getAgentTools() async throws -> [AgentTool] {
        // Ensure we're connected
        try await connect()
        
        // Get tools from MCP client
        let mcpTools = await client.tools
        
        // Convert each tool using the adapter
        return mcpTools.map { mcpTool in
            MCPToolAdapter.toAgentTool(from: mcpTool, client: client)
        }
    }
    
    // MARK: - Private Helpers
    
    private func convertSchemaToDynamic(_ value: Value?) -> DynamicSchema {
        guard let value = value else {
            return DynamicSchema(type: .object, properties: [:])
        }
        
        // Parse the MCP schema into DynamicSchema
        if case let .object(dict) = value {
            var properties: [String: SchemaProperty] = [:]
            
            if let propsValue = dict["properties"],
               case let .object(propsDict) = propsValue {
                for (key, propValue) in propsDict {
                    properties[key] = convertPropertyToDynamic(propValue)
                }
            }
            
            var required: [String] = []
            if let reqValue = dict["required"],
               case let .array(reqArray) = reqValue {
                required = reqArray.compactMap { val in
                    if case let .string(str) = val {
                        return str
                    }
                    return nil
                }
            }
            
            return DynamicSchema(
                type: .object,
                properties: properties,
                required: required
            )
        }
        
        return DynamicSchema(type: .object, properties: [:])
    }
    
    private func convertPropertyToDynamic(_ value: Value) -> SchemaProperty {
        guard case let .object(dict) = value else {
            return SchemaProperty(type: .string)
        }
        
        var type: DynamicSchema.SchemaType = .string
        var description: String?
        
        if let typeValue = dict["type"],
           case let .string(typeStr) = typeValue {
            type = DynamicSchema.SchemaType(rawValue: typeStr) ?? .string
        }
        
        if let descValue = dict["description"],
           case let .string(descStr) = descValue {
            description = descStr
        }
        
        return SchemaProperty(
            type: type,
            description: description
        )
    }
    
    private func convertToAny(_ argument: AgentToolArgument) -> Any {
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
            return array.map { convertToAny($0) }
        case .object(let dict):
            return dict.mapValues { convertToAny($0) }
        case .null:
            return NSNull()
        }
    }
    
    private func convertResponseToArgument(_ response: ToolResponse) -> AgentToolArgument {
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
            return convertContentToArgument(response.content[0])
        } else if response.content.isEmpty {
            // No content
            return .null
        } else {
            // Multiple content items - return as array
            return .array(response.content.map { convertContentToArgument($0) })
        }
    }
    
    private func convertContentToArgument(_ content: MCP.Tool.Content) -> AgentToolArgument {
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