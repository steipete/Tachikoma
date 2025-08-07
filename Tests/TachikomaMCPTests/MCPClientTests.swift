//
//  MCPClientTests.swift
//  TachikomaMCPTests
//

import Testing
import Foundation
@testable import TachikomaMCP
@testable import Tachikoma
import MCP

@Suite("MCP Client Tests")
struct MCPClientTests {
    
    @Test("MCPServerConfig initialization with all parameters")
    func testServerConfigFullInit() {
        let config = MCPServerConfig(
            transport: "stdio",
            command: "npx",
            args: ["test-server", "--verbose"],
            env: ["API_KEY": "test123"],
            enabled: true,
            timeout: 30,
            autoReconnect: true,
            description: "Test server"
        )
        
        #expect(config.transport == "stdio")
        #expect(config.command == "npx")
        #expect(config.args == ["test-server", "--verbose"])
        #expect(config.env["API_KEY"] == "test123")
        #expect(config.enabled == true)
        #expect(config.timeout == 30)
        #expect(config.autoReconnect == true)
        #expect(config.description == "Test server")
    }
    
    @Test("MCPServerConfig initialization with minimal parameters")
    func testServerConfigMinimalInit() {
        let config = MCPServerConfig(command: "test")
        
        #expect(config.transport == "stdio")
        #expect(config.command == "test")
        #expect(config.args.isEmpty)
        #expect(config.env.isEmpty)
        #expect(config.enabled == true)
        #expect(config.timeout == 30)  // Default is 30, not nil
        #expect(config.autoReconnect == true)  // Default is true, not false
        #expect(config.description == nil)
    }
    
    @Test("MCPClient initialization")
    func testClientInit() {
        let config = MCPServerConfig(
            command: "test-command",
            args: ["arg1"],
            description: "Test"
        )
        
        let client = MCPClient(name: "test-client", config: config)
        
        // Just verify it initializes without crashing
        // Note: name and serverConfig are private, so we can't test them directly
        #expect(client != nil)
    }
    
    @Test("MCPError descriptions")
    func testErrorDescriptions() {
        #expect(MCPError.serverDisabled.errorDescription == "MCP server is disabled")
        #expect(MCPError.notConnected.errorDescription == "MCP client is not connected")
        #expect(MCPError.invalidResponse.errorDescription == "Invalid response from MCP server")
        #expect(MCPError.unsupportedTransport("test").errorDescription == "Unsupported transport: test")
        #expect(MCPError.connectionFailed("timeout").errorDescription == "Connection failed: timeout")
        #expect(MCPError.executionFailed("error").errorDescription == "Execution failed: error")
    }
    
    @Test("ToolArguments convenience methods")
    func testToolArgumentsConvenienceMethods() {
        let args = ToolArguments(raw: [
            "text": "hello",
            "number": 42,
            "float": 3.14,
            "bool": true,
            "array": ["a", "b", "c"],
            "null": NSNull()
        ])
        
        // Test getString
        #expect(args.getString("text") == "hello")
        #expect(args.getString("number") == "42")
        #expect(args.getString("bool") == "true")
        #expect(args.getString("missing") == nil)
        
        // Test getInt
        #expect(args.getInt("number") == 42)
        #expect(args.getInt("float") == 3)
        #expect(args.getInt("missing") == nil)
        
        // Test getNumber
        #expect(args.getNumber("number") == 42.0)
        #expect(args.getNumber("float") == 3.14)
        #expect(args.getNumber("missing") == nil)
        
        // Test getBool
        #expect(args.getBool("bool") == true)
        #expect(args.getBool("missing") == nil)
        
        // Test getStringArray
        let stringArray = args.getStringArray("array")
        #expect(stringArray == ["a", "b", "c"])
        #expect(args.getStringArray("missing") == nil)
        
        // Test isEmpty
        #expect(args.isEmpty == false)
        let emptyArgs = ToolArguments(raw: [:])
        #expect(emptyArgs.isEmpty == true)
    }
    
    @Test("ToolArguments from Value")
    func testToolArgumentsFromValue() {
        let value = Value.object([
            "name": .string("test"),
            "count": .int(42),
            "active": .bool(true)
        ])
        
        let args = ToolArguments(value: value)
        
        #expect(args.getString("name") == "test")
        #expect(args.getInt("count") == 42)
        #expect(args.getBool("active") == true)
    }
    
    @Test("ToolResponse creation methods")
    func testToolResponseCreation() {
        // Text response
        let textResponse = ToolResponse.text("Success")
        #expect(textResponse.content.count == 1)
        #expect(textResponse.isError == false)
        if case let .text(text) = textResponse.content.first {
            #expect(text == "Success")
        } else {
            Issue.record("Expected text content")
        }
        
        // Error response
        let errorResponse = ToolResponse.error("Failed")
        #expect(errorResponse.isError == true)
        if case let .text(text) = errorResponse.content.first {
            #expect(text == "Failed")
        } else {
            Issue.record("Expected text content")
        }
        
        // Image response
        let imageData = Data("test".utf8)
        let imageResponse = ToolResponse.image(data: imageData, mimeType: "image/png")
        #expect(imageResponse.content.count == 1)
        if case let .image(data, mimeType, _) = imageResponse.content.first {
            #expect(data == imageData.base64EncodedString())
            #expect(mimeType == "image/png")
        } else {
            Issue.record("Expected image content")
        }
        
        // Multi-content response
        let multiResponse = ToolResponse.multiContent([
            .text("Part 1"),
            .text("Part 2")
        ])
        #expect(multiResponse.content.count == 2)
    }
    
