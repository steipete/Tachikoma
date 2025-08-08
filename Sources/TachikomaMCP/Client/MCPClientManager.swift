import Foundation
import os.log
import Tachikoma
import MCP

/// Instantiable manager for MCP client connections and configuration.
/// Owns parsing of mcpClients from the host profile config.json (JSONC) and
/// merges host-provided defaults with user overrides.
@MainActor
public final class TachikomaMCPClientManager {
    // MARK: Shared (optional)
    public static let shared = TachikomaMCPClientManager()

    // MARK: Profile/config wiring
    /// Name of the profile directory under $HOME (defaults to TachikomaConfiguration.profileDirectoryName)
    public var profileDirectoryName: String {
        get { TachikomaConfiguration.profileDirectoryName }
        set { TachikomaConfiguration.profileDirectoryName = newValue }
    }

    // MARK: Internal state
    private let logger = os.Logger(subsystem: "tachikoma.mcp", category: "client-manager")
    private var connections: [String: MCPClient] = [:]
    private var effectiveConfigs: [String: MCPServerConfig] = [:]
    private var defaultConfigs: [String: MCPServerConfig] = [:]

    public init() {}

    // MARK: Default registration
    public func registerDefaultServers(_ defaults: [String: MCPServerConfig]) {
        self.defaultConfigs = defaults
    }

    // MARK: Initialization
    public func initializeFromProfile(connect: Bool = true) async {
        let fileConfigs = self.loadFileConfigs()
        let merged = self.merge(defaults: defaultConfigs, file: fileConfigs)
        await self.apply(configs: merged, connect: connect)
    }

    public func initialize(with userConfigs: [String: MCPServerConfig], connect: Bool = true) async {
        let merged = self.merge(defaults: defaultConfigs, file: userConfigs)
        await self.apply(configs: merged, connect: connect)
    }

    // MARK: Lifecycle
    public func addServer(name: String, config: MCPServerConfig) async throws {
        effectiveConfigs[name] = config
        if connections[name] == nil { connections[name] = MCPClient(name: name, config: config) }
        if config.enabled { try await connections[name]?.connect() }
    }

    public func removeServer(name: String) async {
        if let client = connections[name] {
            await client.disconnect()
            connections.removeValue(forKey: name)
        }
        effectiveConfigs.removeValue(forKey: name)
    }

    public func enableServer(name: String) async throws {
        guard var cfg = effectiveConfigs[name] else { return }
        cfg.enabled = true
        effectiveConfigs[name] = cfg
        if connections[name] == nil { connections[name] = MCPClient(name: name, config: cfg) }
        try await connections[name]?.connect()
    }

    public func disableServer(name: String) async {
        guard var cfg = effectiveConfigs[name] else { return }
        cfg.enabled = false
        effectiveConfigs[name] = cfg
        if let client = connections[name] { await client.disconnect() }
    }

    public func listServerNames() -> [String] {
        Array(effectiveConfigs.keys).sorted()
    }

    public func getServerConfig(name: String) -> MCPServerConfig? {
        effectiveConfigs[name]
    }

    public func getAllServerConfigs() -> [String: MCPServerConfig] {
        effectiveConfigs
    }

    // MARK: Queries
    public func isServerConnected(name: String) async -> Bool {
        guard let client = connections[name] else { return false }
        return await client.isConnected
    }

    public func getServerTools(name: String) async -> [Tool] {
        guard let client = connections[name] else { return [] }
        return await client.tools
    }

    public func getAllTools() async -> [Tool] {
        var all: [Tool] = []
        for name in listServerNames() {
            let tools = await getServerTools(name: name)
            if !tools.isEmpty { all.append(contentsOf: tools) }
        }
        return all
    }

    // Execute a tool on a specific server
    public func executeTool(serverName: String, toolName: String, arguments: [String: Any]) async throws -> ToolResponse {
        guard let client = connections[serverName] else {
            throw MCPError.executionFailed("Server '\(serverName)' not found")
        }
        // Bridge via TachikomaMCP's adapter to ensure Sendable arguments
        let agentArgs = AgentToolArguments(arguments.mapValues { AnyAgentToolValue.from($0) })
        var mcpArgs: [String: Any] = [:]
        for key in agentArgs.keys {
            if let v = agentArgs[key] { mcpArgs[key] = try v.toJSON() }
        }
        return try await client.executeTool(name: toolName, arguments: mcpArgs)
    }

    /// Get external tools grouped by server name
    public func getExternalToolsByServer() async -> [String: [Tool]] {
        var result: [String: [Tool]] = [:]
        for (name, client) in connections {
            let tools = await client.tools
            if !tools.isEmpty { result[name] = tools }
        }
        return result
    }

    // MARK: Health/Info (lightweight)
    public func getServerNames() -> [String] { Array(effectiveConfigs.keys).sorted() }

