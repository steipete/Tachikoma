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

        return Self.makeDynamicTools(from: mcpTools)
    }

    static func makeDynamicTools(from mcpTools: [Tool]) -> [DynamicTool] {
        mcpTools.map { mcpTool in
            DynamicTool(
                name: mcpTool.name,
                description: mcpTool.description ?? "",
                schema: MCPToolSchemaBridge.dynamicSchema(from: mcpTool.inputSchema),
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
        // Execute via MCP client
        let response = try await client.executeTool(
            name: name,
            arguments: arguments,
        )

        return try response.toAgentToolExecutionValue()
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
}
