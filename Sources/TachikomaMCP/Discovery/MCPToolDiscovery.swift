//
//  MCPToolDiscovery.swift
//  TachikomaMCP
//

import Foundation
import MCP
import Tachikoma
import Logging

/// Utility for discovering and connecting to MCP servers
public enum MCPToolDiscovery {
    
    private static let logger = Logger(label: "tachikoma.mcp.discovery")
    
    /// Discover tools from a command-line MCP server
    public static func discover(from command: String, args: [String] = []) async throws -> [AgentTool] {
        let config = MCPServerConfig(
            transport: "stdio",
            command: command,
            args: args
        )
        
        return try await discover(from: config, name: extractName(from: command))
    }
    
    /// Discover tools from an MCP server with configuration
    public static func discover(from config: MCPServerConfig, name: String) async throws -> [AgentTool] {
        let client = MCPClient(name: name, config: config)
        let provider = MCPToolProvider(client: client)
        
        // Connect and get tools
        try await provider.connect()
        return try await provider.getAgentTools()
    }
    
    /// Connect to an MCP server and return a provider
    public static func connectServer(_ config: MCPServerConfig, name: String? = nil) async throws -> MCPToolProvider {
        let serverName = name ?? extractName(from: config.command)
        let client = MCPClient(name: serverName, config: config)
        let provider = MCPToolProvider(client: client)
        
        // Connect to ensure it's ready
        try await provider.connect()
        
        logger.info("Connected to MCP server '\(serverName)'")
        
        return provider
    }
    
    /// Connect to multiple MCP servers
    public static func connectServers(_ configs: [String: MCPServerConfig]) async throws -> [String: MCPToolProvider] {
        var providers: [String: MCPToolProvider] = [:]
        
        await withTaskGroup(of: (String, Result<MCPToolProvider, Swift.Error>).self) { group in
            for (name, config) in configs {
                group.addTask {
                    do {
                        let provider = try await connectServer(config, name: name)
                        return (name, .success(provider))
                    } catch {
                        return (name, .failure(error))
                    }
                }
            }
            
            for await (name, result) in group {
                switch result {
                case .success(let provider):
                    providers[name] = provider
                    logger.info("Successfully connected to '\(name)'")
                case .failure(let error):
                    logger.error("Failed to connect to '\(name)': \(error)")
                }
            }
        }
        
        return providers
    }
    
    /// Discover all tools from multiple providers
    public static func discoverAll(from providers: [MCPToolProvider]) async throws -> [AgentTool] {
        var allTools: [AgentTool] = []
        
        for provider in providers {
            let tools = try await provider.getAgentTools()
            allTools.append(contentsOf: tools)
        }
        
        // Deduplicate tools by name (keeping first occurrence)
        var seen = Set<String>()
        return allTools.filter { tool in
            if seen.contains(tool.name) {
                logger.warning("Duplicate tool '\(tool.name)' found, keeping first occurrence")
                return false
            }
            seen.insert(tool.name)
            return true
        }
    }
    
    /// Create providers for common MCP servers
    public static func commonProviders() -> [String: MCPServerConfig] {
        return [
            "filesystem": MCPServerConfig(
                transport: "stdio",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-filesystem"],
                description: "File system operations"
            ),
            "github": MCPServerConfig(
                transport: "stdio",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-github"],
                env: ["GITHUB_PERSONAL_ACCESS_TOKEN": ProcessInfo.processInfo.environment["GITHUB_TOKEN"] ?? ""],
                description: "GitHub API access"
            ),
            "browser": MCPServerConfig(
                transport: "stdio",
                command: "npx",
                args: ["-y", "@agent-infra/mcp-server-browser"],
                description: "Browser automation"
            ),
            "postgres": MCPServerConfig(
                transport: "stdio",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-postgres"],
                env: ["DATABASE_URL": ProcessInfo.processInfo.environment["DATABASE_URL"] ?? ""],
                description: "PostgreSQL database access"
            )
        ]
    }
    
    // MARK: - Private Helpers
    
    private static func extractName(from command: String) -> String {
        // Extract a reasonable name from the command
        let components = command.split(separator: "/")
        if let last = components.last {
            return String(last).replacingOccurrences(of: ".js", with: "")
                .replacingOccurrences(of: "-server", with: "")
                .replacingOccurrences(of: "mcp-", with: "")
        }
        return "mcp-server"
    }
}

// MARK: - Convenience Extensions

extension MCPToolDiscovery {
    
    /// Quick start with filesystem tools
    public static func withFilesystem(path: String = ".") async throws -> [AgentTool] {
        let config = MCPServerConfig(
            transport: "stdio",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-filesystem", path]
        )
        return try await discover(from: config, name: "filesystem")
    }
    
    /// Quick start with GitHub tools
    public static func withGitHub(token: String? = nil) async throws -> [AgentTool] {
        let githubToken = token ?? ProcessInfo.processInfo.environment["GITHUB_TOKEN"] ?? ""
        
        guard !githubToken.isEmpty else {
            throw MCPError.connectionFailed("GitHub token required (set GITHUB_TOKEN environment variable)")
        }
        
        let config = MCPServerConfig(
            transport: "stdio",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-github"],
            env: ["GITHUB_PERSONAL_ACCESS_TOKEN": githubToken]
        )
        
        return try await discover(from: config, name: "github")
    }
    
    /// Quick start with browser automation
    public static func withBrowser() async throws -> [AgentTool] {
        let config = MCPServerConfig(
            transport: "stdio",
            command: "npx",
            args: ["-y", "@agent-infra/mcp-server-browser"]
        )
        return try await discover(from: config, name: "browser")
    }
}