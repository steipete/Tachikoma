import Foundation
import Logging
import MCP

// Shared JSON-RPC types for HTTP transport
struct HTTPJSONRPCRequest<P: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let method: String
    let params: P
    let id: Int
}

struct HTTPJSONRPCResponse<R: Decodable>: Decodable {
    let jsonrpc: String
    let result: R?
    let error: HTTPJSONRPCError?
    let id: Int?
}

struct HTTPJSONRPCError: Decodable { let code: Int
    let message: String
}

/// Configuration for an MCP server connection
public struct MCPServerConfig: Sendable, Codable {
    public var transport: String // "stdio", "http", "sse"
    public var command: String // executable path or URL for HTTP/SSE
    public var args: [String] // command arguments (stdio) or unused
    public var env: [String: String] // environment variables
    public var headers: [String: String]? // optional HTTP headers (HTTP/SSE)
    public var enabled: Bool // enable/disable server
    public var timeout: TimeInterval // connection timeout
    public var autoReconnect: Bool // auto-reconnect on failure
    public var description: String? // human-readable description

    public init(
        transport: String = "stdio",
        command: String,
        args: [String] = [],
        env: [String: String] = [:],
        headers: [String: String]? = nil,
        enabled: Bool = true,
        timeout: TimeInterval = 30,
        autoReconnect: Bool = true,
        description: String? = nil,
    ) {
        self.transport = transport
        self.command = command
        self.args = args
        self.env = env
        self.headers = headers
        self.enabled = enabled
        self.timeout = timeout
        self.autoReconnect = autoReconnect
        self.description = description
    }
}

// Actor to manage mutable state for Sendable conformance
private actor MCPClientState {
    var transport: (any MCPTransport)?
    var tools: [Tool] = []
    var isConnected: Bool = false

    func setTransport(_ transport: (any MCPTransport)?) {
        self.transport = transport
    }

    func getTransport() -> (any MCPTransport)? {
        self.transport
    }

    func setConnected(_ connected: Bool) {
        self.isConnected = connected
    }

    func setTools(_ tools: [Tool]) {
        self.tools = tools
    }
}

/// Main MCP client for connecting to MCP servers
public final class MCPClient: Sendable {
    private let config: MCPServerConfig
    private let logger: Logger
    private let client: Client
    private let state = MCPClientState()
    private let name: String

    public init(name: String, config: MCPServerConfig) {
        self.name = name
        self.config = config
        self.logger = Logger(label: "tachikoma.mcp.client.\(name)")
        self.client = Client(
            name: "tachikoma-mcp-client",
            version: "1.0.0",
        )
    }

    /// Connect to the MCP server
    public func connect() async throws {
        // Connect to the MCP server
        guard self.config.enabled else {
            throw MCPError.serverDisabled
        }

        self.logger.info("Connecting to MCP server '\(self.name)'")

        // Create appropriate transport based on config
        let transport: any MCPTransport
        switch self.config.transport.lowercased() {
        case "stdio":
            transport = StdioTransport()
        case "sse":
            transport = SSETransport()
        case "http":
            transport = HTTPTransport()
        default:
            throw MCPError.unsupportedTransport(self.config.transport)
        }

        await self.state.setTransport(transport)

        // Connect transport
        try await transport.connect(config: self.config)

        // Initialize MCP handshake
        let initParams = InitializeParams(
            protocolVersion: "2025-03-26",
            clientInfo: ClientInfo(name: "tachikoma-mcp-client", version: "1.0.0"),
            capabilities: ClientCapabilities(),
        )
        let initResponse: InitializeResponse
        do {
            initResponse = try await transport.sendRequest(method: "initialize", params: initParams)
        } catch {
            // Fallback 1: Older protocol version
            let oldParams = InitializeParams(
                protocolVersion: "2024-11-05",
                clientInfo: initParams.clientInfo,
                capabilities: initParams.capabilities,
            )
            do {
                initResponse = try await transport.sendRequest(method: "initialize", params: oldParams)
            } catch {
                // Fallback 2: snake_case protocol_version with older version
                let snake = InitializeParamsSnake(
                    protocolVersion: oldParams.protocolVersion,
                    clientInfo: initParams.clientInfo,
                    capabilities: initParams.capabilities,
                )
                initResponse = try await transport.sendRequest(method: "initialize", params: snake)
            }
        }

        self.logger.debug("Initialized MCP connection: \(initResponse)")

        // Send initialized notification (per spec name)
        // Some servers (like Context7) may not support this notification
        do {
            try await transport.sendNotification(method: "notifications/initialized", params: EmptyParams())
        } catch {
            self.logger.debug("Server may not support notifications/initialized: \(error)")
        }

        // Discover tools
        await self.discoverTools()

        await self.state.setConnected(true)
    }

