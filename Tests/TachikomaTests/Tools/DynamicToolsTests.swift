//
//  DynamicToolsTests.swift
//  TachikomaTests
//

import Testing
@testable import Tachikoma

@Suite("Dynamic Tools System Tests")
struct DynamicToolsTests {
    
    @Test("DynamicTool creates valid AgentTool")
    func testDynamicToolToAgentTool() async throws {
        let schema = DynamicSchema(
            type: .object,
            properties: [
                "query": SchemaProperty(type: .string, description: "Search query"),
                "limit": SchemaProperty(type: .integer, description: "Result limit")
            ],
            required: ["query"]
        )
        
        let dynamicTool = DynamicTool(
            name: "search",
            description: "Search for information",
            schema: schema
        )
        
        let agentTool = dynamicTool.toAgentTool { args in
            .string("Searched for: \(args["query"] ?? .null)")
        }
        
        #expect(agentTool.name == "search")
        #expect(agentTool.description == "Search for information")
        #expect(agentTool.parameters.required == ["query"])
        
        // Test execution
        let result = try await agentTool.execute(["query": .string("test")])
        #expect(result == .string("Searched for: string(\"test\")"))
    }
    
    @Test("DynamicSchema converts to AgentToolParameters")
    func testSchemaConversion() throws {
        let schema = DynamicSchema(
            type: .object,
            properties: [
                "name": SchemaProperty(type: .string, description: "User name"),
                "age": SchemaProperty(type: .integer, description: "User age"),
                "active": SchemaProperty(type: .boolean, description: "Is active")
            ],
            required: ["name"]
        )
        
        let parameters = schema.toAgentToolParameters()
        
        #expect(parameters.type == "object")
        #expect(parameters.required == ["name"])
        #expect(parameters.properties["name"]?.type == .string)
        #expect(parameters.properties["age"]?.type == .integer)
        #expect(parameters.properties["active"]?.type == .boolean)
    }
    
    @Test("SchemaProperty handles nested structures")
    func testNestedSchemaProperty() throws {
        let addressSchema = SchemaProperty(
            type: .object,
            description: "Address",
            properties: [
                "street": SchemaProperty(type: .string, description: "Street name"),
                "city": SchemaProperty(type: .string, description: "City name")
            ]
        )
        
        let userSchema = DynamicSchema(
            type: .object,
            properties: [
                "name": SchemaProperty(type: .string, description: "Name"),
                "address": addressSchema
            ]
        )
        
        let parameters = userSchema.toAgentToolParameters()
        #expect(parameters.properties["address"]?.type == .object)
    }
    
    @Test("DynamicToolRegistry manages tools")
    func testDynamicToolRegistry() async throws {
        let registry = DynamicToolRegistry()
        
        // Register a tool
        let tool = DynamicTool(
            name: "test_tool",
            description: "A test tool",
            schema: DynamicSchema(type: .object)
        )
        
        await registry.registerTool(tool) { args in
            .string("Executed test_tool")
        }
        
        // Get agent tools
        let agentTools = await registry.getAgentTools()
        #expect(agentTools.count == 1)
        #expect(agentTools[0].name == "test_tool")
        
        // Execute tool
        let result = try await registry.executeTool(
            name: "test_tool",
            arguments: [:]
        )
        #expect(result == .string("Executed test_tool"))
        
        // Unregister tool
        await registry.unregisterTool(name: "test_tool")
        let remainingTools = await registry.getAgentTools()
        #expect(remainingTools.isEmpty)
    }
    
    @Test("DynamicToolProvider discovers tools")
    func testDynamicToolProvider() async throws {
        let provider = MCPToolProvider(
            endpoint: URL(string: "https://example.com/mcp")!
        )
        
        let tools = try await provider.discoverTools()
        #expect(tools.count == 2)
        #expect(tools[0].name == "search_web")
        #expect(tools[1].name == "get_weather")
        
        // Test tool execution
        let result = try await provider.executeTool(
            name: "search_web",
            arguments: ["query": .string("Swift")]
        )
        #expect(result == .string("Mock search results for: string(\"Swift\")"))
    }
    
    @Test("DynamicToolRegistry with provider")
    func testRegistryWithProvider() async throws {
        let registry = DynamicToolRegistry()
        let provider = MCPToolProvider(
            endpoint: URL(string: "https://example.com/mcp")!
        )
        
        await registry.registerProvider(provider, id: "mcp")
        try await registry.discoverTools()
        
        let tools = await registry.getAgentTools()
        #expect(tools.count == 2)
        
        // Execute discovered tool
        let result = try await registry.executeTool(
            name: "get_weather",
            arguments: ["location": .string("New York")]
        )
        
        if case .object(let dict) = result {
            #expect(dict["temperature"] == .double(72))
            #expect(dict["condition"] == .string("Sunny"))
            #expect(dict["location"] == .string("New York"))
        } else {
            Issue.record("Expected object result")
        }
    }
    
