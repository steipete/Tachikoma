import Foundation
import Tachikoma
import TachikomaAgent
import TachikomaMCP

/// Manages MCP (Model Context Protocol) server connections and tools
final class MCPManager {
    private var servers: [MCPServer] = []
    private let registry = DynamicToolRegistry()

    /// Add an MCP server
    func addServer(name: String, command: String) async throws {
        // Parse command into executable and arguments
        let components = command.split(separator: " ").map(String.init)
        guard !components.isEmpty else {
            throw MCPError.invalidCommand("Empty command")
        }

        let executable = components[0]
        let arguments = Array(components.dropFirst())

        // Create MCP server connection
        let server = MCPServer(
            name: name,
            executable: executable,
            arguments: arguments,
        )

        // Start the server
        try await server.start()

        // Discover available tools
        let tools = try await server.discoverTools()

        // Register tools with the registry
        let provider = MCPToolProvider(server: server, tools: tools)
        await registry.register(provider, id: name)

        self.servers.append(server)
    }

    /// Get all available tools from all servers
    func getTools() async -> [AgentTool] {
        do {
            return try await self.registry.getAllAgentTools()
        } catch {
            print("Warning: Failed to get MCP tools: \(error)")
            return []
        }
    }

    /// Shutdown all servers
    func shutdown() async {
        for server in self.servers {
            await server.stop()
        }
        self.servers.removeAll()
    }
}

// MARK: - MCP Server

/// Represents an MCP server connection
final class MCPServer: @unchecked Sendable {
    let name: String
    private let executable: String
    private let arguments: [String]
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?

    init(name: String, executable: String, arguments: [String]) {
        self.name = name
        self.executable = executable
        self.arguments = arguments
    }

    func start() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [self.executable] + self.arguments

        // Setup pipes for communication
        let inputPipe = Pipe()
        let outputPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        // Start the process
        try process.run()

        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe

        // Wait for server to initialize
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }

    func stop() async {
        self.process?.terminate()
        self.process = nil
        self.inputPipe = nil
        self.outputPipe = nil
    }

    func discoverTools() async throws -> [DynamicTool] {
        // Send tool discovery request
        let request = MCPRequest(method: "tools/list", params: nil)
        let response = try await sendRequest(request)

        // Parse tools from response
        guard let tools = response["tools"] as? [[String: Any]] else {
            return []
        }

        return tools.compactMap { toolData in
            guard
                let name = toolData["name"] as? String,
                let description = toolData["description"] as? String,
                let schemaData = toolData["input_schema"] as? [String: Any] else
            {
                return nil
            }

            let schema = self.parseDynamicSchema(from: schemaData)
            return DynamicTool(
                name: name,
                description: description,
                schema: schema,
            )
        }
    }

    func executeTool(name: String, arguments: [String: Any]) async throws -> Any {
        let request = MCPRequest(
            method: "tools/call",
            params: [
                "name": name,
                "arguments": arguments,
            ],
        )

        let response = try await sendRequest(request)
        return response["result"] ?? [:]
    }

    private func sendRequest(_ request: MCPRequest) async throws -> [String: Any] {
        guard
            let inputPipe,
            let outputPipe else
        {
            throw MCPError.serverNotRunning
        }

        // Encode request
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)

        // Send request
        inputPipe.fileHandleForWriting.write(requestData)
        inputPipe.fileHandleForWriting.write("\n".utf8Data())

        // Read response
        let responseData = outputPipe.fileHandleForReading.availableData

        // Parse response
        guard let response = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw MCPError.invalidResponse
        }

        // Check for errors
        if let error = response["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown error"
            throw MCPError.serverError(message)
        }

        return response["result"] as? [String: Any] ?? [:]
    }

    private func parseDynamicSchema(from data: [String: Any]) -> DynamicSchema {
        let type = DynamicSchema.SchemaType(rawValue: data["type"] as? String ?? "object") ?? .object

        var properties: [String: DynamicSchema.SchemaProperty] = [:]
        if let props = data["properties"] as? [String: [String: Any]] {
            for (key, value) in props {
                let propType = DynamicSchema.SchemaType(rawValue: value["type"] as? String ?? "string") ?? .string
                let description = value["description"] as? String
                properties[key] = DynamicSchema.SchemaProperty(
                    type: propType,
                    description: description,
                )
            }
        }

        let required = data["required"] as? [String] ?? []

        return DynamicSchema(
            type: type,
            properties: properties,
            required: required,
        )
    }
}

// MARK: - MCP Tool Provider

/// Provides tools from an MCP server to the agent
final class MCPToolProvider: DynamicToolProvider {
    private let server: MCPServer
    private let tools: [DynamicTool]

    init(server: MCPServer, tools: [DynamicTool]) {
        self.server = server
        self.tools = tools
    }

    func discoverTools() async throws -> [DynamicTool] {
        self.tools
    }

    func executeTool(name: String, arguments: AgentToolArguments) async throws -> AnyAgentToolValue {
        // Convert arguments to dictionary
        var args: [String: Any] = [:]
        for key in arguments.keys {
            if let value = arguments[key] {
                args[key] = self.convertToAny(value)
            }
        }

        // Execute tool on server
        let result = try await server.executeTool(name: name, arguments: args)

        // Convert result back to AnyAgentToolValue
        return self.convertToAgentValue(result)
    }

    private func convertToAny(_ value: AnyAgentToolValue) -> Any {
        if let string = value.stringValue {
            return string
        } else if let int = value.intValue {
            return int
        } else if let double = value.doubleValue {
            return double
        } else if let bool = value.boolValue {
            return bool
        } else if let array = value.arrayValue {
            return array.map { self.convertToAny($0) }
        } else if let object = value.objectValue {
            var dict: [String: Any] = [:]
            for (key, val) in object {
                dict[key] = self.convertToAny(val)
            }
            return dict
        } else {
            return NSNull()
        }
    }

    private func convertToAgentValue(_ value: Any) -> AnyAgentToolValue {
        if let string = value as? String {
            return AnyAgentToolValue(string: string)
        } else if let int = value as? Int {
            return AnyAgentToolValue(int: int)
        } else if let double = value as? Double {
            return AnyAgentToolValue(double: double)
        } else if let bool = value as? Bool {
            return AnyAgentToolValue(bool: bool)
        } else if let array = value as? [Any] {
            let converted = array.map { self.convertToAgentValue($0) }
            return AnyAgentToolValue(array: converted)
        } else if let dict = value as? [String: Any] {
            var converted: [String: AnyAgentToolValue] = [:]
            for (key, val) in dict {
                converted[key] = self.convertToAgentValue(val)
            }
            return AnyAgentToolValue(object: converted)
        } else {
            return AnyAgentToolValue(null: ())
        }
    }
}

// MARK: - Supporting Types

struct MCPRequest: Encodable {
    let method: String
    let params: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case method
        case params
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.method, forKey: .method)
        if let params {
            let data = try JSONSerialization.data(withJSONObject: params)
            try container.encode(data, forKey: .params)
        }
    }
}

enum MCPError: LocalizedError {
    case invalidCommand(String)
    case serverNotRunning
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case let .invalidCommand(message):
            "Invalid MCP command: \(message)"
        case .serverNotRunning:
            "MCP server is not running"
        case .invalidResponse:
            "Invalid response from MCP server"
        case let .serverError(message):
            "MCP server error: \(message)"
        }
    }
}