    public func getServerInfo(name: String) async -> (config: MCPServerConfig, connected: Bool)? {
        guard let cfg = effectiveConfigs[name] else { return nil }
        let isConnected = await connections[name]?.isConnected ?? false
        return (cfg, isConnected)
    }

    /// Build Tachikoma AgentTools for all connected servers
    public func getAllAgentTools() async -> [AgentTool] {
        var all: [AgentTool] = []
        for (_, client) in connections {
            // Only attempt if connected
            if await client.isConnected {
                let provider = MCPToolProvider(client: client)
                if let tools = try? await provider.getAgentTools() {
                    all.append(contentsOf: tools)
                }
            } else {
                // Try to connect quickly and then fetch
                do {
                    try await client.connect()
                    let provider = MCPToolProvider(client: client)
                    if let tools = try? await provider.getAgentTools() {
                        all.append(contentsOf: tools)
                    }
                } catch {
                    continue
                }
            }
        }
        return all
    }

    // MARK: Health checks
    /// Probe a specific server with a timeout. Attempts to connect if not connected.
    /// Returns tuple: (connected, toolCount, responseTime, error)
    public func probeServer(name: String, timeoutMs: Int = 5000) async -> (Bool, Int, TimeInterval, String?) {
        let start = Date()
        guard let client = connections[name], let cfg = effectiveConfigs[name], cfg.enabled else {
            return (false, 0, 0, "Disabled or not configured")
        }

        // If already connected, return quickly
        if await client.isConnected {
            let tools = await client.tools
            return (true, tools.count, Date().timeIntervalSince(start), nil)
        }

        // Try to connect with timeout
        let connectTask: Task<String?, Never> = Task { () -> String? in
            do { try await client.connect(); return nil } catch { return error.localizedDescription }
        }
        let timeoutTask: Task<String?, Never> = Task { () -> String? in
            try? await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)
            return "timeout after \(timeoutMs)ms"
        }

        var errorMessage: String? = nil
        let winner = await firstResult(connectTask, timeoutTask)
        if let msg = winner { errorMessage = msg }

        // Cancel the loser task
        connectTask.cancel()
        timeoutTask.cancel()

