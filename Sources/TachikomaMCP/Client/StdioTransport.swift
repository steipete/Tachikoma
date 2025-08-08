//
//  StdioTransport.swift
//  TachikomaMCP
//

import Foundation
import MCP
import Logging

// Actor to manage mutable state for Sendable conformance
private actor StdioTransportState {
    var process: Process?
    var inputPipe: Pipe?
    var outputPipe: Pipe?
    var nextId: Int = 1
    var pendingRequests: [String: CheckedContinuation<Data, Swift.Error>] = [:]
    var timeoutTasks: [Int: Task<Void, Never>] = [:]
    var requestTimeoutNs: UInt64 = 30_000_000_000 // default 30s
    
    func setProcess(_ process: Process?, input: Pipe?, output: Pipe?) {
        self.process = process
        self.inputPipe = input
        self.outputPipe = output
    }
    
    func getNextId() -> Int {
        let id = nextId
        nextId += 1
        return id
    }
    
    func addPendingRequest(id: Int, continuation: CheckedContinuation<Data, Swift.Error>) {
        pendingRequests[String(id)] = continuation
    }
    
    func removePendingRequest(id: Int) -> CheckedContinuation<Data, Swift.Error>? {
        return pendingRequests.removeValue(forKey: String(id))
    }
    
    func removePendingRequestByStringId(_ id: String) -> CheckedContinuation<Data, Swift.Error>? {
        return pendingRequests.removeValue(forKey: id)
    }
    
    func setRequestTimeout(seconds: TimeInterval) {
        let ns = seconds > 0 ? seconds * 1_000_000_000 : 30_000_000_000
        requestTimeoutNs = UInt64(ns)
    }
    
    func addTimeoutTask(id: Int, task: Task<Void, Never>) {
        timeoutTasks[id] = task
    }
    
    func cancelTimeoutTask(id: Int) {
        if let task = timeoutTasks.removeValue(forKey: id) {
            task.cancel()
        }
    }
    
    func cancelAllRequests() {
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: MCPError.notConnected)
        }
        pendingRequests.removeAll()
    }
    
    func getInputPipe() -> Pipe? {
        return inputPipe
    }
    
    func getOutputPipe() -> Pipe? {
        return outputPipe
    }
}

/// Standard I/O transport for MCP communication
public final class StdioTransport: MCPTransport {
    private let state = StdioTransportState()
    private let logger = Logger(label: "tachikoma.mcp.stdio")
    
    public init() {}
    
    public func connect(config: MCPServerConfig) async throws {
        logger.info("Starting stdio transport with command: \(config.command)")
        
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.standardError
        
        // Parse command and arguments
        let components = config.command.split(separator: " ").map(String.init)
        guard !components.isEmpty else {
            throw MCPError.executionFailed("Invalid command")
        }
        
        // Set executable path
        if components[0].starts(with: "/") {
            process.executableURL = URL(fileURLWithPath: components[0])
            process.arguments = config.args.isEmpty ? Array(components.dropFirst()) : config.args
        } else {
            // Use which to find the executable
            let whichProcess = Process()
            let whichPipe = Pipe()
            whichProcess.standardOutput = whichPipe
            whichProcess.standardError = FileHandle.nullDevice
            whichProcess.launchPath = "/usr/bin/which"
            whichProcess.arguments = [components[0]]
            
            do {
                try whichProcess.run()
                whichProcess.waitUntilExit()
                
                if whichProcess.terminationStatus == 0 {
                    let data = whichPipe.fileHandleForReading.readDataToEndOfFile()
                    if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !path.isEmpty {
                        process.executableURL = URL(fileURLWithPath: path)
                        process.arguments = config.args.isEmpty ? Array(components.dropFirst()) : config.args
                    } else {
                        throw MCPError.connectionFailed("Command not found: \(components[0])")
                    }
                } else {
                    throw MCPError.connectionFailed("Command not found: \(components[0])")
                }
            } catch {
                throw MCPError.connectionFailed("Failed to locate command: \(components[0])")
            }
        }
        
        // Set environment - always inherit current environment and merge custom vars
        process.environment = ProcessInfo.processInfo.environment.merging(config.env) { _, new in new }
        
        // Start process
        do {
            try process.run()
        } catch {
            throw MCPError.connectionFailed("Failed to start process: \(error)")
        }
        
        await state.setProcess(process, input: inputPipe, output: outputPipe)
        await state.setRequestTimeout(seconds: config.timeout)
        
        // Start reading output
        startReadingOutput()
        
        logger.info("Stdio transport connected")
    }
    
