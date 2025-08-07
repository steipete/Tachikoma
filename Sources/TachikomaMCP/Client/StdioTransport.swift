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
    var pendingRequests: [Int: CheckedContinuation<Data, Swift.Error>] = [:]
    
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
        pendingRequests[id] = continuation
    }
    
    func removePendingRequest(id: Int) -> CheckedContinuation<Data, Swift.Error>? {
        return pendingRequests.removeValue(forKey: id)
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
        } else {
            // Try to find in PATH
            process.launchPath = "/usr/bin/env"
            process.arguments = [components[0]] + config.args
        }
        
        // If we have a direct path, use provided args
        if process.executableURL != nil {
            process.arguments = config.args.isEmpty ? Array(components.dropFirst()) : config.args
        }
        
        // Set environment
        if !config.env.isEmpty {
            process.environment = ProcessInfo.processInfo.environment.merging(config.env) { _, new in new }
        }
        
        // Start process
        do {
            try process.run()
        } catch {
            throw MCPError.connectionFailed("Failed to start process: \(error)")
        }
        
        await state.setProcess(process, input: inputPipe, output: outputPipe)
        
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
        try await send(data)
        
        // Wait for response
        let responseData = try await withCheckedThrowingContinuation { continuation in
            Task {
                await state.addPendingRequest(id: id, continuation: continuation)
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
        
        // Add newline for line-delimited JSON
        var dataWithNewline = data
        dataWithNewline.append("\n".data(using: .utf8)!)
        
        try inputPipe.fileHandleForWriting.write(contentsOf: dataWithNewline)
    }
    
    private func startReadingOutput() {
        Task {
            guard let outputPipe = await state.getOutputPipe() else { return }
            
            let fileHandle = outputPipe.fileHandleForReading
            
            while true {
                do {
                    // Read line by line (JSON-RPC is line-delimited)
                    guard let line = try await readLine(from: fileHandle) else {
                        break
                    }
                    
                    // Parse JSON-RPC response
                    if let data = line.data(using: .utf8) {
                        await handleResponse(data)
                    }
                } catch {
                    logger.error("Error reading output: \(error)")
                    break
                }
            }
        }
    }
    
    private func readLine(from fileHandle: FileHandle) async throws -> String? {
        var buffer = Data()
        
        while true {
            let byte = try fileHandle.read(upToCount: 1)
            guard let byte = byte, !byte.isEmpty else {
                return buffer.isEmpty ? nil : String(data: buffer, encoding: .utf8)
            }
            
            if byte[0] == 0x0A { // newline
                return String(data: buffer, encoding: .utf8)
            }
            
            buffer.append(byte)
        }
    }
    
    private func handleResponse(_ data: Data) async {
        do {
            // Try to parse as a response with ID
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = response["id"] as? Int {
                
                if let continuation = await state.removePendingRequest(id: id) {
                    continuation.resume(returning: data)
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