    /// Disconnect from the MCP server
    public func disconnect() async {
        // Disconnect from the MCP server
        self.logger.info("Disconnecting from MCP server '\(self.name)'")
        if let transport = await state.getTransport() {
            await transport.disconnect()
        }
        await self.state.setConnected(false)
        await self.state.setTools([])
    }

    /// Check if the client is connected
    public var isConnected: Bool {
        get async {
            await self.state.isConnected
        }
    }

    /// Get available tools
    public var tools: [Tool] {
        get async {
            await self.state.tools
        }
    }

    /// Discover available tools from the server
    private func discoverTools() async {
        // Discover available tools from the server
        do {
            guard let transport = await state.getTransport() else {
                throw MCPError.notConnected
            }

            let response: ToolsListResponse = try await transport.sendRequest(
                method: "tools/list",
                params: EmptyParams(),
            )

            await self.state.setTools(response.tools)
            self.logger.info("Discovered \(response.tools.count) tools from '\(self.name)'")
        } catch {
            self.logger.error("Failed to discover tools: \(error)")
        }
    }

    /// Execute a tool by name
    public func executeTool(name: String, arguments: [String: Any]) async throws -> ToolResponse {
        // Execute a tool by name
        guard let transport = await state.getTransport() else {
            throw MCPError.notConnected
        }

        guard await self.isConnected else {
            throw MCPError.notConnected
        }

        // Convert arguments to MCP Value
        let args = ToolArguments(raw: arguments)

        // Send tool execution request
        let response: ToolCallResponse = try await transport.sendRequest(
            method: "tools/call",
            params: ToolCallParams(
                name: name,
                arguments: args.rawValue,
            ),
        )

        // Convert response to ToolResponse
        return ToolResponse(
            content: response.content,
            isError: response.isError ?? false,
        )
    }
}

// MARK: - MCP Protocol Types

struct InitializeParams: Codable {
    let protocolVersion: String
    let clientInfo: ClientInfo
    let capabilities: ClientCapabilities
    enum CodingKeys: String, CodingKey {
        case protocolVersion
        case clientInfo
        case capabilities
    }
}

// Some servers use snake_case for protocol_version in initialize
struct InitializeParamsSnake: Codable {
    let protocolVersion: String
    let clientInfo: ClientInfo
    let capabilities: ClientCapabilities
    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case clientInfo
        case capabilities
    }
}

struct InitializeResponse: Decodable {
    let serverInfo: ServerInfo?
    let capabilities: ServerCapabilities?

    struct ServerInfo: Decodable {
        let name: String
        let version: String?
    }

    struct ServerCapabilities: Decodable {
        // Simplified for now - can be expanded as needed
    }
}

struct ClientInfo: Codable {
    let name: String
    let version: String
}

struct ClientCapabilities: Codable {
    // Add capabilities as needed
}

struct EmptyParams: Codable {}
struct InitializedParams: Codable { let clientInfo: ClientInfo }

struct ToolsListResponse: Codable {
    let tools: [Tool]
}

struct ToolCallParams: Codable {
    let name: String
    let arguments: Value
}

struct ToolCallResponse: Codable {
    let content: [MCP.Tool.Content]
    let isError: Bool?
}

// MARK: - Errors

public enum MCPError: LocalizedError {
    case serverDisabled
    case unsupportedTransport(String)
    case notConnected
    case invalidResponse
    case connectionFailed(String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .serverDisabled:
            "MCP server is disabled"
        case let .unsupportedTransport(transport):
            "Unsupported transport: \(transport)"
        case .notConnected:
            "MCP client is not connected"
        case .invalidResponse:
            "Invalid response from MCP server"
        case let .connectionFailed(reason):
            "Connection failed: \(reason)"
        case let .executionFailed(reason):
            "Execution failed: \(reason)"
        }
    }
}
