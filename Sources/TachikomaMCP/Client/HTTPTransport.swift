//
//  HTTPTransport.swift
//  TachikomaMCP
//

import Foundation
import Logging

// Actor to manage mutable state for Sendable conformance
private actor HTTPTransportState {
    var urlSession: URLSession?
    var baseURL: URL?
    
    func setConnection(session: URLSession?, url: URL?) {
        self.urlSession = session
        self.baseURL = url
    }
    
    func getSession() -> URLSession? {
        return urlSession
    }
    
    func getBaseURL() -> URL? {
        return baseURL
    }
}

/// HTTP transport for MCP communication
public final class HTTPTransport: MCPTransport {
    private let logger = Logger(label: "tachikoma.mcp.http")
    private let state = HTTPTransportState()
    
    public init() {}
    
    public func connect(config: MCPServerConfig) async throws {
        guard let url = URL(string: config.command) else {
            throw MCPError.connectionFailed("Invalid URL: \(config.command)")
        }
        
        let session = URLSession(configuration: .default)
        await state.setConnection(session: session, url: url)
        
        logger.info("HTTP transport connecting to: \(url)")
        
        // HTTP doesn't require a persistent connection
        // Just validate the endpoint is reachable
        // TODO: Implement health check
    }
    
    public func disconnect() async {
        logger.info("Disconnecting HTTP transport")
        await state.setConnection(session: nil, url: nil)
    }
    
    public func sendRequest<P: Encodable, R: Decodable>(
        method: String,
        params: P
    ) async throws -> R {
        guard let baseURL = await state.getBaseURL(),
              let urlSession = await state.getSession() else {
            throw MCPError.notConnected
        }
        
        // Build request URL
        let requestURL = baseURL.appendingPathComponent(method)
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode params
        request.httpBody = try JSONEncoder().encode(params)
        
        // Send request
        let (data, response) = try await urlSession.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MCPError.executionFailed("HTTP request failed")
        }
        
        // Decode response
        return try JSONDecoder().decode(R.self, from: data)
    }
    
    public func sendNotification<P: Encodable>(
        method: String,
        params: P
    ) async throws {
        // For HTTP, notifications are just fire-and-forget requests
        _ = try await sendRequest(method: method, params: params) as EmptyResponse
    }
}

private struct EmptyResponse: Decodable {}