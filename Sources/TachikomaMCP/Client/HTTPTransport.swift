import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

// Actor to manage mutable state for Sendable conformance
private actor HTTPTransportState {
    var urlSession: URLSession?
    var baseURL: URL?
    var requestTimeout: TimeInterval = 30
    var headers: [String: String] = [:]

    func setConnection(session: URLSession?, url: URL?, timeout: TimeInterval, headers: [String: String]) {
        self.urlSession = session
        self.baseURL = url
        self.requestTimeout = timeout
        self.headers = headers
    }

    func getSession() -> URLSession? { self.urlSession }
    func getBaseURL() -> URL? { self.baseURL }
    func getTimeout() -> TimeInterval { self.requestTimeout }
    func getHeaders() -> [String: String] { self.headers }
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
        await state.setConnection(session: session, url: url, timeout: config.timeout, headers: config.headers ?? [:])

        self.logger.info("HTTP transport ready (with SSE support): \(url)")
    }

    public func disconnect() async {
        self.logger.info("Disconnecting HTTP transport")
        let currentTimeout = await state.getTimeout()
        let currentHeaders = await state.getHeaders()
        await self.state.setConnection(session: nil, url: nil, timeout: currentTimeout, headers: currentHeaders)
    }

    public func sendRequest<R: Decodable>(
        method: String,
        params: some Encodable,
    ) async throws
        -> R
    {
        guard
            let baseURL = await state.getBaseURL(),
            let urlSession = await state.getSession() else
        {
            throw MCPError.notConnected
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Context7 requires both application/json and text/event-stream in Accept header
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")

        // Add any custom headers from config
        let headers = await state.getHeaders()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // JSON-RPC 2.0 over HTTP
        let id = Int.random(in: 1...Int(Int32.max))
        let body = HTTPJSONRPCRequest(method: method, params: params, id: id)
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            self.logger.error("HTTP request failed for \(method): \(error)")
            throw MCPError.executionFailed("HTTP request failed: \(error)")
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.executionFailed("Invalid HTTP response")
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let bodyStr = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            self.logger.error("HTTP \(httpResponse.statusCode) for \(method): \(bodyStr)")
            throw MCPError.executionFailed("HTTP \(httpResponse.statusCode): \(bodyStr)")
        }

        // Check if response is SSE format (Context7 returns text/event-stream)
        if
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
            contentType.contains("text/event-stream")
        {
            // Parse SSE format: "event: message\ndata: {json}\n\n"
            guard let responseStr = String(data: data, encoding: .utf8) else {
                throw MCPError.invalidResponse
            }

            // Extract JSON from SSE data field
            var jsonData: Data?
            for line in responseStr.split(separator: "\n") {
                if line.hasPrefix("data:") {
                    let dataStr = String(line.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces)
                    jsonData = Data(dataStr.utf8)
                    break
                }
            }

            guard let jsonData else {
                self.logger.error("No JSON data found in SSE response: \(responseStr)")
                throw MCPError.invalidResponse
            }

            let decoded = try JSONDecoder().decode(HTTPJSONRPCResponse<R>.self, from: jsonData)
            if let err = decoded.error { throw MCPError.executionFailed(err.message) }
            guard let result = decoded.result else { throw MCPError.invalidResponse }
            return result
        } else {
            // Standard JSON response
            let decoded = try JSONDecoder().decode(HTTPJSONRPCResponse<R>.self, from: data)
            if let err = decoded.error { throw MCPError.executionFailed(err.message) }
            guard let result = decoded.result else { throw MCPError.invalidResponse }
            return result
        }
    }

    public func sendNotification(
        method: String,
        params: some Encodable,
    ) async throws {
        // Reuse request path; ignore result
        let _: EmptyResponse = try await sendRequest(method: method, params: params)
    }
}

private struct EmptyResponse: Decodable {}
