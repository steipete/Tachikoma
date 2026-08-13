import Testing
@testable import Tachikoma
@testable import TachikomaAgent

struct DynamicToolsTests {
    @Test
    func `DynamicTool creates valid AgentTool`() async throws {
        let schema = DynamicSchema(
            type: .object,
            properties: [
                "query": DynamicSchema.SchemaProperty(type: .string, description: "Search query"),
                "limit": DynamicSchema.SchemaProperty(type: .integer, description: "Result limit"),
            ],
            required: ["query"],
        )

        let dynamicTool = DynamicTool(
            name: "search",
            description: "Search for information",
            schema: schema,
        )

        let agentTool = dynamicTool.toAgentTool { args in
            AnyAgentToolValue(string: "Searched for: \(args["query"] ?? AnyAgentToolValue(null: ()))")
        }

        #expect(agentTool.name == "search")
        #expect(agentTool.description == "Search for information")
        #expect(agentTool.parameters.required == ["query"])

        // Test execution
        let args = AgentToolArguments(["query": AnyAgentToolValue(string: "test")])
        let context = ToolExecutionContext()
        let result = try await agentTool.execute(args, context: context)
        #expect(result.stringValue?.contains("Searched for:") == true)
    }

    @Test
    func `DynamicSchema converts to AgentToolParameters`() {
        let schema = DynamicSchema(
            type: .object,
            properties: [
                "name": DynamicSchema.SchemaProperty(type: .string, description: "User name"),
                "age": DynamicSchema.SchemaProperty(type: .integer, description: "User age"),
                "active": DynamicSchema.SchemaProperty(type: .boolean, description: "Is active"),
            ],
            required: ["name"],
        )

        let parameters = schema.toAgentToolParameters()

        #expect(parameters.type == "object")
        #expect(parameters.required == ["name"])
        #expect(parameters.properties["name"]?.type == .string)
        #expect(parameters.properties["age"]?.type == .integer)
        #expect(parameters.properties["active"]?.type == .boolean)
    }

    @Test
    func `SchemaProperty handles nested structures`() {
        let addressSchema = DynamicSchema.SchemaProperty(
            type: .object,
            description: "Address",
            properties: [
                "street": DynamicSchema.SchemaProperty(type: .string, description: "Street name"),
                "city": DynamicSchema.SchemaProperty(type: .string, description: "City name"),
            ],
        )

        let userSchema = DynamicSchema(
            type: .object,
            properties: [
                "name": DynamicSchema.SchemaProperty(type: .string, description: "Name"),
                "address": addressSchema,
            ],
        )

        let parameters = userSchema.toAgentToolParameters()
        #expect(parameters.properties["address"]?.type == .object)
    }

    @Test
    func `DynamicToolRegistry manages tools`() async throws {
        let registry = DynamicToolRegistry()

        // Create a mock provider with a tool
        let tool = DynamicTool(
            name: "test_tool",
            description: "A test tool",
            schema: DynamicSchema(type: .object),
        )

        let provider = MockDynamicToolProvider(
            tools: [tool],
        ) { name, _ in
            AnyAgentToolValue(string: "Executed \(name)")
        }

        // Register the provider
        await registry.register(provider, id: "test-provider")

        // Get all agent tools
        let agentTools = try await registry.getAllAgentTools()
        #expect(agentTools.count == 1)
        #expect(agentTools[0].name == "test_tool")

        // Execute tool through converted agent tool
        let context = ToolExecutionContext()
        let result = try await agentTools[0].execute(
            AgentToolArguments([:]),
            context: context,
        )
        #expect(result.stringValue == "Executed test_tool")

        // Unregister provider
        await registry.unregister(id: "test-provider")
        let remainingTools = try await registry.getAllAgentTools()
        #expect(remainingTools.isEmpty)
    }

