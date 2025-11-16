import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging
import MCP

// Internal state for SSE transport
private actor SSEState {
    var transport: HTTPClientTransport?
    var baseURL: URL?
    var endpointURL: URL?
    var headers: [String: String] = [:]
    var nextId: Int = 1
    var pendingRequests: [Int: CheckedContinuation<Data, Swift.Error>] = [:]
    var timeoutTasks: [Int: Task<Void, Never>] = [:]
    var requestTimeoutNs: UInt64 = 30_000_000_000 // default 30s

    func setTransport(_ t: HTTPClientTransport?) { self.transport = t }
    func getTransport() -> HTTPClientTransport? { self.transport }
    func setBaseURL(_ url: URL?) { self.baseURL = url }
    func setHeaders(_ h: [String: String]) { self.headers = h }
    func setEndpoint(_ url: URL?) { self.endpointURL = url }
    func getEndpoint() -> URL? { self.endpointURL }
    func getBaseURL() -> URL? { self.baseURL }

    func getNextId() -> Int { defer { nextId += 1 }
        return self.nextId
    }

    func addPending(_ id: Int, _ cont: CheckedContinuation<Data, Swift.Error>) { self.pendingRequests[id] = cont }
    func removePending(_ id: Int) -> CheckedContinuation<Data, Swift.Error>? { self.pendingRequests
        .removeValue(forKey: id)
    }

    func setTimeout(_ seconds: TimeInterval) {
        self.requestTimeoutNs = UInt64((seconds > 0 ? seconds : 30) * 1_000_000_000)
    }

    func addTimeoutTask(_ id: Int, _ task: Task<Void, Never>) { self.timeoutTasks[id] = task }
    func cancelTimeout(_ id: Int) { self.timeoutTasks.removeValue(forKey: id)?.cancel() }
    func cancelAll(_ error: Swift.Error) {
        for (_, c) in self.pendingRequests {
            c.resume(throwing: error)
        }
        self.pendingRequests.removeAll()
        for (_, t) in self.timeoutTasks {
            t.cancel()
        }
        self.timeoutTasks.removeAll()
    }
}

/// SSE (HTTP streaming) transport using swift-sdk HTTPClientTransport
public final class SSETransport: MCPTransport {
    private let logger = Logger(label: "tachikoma.mcp.sse")
    private let state = SSEState()
    private let urlSession = URLSession(configuration: .ephemeral)

    public init() {}

    public func connect(config: MCPServerConfig) async throws {
        guard let url = URL(string: config.command) else {
            throw MCPError.connectionFailed("Invalid URL: \(config.command)")
        }
        // Per AI SDK, the SSE GET uses Accept: text/event-stream. Also forward any custom headers (e.g., Authorization)
        var getHeaders = [
            "Accept": "text/event-stream",
        ]
        if let custom = config.headers {
            for (k, v) in custom {
                getHeaders[k] = v
            }
        }
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.httpAdditionalHeaders = getHeaders
        let transport = HTTPClientTransport(
            endpoint: url,
            configuration: sessionConfiguration,
            streaming: true,
            sseInitializationTimeout: min(max(config.timeout, 1), 60),
        )
        try await transport.connect()
        await self.state.setTransport(transport)
        await self.state.setBaseURL(url)
        await self.state.setHeaders(config.headers ?? [:])
        // Set the base URL as the default endpoint (can be overridden by 'endpoint' event)
        await self.state.setEndpoint(url)
        await self.state.setTimeout(config.timeout)
        let verifyEndpoint = await state.getEndpoint()
        self.logger.info("SSE transport connected: \(url), endpoint set to: \(verifyEndpoint?.absoluteString ?? "nil")")
        self.startReading()
    }

    public func disconnect() async {
        self.logger.info("Disconnecting SSE transport")
        if let t = await state.getTransport() { await t.disconnect() }
        await self.state.cancelAll(MCPError.notConnected)
        await self.state.setTransport(nil)
    }