    @Test("ToolResponse with metadata")
    func testToolResponseWithMetadata() {
        let meta = Value.object([
            "executionTime": .double(1.5),
            "status": .string("ok")
        ])
        
        let response = ToolResponse.text("Result", meta: meta)
        
        #expect(response.meta != nil)
        if case let .object(metaDict) = response.meta {
            #expect(metaDict["executionTime"] == .double(1.5))
            #expect(metaDict["status"] == .string("ok"))
        } else {
            Issue.record("Expected metadata object")
        }
    }
    
    @Test("MCPToolProvider initialization")
    func testToolProviderInit() {
        let config = MCPServerConfig(command: "test")
        let client = MCPClient(name: "test", config: config)
        let provider = MCPToolProvider(client: client)
        
        // Just verify it initializes without crashing
        // Note: client property is private
        #expect(provider != nil)
    }
    
    @Test("MCPToolProvider as DynamicToolProvider")
    func testToolProviderAsDynamicToolProvider() {
        let config = MCPServerConfig(command: "test")
        let client = MCPClient(name: "test-server", config: config)
        let provider = MCPToolProvider(client: client)
        
        // Test that it conforms to DynamicToolProvider
        let dynamicProvider: DynamicToolProvider = provider
        // Note: DynamicToolProvider protocol doesn't require an 'id' property
        #expect(dynamicProvider != nil)
    }
    
    @Test("Tool metadata structure")
    func testToolMetadata() {
        let tool = MCP.Tool(
            name: "test-tool",
            description: "A test tool",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "message": .object([
                        "type": .string("string")
                    ])
                ])
            ])
        )
        
        #expect(tool.name == "test-tool")
        #expect(tool.description == "A test tool")
        if case let .object(schema) = tool.inputSchema {
            #expect(schema["type"] == .string("object"))
            if case let .object(props) = schema["properties"] {
                #expect(props["message"] != nil)
            }
        } else {
            Issue.record("Expected object schema")
        }
    }
    
    @Test("Value encoding and decoding")
    func testValueEncodingDecoding() throws {
        let originalValue = Value.object([
            "string": .string("test"),
            "number": .int(42),
            "float": .double(3.14),
            "bool": .bool(true),
            "null": .null,
            "array": .array([.string("a"), .string("b")]),
            "object": .object(["nested": .string("value")])
        ])
        
        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalValue)
        
        // Decode back
        let decoder = JSONDecoder()
        let decodedValue = try decoder.decode(Value.self, from: data)
        
        #expect(originalValue == decodedValue)
    }
    
    @Test("ToolArguments decoding")
    func testToolArgumentsDecoding() throws {
        struct TestArgs: Decodable {
            let name: String
            let count: Int
            let active: Bool
        }
        
        let args = ToolArguments(raw: [
            "name": "test",
            "count": 42,
            "active": true
        ])
        
        let decoded = try args.decode(TestArgs.self)
        #expect(decoded.name == "test")
        #expect(decoded.count == 42)
        #expect(decoded.active == true)
    }
}

// MARK: - Mock MCP Tool for Testing

private struct MockMCPTool: MCPTool {
    let name: String = "mock_tool"
    let description: String = "A mock tool for testing"
    
    var inputSchema: Value {
        .object([
            "type": .string("object"),
            "properties": .object([
                "message": .object([
                    "type": .string("string"),
                    "description": .string("Test message")
                ])
            ]),
            "required": .array([.string("message")])
        ])
    }
    
    func execute(arguments: ToolArguments) async throws -> ToolResponse {
        guard let message = arguments.getString("message") else {
            return .error("Missing required 'message' parameter")
        }
        
        return .text("Received: \(message)")
    }
}

@Suite("Mock Tool Tests")
struct MockToolTests {
    
    @Test("Mock tool execution with valid arguments")
    func testMockToolValidExecution() async throws {
        let tool = MockMCPTool()
        
        let args = ToolArguments(raw: ["message": "Hello World"])
        let response = try await tool.execute(arguments: args)
        
        #expect(response.isError == false)
        if case let .text(text) = response.content.first {
            #expect(text == "Received: Hello World")
        } else {
            Issue.record("Expected text response")
        }
    }
    
    @Test("Mock tool execution with missing arguments")
    func testMockToolMissingArguments() async throws {
        let tool = MockMCPTool()
        
        let args = ToolArguments(raw: [:])
        let response = try await tool.execute(arguments: args)
        
        #expect(response.isError == true)
        if case let .text(text) = response.content.first {
            #expect(text == "Missing required 'message' parameter")
        } else {
            Issue.record("Expected error text")
        }
    }
    
    @Test("Mock tool schema validation")
    func testMockToolSchema() {
        let tool = MockMCPTool()
        
        #expect(tool.name == "mock_tool")
        #expect(tool.description == "A mock tool for testing")
        
        if case let .object(schema) = tool.inputSchema {
            #expect(schema["type"] == .string("object"))
            
            if case let .object(properties) = schema["properties"],
               case let .object(messageSchema) = properties["message"] {
                #expect(messageSchema["type"] == .string("string"))
                #expect(messageSchema["description"] == .string("Test message"))
            } else {
                Issue.record("Expected properties.message object")
            }
            
            if case let .array(required) = schema["required"] {
                #expect(required.contains(.string("message")))
            } else {
                Issue.record("Expected required array")
            }
        } else {
            Issue.record("Expected object schema")
        }
    }
}