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
    var requestTimeout: TimeInterval = 30
    
    func setConnection(session: URLSession?, url: URL?, timeout: TimeInterval) {
        self.urlSession = session
        self.baseURL = url
        self.requestTimeout = timeout
    }
    
    func getSession() -> URLSession? { urlSession }
    func getBaseURL() -> URL? { baseURL }
    func getTimeout() -> TimeInterval { requestTimeout }
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
        
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = max(1, config.timeout)
        cfg.timeoutIntervalForResource = max(1, config.timeout)
        let session = URLSession(configuration: cfg)
        await state.setConnection(session: session, url: url, timeout: config.timeout)
        
        logger.info("HTTP transport ready: \(url)")
    }
    
    public func disconnect() async {
        logger.info("Disconnecting HTTP transport")
        let currentTimeout = await state.getTimeout()
        await state.setConnection(session: nil, url: nil, timeout: currentTimeout)
    }
    
    public func sendRequest<P: Encodable, R: Decodable>(
        method: String,
        params: P
    ) async throws -> R {
        guard let baseURL = await state.getBaseURL(),
              let urlSession = await state.getSession() else {
            throw MCPError.notConnected
        }
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // JSON-RPC 2.0 over HTTP
        let id = Int.random(in: 1...Int(Int32.max))
        let body = HTTPJSONRPCRequest(method: method, params: params, id: id)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MCPError.executionFailed("HTTP request failed")
        }
        
        let decoded = try JSONDecoder().decode(HTTPJSONRPCResponse<R>.self, from: data)
        if let err = decoded.error { throw MCPError.executionFailed(err.message) }
        guard let result = decoded.result else { throw MCPError.invalidResponse }
        return result
    }
    
    public func sendNotification<P: Encodable>(
        method: String,
        params: P
    ) async throws {
        // Reuse request path; ignore result
        let _: EmptyResponse = try await sendRequest(method: method, params: params)
    }
}

private struct EmptyResponse: Decodable {}