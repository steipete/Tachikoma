import Darwin
import Foundation
import Logging
import MCP

// Actor to manage mutable state for Sendable conformance
private actor StdioTransportPTYState {
    var process: Process?
    var masterHandle: FileHandle?
    var slaveHandle: FileHandle?
    var errorPipe: Pipe?
    var nextId: Int = 1
    var pendingRequests: [String: CheckedContinuation<Data, Swift.Error>] = [:]
    var timeoutTasks: [Int: Task<Void, Never>] = [:]
    var requestTimeoutNs: UInt64 = 30_000_000_000 // default 30s

    func setProcess(_ process: Process?, master: FileHandle?, slave: FileHandle?, error: Pipe?) {
        self.process = process
        self.masterHandle = master
        self.slaveHandle = slave
        self.errorPipe = error
    }

    func getNextId() -> Int {
        let id = self.nextId
        self.nextId += 1
        return id
    }

    func addPendingRequest(id: Int, continuation: CheckedContinuation<Data, Swift.Error>) {
        self.pendingRequests[String(id)] = continuation
    }

    func removePendingRequest(id: Int) -> CheckedContinuation<Data, Swift.Error>? {
        self.pendingRequests.removeValue(forKey: String(id))
    }

    func removePendingRequestByStringId(_ id: String) -> CheckedContinuation<Data, Swift.Error>? {
        self.pendingRequests.removeValue(forKey: id)
    }

    func setRequestTimeout(seconds: TimeInterval) {
        let ns = seconds > 0 ? seconds * 1_000_000_000 : 30_000_000_000
        self.requestTimeoutNs = UInt64(ns)
    }

    func addTimeoutTask(id: Int, task: Task<Void, Never>) {
        self.timeoutTasks[id] = task
    }

    func cancelTimeoutTask(id: Int) {
        if let task = timeoutTasks.removeValue(forKey: id) {
            task.cancel()
        }
    }

    func cancelAllRequests() {
        for (_, continuation) in self.pendingRequests {
            continuation.resume(throwing: MCPError.notConnected)
        }
        self.pendingRequests.removeAll()
    }

    func getMasterHandle() -> FileHandle? {
        self.masterHandle
    }
}

/// PTY-enabled Standard I/O transport for MCP communication
/// This version creates a pseudo-terminal to better support tools like npx that check for TTY
public final class StdioTransportPTY: MCPTransport {
    private let state = StdioTransportPTYState()
    private let logger = Logger(label: "tachikoma.mcp.stdio-pty")

    public init() {}

    public func connect(config: MCPServerConfig) async throws {
        self.logger.info("Starting PTY stdio transport with command: \(config.command)")

        // Create PTY pair
        var masterFD: Int32 = 0
        var slaveFD: Int32 = 0

        guard Darwin.openpty(&masterFD, &slaveFD, nil, nil, nil) != -1 else {
            throw MCPError.connectionFailed("Failed to create PTY")
        }

        let masterHandle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
        let slaveHandle = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: true)

        let process = Process()
        let errorPipe = Pipe()

