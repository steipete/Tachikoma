import Foundation
import Testing
@testable import Tachikoma
@testable import TachikomaAgent

@Suite("Simplified Tools Tests")
struct SimplifiedToolsTests {
    @Test("Create simple tool with schema builder")
    func toolSchemaBuilder() throws {
        let schema = ToolSchemaBuilder()
            .string("name", description: "User's name", required: true)
            .integer("age", description: "User's age", required: true)
            .boolean("subscribed", description: "Newsletter subscription")
            .array("tags", description: "User tags", itemType: .string)
            .build()

        #expect(schema.properties.count == 4)
        #expect(schema.required.count == 2)
        #expect(schema.required.contains("name"))
        #expect(schema.required.contains("age"))
    }

    @Test("SimplifiedToolBuilder with structured input")
    func simplifiedToolBuilderWithCodable() async throws {
        struct CalculatorInput: Codable, Sendable {
            let expression: String
        }

        struct CalculatorOutput: Codable, Sendable {
            let result: Double
        }

        let tool = SimplifiedToolBuilder.tool(
            "calculator",
            description: "Evaluate mathematical expressions",
            inputSchema: CalculatorInput.self,
        ) { (_: CalculatorInput) async throws -> CalculatorOutput in
            // Mock calculation
            CalculatorOutput(result: 42.0)
        }

        #expect(tool.name == "calculator")
        #expect(tool.description == "Evaluate mathematical expressions")

        // Test execution
        let args = AgentToolArguments(["expression": "21*2"])
        let context = ToolExecutionContext()
        let result = try await tool.execute(args, context: context)

        // The result should be an AnyAgentToolValue
        #expect(result.doubleValue == 42.0 || result.objectValue?["result"]?.doubleValue == 42.0)
    }

    @Test("SimplifiedToolBuilder with context")
    func testToolWithContext() async throws {
        struct SearchInput: Codable, Sendable {
            let query: String
        }

        struct SearchOutput: Codable, Sendable {
            let results: [String]
        }

        let tool = SimplifiedToolBuilder.toolWithContext(
            "search",
            description: "Search with context",
            inputSchema: SearchInput.self,
        ) { (input: SearchInput, context: ToolExecutionContext) async throws -> SearchOutput in
            // Use context to get conversation history
            let messageCount = context.messages.count
            return SearchOutput(results: ["Result for \(input.query) with \(messageCount) messages"])
        }

        #expect(tool.name == "search")

        // Test execution with context
        let context = ToolExecutionContext(
            messages: [.user("Previous message")],
            sessionId: "test-session",
        )

        let args = AgentToolArguments(["query": "test"])
        let result = try await tool.execute(args, context: context)

        // Verify the result contains context info
        let json = try result.toJSON()
        if
            let dict = json as? [String: Any],
            let results = dict["results"] as? [String]
        {
            #expect(results[0].contains("1 messages"))
        }
    }

    @Test("Simple tool without structured types")
    func simpleToolWithoutCodable() async throws {
        let tool = SimplifiedToolBuilder.simpleTool(
            "echo",
            description: "Echo the input",
            parameters: [
                "message": "The message to echo",
                "uppercase": "Whether to uppercase the message",
            ],
        ) { args async throws -> Any in
            let message = args["message"] as? String ?? ""
            let uppercase = args["uppercase"] as? Bool ?? false
            return ["echoed": uppercase ? message.uppercased() : message]
        }

        #expect(tool.name == "echo")
        #expect(tool.parameters.required.contains("message"))
        #expect(tool.parameters.required.contains("uppercase"))

        // Test execution
        let args = AgentToolArguments([
            "message": "hello",
            "uppercase": true,
        ])
        let context = ToolExecutionContext()
        let result = try await tool.execute(args, context: context)

        #expect(result.objectValue?["echoed"]?.stringValue == "HELLO")
    }

    @Test("AgentTool.create with schema builder")
    func agentToolCreate() async throws {
        let tool = AgentTool.create(
            name: "weather",
            description: "Get weather information",
            schema: { builder in
                builder
                    .string("location", description: "City name", required: true)
                    .string("units", description: "Temperature units", enum: ["celsius", "fahrenheit"])
            },
            execute: { args async throws -> AnyAgentToolValue in
                let location = try args.stringValue("location")
                let units = args.optionalStringValue("units") ?? "celsius"

                return try AnyAgentToolValue.fromJSON([
                    "location": location,
                    "temperature": 22,
                    "units": units,
                ])
            },
        )

        #expect(tool.name == "weather")
        #expect(tool.parameters.required.contains("location"))

        // Test execution
        let args = AgentToolArguments([
            "location": "San Francisco",
            "units": "fahrenheit",
        ])

        let context = ToolExecutionContext()
        let result = try await tool.execute(args, context: context)
        #expect(result.objectValue?["location"]?.stringValue == "San Francisco")
        #expect(result.objectValue?["units"]?.stringValue == "fahrenheit")
    }

    @Test("Tool schema builder with all parameter types")
    func schemaBuilderAllTypes() throws {
        let schema = ToolSchemaBuilder()
            .string("text", description: "Text field")
            .number("price", description: "Price field")
            .integer("count", description: "Count field")
            .boolean("enabled", description: "Enabled flag")
            .array("items", description: "Item list", itemType: .string)
            .object("metadata", description: "Metadata object")
            .build()

        #expect(schema.properties.count == 6)

        // Verify each property type
        let properties = schema.properties
        #expect(properties["text"]?.type == .string)
        #expect(properties["price"]?.type == .number)
        #expect(properties["count"]?.type == .integer)
        #expect(properties["enabled"]?.type == .boolean)
        #expect(properties["items"]?.type == .array)
        #expect(properties["metadata"]?.type == .object)
    }

    @Test("Tool parameter property with enum values")
    func toolParameterWithEnum() throws {
        let schema = ToolSchemaBuilder()
            .string("status", description: "Status", required: true, enum: ["active", "inactive", "pending"])
            .build()

        let statusProp = schema.properties["status"]
        #expect(statusProp?.enumValues?.count == 3)
        #expect(statusProp?.enumValues?.contains("active") == true)
    }
}
