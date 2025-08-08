//
//  SSETransport.swift
//  TachikomaMCP
//

import Foundation
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

    func setTransport(_ t: HTTPClientTransport?) { transport = t }
    func getTransport() -> HTTPClientTransport? { transport }
    func setBaseURL(_ url: URL?) { baseURL = url }
    func setHeaders(_ h: [String: String]) { headers = h }
    func setEndpoint(_ url: URL?) { endpointURL = url }
    func getEndpoint() -> URL? { endpointURL }

    func getNextId() -> Int { defer { nextId += 1 }; return nextId }
    func addPending(_ id: Int, _ cont: CheckedContinuation<Data, Swift.Error>) { pendingRequests[id] = cont }
    func removePending(_ id: Int) -> CheckedContinuation<Data, Swift.Error>? { pendingRequests.removeValue(forKey: id) }
    func setTimeout(_ seconds: TimeInterval) { requestTimeoutNs = UInt64((seconds > 0 ? seconds : 30) * 1_000_000_000) }
    func addTimeoutTask(_ id: Int, _ task: Task<Void, Never>) { timeoutTasks[id] = task }
    func cancelTimeout(_ id: Int) { timeoutTasks.removeValue(forKey: id)?.cancel() }
    func cancelAll(_ error: Swift.Error) {
        for (_, c) in pendingRequests { c.resume(throwing: error) }
        pendingRequests.removeAll()
        for (_, t) in timeoutTasks { t.cancel() }
        timeoutTasks.removeAll()
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
        // Per AI SDK, the SSE GET uses Accept: text/event-stream only
        let transport = HTTPClientTransport(
            endpoint: url,
            headers: [
                "Accept": "text/event-stream"
            ],
            streaming: true,
            sseInitializationTimeout: min(max(config.timeout, 1), 60)
        )
        try await transport.connect()
        await state.setTransport(transport)
        await state.setBaseURL(url)
        await state.setHeaders(config.headers ?? [:])
        await state.setTimeout(config.timeout)
        startReading()
        logger.info("SSE transport connected: \(url)")
    }

    public func disconnect() async {
        logger.info("Disconnecting SSE transport")
        if let t = await state.getTransport() { await t.disconnect() }
        await state.cancelAll(MCPError.notConnected)
        await state.setTransport(nil)
    }

    // Expose underlying swift-sdk HTTP transport for advanced usage
    public func underlyingSDKTransport() async -> HTTPClientTransport? {
        await state.getTransport()
    }

    public func sendRequest<P: Encodable, R: Decodable>(
        method: String,
        params: P
    ) async throws -> R {
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

        // Ensure endpoint is available (wait briefly if needed)
        let start = Date()
        while await state.getEndpoint() == nil {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            if Date().timeIntervalSince(start) > 10 { // 10s safety
                logger.error("SSE endpoint not established before send; method=\(method)")
                throw MCPError.connectionFailed("SSE endpoint not established")
            }
        }

        // Register pending BEFORE POSTing
        let responseData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Swift.Error>) in
            Task { @MainActor in
                await state.addPending(id, continuation)
                // Schedule timeout
                let timeoutTask = Task { [logger] in
                    let ns = await state.requestTimeoutNs
                    try? await Task.sleep(nanoseconds: ns)
                    if let pending = await state.removePending(id) {
                        logger.error("MCP SSE request timed out: method=\(method), id=\(id)")
                        pending.resume(throwing: MCPError.executionFailed("Request timed out after \(ns / 1_000_000)ms"))
                    }
                }
                await state.addTimeoutTask(id, timeoutTask)
                // Fire-and-forget POST to endpoint; responses arrive via SSE 'message'
                Task { [logger] in
                    let endpoint = await state.getEndpoint()!
                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.httpBody = postBody
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    // Custom headers if any
                    let headers = await state.headers
                    for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
                    do {
                        let (_, resp) = try await urlSession.data(for: request)
                        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
                            logger.error("MCP SSE POST error: HTTP \(http.statusCode) for method=\(method), id=\(id)")
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

    public func sendNotification<P: Encodable>(
        method: String,
        params: P
    ) async throws {
        let note = JSONRPCNotification(jsonrpc: "2.0", method: method, params: params)
        let data = try JSONEncoder().encode(note)
        // Ensure endpoint
        guard let endpoint = await state.getEndpoint() else { throw MCPError.notConnected }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let headers = await state.headers
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        _ = try? await urlSession.data(for: request)
    }

    private func startReading() {
        Task {
            guard let transport = await state.getTransport() else { return }
            let stream = await transport.receive()
            var buffer = ""
            for try await data in stream {
                guard let chunk = String(data: data, encoding: .utf8) else {
                    logger.debug("[SSE] Received non-UTF8 data of size \(data.count)")
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
        logger.trace("[SSE] event=\(eventType) data=\(dataString)")
        switch eventType {
        case "endpoint":
            // Resolve endpoint relative to base URL
            if let base = await state.baseURL, let url = URL(string: dataString, relativeTo: base) {
                // Ensure same-origin
                if url.host == base.host && url.scheme == base.scheme {
                    await state.setEndpoint(url.absoluteURL)
                    logger.info("[SSE] Endpoint established: \(url.absoluteString)")
                } else {
                    logger.error("[SSE] Endpoint origin mismatch: \(url.absoluteString)")
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
                logger.trace("[SSE] Received non-JSON event: \(text)")
            }
            return
        }
        // id may be int or string; we track by int ids we generate
        if let id = json["id"] as? Int {
            if let pending = await state.removePending(id) {
                await state.cancelTimeout(id)
                pending.resume(returning: data)
            }
        } else if let idString = json["id"] as? String, let id = Int(idString) {
            if let pending = await state.removePending(id) {
                await state.cancelTimeout(id)
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
        if let i = try? c.decode(Int.self) { self = .int(i); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if c.decodeNil() { self = .null; return }
        throw DecodingError.typeMismatch(JSONRPCID.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported id type"))
    }
}

private struct JSONRPCError: Decodable { let code: Int; let message: String }