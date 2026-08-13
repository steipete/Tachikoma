import Foundation
import MCP
import Tachikoma

/// Adapter to convert MCP tools to Tachikoma's AgentTool format
public enum MCPToolAdapter {
    /// Convert an MCP Tool to Tachikoma's AgentTool
    public static func toAgentTool(from mcpTool: Tool, client: MCPClient) -> AgentTool {
        let parameters = MCPToolSchemaBridge.dynamicSchema(from: mcpTool.inputSchema).toAgentToolParameters()

        return AgentTool(
            name: mcpTool.name,
            description: mcpTool.description ?? "",
            parameters: parameters,
        ) { arguments in
            // Execute the tool via MCP client
            let response = try await client.executeTool(
                name: mcpTool.name,
                arguments: arguments,
            )

            return try response.toAgentToolExecutionValue()
        }
    }
}
