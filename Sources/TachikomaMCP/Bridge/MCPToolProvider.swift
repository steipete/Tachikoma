import Foundation
import Logging
import MCP
import Tachikoma

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
        // Connect to the MCP server (if not already connected)
        if await !(self.client.isConnected) {
            try await self.client.connect()
        }
    }

    /// Discover available tools from the MCP server
    public func discoverTools() async throws -> [DynamicTool] {
        // Ensure we're connected
        try await self.connect()

        // Get tools from MCP client
        let mcpTools = await client.tools

        self.logger.info("Discovered \(mcpTools.count) tools from MCP server")

        // Convert to DynamicTool format
        return mcpTools.map { mcpTool in
            DynamicTool(
                name: mcpTool.name,
                description: mcpTool.description ?? "",
                schema: self.convertSchemaToDynamic(mcpTool.inputSchema),
            )
        }
    }

    /// Execute a tool by name
    public func executeTool(
        name: String,
        arguments: AgentToolArguments,
    ) async throws
        -> AnyAgentToolValue
    {
        // Convert arguments to MCP format
        var mcpArgs: [String: Any] = [:]
        for key in arguments.keys {
            if let value = arguments[key] {
                mcpArgs[key] = try value.toJSON()
            }
        }

        // Execute via MCP client
        let response = try await client.executeTool(
            name: name,
            arguments: mcpArgs,
        )

        // Convert response back to AnyAgentToolValue
        return self.convertResponseToAnyAgentToolValue(response)
    }

    /// Get all available tools as AgentTools
    public func getAgentTools() async throws -> [AgentTool] {
        // Ensure we're connected
        try await self.connect()

        // Get tools from MCP client
        let mcpTools = await client.tools

        // Convert each tool using the adapter
        return mcpTools.map { mcpTool in
            MCPToolAdapter.toAgentTool(from: mcpTool, client: self.client)
        }
    }

    // MARK: - Private Helpers

    private func convertSchemaToDynamic(_ value: Value?) -> DynamicSchema {
        guard let value else {
            return DynamicSchema(type: .object, properties: [:])
        }

        // Parse the MCP schema into DynamicSchema
        if case let .object(dict) = value {
            var properties: [String: DynamicSchema.SchemaProperty] = [:]

            if
                let propsValue = dict["properties"],
                case let .object(propsDict) = propsValue
            {
                for (key, propValue) in propsDict {
                    properties[key] = self.convertPropertyToDynamic(propValue)
                }
            }

            var required: [String] = []
            if
                let reqValue = dict["required"],
                case let .array(reqArray) = reqValue
            {
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
                required: required,
            )
        }

        return DynamicSchema(type: .object, properties: [:])
    }

    private func convertPropertyToDynamic(_ value: Value) -> DynamicSchema.SchemaProperty {
        guard case let .object(dict) = value else {
            return DynamicSchema.SchemaProperty(type: .string)
        }

        var type: DynamicSchema.SchemaType = .string
        var description: String?

        if
            let typeValue = dict["type"],
            case let .string(typeStr) = typeValue
        {
            type = DynamicSchema.SchemaType(rawValue: typeStr) ?? .string
        }

        if
            let descValue = dict["description"],
            case let .string(descStr) = descValue
        {
            description = descStr
        }

        return DynamicSchema.SchemaProperty(
            type: type,
            description: description,
        )
    }

    private func convertResponseToAnyAgentToolValue(_ response: ToolResponse) -> AnyAgentToolValue {
        // If there's an error, return it as a string
        if response.isError {
            let errorMessage = response.content.compactMap { content -> String? in
                if case let .text(text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")

            return AnyAgentToolValue(string: "Error: \(errorMessage)")
        }

        // Convert content to appropriate format
        if response.content.count == 1 {
            // Single content item
            return self.convertContentToAnyAgentToolValue(response.content[0])
        } else if response.content.isEmpty {
            // No content
            return AnyAgentToolValue(null: ())
        } else {
            // Multiple content items - return as array
            return AnyAgentToolValue(array: response.content.map { self.convertContentToAnyAgentToolValue($0) })
        }
    }

    private func convertContentToAnyAgentToolValue(_ content: MCP.Tool.Content) -> AnyAgentToolValue {
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