    @Test("SchemaBuilder creates schemas fluently")
    func testSchemaBuilder() throws {
        let schema = SchemaBuilder.object()
            .property("username", type: .string, description: "Username", required: true)
            .property("email", type: .string, description: "Email", required: true)
            .property("age", type: .integer, description: "Age")
            .property("active", type: .boolean, description: "Is active")
            .build()
        
        #expect(schema.type == .object)
        #expect(schema.required == ["username", "email"])
        #expect(schema.properties?.count == 4)
    }
    
    @Test("SchemaBuilder with array schema")
    func testSchemaBuilderArray() throws {
        let itemSchema = SchemaProperty(type: .string, description: "Item")
        
        let schema = SchemaBuilder.array()
            .items(itemSchema)
            .minLength(1)
            .maxLength(10)
            .build()
        
        #expect(schema.type == .array)
        #expect(schema.items != nil)
        #expect(schema.minLength == 1)
        #expect(schema.maxLength == 10)
    }
    
    @Test("SchemaBuilder with enum values")
    func testSchemaBuilderEnum() throws {
        let schema = SchemaBuilder.string()
            .enumValues(["red", "green", "blue"])
            .build()
        
        #expect(schema.type == .string)
        #expect(schema.enumValues == ["red", "green", "blue"])
    }
    
    @Test("SchemaBuilder with number constraints")
    func testSchemaBuilderNumberConstraints() throws {
        let schema = SchemaBuilder.number()
            .minimum(0)
            .maximum(100)
            .format("percentage")
            .build()
        
        #expect(schema.type == .number)
        #expect(schema.minimum == 0)
        #expect(schema.maximum == 100)
        #expect(schema.format == "percentage")
    }
    
    @Test("Complex nested schema with builder")
    func testComplexNestedSchema() throws {
        let addressProp = SchemaProperty(
            type: .object,
            description: "Address",
            properties: [
                "street": SchemaProperty(type: .string, description: "Street"),
                "city": SchemaProperty(type: .string, description: "City"),
                "zipCode": SchemaProperty(type: .string, description: "ZIP code")
            ],
            required: ["street", "city"]
        )
        
        let schema = SchemaBuilder.object()
            .property("name", type: .string, description: "Full name", required: true)
            .property("email", type: .string, description: "Email address", required: true)
            .property("age", type: .integer, description: "Age in years")
            .property("address", addressProp, required: false)
            .build()
        
        #expect(schema.type == .object)
        #expect(schema.required == ["name", "email"])
        #expect(schema.properties?.count == 4)
        
        // Convert to AgentToolParameters
        let parameters = schema.toAgentToolParameters()
        #expect(parameters.required == ["name", "email"])
        #expect(parameters.properties["address"]?.type == .object)
    }
    
    @Test("Box type for recursive schemas")
    func testBoxType() throws {
        // Create a recursive structure (like a tree node)
        let nodeSchema = SchemaProperty(
            type: .object,
            description: "Tree node",
            properties: [
                "value": SchemaProperty(type: .string, description: "Node value"),
                "children": SchemaProperty(
                    type: .array,
                    description: "Child nodes",
                    items: SchemaProperty(type: .object, description: "Child node")
                )
            ]
        )
        
        // Box allows for indirect recursion
        let boxedSchema = Box(nodeSchema)
        #expect(boxedSchema.value.type == .object)
    }
    
    @Test("Non-object schema conversion")
    func testNonObjectSchemaConversion() throws {
        // Test conversion of non-object schema (wraps in object)
        let stringSchema = DynamicSchema(type: .string)
        let parameters = stringSchema.toAgentToolParameters()
        
        #expect(parameters.type == "object")
        #expect(parameters.properties["value"]?.type == .string)
        #expect(parameters.required == ["value"])
    }
    
    @Test("Clear registry")
    func testClearRegistry() async throws {
        let registry = DynamicToolRegistry()
        
        // Add multiple tools
        for i in 1...3 {
            let tool = DynamicTool(
                name: "tool_\(i)",
                description: "Tool \(i)",
                schema: DynamicSchema(type: .object)
            )
            await registry.registerTool(tool) { _ in .null }
        }
        
        let toolsBefore = await registry.getAgentTools()
        #expect(toolsBefore.count == 3)
        
        // Clear all
        await registry.clear()
        
        let toolsAfter = await registry.getAgentTools()
        #expect(toolsAfter.isEmpty)
    }
}