    public func disconnect() async {
        logger.info("Disconnecting stdio transport")
        let process = await state.process
        process?.terminate()
        await state.setProcess(nil, input: nil, output: nil)
        await state.cancelAllRequests()
    }
    
    public func sendRequest<P: Encodable, R: Decodable>(
        method: String,
        params: P
    ) async throws -> R {
        let id = await state.getNextId()
        
        // Create JSON-RPC request
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: method,
            params: params,
            id: id
        )
        
        // Encode and send
        let data = try JSONEncoder().encode(request)
        if method == "initialize", let json = String(data: data, encoding: .utf8) {
            logger.info("[MCP stdio] → initialize payload: \(json)")
        }
        try await send(data)
        
        // Wait for response with timeout
        let responseData = try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                await state.addPendingRequest(id: id, continuation: continuation)
                // Schedule timeout task
                let timeoutTask = Task { [logger] in
                    let ns = await state.requestTimeoutNs
                    try? await Task.sleep(nanoseconds: ns)
                    // On timeout, try to remove pending and resume throwing
                    if let pending = await state.removePendingRequest(id: id) {
                        logger.error("MCP stdio request timed out: method=\(method), id=\(id)")
                        pending.resume(throwing: MCPError.executionFailed("Request timed out after \(ns / 1_000_000)ms"))
                    }
                }
                await state.addTimeoutTask(id: id, task: timeoutTask)
            }
        }
        
        // Decode response
        let response = try JSONDecoder().decode(JSONRPCResponse<R>.self, from: responseData)
        
        if let error = response.error {
            throw MCPError.executionFailed(error.message)
        }
        
        guard let result = response.result else {
            throw MCPError.invalidResponse
        }
        
        return result
    }
    
    public func sendNotification<P: Encodable>(
        method: String,
        params: P
    ) async throws {
        // Create JSON-RPC notification (no id)
        let notification = JSONRPCNotification(
            jsonrpc: "2.0",
            method: method,
            params: params
        )
        
        // Encode and send
        let data = try JSONEncoder().encode(notification)
        try await send(data)
    }
    
    private func send(_ data: Data) async throws {
        guard let inputPipe = await state.getInputPipe() else {
            throw MCPError.notConnected
        }
        // MCP stdio framing: Content-Length header and blank line, then JSON payload
        let header = "Content-Length: \(data.count)\r\n\r\n"
        let headerData = header.data(using: .utf8)!
        try inputPipe.fileHandleForWriting.write(contentsOf: headerData)
        try inputPipe.fileHandleForWriting.write(contentsOf: data)
    }
    
    private func startReadingOutput() {
        Task {
            guard let outputPipe = await state.getOutputPipe() else { return }
            
            let fileHandle = outputPipe.fileHandleForReading
            
            while true {
                do {
                    // Read MCP stdio-framed message: headers then body
                    guard let (headers, body) = try await readFramedMessage(from: fileHandle) else { break }
                    if let len = headers["content-length"], Int(len) == body.count {
                        await handleResponse(body)
                    } else {
                        logger.error("Invalid MCP stdio frame: content-length mismatch")
                    }
                } catch {
                    logger.error("Error reading output: \(error)")
                    break
                }
            }
        }
    }

    // Robustly read MCP stdio-framed message, tolerating banner/noise
    // Looks for a "Content-Length:" header, supports both CRLF and LF newlines
    private func readFramedMessage(from fileHandle: FileHandle) async throws -> ([String: String], Data)? {
        var buffer = Data()
        let contentLengthTokenLower = "content-length:" // search case-insensitively
        let crlfcrlf = "\r\n\r\n".data(using: .utf8)!
        let lflf = "\n\n".data(using: .utf8)!

        // Read until we have at least a Content-Length header and the blank line after headers
        while true {
            if let chunk = try fileHandle.read(upToCount: 1), !chunk.isEmpty {
                buffer.append(chunk)
                // Skip any leading noise before header (case-insensitive search)
                let lower = String(data: buffer, encoding: .utf8)?.lowercased() ?? ""
                if lower.contains(contentLengthTokenLower) {
                    // Check for end of headers (CRLFCRLF or LFLF)
                    if buffer.range(of: crlfcrlf) != nil || buffer.range(of: lflf) != nil {
                        break
                    }
                }
                // Otherwise keep reading
            } else {
                // EOF
                return nil
            }
        }

        // Normalize header segment starting at Content-Length
        // Find start by locating the content-length line case-insensitively
        let headerStringAll = String(data: buffer, encoding: .utf8) ?? ""
        guard let tokenRange = headerStringAll.lowercased().range(of: contentLengthTokenLower) else {
            // Did not find a frame header; drop noise and continue
            return nil
        }
        let headerStartIndex = headerStringAll.distance(from: headerStringAll.startIndex, to: tokenRange.lowerBound)
        let headerBytes = buffer.suffix(buffer.count - headerStartIndex)
        let headerSegment = headerBytes

        // Determine newline convention and split headers
        let headerEndRange = headerSegment.range(of: crlfcrlf) ?? headerSegment.range(of: lflf)
        guard let headerEnd = headerEndRange?.lowerBound else { return nil }
        let headersData = headerSegment[..<headerEnd]
        let headersString = String(data: headersData, encoding: .utf8) ?? ""
        let lines = headersString.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n").filter { !$0.isEmpty }

        var headers: [String: String] = [:]
        for line in lines {
            if let sep = line.firstIndex(of: ":") {
                let key = line[..<sep].lowercased().trimmingCharacters(in: .whitespaces)
                let value = line[line.index(after: sep)...].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        let length = Int(headers["content-length"] ?? "0") ?? 0

        // Compute how many bytes remain in the file after headers to fulfill the body
        var body = Data(capacity: max(length, 0))
        var remaining = length
        while remaining > 0 {
            let chunk = try fileHandle.read(upToCount: remaining)
            guard let chunk = chunk, !chunk.isEmpty else { break }
            body.append(chunk)
            remaining -= chunk.count
        }
        return (headers, body)
    }
    
    private func handleResponse(_ data: Data) async {
        do {
            // Try to parse as a response with ID
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = response["id"] as? Int {
                
                if let continuation = await state.removePendingRequest(id: id) {
                    await state.cancelTimeoutTask(id: id)
                    continuation.resume(returning: data)
                }
            } else if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let idString = response["id"] as? String,
                      let idInt = Int(idString) {
                if let contByString = await state.removePendingRequestByStringId(idString) {
                    await state.cancelTimeoutTask(id: idInt)
                    contByString.resume(returning: data)
                } else if let contByInt = await state.removePendingRequest(id: idInt) {
                    await state.cancelTimeoutTask(id: idInt)
                    contByInt.resume(returning: data)
                }
            }
            // Otherwise it might be a notification or other message
        } catch {
            logger.error("Failed to parse response: \(error)")
        }
    }
}

// MARK: - JSON-RPC Types

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
    let id: Int
}

private struct JSONRPCError: Decodable {
    let code: Int
    let message: String
    let data: AnyCodable?
}

// Simple AnyCodable for error data
private struct AnyCodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else {
            value = NSNull()
        }
    }
}