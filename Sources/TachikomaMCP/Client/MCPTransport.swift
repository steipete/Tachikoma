import Foundation
import MCP

/// Protocol for MCP transport implementations
public protocol MCPTransport: Sendable {
    /// Connect to the MCP server
    func connect(config: MCPServerConfig) async throws

    /// Disconnect from the MCP server
    func disconnect() async

    /// Send a request and wait for response
    func sendRequest<R: Decodable>(
        method: String,
        params: some Encodable,
    ) async throws
        -> R

    /// Send a notification (no response expected)
    func sendNotification(
        method: String,
        params: some Encodable,
    ) async throws
}

// Remove the extension as it causes issues with opaque return types
