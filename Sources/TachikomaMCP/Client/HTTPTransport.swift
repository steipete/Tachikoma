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
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // JSON-RPC 2.0 over HTTP
        struct JSONRPCRequest<P: Encodable>: Encodable {
            let jsonrpc = "2.0"
            let method: String
            let params: P
            let id: Int
        }
        let id = Int.random(in: 1...Int(Int32.max))
        let body = JSONRPCRequest(method: method, params: params, id: id)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MCPError.executionFailed("HTTP request failed")
        }
        
        struct JSONRPCResponse<R: Decodable>: Decodable {
            let jsonrpc: String
            let result: R?
            let error: JSONRPCError?
            let id: Int?
        }
        struct JSONRPCError: Decodable { let code: Int; let message: String }
        let decoded = try JSONDecoder().decode(JSONRPCResponse<R>.self, from: data)
        if let err = decoded.error { throw MCPError.executionFailed(err.message) }
        guard let result = decoded.result else { throw MCPError.invalidResponse }
        return result
    }
    
    public func sendNotification<P: Encodable>(
        method: String,
        params: P
    ) async throws {
        // Use same path with an id we ignore
        struct JSONRPCNotification<P: Encodable>: Encodable {
            let jsonrpc = "2.0"
            let method: String
            let params: P
        }
        guard let baseURL = await state.getBaseURL(),
              let urlSession = await state.getSession() else {
            throw MCPError.notConnected
        }
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(JSONRPCNotification(method: method, params: params))
        _ = try await urlSession.data(for: request)
    }
}

private struct EmptyResponse: Decodable {}