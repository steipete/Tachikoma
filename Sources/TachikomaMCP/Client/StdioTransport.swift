import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Logging
import MCP
import Tachikoma

// Actor to manage mutable state for Sendable conformance
private actor StdioTransportState {
    var process: Process?
    var inputPipe: Pipe?
    var outputPipe: Pipe?
    var errorPipe: Pipe?
    var nextId: Int = 1
    var pendingRequests: [String: CheckedContinuation<Data, Swift.Error>] = [:]
    var timeoutTasks: [Int: Task<Void, Never>] = [:]
    var requestTimeoutNs: UInt64 = 30_000_000_000 // default 30s

    func setProcess(_ process: Process?, input: Pipe?, output: Pipe?, error: Pipe?) {
        self.process = process
        self.inputPipe = input
        self.outputPipe = output
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

    func getInputPipe() -> Pipe? {
        self.inputPipe
    }

    func getOutputPipe() -> Pipe? {
        self.outputPipe
    }

    func getErrorPipe() -> Pipe? {
        self.errorPipe
    }
}

/// Standard I/O transport for MCP communication
public final class StdioTransport: MCPTransport {
    private let state = StdioTransportState()
    private let logger = Logger(label: "tachikoma.mcp.stdio")
    private static let _sigpipeHandlerInstalled: Void = {
        signal(SIGPIPE, SIG_IGN)
    }()

    private let debugStdoutHandle: FileHandle?
    private let debugStderrHandle: FileHandle?
    private let debugQueue = DispatchQueue(label: "tachikoma.mcp.stdio.debug")
    private let stdoutQueue = DispatchQueue(label: "tachikoma.mcp.stdio.stdout")
    private let stderrQueue = DispatchQueue(label: "tachikoma.mcp.stdio.stderr")
    private var stdoutSource: DispatchSourceRead?
    private var stderrSource: DispatchSourceRead?
    private var stdoutBuffer = Data()
    private var stderrBuffer = Data()

    public init() {
        Self._sigpipeHandlerInstalled
        self.debugStdoutHandle = Self.makeDebugHandle(for: "MCP_STDIO_STDOUT")
        self.debugStderrHandle = Self.makeDebugHandle(for: "MCP_STDIO_STDERR")
    }

    public func connect(config: MCPServerConfig) async throws {
        self.logger.info("Starting stdio transport with command: \(config.command)")

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        // Keep stderr separate; mixing can corrupt frame boundaries
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
        process.environment = ProcessInfo.processInfo.environment.merging(config.env) { _, new in new }

        // Start process
        do {
            try process.run()
        } catch {
            throw MCPError.connectionFailed("Failed to start process: \(error)")
        }

        // Close parent's write ends for stdout/stderr so EOF is detected promptly
        try? outputPipe.fileHandleForWriting.close()
        try? errorPipe.fileHandleForWriting.close()

        await self.state.setProcess(process, input: inputPipe, output: outputPipe, error: errorPipe)
        await self.state.setRequestTimeout(seconds: config.timeout)

        self.logger.info("About to start reading output")
        self.stdoutSource = self.makeReadSource(for: outputPipe, isStderr: false)
        self.stderrSource = self.makeReadSource(for: errorPipe, isStderr: true)

        self.logger.info("Stdio transport connected")
    }

    public func disconnect() async {
        self.logger.info("Disconnecting stdio transport")

        self.stdoutSource?.cancel()
        self.stderrSource?.cancel()
        self.stdoutSource = nil
        self.stderrSource = nil
        self.stdoutQueue.sync { self.stdoutBuffer.removeAll(keepingCapacity: false) }
        self.stderrQueue.sync { self.stderrBuffer.removeAll(keepingCapacity: false) }
        self.closeDebugHandles()

        let inputPipe = await state.getInputPipe()
        let outputPipe = await state.getOutputPipe()
        let errorPipe = await state.getErrorPipe()
        let process = await state.process

        self.closePipe(inputPipe)
        self.closePipe(outputPipe)
        self.closePipe(errorPipe)

        self.terminateProcess(process)

        await self.state.setProcess(nil, input: nil, output: nil, error: nil)
        await self.state.cancelAllRequests()
    }

    deinit {
        self.closeDebugHandles()
    }

    public func sendRequest<R: Decodable>(
        method: String,
        params: some Encodable,
    ) async throws
        -> R
    {
        let id = await state.getNextId()

        // Create JSON-RPC request with canonical key order
        var dict: [String: Any] = [:]
        dict["jsonrpc"] = "2.0"
        dict["method"] = method
        let paramsData = try JSONEncoder().encode(params)
        let paramsObj = try JSONSerialization.jsonObject(with: paramsData)
        dict["params"] = paramsObj
        dict["id"] = id
        let data = try JSONSerialization.data(withJSONObject: dict)
        if method == "initialize", let json = String(data: data, encoding: .utf8) {
            self.logger.info("[MCP stdio] → initialize payload: \(json)")
        }

        let responseData = try await withCheckedThrowingContinuation { continuation in
            Task {
                await self.state.addPendingRequest(id: id, continuation: continuation)
                let timeoutTask = Task { [logger] in
                    let ns = await state.requestTimeoutNs
                    try? await Task.sleep(nanoseconds: ns)
                    if let pending = await state.removePendingRequest(id: id) {
                        logger.error("MCP stdio request timed out: method=\(method), id=\(id)")
                        pending
                            .resume(throwing: MCPError.executionFailed("Request timed out after \(ns / 1_000_000)ms"))
                    }
                }
                await state.addTimeoutTask(id: id, task: timeoutTask)

                do {
                    try await self.send(data)
                } catch {
                    _ = await self.state.removePendingRequest(id: id)
                    await self.state.cancelTimeoutTask(id: id)
                    continuation.resume(throwing: error)
                }
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

    public func sendNotification(
        method: String,
        params: some Encodable,
    ) async throws {
        // Create JSON-RPC notification (no id)
        let notification = JSONRPCNotification(
            jsonrpc: "2.0",
            method: method,
            params: params,
        )

        // Encode and send
        let data = try JSONEncoder().encode(notification)
        try await self.send(data)
    }

    private func send(_ data: Data) async throws {
        guard let inputPipe = await state.getInputPipe() else {
            throw MCPError.notConnected
        }
        // MCP TypeScript SDK uses simple newline-delimited JSON, NOT LSP-style framing
        // Just send the JSON followed by a newline
        try inputPipe.fileHandleForWriting.write(contentsOf: data)
        try inputPipe.fileHandleForWriting.write(contentsOf: "\n".utf8Data())

        // Log what we sent for debugging
        if let json = String(data: data, encoding: .utf8) {
            self.logger.debug("[MCP stdio] → sent: \(json)")
        }
    }

    private func makeReadSource(for pipe: Pipe, isStderr: Bool) -> DispatchSourceRead? {
        let fileHandle = pipe.fileHandleForReading
        let fd = fileHandle.fileDescriptor
        let currentFlags = fcntl(fd, F_GETFL)
        if currentFlags != -1 {
            _ = fcntl(fd, F_SETFL, currentFlags | O_NONBLOCK)
        }

        let queue = isStderr ? self.stderrQueue : self.stdoutQueue
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            var buffer = [UInt8](repeating: 0, count: 8192)
            while true {
                let count = read(fd, &buffer, buffer.count)
                if count > 0 {
                    let data = Data(buffer[0..<count])
                    self.handleBytes(data, isStderr: isStderr)
                    continue
                }
                if count == 0 {
                    self.logger.debug("[MCP stdio] \(isStderr ? "stderr" : "stdout") pipe closed")
                    source.cancel()
                    break
                }
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    break
                }
                self.logger.error("[MCP stdio] Read error: \(String(cString: strerror(errno)))")
                source.cancel()
                break
            }
        }
        source.resume()
        return source
    }

    private func handleBytes(_ chunk: Data, isStderr: Bool) {
        guard !chunk.isEmpty else { return }
        if isStderr {
            self.stderrBuffer.append(chunk)
            self.writeDebug(chunk, handle: self.debugStderrHandle)
            self.consumeBuffer(&self.stderrBuffer, isStderr: true)
        } else {
            self.stdoutBuffer.append(chunk)
            self.writeDebug(chunk, handle: self.debugStdoutHandle)
            self.consumeBuffer(&self.stdoutBuffer, isStderr: false)
        }
    }

    private func consumeBuffer(_ buffer: inout Data, isStderr: Bool) {
        if isStderr {
            while let line = Self.consumeLine(from: &buffer) {
                guard !line.isEmpty else { continue }
                if let message = String(data: line, encoding: .utf8), !message.isEmpty {
                    self.logger.debug("[MCP stdio][stderr] \(message)")
                }
            }
            return
        }

        while let framed = Self.extractFramedMessageBytes(from: &buffer) {
            if let json = String(data: framed, encoding: .utf8) {
                self.logger.debug("[MCP stdio] ← framed: \(json)")
            }
            Task { await self.handleResponse(framed) }
        }

        while let line = Self.consumeLine(from: &buffer) {
            guard !line.isEmpty else { continue }
            if let json = String(data: line, encoding: .utf8) {
                self.logger.debug("[MCP stdio] ← received: \(json)")
            }
            Task { await self.handleResponse(line) }
        }
    }

    private static func consumeLine(from buffer: inout Data) -> Data? {
        guard let newlineIndex = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) else {
            return nil
        }
        let line = buffer[..<newlineIndex]
        var removeEnd = buffer.index(after: newlineIndex)
        if
            buffer[newlineIndex] == 0x0D,
            removeEnd < buffer.endIndex,
            buffer[removeEnd] == 0x0A
        {
            removeEnd = buffer.index(after: removeEnd)
        }
        buffer.removeSubrange(buffer.startIndex..<removeEnd)
        return Data(line)
    }

    private static func extractFramedMessageBytes(from buffer: inout Data) -> Data? {
        guard
            let headerEndRange = buffer.range(of: Data([13, 10, 13, 10])) ??
            buffer.range(of: Data([10, 10])) else
        {
            return nil
        }

        let header = buffer[..<headerEndRange.lowerBound]
        guard let headerString = String(data: header, encoding: .utf8) else {
            return nil
        }
        let lowerHeader = headerString.lowercased()
        guard let tokenRange = lowerHeader.range(of: "content-length:") else {
            return nil
        }

        var digitIndex = tokenRange.upperBound
        while digitIndex < lowerHeader.endIndex, lowerHeader[digitIndex] == " " {
            digitIndex = lowerHeader.index(after: digitIndex)
        }

        var digitsEnd = digitIndex
        while digitsEnd < lowerHeader.endIndex, lowerHeader[digitsEnd].isNumber {
            digitsEnd = lowerHeader.index(after: digitsEnd)
        }

        guard digitsEnd > digitIndex else { return nil }
        let lengthSubstring = lowerHeader[digitIndex..<digitsEnd]
        guard let length = Int(lengthSubstring) else { return nil }

        let headerBytes = buffer.distance(from: buffer.startIndex, to: headerEndRange.upperBound)
        guard buffer.count >= headerBytes + length else { return nil }

        let bodyStart = buffer.index(buffer.startIndex, offsetBy: headerBytes)
        let bodyEnd = buffer.index(bodyStart, offsetBy: length)
        let body = buffer[bodyStart..<bodyEnd]
        buffer.removeSubrange(buffer.startIndex..<bodyEnd)
        return Data(body)
    }

    private func handleResponse(_ data: Data) async {
        // Try to parse as a response with ID
        if
            let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = response["id"] as? Int
        {
            if let continuation = await state.removePendingRequest(id: id) {
                await self.state.cancelTimeoutTask(id: id)
                continuation.resume(returning: data)
            }
        } else if
            let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let idString = response["id"] as? String,
            let idInt = Int(idString)
        {
            if let contByString = await state.removePendingRequestByStringId(idString) {
                await self.state.cancelTimeoutTask(id: idInt)
                contByString.resume(returning: data)
            } else if let contByInt = await state.removePendingRequest(id: idInt) {
                await self.state.cancelTimeoutTask(id: idInt)
                contByInt.resume(returning: data)
            }
        } else if
            let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let idNull = response["id"], idNull is NSNull
        {
            // Some servers return null id for notifications; ignore
        }
        // Otherwise it might be a notification or other message
    }

    private func closePipe(_ pipe: Pipe?) {
        guard let pipe else { return }
        do {
            try pipe.fileHandleForWriting.close()
        } catch {
            // ignore
        }
        do {
            try pipe.fileHandleForReading.close()
        } catch {
            // ignore
        }
    }

    private func terminateProcess(_ process: Process?) {
        guard let process else { return }

        if process.isRunning {
            process.terminate()
        }

        if !self.waitForProcessExit(process, timeout: 0.7) {
            kill(process.processIdentifier, SIGTERM)
            if !self.waitForProcessExit(process, timeout: 0.7) {
                kill(process.processIdentifier, SIGKILL)
                _ = self.waitForProcessExit(process, timeout: 0.3)
            }
        }
    }

    private func waitForProcessExit(_ process: Process, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        return !process.isRunning
    }

    private static func makeDebugHandle(for envKey: String) -> FileHandle? {
        guard let path = ProcessInfo.processInfo.environment[envKey], !path.isEmpty else {
            return nil
        }

        let fileURL = URL(fileURLWithPath: path).standardizedFileURL
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }

        do {
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            return handle
        } catch {
            return nil
        }
    }

    private func writeDebug(_ data: Data, handle: FileHandle?) {
        guard let handle, !data.isEmpty else { return }
        self.debugQueue.async {
            do {
                try handle.write(contentsOf: data)
            } catch {
                // Ignore debug output failures entirely.
            }
        }
    }

    private func closeDebugHandles() {
        try? self.debugStdoutHandle?.close()
        try? self.debugStderrHandle?.close()
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
    let id: JSONRPCID?
}

private enum JSONRPCID: Decodable {
    case int(Int)
    case string(String)
    case null
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let i = try? container.decode(Int.self) { self = .int(i)
            return
        }
        if let s = try? container.decode(String.self) { self = .string(s)
            return
        }
        if container.decodeNil() { self = .null
            return
        }
        throw DecodingError.typeMismatch(
            JSONRPCID.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported id type"),
        )
    }
}

private struct JSONRPCError: Decodable {
    let code: Int
    let message: String
}

extension StdioTransport: @unchecked Sendable {}
