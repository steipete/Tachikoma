//
//  MCPTransport.swift
//  TachikomaMCP
//

import Foundation
import MCP

/// Protocol for MCP transport implementations
public protocol MCPTransport: Sendable {
    /// Connect to the MCP server
    func connect(config: MCPServerConfig) async throws
    
    /// Disconnect from the MCP server
    func disconnect() async
    
    /// Send a request and wait for response
    func sendRequest<P: Encodable, R: Decodable>(
        method: String,
        params: P
    ) async throws -> R
    
    /// Send a notification (no response expected)
    func sendNotification<P: Encodable>(
        method: String,
        params: P
    ) async throws
}

// Remove the extension as it causes issues with opaque return types