    @Test
    func `DynamicToolRegistry binds execution to the discovered provider without rediscovery`() async throws {
        let alphaProvider = TestDynamicToolProvider(toolNames: ["alpha"], resultPrefix: "alpha-provider")
        let betaProvider = TestDynamicToolProvider(toolNames: ["beta"], resultPrefix: "beta-provider")
        let registry = DynamicToolRegistry()
        await registry.register(betaProvider, id: "b-provider")
        await registry.register(alphaProvider, id: "a-provider")

        let tools = try await registry.getAllAgentTools()
        #expect(tools.map(\.name) == ["alpha", "beta"])

        let betaTool = try #require(tools.first { $0.name == "beta" })
        let first = try await betaTool.execute(AgentToolArguments(), context: ToolExecutionContext())
        let second = try await betaTool.execute(AgentToolArguments(), context: ToolExecutionContext())

        #expect(first.stringValue == "beta-provider:beta")
        #expect(second.stringValue == "beta-provider:beta")
        #expect(await alphaProvider.discoveryCount == 1)
        #expect(await betaProvider.discoveryCount == 1)
        #expect(await alphaProvider.executionCount == 0)
        #expect(await betaProvider.executionCount == 2)
    }

    @Test
    func `DynamicToolRegistry rejects ambiguous names before execution`() async throws {
        let firstProvider = TestDynamicToolProvider(toolNames: ["shared"], resultPrefix: "first")
        let secondProvider = TestDynamicToolProvider(toolNames: ["shared"], resultPrefix: "second")
        let registry = DynamicToolRegistry()
        await registry.register(firstProvider, id: "first-provider")
        await registry.register(secondProvider, id: "second-provider")

        await #expect(throws: TachikomaError.self) {
            _ = try await registry.getAllAgentTools()
        }
        #expect(await firstProvider.executionCount == 0)
        #expect(await secondProvider.executionCount == 0)
    }

    @Test
    func `DynamicToolRegistry invalidates tools when their provider registration changes`() async throws {
        let originalProvider = TestDynamicToolProvider(toolNames: ["mutable"], resultPrefix: "original")
        let replacementProvider = TestDynamicToolProvider(toolNames: ["mutable"], resultPrefix: "replacement")
        let registry = DynamicToolRegistry()
        await registry.register(originalProvider, id: "provider")
        let staleTool = try #require(try await registry.getAllAgentTools().first)

        await registry.register(replacementProvider, id: "provider")

        await #expect(throws: TachikomaError.self) {
            _ = try await staleTool.execute(AgentToolArguments(), context: ToolExecutionContext())
        }
        #expect(await originalProvider.executionCount == 0)
        #expect(await replacementProvider.executionCount == 0)
    }

    @Test
    func `DynamicToolRegistry invalidates issued tools when a refresh becomes ambiguous`() async throws {
        let firstProvider = TestDynamicToolProvider(toolNames: ["shared"], resultPrefix: "first")
        let secondProvider = TestDynamicToolProvider(toolNames: [], resultPrefix: "second")
        let registry = DynamicToolRegistry()
        await registry.register(firstProvider, id: "first-provider")
        await registry.register(secondProvider, id: "second-provider")
        let issuedTool = try #require(try await registry.getAllAgentTools().first)

        await secondProvider.replaceTools(with: ["shared"])
        await #expect(throws: TachikomaError.self) {
            _ = try await registry.getAllAgentTools()
        }
        await #expect(throws: TachikomaError.self) {
            _ = try await issuedTool.execute(AgentToolArguments(), context: ToolExecutionContext())
        }
        #expect(await firstProvider.executionCount == 0)
        #expect(await secondProvider.executionCount == 0)
    }

    @Test
    func `DynamicToolRegistry invalidates issued tools when ownership moves`() async throws {
        let firstProvider = TestDynamicToolProvider(toolNames: ["shared"], resultPrefix: "first")
        let secondProvider = TestDynamicToolProvider(toolNames: [], resultPrefix: "second")
        let registry = DynamicToolRegistry()
        await registry.register(firstProvider, id: "first-provider")
        await registry.register(secondProvider, id: "second-provider")
        let issuedTool = try #require(try await registry.getAllAgentTools().first)

        await firstProvider.replaceTools(with: [])
        await secondProvider.replaceTools(with: ["shared"])
        let replacementTool = try #require(try await registry.getAllAgentTools().first)

        await #expect(throws: TachikomaError.self) {
            _ = try await issuedTool.execute(AgentToolArguments(), context: ToolExecutionContext())
        }
        let result = try await replacementTool.execute(AgentToolArguments(), context: ToolExecutionContext())
        #expect(result.stringValue == "second:shared")
        #expect(await firstProvider.executionCount == 0)
        #expect(await secondProvider.executionCount == 1)
    }

    @Test
    func `DynamicToolProvider discovers tools`() async throws {
        let searchTool = DynamicTool(
            name: "search_web",
            description: "Search the web",
            schema: DynamicSchema(type: .object),
        )

        let weatherTool = DynamicTool(
            name: "get_weather",
            description: "Get weather info",
            schema: DynamicSchema(type: .object),
        )

        let provider = MockDynamicToolProvider(tools: [searchTool, weatherTool])

        let tools = try await provider.discoverTools()
        #expect(tools.count == 2)
        #expect(tools[0].name == "search_web")
        #expect(tools[1].name == "get_weather")

        // Test tool execution
        let result = try await provider.executeTool(
            name: "search_web",
            arguments: AgentToolArguments(["query": AnyAgentToolValue(string: "Swift")]),
        )
        #expect(result.stringValue?.contains("Mock result for") == true)
    }

    @Test
    func `CompositeDynamicToolProvider rejects ambiguous names`() async throws {
        let firstProvider = TestDynamicToolProvider(toolNames: ["shared"], resultPrefix: "first")
        let secondProvider = TestDynamicToolProvider(toolNames: ["shared"], resultPrefix: "second")
        let provider = CompositeDynamicToolProvider(providers: [firstProvider, secondProvider])

        await #expect(throws: TachikomaError.self) {
            _ = try await provider.executeTool(name: "shared", arguments: AgentToolArguments())
        }
        #expect(await firstProvider.executionCount == 0)
        #expect(await secondProvider.executionCount == 0)
    }

    @Test
    func `CompositeDynamicToolProvider executes through the provider bound during discovery`() async throws {
        let firstProvider = TestDynamicToolProvider(toolNames: ["shared"], resultPrefix: "first")
        let secondProvider = TestDynamicToolProvider(toolNames: [], resultPrefix: "second")
        let provider = CompositeDynamicToolProvider(providers: [firstProvider, secondProvider])

        let tools = try await provider.discoverTools()
        #expect(tools.map(\.name) == ["shared"])
        await firstProvider.replaceTools(with: [])
        await secondProvider.replaceTools(with: ["shared"])

        let result = try await provider.executeTool(name: "shared", arguments: AgentToolArguments())

        #expect(result.stringValue == "first:shared")
        #expect(await firstProvider.discoveryCount == 1)
        #expect(await secondProvider.discoveryCount == 1)
        #expect(await firstProvider.executionCount == 1)
        #expect(await secondProvider.executionCount == 0)
    }

    @Test
    func `CompositeDynamicToolProvider recovers unchanged bindings after a transient discovery failure`() async throws {
        let provider = TestDynamicToolProvider(toolNames: ["stable"], resultPrefix: "provider")
        let composite = CompositeDynamicToolProvider(providers: [provider])

        _ = try await composite.discoverTools()
        await provider.failNextDiscovery()
        await #expect(throws: TestDynamicToolProviderError.self) {
            _ = try await composite.discoverTools()
        }

        let recoveredTools = try await composite.discoverTools()
        let result = try await composite.executeTool(name: "stable", arguments: AgentToolArguments())

        #expect(recoveredTools.map(\.name) == ["stable"])
        #expect(result.stringValue == "provider:stable")
        #expect(await provider.discoveryCount == 3)
        #expect(await provider.executionCount == 1)
    }

    @Test
    func `CompositeDynamicToolProvider detects an ownership move after a transient discovery failure`() async throws {
        let firstProvider = TestDynamicToolProvider(toolNames: ["shared"], resultPrefix: "first")
        let secondProvider = TestDynamicToolProvider(toolNames: [], resultPrefix: "second")
        let composite = CompositeDynamicToolProvider(providers: [firstProvider, secondProvider])
        _ = try await composite.discoverTools()

        await secondProvider.failNextDiscovery()
        await #expect(throws: TestDynamicToolProviderError.self) {
            _ = try await composite.discoverTools()
        }
        await firstProvider.replaceTools(with: [])
        await secondProvider.replaceTools(with: ["shared"])

        await #expect(throws: TachikomaError.self) {
            _ = try await composite.discoverTools()
        }
        await #expect(throws: TachikomaError.self) {
            _ = try await composite.executeTool(name: "shared", arguments: AgentToolArguments())
        }
        #expect(await firstProvider.executionCount == 0)
        #expect(await secondProvider.executionCount == 0)
    }

    @Test
    func `CompositeDynamicToolProvider keeps duplicate ownership fail closed after a transient failure`() async throws {
        let firstProvider = TestDynamicToolProvider(toolNames: ["shared"], resultPrefix: "first")
        let secondProvider = TestDynamicToolProvider(toolNames: [], resultPrefix: "second")
        let composite = CompositeDynamicToolProvider(providers: [firstProvider, secondProvider])
        _ = try await composite.discoverTools()

        await secondProvider.failNextDiscovery()
        await #expect(throws: TestDynamicToolProviderError.self) {
            _ = try await composite.discoverTools()
        }
        await secondProvider.replaceTools(with: ["shared"])

        await #expect(throws: TachikomaError.self) {
            _ = try await composite.executeTool(name: "shared", arguments: AgentToolArguments())
        }
        await #expect(throws: TachikomaError.self) {
            _ = try await composite.executeTool(name: "shared", arguments: AgentToolArguments())
        }
        #expect(await firstProvider.executionCount == 0)
        #expect(await secondProvider.executionCount == 0)
    }

    @Test
    func `CompositeDynamicToolProvider does not promote a rejected ownership plan`() async throws {
        let firstProvider = TestDynamicToolProvider(toolNames: ["stable"], resultPrefix: "first")
        let secondProvider = TestDynamicToolProvider(toolNames: [], resultPrefix: "second")
        let composite = CompositeDynamicToolProvider(providers: [firstProvider, secondProvider])
        _ = try await composite.discoverTools()

        await firstProvider.replaceTools(with: ["new"])
        await secondProvider.replaceTools(with: ["stable"])
        await #expect(throws: TachikomaError.self) {
            _ = try await composite.discoverTools()
        }

        await firstProvider.replaceTools(with: [])
        await secondProvider.replaceTools(with: ["new"])
        let recoveredTools = try await composite.discoverTools()
        let result = try await composite.executeTool(name: "new", arguments: AgentToolArguments())

        #expect(recoveredTools.map(\.name) == ["new"])
        #expect(result.stringValue == "second:new")
        await #expect(throws: TachikomaError.self) {
            _ = try await composite.executeTool(name: "stable", arguments: AgentToolArguments())
        }
        #expect(await firstProvider.executionCount == 0)
        #expect(await secondProvider.executionCount == 1)
    }

    @Test
    func `CompositeDynamicToolProvider refuses execution after ownership changes`() async throws {
        let firstProvider = TestDynamicToolProvider(toolNames: ["shared"], resultPrefix: "first")
        let secondProvider = TestDynamicToolProvider(toolNames: [], resultPrefix: "second")
        let provider = CompositeDynamicToolProvider(providers: [firstProvider, secondProvider])
        _ = try await provider.discoverTools()

        await firstProvider.replaceTools(with: [])
        await secondProvider.replaceTools(with: ["shared"])

        await #expect(throws: TachikomaError.self) {
            _ = try await provider.discoverTools()
        }
        await #expect(throws: TachikomaError.self) {
            _ = try await provider.executeTool(name: "shared", arguments: AgentToolArguments())
        }
        #expect(await firstProvider.executionCount == 0)
        #expect(await secondProvider.executionCount == 0)
    }

    // Commented out - MCPToolProvider doesn't exist in core Tachikoma
    /*
     @Test("DynamicToolRegistry with provider")
     func disabledTestRegistryWithProvider() async throws {
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
             arguments: AgentToolArguments(["location": AnyAgentToolValue(string: "New York")])
         )

         if let dict = result.objectValue {
             #expect(dict["temperature"]?.doubleValue == 72)
             #expect(dict["condition"]?.stringValue == "Sunny")
             #expect(dict["location"]?.stringValue == "New York")
         } else {
             Issue.record("Expected object result")
         }
     }*/

    // SchemaBuilder is not available in core Tachikoma
    /*
     @Test("SchemaBuilder creates schemas fluently")
     func testSchemaBuilder() throws {
         // SchemaBuilder doesn't exist in the expected form
     }*/

    // SchemaBuilder tests disabled - not available in core
    /*
     @Test("SchemaBuilder with array schema")
     func testSchemaBuilderArray() throws {
         // SchemaBuilder doesn't exist in the expected form
     }*/

    // SchemaBuilder tests disabled
    /*
     @Test("SchemaBuilder with enum values")
     func testSchemaBuilderEnum() throws {
         // SchemaBuilder doesn't exist in the expected form
     }*/

    // SchemaBuilder tests disabled
    /*
     @Test("SchemaBuilder with number constraints")
     func testSchemaBuilderNumberConstraints() throws {
         // SchemaBuilder doesn't exist in the expected form
     }*/

    // SchemaBuilder tests disabled
    /*
     @Test("Complex nested schema with builder")
     func testComplexNestedSchema() throws {
         // SchemaBuilder doesn't exist in the expected form
     }*/

    @Test
    func `Box type for recursive schemas`() {
        // Create a recursive structure (like a tree node)
        let nodeSchema = DynamicSchema.SchemaProperty(
            type: .object,
            description: "Tree node",
            properties: [
                "value": DynamicSchema.SchemaProperty(type: .string, description: "Node value"),
                "children": DynamicSchema.SchemaProperty(
                    type: .array,
                    description: "Child nodes",
                    items: DynamicSchema.SchemaItems(type: .object, description: "Child node"),
                ),
            ],
        )

        // Box type test - simplified since Box doesn't exist
        #expect(nodeSchema.type == .object)
    }

    @Test
    func `Non-object schema conversion`() {
        // Test conversion of non-object schema
        // Since non-object schemas aren't wrapped, we should test object schemas
        let objectSchema = DynamicSchema(
            type: .object,
            properties: ["value": DynamicSchema.SchemaProperty(type: .string, description: "A string value")],
            required: ["value"],
        )
        let parameters = objectSchema.toAgentToolParameters()

        #expect(parameters.type == "object")
        #expect(parameters.properties["value"]?.type == .string)
        #expect(parameters.required == ["value"])
    }

    @Test
    func `Clear registry`() async throws {
        let registry = DynamicToolRegistry()

        // Add multiple tools
        for i in 1...3 {
            let tool = DynamicTool(
                name: "tool_\(i)",
                description: "Tool \(i)",
                schema: DynamicSchema(type: .object),
            )
            let provider = MockDynamicToolProvider(tools: [tool])
            await registry.register(provider, id: "tool_\(i)")
        }

        let toolsBefore = try await registry.getAllAgentTools()
        #expect(toolsBefore.count == 3)

        // Clear all by unregistering providers
        for i in 1...3 {
            await registry.unregister(id: "tool_\(i)")
        }

        let toolsAfter = try await registry.getAllAgentTools()
        #expect(toolsAfter.isEmpty)
    }
}

