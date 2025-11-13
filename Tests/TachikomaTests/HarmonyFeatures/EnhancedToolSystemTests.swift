import Testing
@testable import Tachikoma

@Suite("Enhanced Tool System")
struct EnhancedToolSystemTests {
    @Test("AgentToolCall supports namespace and recipient")
    func toolCallNamespaceRecipient() {
        let toolCall = AgentToolCall(
            id: "call-123",
            name: "search",
            arguments: ["query": AnyAgentToolValue(string: "test")],
            namespace: "web",
            recipient: "google-search",
        )

        #expect(toolCall.id == "call-123")
        #expect(toolCall.name == "search")
        #expect(toolCall.namespace == "web")
        #expect(toolCall.recipient == "google-search")
        #expect(toolCall.arguments["query"]?.stringValue == "test")
    }

    @Test("AgentToolCall works without namespace and recipient")
    func toolCallWithoutNamespaceRecipient() {
        let toolCall = AgentToolCall(
            name: "calculate",
            arguments: ["expression": AnyAgentToolValue(string: "2+2")],
        )

        #expect(toolCall.namespace == nil)
        #expect(toolCall.recipient == nil)
        #expect(toolCall.name == "calculate")
    }

    @Test("AgentTool supports namespace and recipient")
    func agentToolNamespaceRecipient() {
        let tool = AgentTool(
            name: "readFile",
            description: "Read file contents",
            parameters: AgentToolParameters(
                properties: [
                    "path": AgentToolParameterProperty(
                        name: "path",
                        type: .string,
                        description: "File path",
                    ),
                ],
                required: ["path"],
            ),
            namespace: "filesystem",
            recipient: "local-fs",
        ) { _ in
            AnyAgentToolValue(string: "file contents")
        }

        #expect(tool.name == "readFile")
        #expect(tool.namespace == "filesystem")
        #expect(tool.recipient == "local-fs")
        #expect(tool.description == "Read file contents")
    }

    @Test("AgentTool works without namespace and recipient")
    func agentToolWithoutNamespaceRecipient() {
        let tool = AgentTool(
            name: "echo",
            description: "Echo input",
            parameters: AgentToolParameters(properties: [:], required: []),
        ) { _ in AnyAgentToolValue(string: "echo") }

        #expect(tool.namespace == nil)
        #expect(tool.recipient == nil)
        #expect(tool.name == "echo")
    }

    @Test("Tool organization by namespace")
    func toolOrganizationByNamespace() {
        let tools = [
            AgentTool(
                name: "readFile",
                description: "Read file",
                parameters: AgentToolParameters(properties: [:], required: []),
                namespace: "filesystem",
            ) { _ in AnyAgentToolValue(string: "") },
            AgentTool(
                name: "writeFile",
                description: "Write file",
                parameters: AgentToolParameters(properties: [:], required: []),
                namespace: "filesystem",
            ) { _ in AnyAgentToolValue(string: "") },
            AgentTool(
                name: "query",
                description: "Database query",
                parameters: AgentToolParameters(properties: [:], required: []),
                namespace: "database",
            ) { _ in AnyAgentToolValue(string: "") },
            AgentTool(
                name: "search",
                description: "Web search",
                parameters: AgentToolParameters(properties: [:], required: []),
                namespace: "web",
            ) { _ in AnyAgentToolValue(string: "") },
        ]

        // Group by namespace
        var toolsByNamespace: [String?: [AgentTool]] = [:]
        for tool in tools {
            toolsByNamespace[tool.namespace, default: []].append(tool)
        }

        #expect(toolsByNamespace["filesystem"]?.count == 2)
        #expect(toolsByNamespace["database"]?.count == 1)
        #expect(toolsByNamespace["web"]?.count == 1)
    }

    @Test("Tool routing by recipient")
    func toolRoutingByRecipient() {
        let tools = [
            AgentTool(
                name: "query",
                description: "Query database",
                parameters: AgentToolParameters(properties: [:], required: []),
                namespace: "database",
                recipient: "postgres-primary",
            ) { _ in AnyAgentToolValue(string: "primary result") },
            AgentTool(
                name: "query",
                description: "Query database",
                parameters: AgentToolParameters(properties: [:], required: []),
                namespace: "database",
                recipient: "postgres-replica",
            ) { _ in AnyAgentToolValue(string: "replica result") },
        ]

        // Find tool for specific recipient
        let primaryTool = tools.first { $0.recipient == "postgres-primary" }
        let replicaTool = tools.first { $0.recipient == "postgres-replica" }

        #expect(primaryTool != nil)
        #expect(replicaTool != nil)
        #expect(primaryTool?.name == "query")
        #expect(replicaTool?.name == "query")
    }

    @Test("AgentToolCall Codable with namespace and recipient")
    func toolCallCodableWithNamespaceRecipient() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let decoder = JSONDecoder()

        let original = AgentToolCall(
            id: "test-123",
            name: "search",
            arguments: ["query": AnyAgentToolValue(string: "Swift")],
            namespace: "web",
            recipient: "duckduckgo",
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AgentToolCall.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.namespace == original.namespace)
        #expect(decoded.recipient == original.recipient)
        #expect(decoded.arguments["query"] == original.arguments["query"])
    }

    @Test("AgentToolCall Codable without namespace and recipient")
    func toolCallCodableWithoutNamespaceRecipient() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = AgentToolCall(
            name: "calculate",
            arguments: ["expr": AnyAgentToolValue(double: 42.0)],
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AgentToolCall.self, from: data)

        #expect(decoded.namespace == nil)
        #expect(decoded.recipient == nil)
        #expect(decoded.name == "calculate")
    }

    @Test("Tool execution with namespace context")
    func toolExecutionWithNamespaceContext() async throws {
        actor NamespaceCapture {
            var namespace: String?
            func set(_ value: String) { self.namespace = value }
        }

        let capture = NamespaceCapture()

        let tool = AgentTool(
            name: "contextAware",
            description: "Namespace-aware tool",
            parameters: AgentToolParameters(properties: [:], required: []),
            namespace: "test-namespace",
        ) { _ in
            // In real implementation, namespace could be passed via context
            await capture.set("test-namespace")
            return AnyAgentToolValue(string: "executed in namespace")
        }

        let toolArgs = AgentToolArguments([:])
        let context = ToolExecutionContext()
        let result = try await tool.execute(toolArgs, context: context)
        #expect(result.stringValue == "executed in namespace")
        #expect(await capture.namespace == "test-namespace")
    }

    @Test("Multiple tools with same name but different namespaces")
    func multipleToolsSameNameDifferentNamespaces() {
        let webSearch = AgentTool(
            name: "search",
            description: "Web search",
            parameters: AgentToolParameters(properties: [:], required: []),
            namespace: "web",
        ) { _ in AnyAgentToolValue(string: "web results") }

        let dbSearch = AgentTool(
            name: "search",
            description: "Database search",
            parameters: AgentToolParameters(properties: [:], required: []),
            namespace: "database",
        ) { _ in AnyAgentToolValue(string: "db results") }

        let fileSearch = AgentTool(
            name: "search",
            description: "File search",
            parameters: AgentToolParameters(properties: [:], required: []),
            namespace: "filesystem",
        ) { _ in AnyAgentToolValue(string: "file results") }

        // All have same name but different namespaces
        #expect(webSearch.name == dbSearch.name)
        #expect(dbSearch.name == fileSearch.name)
        #expect(webSearch.namespace != dbSearch.namespace)
        #expect(dbSearch.namespace != fileSearch.namespace)
        #expect(webSearch.namespace != fileSearch.namespace)
    }
}