    // Expose underlying swift-sdk HTTP transport for advanced usage
    public func underlyingSDKTransport() async -> HTTPClientTransport? {
        await self.state.getTransport()
    }

    public func sendRequest<R: Decodable>(
        method: String,
        params: some Encodable,
    ) async throws
        -> R
    {
        let id = await state.getNextId()
        // Build JSON-RPC request
        var dict: [String: Any] = [:]
        dict["jsonrpc"] = "2.0"
        dict["method"] = method
        let paramsData = try JSONEncoder().encode(params)
        let paramsObj = try JSONSerialization.jsonObject(with: paramsData)
        dict["params"] = paramsObj
        dict["id"] = id
        let postBody = try JSONSerialization.data(withJSONObject: dict)

        // Ensure endpoint is available - either from 'endpoint' event or base URL
        guard let endpoint = await state.getEndpoint() else {
            let baseURL = await state.getBaseURL()
            self.logger
                .error(
                    "SSE endpoint not established before send; method=\(method), baseURL=\(baseURL?.absoluteString ?? "nil")",
                )
            throw MCPError.connectionFailed("SSE endpoint not established")
        }
        self.logger.debug("Using endpoint: \(endpoint.absoluteString) for method=\(method)")

        // Register pending BEFORE POSTing
        let responseData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
            Data,
            Swift.Error,
        >) in
            Task {
                await self.state.addPending(id, continuation)
                // Schedule timeout
                let timeoutTask = Task { [logger] in
                    let ns = await state.requestTimeoutNs
                    try? await Task.sleep(nanoseconds: ns)
                    if let pending = await state.removePending(id) {
                        logger.error("MCP SSE request timed out: method=\(method), id=\(id)")
                        pending
                            .resume(throwing: MCPError.executionFailed("Request timed out after \(ns / 1_000_000)ms"))
                    }
                }
                await state.addTimeoutTask(id, timeoutTask)
                // Fire-and-forget POST to endpoint; responses arrive via SSE 'message'
                Task { [logger, endpoint] in
                    logger.info("[SSE] POSTing to endpoint: \(endpoint.absoluteString) method=\(method) id=\(id)")
                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.httpBody = postBody
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    // Context7 requires both application/json and text/event-stream in Accept header
                    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
                    // Custom headers if any
                    let headers = await state.headers
                    for (k, v) in headers {
                        request.setValue(v, forHTTPHeaderField: k)
                    }
                    do {
                        let (respData, resp) = try await urlSession.data(for: request)
                        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
                            let body = String(data: respData, encoding: .utf8) ?? "<non-utf8>"
                            logger
                                .error(
                                    "MCP SSE POST error: HTTP \(http.statusCode) for method=\(method), id=\(id) body=\(body)",
                                )
                        } else {
                            logger.debug("MCP SSE POST sent: method=\(method), id=\(id)")
                        }
                    } catch {
                        logger.error("MCP SSE POST failed: \(String(describing: error))")
                        // Do not fail continuation here; server might still deliver via SSE
                    }
                }
            }
        }

        // Decode JSON-RPC response when SSE delivers it
        let response = try JSONDecoder().decode(JSONRPCResponse<R>.self, from: responseData)
        if let error = response.error { throw MCPError.executionFailed(error.message) }
        guard let result = response.result else { throw MCPError.invalidResponse }
        return result
    }

    public func sendNotification(
        method: String,
        params: some Encodable,
    ) async throws {
        let note = JSONRPCNotification(jsonrpc: "2.0", method: method, params: params)
        let data = try JSONEncoder().encode(note)
        // Ensure endpoint
        guard let endpoint = await state.getEndpoint() else { throw MCPError.notConnected }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        let headers = await state.headers
        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        _ = try? await self.urlSession.data(for: request)
    }

    private func startReading() {
        Task {
            guard let transport = await state.getTransport() else { return }
            self.logger.debug("[SSE] Starting to read from transport stream")
            let stream = await transport.receive()
            var buffer = ""
            for try await data in stream {
                guard let chunk = String(data: data, encoding: .utf8) else {
                    self.logger.debug("[SSE] Received non-UTF8 data of size \(data.count)")
                    continue
                }
                buffer += chunk
                // Process complete SSE events separated by double newlines
                while let range = buffer.range(of: "\n\n") {
                    let eventBlock = String(buffer[..<range.lowerBound])
                    buffer = String(buffer[range.upperBound...])
                    await self.processEventBlock(eventBlock)
                }
            }
        }
    }

    private func processEventBlock(_ block: String) async {
        // Parse SSE block: lines like 'event: type' and 'data: payload'
        var eventType = "message" // default per SSE
        var dataLines: [String] = []
        for line in block.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("event:") {
                let v = line.dropFirst("event:".count)
                eventType = v.trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                let v = line.dropFirst("data:".count)
                dataLines.append(v.trimmingCharacters(in: .whitespaces))
            }
        }
        let dataString = dataLines.joined(separator: "\n")
        self.logger.trace("[SSE] event=\(eventType) data=\(dataString)")
        switch eventType {
        case "endpoint":
            // Allow either a plain string URL or a JSON object: { "url": "/rpc" } or { "endpoint": "/rpc" }
            if let base = await state.baseURL {
                var endpointCandidate: String? = dataString
                if dataString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
                    if
                        let jsonData = dataString.data(using: .utf8),
                        let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                    {
                        if let urlValue = obj["url"] as? String {
                            endpointCandidate = urlValue
                        } else if let endpoint = obj["endpoint"] as? String {
                            endpointCandidate = endpoint
                        }
                    }
                }
                if let candidate = endpointCandidate, let url = URL(string: candidate, relativeTo: base) {
                    if url.host == base.host, url.scheme == base.scheme {
                        await self.state.setEndpoint(url.absoluteURL)
                        self.logger.info("[SSE] Endpoint established: \(url.absoluteString)")
                    } else {
                        self.logger.error("[SSE] Endpoint origin mismatch: \(url.absoluteString)")
                    }
                }
            }
        case "message":
            if let jsonData = dataString.data(using: .utf8) {
                await self.handleIncoming(jsonData)
            }
        default:
            // Ignore other events
            break
        }
    }

    private func handleIncoming(_ data: Data) async {
        // Try to parse as JSON object with id
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if let text = String(data: data, encoding: .utf8) {
                self.logger.trace("[SSE] Received non-JSON event: \(text)")
            }
            return
        }
        // id may be int or string; we track by int ids we generate
        if let id = json["id"] as? Int {
            if let pending = await state.removePending(id) {
                await self.state.cancelTimeout(id)
                pending.resume(returning: data)
            }
        } else if let idString = json["id"] as? String, let id = Int(idString) {
            if let pending = await state.removePending(id) {
                await self.state.cancelTimeout(id)
                pending.resume(returning: data)
            }
        }
    }
}

// MARK: - JSON-RPC Types (local)

private struct JSONRPCRequest<P: Encodable>: Encodable {
    let jsonrpc: String
    let method: String
    let params: P
    let id: Int
}

private struct JSONRPCNotification<P: Encodable>: Encodable {
    let jsonrpc: String
    let method: String
    let params: P
}

private struct JSONRPCResponse<R: Decodable>: Decodable {
    let jsonrpc: String
    let result: R?
    let error: JSONRPCError?
    let id: JSONRPCID?
}

private enum JSONRPCID: Decodable { case int(Int), string(String), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { self = .int(i)
            return
        }
        if let s = try? c.decode(String.self) { self = .string(s)
            return
        }
        if c.decodeNil() { self = .null
            return
        }
        throw DecodingError.typeMismatch(
            JSONRPCID.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported id type"),
        )
    }
}

private struct JSONRPCError: Decodable { let code: Int
    let message: String
}