        if errorMessage == nil {
            let tools = await client.tools
            return (true, tools.count, Date().timeIntervalSince(start), nil)
        } else {
            // Ensure process is cleaned up on timeout/failure
            await client.disconnect()
            return (false, 0, Date().timeIntervalSince(start), errorMessage)
        }
    }

    /// Probe all servers in parallel
    public func probeAllServers(timeoutMs: Int = 5000) async -> [String: (Bool, Int, TimeInterval, String?)] {
        var results: [String: (Bool, Int, TimeInterval, String?)] = [:]
        await withTaskGroup(of: (String, (Bool, Int, TimeInterval, String?)).self) { group in
            for name in listServerNames() {
                group.addTask { [weak self] in
                    let res = await self?.probeServer(name: name, timeoutMs: timeoutMs) ?? (false, 0, 0, "not found")
                    return (name, res)
                }
            }
            for await (name, res) in group { results[name] = res }
        }
        return results
    }

    // Simple race between two tasks, returning the first result
    private func firstResult<T>(_ a: Task<T, Never>, _ b: Task<T, Never>) async -> T {
        await withTaskGroup(of: T.self) { group in
            group.addTask { await a.value }
            group.addTask { await b.value }
            let result = await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: Persistence
    /// Persist the current effectiveConfigs back to the profile config file under mcpClients.
    public func persist() throws {
        var json = self.loadRawConfigJSON() ?? [:]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Build mcpClients object
        var mcpDict: [String: Any] = [:]
        for (name, cfg) in effectiveConfigs {
                            let obj: [String: Any?] = [
                "transport": cfg.transport,
                "command": cfg.command,
                "args": cfg.args,
                "env": cfg.env,
                "headers": cfg.headers,
                "enabled": cfg.enabled,
                "timeout": cfg.timeout,
                "autoReconnect": cfg.autoReconnect,
                "description": cfg.description
            ]
            mcpDict[name] = obj.compactMapValues { $0 }
        }
        json["mcpClients"] = mcpDict

        // Serialize back to JSON (comments will be lost for this section)
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        let path = self.profileConfigPath()
        try self.ensureProfileDirectoryExists()
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    // MARK: Helpers
    private func apply(configs: [String: MCPServerConfig], connect: Bool = true) async {
        // Disconnect removed servers
        let toRemove = Set(connections.keys).subtracting(Set(configs.keys))
        for name in toRemove { await connections[name]?.disconnect(); connections.removeValue(forKey: name) }

        // Create/Update and connect enabled
        effectiveConfigs = configs
        for (name, cfg) in configs {
            if connections[name] == nil {
                connections[name] = MCPClient(name: name, config: cfg)
            }
        }

        if connect {
            await withTaskGroup(of: Void.self) { group in
                for (name, cfg) in configs where cfg.enabled {
                    group.addTask { [weak self] in
                        do { try await self?.connections[name]?.connect() } catch {
                            self?.logger.error("Failed to connect to \(name): \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    private func merge(defaults D: [String: MCPServerConfig], file F: [String: MCPServerConfig]) -> [String: MCPServerConfig] {
        var result: [String: MCPServerConfig] = [:]
        let keys = Set(D.keys).union(F.keys)
        for k in keys {
            if let f = F[k] {
                if f.enabled == false { continue }
                if let d = D[k] {
                    // Fill missing fields from defaults
                    var merged = f
                    if merged.transport.isEmpty { merged.transport = d.transport }
                    if merged.command.isEmpty { merged.command = d.command }
                    if merged.args.isEmpty { merged.args = d.args }
                    if merged.env.isEmpty { merged.env = d.env }
                    if merged.timeout <= 0 { merged.timeout = d.timeout }
                    if merged.description == nil { merged.description = d.description }
                    result[k] = merged
                } else {
                    result[k] = f
                }
            } else if let d = D[k], d.enabled {
                result[k] = d
            }
        }
        return result
    }

    // MARK: File loading
    private func loadFileConfigs() -> [String: MCPServerConfig] {
        guard let json = self.loadRawConfigJSON() else { return [:] }
        guard let mcp = json["mcpClients"] as? [String: Any] else { return [:] }
        var out: [String: MCPServerConfig] = [:]
        for (name, value) in mcp {
            guard let dict = value as? [String: Any] else { continue }
            let transport = (dict["transport"] as? String) ?? "stdio"
            let command = (dict["command"] as? String) ?? ""
            let args = (dict["args"] as? [String]) ?? []
            let env = (dict["env"] as? [String: String]) ?? [:]
            let headers = (dict["headers"] as? [String: String])
            let enabled = (dict["enabled"] as? Bool) ?? true
            let timeout = (dict["timeout"] as? Double) ?? 30
            let autoReconnect = (dict["autoReconnect"] as? Bool) ?? true
            let description = dict["description"] as? String
            out[name] = MCPServerConfig(
                transport: transport,
                command: command,
                args: args,
                env: env,
                headers: headers,
                enabled: enabled,
                timeout: timeout,
                autoReconnect: autoReconnect,
                description: description
            )
        }
        return out
    }

    private func loadRawConfigJSON() -> [String: Any]? {
        let path = self.profileConfigPath()
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        do {
            let raw = try String(contentsOfFile: path)
            let cleaned = Self.stripJSONComments(from: raw)
            let expanded = Self.expandEnvironmentVariables(in: cleaned)
            if let data = expanded.data(using: .utf8) {
                return try JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
        } catch {
            logger.error("Failed to load config.json: \(error.localizedDescription)")
        }
        return nil
    }

    private func ensureProfileDirectoryExists() throws {
        let dir = self.profileDirectoryPath()
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    private func profileDirectoryPath() -> String {
        #if os(Windows)
        let home = ProcessInfo.processInfo.environment["USERPROFILE"] ?? ""
        #else
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
        #endif
        return "\(home)/\(self.profileDirectoryName)"
    }

    private func profileConfigPath() -> String {
        "\(self.profileDirectoryPath())/config.json"
    }

    // MARK: JSONC + ENV utilities (shared minimal)
    static func stripJSONComments(from json: String) -> String {
        var result = ""
        var inString = false
        var escapeNext = false
        var inSingle = false
        var inMulti = false
        let chars = Array(json)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let n: Character? = i + 1 < chars.count ? chars[i + 1] : nil
            if escapeNext { result.append(c); escapeNext = false; i += 1; continue }
            if c == "\\" && inString { escapeNext = true; result.append(c); i += 1; continue }
            if c == "\"" && !inSingle && !inMulti { inString.toggle(); result.append(c); i += 1; continue }
            if inString { result.append(c); i += 1; continue }
            if c == "/" && n == "/" && !inMulti { inSingle = true; i += 2; continue }
            if c == "/" && n == "*" && !inSingle { inMulti = true; i += 2; continue }
            if c == "\n" && inSingle { inSingle = false; result.append(c); i += 1; continue }
            if c == "*" && n == "/" && inMulti { inMulti = false; i += 2; continue }
            if !inSingle && !inMulti { result.append(c) }
            i += 1
        }
        return result
    }

    static func expandEnvironmentVariables(in text: String) -> String {
        let pattern = #"\$\{([A-Za-z_][A-Za-z0-9_]*)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        var result = text
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed()
        for m in matches {
            let nameRange = m.range(at: 1)
            let fullRange = m.range(at: 0)
            if nameRange.location != NSNotFound, let swiftName = Range(nameRange, in: text), let swiftFull = Range(fullRange, in: text) {
                let name = String(text[swiftName])
                if let val = ProcessInfo.processInfo.environment[name] {
                    result.replaceSubrange(swiftFull, with: val)
                }
            }
        }
        return result
    }
}
