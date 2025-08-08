//
//  MCPClient.swift
//  TachikomaMCP
//

import Foundation
import MCP
import Logging

/// Configuration for an MCP server connection
public struct MCPServerConfig: Sendable, Codable {
    public var transport: String          // "stdio", "http", "sse"
    public var command: String            // executable path
    public var args: [String]             // command arguments
    public var env: [String: String]      // environment variables
    public var enabled: Bool              // enable/disable server
    public var timeout: TimeInterval      // connection timeout
    public var autoReconnect: Bool        // auto-reconnect on failure
    public var description: String?       // human-readable description
    
    public init(
        transport: String = "stdio",
        command: String,
        args: [String] = [],
        env: [String: String] = [:],
        enabled: Bool = true,
        timeout: TimeInterval = 30,
        autoReconnect: Bool = true,
        description: String? = nil
    ) {
        self.transport = transport
        self.command = command
        self.args = args
        self.env = env
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
        return transport
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
            version: "1.0.0"
        )
    }
    
    /// Connect to the MCP server
    public func connect() async throws {
        guard config.enabled else {
            throw MCPError.serverDisabled
        }
        
        logger.info("Connecting to MCP server '\(name)'")
        
        // Create appropriate transport based on config
        let transport: any MCPTransport
        switch config.transport.lowercased() {
        case "stdio":
            transport = StdioTransport()
        case "sse":
            transport = SSETransport()
        case "http":
            transport = HTTPTransport()
        default:
            throw MCPError.unsupportedTransport(config.transport)
        }
        
        await state.setTransport(transport)
        
        // Connect transport
        try await transport.connect(config: config)
        
        // Initialize MCP handshake
        let initResponse: InitializeResponse = try await transport.sendRequest(
            method: "initialize",
            params: InitializeParams(
                protocolVersion: "2024-11-05",
                clientInfo: ClientInfo(
                    name: "tachikoma-mcp-client",
                    version: "1.0.0"
                ),
                capabilities: ClientCapabilities()
            )
        )
        
        logger.debug("Initialized MCP connection: \(initResponse)")
        
        // Send initialized notification
        try await transport.sendNotification(
            method: "initialized",
            params: EmptyParams()
        )
        
        // Discover tools
        await discoverTools()
        
        await state.setConnected(true)
    }
    
    /// Disconnect from the MCP server
    public func disconnect() async {
        logger.info("Disconnecting from MCP server '\(name)'")
        if let transport = await state.getTransport() {
            await transport.disconnect()
        }
        await state.setConnected(false)
        await state.setTools([])
    }
    
    /// Check if the client is connected
    public var isConnected: Bool {
        get async {
            await state.isConnected
        }
    }
    
    /// Get available tools
    public var tools: [Tool] {
        get async {
            await state.tools
        }
    }
    
    /// Discover available tools from the server
    private func discoverTools() async {
        do {
            guard let transport = await state.getTransport() else {
                throw MCPError.notConnected
            }
            
            let response: ToolsListResponse = try await transport.sendRequest(
                method: "tools/list",
                params: EmptyParams()
            )
            
            await state.setTools(response.tools)
            logger.info("Discovered \(response.tools.count) tools from '\(name)'")
        } catch {
            logger.error("Failed to discover tools: \(error)")
        }
    }
    
    /// Execute a tool by name
    public func executeTool(name: String, arguments: [String: Any]) async throws -> ToolResponse {
        guard let transport = await state.getTransport() else {
            throw MCPError.notConnected
        }
        
        guard await isConnected else {
            throw MCPError.notConnected
        }
        
        // Convert arguments to MCP Value
        let args = ToolArguments(raw: arguments)
        
        // Send tool execution request
        let response: ToolCallResponse = try await transport.sendRequest(
            method: "tools/call",
            params: ToolCallParams(
                name: name,
                arguments: args.rawValue
            )
        )
        
        // Convert response to ToolResponse
        return ToolResponse(
            content: response.content,
            isError: response.isError ?? false
        )
    }
}

// MARK: - MCP Protocol Types

struct InitializeParams: Codable {
    let protocolVersion: String
    let clientInfo: ClientInfo
    let capabilities: ClientCapabilities
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
            return "MCP server is disabled"
        case .unsupportedTransport(let transport):
            return "Unsupported transport: \(transport)"
        case .notConnected:
            return "MCP client is not connected"
        case .invalidResponse:
            return "Invalid response from MCP server"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        }
    }
}