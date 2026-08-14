# TachikomaMCP

Optional MCP (Model Context Protocol) extension for Tachikoma that enables connection to external tool servers.

## Installation

TachikomaMCP is an optional module. You can use Tachikoma without it for a lightweight experience, or import both for full MCP support.

### Lightweight (No MCP)
```swift
import Tachikoma

// Use Tachikoma normally without MCP
let result = try await generateText(
    model: .openai(.gpt55),
    messages: messages,
    tools: staticTools
)
```

### With MCP Support
```swift
import Tachikoma
import TachikomaMCP

// Now you can use MCP tools alongside static tools
let mcpTools = try await MCPToolDiscovery.withFilesystem()
let result = try await generateText(
    model: .openai(.gpt55),
    messages: messages,
    tools: staticTools + mcpTools
)
```

## Quick Start

### Connect to Common MCP Servers

```swift
import TachikomaMCP

// Filesystem access
let fsTools = try await MCPToolDiscovery.withFilesystem(path: "/path/to/files")

// GitHub API
let githubTools = try await MCPToolDiscovery.withGitHub()  // Uses GITHUB_TOKEN env var

// Browser automation
let browserTools = try await MCPToolDiscovery.withChromeDevTools()
```

### Custom MCP Server

```swift
// Configure custom server
let config = MCPServerConfig(
    transport: "stdio",
    command: "npx",
    args: ["-y", "@your/mcp-server"],
    env: ["API_KEY": "your-key"]
)

// Connect and discover tools
let tools = try await MCPToolDiscovery.discover(from: config, name: "custom-server")
```

### Using MCP Provider

```swift
// Create provider
let provider = MCPToolProvider(
    name: "my-server",
    config: MCPServerConfig(
        command: "npx",
        args: ["my-mcp-server"]
    )
)

// Connect and get tools
try await provider.connect()
let tools = try await provider.getAgentTools()

// Use with Tachikoma generation
let result = try await generateText(
    model: .anthropic(.opus4),
    messages: messages,
    tools: tools
)
```

### Multiple MCP Servers

```swift
// Define servers
let configs = [
    "filesystem": MCPServerConfig(
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-filesystem"]
    ),
    "github": MCPServerConfig(
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-github"],
        env: ["GITHUB_PERSONAL_ACCESS_TOKEN": githubToken]
    )
]

// Connect to all
let providers = try await MCPToolDiscovery.connectServers(configs)

// Get all tools
var allTools: [AgentTool] = []
for provider in providers.values {
    let tools = try await provider.getAgentTools()
    allTools.append(contentsOf: tools)
}
```

## Architecture

### Modular Design

- **Core Tachikoma**: Lightweight, no MCP dependencies (~500KB)
- **TachikomaMCP**: Optional MCP support (~1MB additional)
- **Pay for what you use**: Only include MCP if needed

### Components

- **MCPClient**: Core client for connecting to MCP servers
- **Transports**: Stdio, SSE, and HTTP transport implementations
- **MCPToolProvider**: Implements Tachikoma's DynamicToolProvider
- **MCPToolAdapter**: Converts between MCP and Tachikoma formats
- **MCPToolDiscovery**: Utility functions for easy setup

## MCP Servers

MCP servers are external processes that expose tools via the Model Context Protocol. Popular servers include:

- `@modelcontextprotocol/server-filesystem` - File system operations
- `@modelcontextprotocol/server-github` - GitHub API access
- `chrome-devtools-mcp` - Chrome DevTools automation
- `@modelcontextprotocol/server-postgres` - PostgreSQL database
- Custom servers for your specific needs

## Advanced Usage

### Custom Transport

```swift
enum MyTransportError: Error {
    case notImplemented
}

// Implement the complete transport lifecycle.
actor MyCustomTransport: MCPTransport {
    func connect(config: MCPServerConfig) async throws {
        // Custom connection logic
    }

    func disconnect() async {
        // Release transport resources and fail pending requests.
    }
    
    func sendRequest<R: Decodable>(
        method: String,
        params: some Encodable
    ) async throws -> R {
        // Encode the request, await its matching response, and decode R.
        throw MyTransportError.notImplemented
    }

    func sendNotification(
        method: String,
        params: some Encodable
    ) async throws {
        // Encode and send without waiting for a response.
    }
}
```

`MCPClient` selects the bundled stdio, HTTP, or SSE transport from `MCPServerConfig`. The protocol is public for wrappers and alternate clients that need the same request/notification contract.

### Tool Filtering

```swift
// Discover and filter tools
let provider = try await MCPToolDiscovery.connectServer(config, name: "server")
let tools = try await provider.getAgentTools()

// Filter tools by name or description
let filteredTools = tools.filter { tool in
    tool.name.contains("read") || tool.description.contains("file")
}
```

### Error Handling

```swift
do {
    let tools = try await MCPToolDiscovery.withFilesystem()
    // Use tools
} catch MCPError.connectionFailed(let reason) {
    print("Failed to connect: \(reason)")
} catch MCPError.notConnected {
    print("Server disconnected")
} catch {
    print("Unexpected error: \(error)")
}
```

## Requirements

- Swift 6.2+
- macOS 14+, iOS 17+, watchOS 10+, tvOS 17+, visionOS 1+
- MCP servers require Node.js for `npx` commands

## License

Same as Tachikoma - see main LICENSE file.