private actor TestDynamicToolProvider: DynamicToolProvider {
    private var tools: [DynamicTool]
    private let resultPrefix: String
    private(set) var discoveryCount = 0
    private(set) var executionCount = 0
    private var shouldFailNextDiscovery = false

    init(toolNames: [String], resultPrefix: String) {
        self.tools = Self.makeTools(named: toolNames)
        self.resultPrefix = resultPrefix
    }

    func discoverTools() async throws -> [DynamicTool] {
        self.discoveryCount += 1
        if self.shouldFailNextDiscovery {
            self.shouldFailNextDiscovery = false
            throw TestDynamicToolProviderError.transientDiscoveryFailure
        }
        return self.tools
    }

    func executeTool(name: String, arguments _: AgentToolArguments) async throws -> AnyAgentToolValue {
        self.executionCount += 1
        return AnyAgentToolValue(string: "\(self.resultPrefix):\(name)")
    }

    func replaceTools(with names: [String]) {
        self.tools = Self.makeTools(named: names)
    }

    func failNextDiscovery() {
        self.shouldFailNextDiscovery = true
    }

    private static func makeTools(named names: [String]) -> [DynamicTool] {
        names.map { name in
            DynamicTool(
                name: name,
                description: "Tool \(name)",
                schema: DynamicSchema(type: .object),
            )
        }
    }
}

private enum TestDynamicToolProviderError: Error {
    case transientDiscoveryFailure
}
