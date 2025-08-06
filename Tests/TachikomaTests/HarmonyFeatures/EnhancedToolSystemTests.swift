//
//  EnhancedToolSystemTests.swift
//  Tachikoma
//

import Testing
@testable import Tachikoma

@Suite("Enhanced Tool System")
struct EnhancedToolSystemTests {
    
    @Test("ToolCall supports namespace and recipient")
    func testToolCallNamespaceRecipient() {
        let toolCall = ToolCall(
            id: "call-123",
            name: "search",
            arguments: ["query": .string("test")],
            namespace: "web",
            recipient: "google-search"
        )
        
        #expect(toolCall.id == "call-123")
        #expect(toolCall.name == "search")
        #expect(toolCall.namespace == "web")
        #expect(toolCall.recipient == "google-search")
        #expect(toolCall.arguments["query"] == .string("test"))
    }
    
    @Test("ToolCall works without namespace and recipient")
    func testToolCallWithoutNamespaceRecipient() {
        let toolCall = ToolCall(
            name: "calculate",
            arguments: ["expression": .string("2+2")]
        )
        
        #expect(toolCall.namespace == nil)
        #expect(toolCall.recipient == nil)
        #expect(toolCall.name == "calculate")
    }
    
    @Test("SimpleTool supports namespace and recipient")
    func testSimpleToolNamespaceRecipient() {
        let tool = SimpleTool(
            name: "readFile",
            description: "Read file contents",
            parameters: ToolParameters(
                properties: [
                    ToolParameterProperty(
                        name: "path",
                        type: .string,
                        description: "File path"
                    )
                ],
                required: ["path"]
            ),
            namespace: "filesystem",
            recipient: "local-fs",
            execute: { args in
                .string("file contents")
            }
        )
        
        #expect(tool.name == "readFile")
        #expect(tool.namespace == "filesystem")
        #expect(tool.recipient == "local-fs")
        #expect(tool.description == "Read file contents")
    }
    
    @Test("SimpleTool works without namespace and recipient")
    func testSimpleToolWithoutNamespaceRecipient() {
        let tool = SimpleTool(
            name: "echo",
            description: "Echo input",
            parameters: ToolParameters(properties: [], required: []),
            execute: { args in .string("echo") }
        )
        
        #expect(tool.namespace == nil)
        #expect(tool.recipient == nil)
        #expect(tool.name == "echo")
    }
    
    @Test("Tool organization by namespace")
    func testToolOrganizationByNamespace() {
        let tools = [
            SimpleTool(
                name: "readFile",
                description: "Read file",
                parameters: ToolParameters(properties: [], required: []),
                namespace: "filesystem",
                execute: { _ in .string("") }
            ),
            SimpleTool(
                name: "writeFile",
                description: "Write file",
                parameters: ToolParameters(properties: [], required: []),
                namespace: "filesystem",
                execute: { _ in .string("") }
            ),
            SimpleTool(
                name: "query",
                description: "Database query",
                parameters: ToolParameters(properties: [], required: []),
                namespace: "database",
                execute: { _ in .string("") }
            ),
            SimpleTool(
                name: "search",
                description: "Web search",
                parameters: ToolParameters(properties: [], required: []),
                namespace: "web",
                execute: { _ in .string("") }
            )
        ]
        
        // Group by namespace
        var toolsByNamespace: [String?: [SimpleTool]] = [:]
        for tool in tools {
            toolsByNamespace[tool.namespace, default: []].append(tool)
        }
        
        #expect(toolsByNamespace["filesystem"]?.count == 2)
        #expect(toolsByNamespace["database"]?.count == 1)
        #expect(toolsByNamespace["web"]?.count == 1)
    }
    
    @Test("Tool routing by recipient")
    func testToolRoutingByRecipient() {
        let tools = [
            SimpleTool(
                name: "query",
                description: "Query database",
                parameters: ToolParameters(properties: [], required: []),
                namespace: "database",
                recipient: "postgres-primary",
                execute: { _ in .string("primary result") }
            ),
            SimpleTool(
                name: "query",
                description: "Query database",
                parameters: ToolParameters(properties: [], required: []),
                namespace: "database",
                recipient: "postgres-replica",
                execute: { _ in .string("replica result") }
            )
        ]
        
        // Find tool for specific recipient
        let primaryTool = tools.first { $0.recipient == "postgres-primary" }
        let replicaTool = tools.first { $0.recipient == "postgres-replica" }
        
        #expect(primaryTool != nil)
        #expect(replicaTool != nil)
        #expect(primaryTool?.name == "query")
        #expect(replicaTool?.name == "query")
    }
    
    @Test("ToolCall Codable with namespace and recipient")
    func testToolCallCodableWithNamespaceRecipient() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let decoder = JSONDecoder()
        
        let original = ToolCall(
            id: "test-123",
            name: "search",
            arguments: ["query": .string("Swift")],
            namespace: "web",
            recipient: "duckduckgo"
        )
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ToolCall.self, from: data)
        
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.namespace == original.namespace)
        #expect(decoded.recipient == original.recipient)
        #expect(decoded.arguments["query"] == original.arguments["query"])
    }
    
    @Test("ToolCall Codable without namespace and recipient")
    func testToolCallCodableWithoutNamespaceRecipient() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let original = ToolCall(
            name: "calculate",
            arguments: ["expr": .double(42.0)]
        )
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ToolCall.self, from: data)
        
        #expect(decoded.namespace == nil)
        #expect(decoded.recipient == nil)
        #expect(decoded.name == "calculate")
    }
    
    @Test("Tool execution with namespace context")
    func testToolExecutionWithNamespaceContext() async throws {
        actor NamespaceCapture {
            var namespace: String?
            func set(_ value: String) { namespace = value }
        }
        
        let capture = NamespaceCapture()
        
        let tool = SimpleTool(
            name: "contextAware",
            description: "Namespace-aware tool",
            parameters: ToolParameters(properties: [], required: []),
            namespace: "test-namespace",
            execute: { args in
                // In real implementation, namespace could be passed via context
                await capture.set("test-namespace")
                return .string("executed in namespace")
            }
        )
        
        let toolArgs = ToolArguments([:])
        let result = try await tool.execute(toolArgs)
        #expect(result == .string("executed in namespace"))
        #expect(await capture.namespace == "test-namespace")
    }
    
    @Test("Multiple tools with same name but different namespaces")
    func testMultipleToolsSameNameDifferentNamespaces() {
        let webSearch = SimpleTool(
            name: "search",
            description: "Web search",
            parameters: ToolParameters(properties: [], required: []),
            namespace: "web",
            execute: { _ in .string("web results") }
        )
        
        let dbSearch = SimpleTool(
            name: "search",
            description: "Database search",
            parameters: ToolParameters(properties: [], required: []),
            namespace: "database",
            execute: { _ in .string("db results") }
        )
        
        let fileSearch = SimpleTool(
            name: "search",
            description: "File search",
            parameters: ToolParameters(properties: [], required: []),
            namespace: "filesystem",
            execute: { _ in .string("file results") }
        )
        
        // All have same name but different namespaces
        #expect(webSearch.name == dbSearch.name)
        #expect(dbSearch.name == fileSearch.name)
        #expect(webSearch.namespace != dbSearch.namespace)
        #expect(dbSearch.namespace != fileSearch.namespace)
        #expect(webSearch.namespace != fileSearch.namespace)
    }
}