        // Use slave side of PTY for process stdio
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = errorPipe

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
                    if
                        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                        !path.isEmpty
                    {
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
        // Add explicit PATH that includes common node locations
        var env = ProcessInfo.processInfo.environment
        if let existingPath = env["PATH"] {
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(existingPath)"
        } else {
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        }
        env = env.merging(config.env) { _, new in new }
        process.environment = env

        // Start process
        do {
            try process.run()
        } catch {
            throw MCPError.connectionFailed("Failed to start process: \(error)")
        }

        await self.state.setProcess(process, master: masterHandle, slave: slaveHandle, error: errorPipe)
        await self.state.setRequestTimeout(seconds: config.timeout)

        // Start reading output from master side of PTY
        self.startReadingOutput()

        // Drain and log stderr separately (non-blocking)
        Task {
            let fh = errorPipe.fileHandleForReading
            while true {
                let chunk = try? fh.read(upToCount: 4096)
                guard let chunk, !chunk.isEmpty else { break }
                if let s = String(data: chunk, encoding: .utf8), !s.isEmpty {
                    self.logger.debug("[MCP stdio-pty][stderr] \(s.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
        }

        self.logger.info("PTY stdio transport connected")
    }

    public func disconnect() async {
        self.logger.info("Disconnecting PTY stdio transport")
        let process = await state.process
        process?.terminate()
        await self.state.setProcess(nil, master: nil, slave: nil, error: nil)
        await self.state.cancelAllRequests()
    }

    public func sendRequest<R: Decodable>(
        method: String,
        params: some Encodable
    ) async throws
    -> R {
        let id = await state.getNextId()

        // Create JSON-RPC request
        var dict: [String: Any] = [:]
        dict["jsonrpc"] = "2.0"
        dict["method"] = method
        let paramsData = try JSONEncoder().encode(params)
        let paramsObj = try JSONSerialization.jsonObject(with: paramsData)
        dict["params"] = paramsObj
        dict["id"] = id
        let data = try JSONSerialization.data(withJSONObject: dict)

        if method == "initialize", let json = String(data: data, encoding: .utf8) {
            self.logger.info("[MCP stdio-pty] → initialize payload: \(json)")
        }

        try await self.send(data)

        // Wait for response with timeout
        let responseData = try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                await self.state.addPendingRequest(id: id, continuation: continuation)
                // Schedule timeout task
                let timeoutTask = Task {
                    let timeout = await state.requestTimeoutNs
                    try? await Task.sleep(nanoseconds: timeout)
                    if let continuation = await state.removePendingRequest(id: id) {
                        self.logger.error("MCP stdio-pty request timed out: method=\(method), id=\(id)")
                        continuation.resume(throwing: MCPError.connectionFailed("Request timed out"))
                    }
                }
                await state.addTimeoutTask(id: id, task: timeoutTask)
            }
        }

        // Cancel timeout task
        await state.cancelTimeoutTask(id: id)

        // Parse response
        let response = try JSONDecoder().decode(JSONRPCResponse<R>.self, from: responseData)
        if let error = response.error {
            throw MCPError.executionFailed("JSON-RPC error \(error.code): \(error.message)")
        }
        guard let result = response.result else {
            throw MCPError.invalidResponse
        }
        return result
    }

    public func sendNotification(method: String, params: some Encodable) async throws {
        var dict: [String: Any] = [:]
        dict["jsonrpc"] = "2.0"
        dict["method"] = method
        let paramsData = try JSONEncoder().encode(params)
        let paramsObj = try JSONSerialization.jsonObject(with: paramsData)
        dict["params"] = paramsObj
        let data = try JSONSerialization.data(withJSONObject: dict)
        try await self.send(data)
    }

    private func send(_ data: Data) async throws {
        guard let handle = await state.getMasterHandle() else {
            throw MCPError.notConnected
        }

        // Write to master side of PTY
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error>) in
            handle.write(data)
            handle.write("\n".data(using: .utf8)!)
            continuation.resume()
        }
    }

    private func startReadingOutput() {
        Task {
            guard let handle = await state.getMasterHandle() else { return }

            var buffer = Data()
            while true {
                do {
                    let chunk = try handle.read(upToCount: 4096)
                    guard let chunk, !chunk.isEmpty else { break }

                    buffer.append(chunk)

                    // Process complete lines
                    while let newlineRange = buffer.firstRange(of: Data("\n".utf8)) {
                        let lineData = buffer[..<newlineRange.lowerBound]
                        buffer.removeSubrange(..<newlineRange.upperBound)

                        if !lineData.isEmpty {
                            await self.processLine(lineData)
                        }
                    }
                } catch {
                    self.logger.error("Error reading from PTY: \(error)")
                    break
                }
            }
        }
    }

    private func processLine(_ data: Data) async {
        // Try to parse as JSON-RPC response
        if
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let idValue = json["id"]
        {
            let idString = String(describing: idValue)
            if let continuation = await state.removePendingRequestByStringId(idString) {
                continuation.resume(returning: data)
            }
        }
    }
}

// JSON-RPC Response structure
private struct JSONRPCResponse<T: Decodable>: Decodable {
    let jsonrpc: String?
    let id: Int?
    let result: T?
    let error: JSONRPCError?
}

private struct JSONRPCError: Decodable {
    let code: Int
    let message: String
}
