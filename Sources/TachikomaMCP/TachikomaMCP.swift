import MCP

// Re-export all public APIs from TachikomaMCP module
// This file serves as the main entry point for the module

// Simply having the public types in the module is enough
// Swift will automatically make them available when importing TachikomaMCP

// Users can import like:
// import TachikomaMCP
//
// And then use:
// - MCPTool, ToolArguments, ToolResponse
// - SchemaBuilder
// - MCPClient, MCPServerConfig
// - MCPTransport, StdioTransport, SSETransport, HTTPTransport
// - MCPError
// - MCPToolAdapter, MCPToolProvider
// - MCPToolDiscovery

// Note: MCP.Value is used directly in the module, no need for re-export
