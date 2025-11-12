import Foundation
import Testing
@testable import Tachikoma

@Suite("Tool System Tests")
struct ToolSystemTests {
    // MARK: - AgentTool Tests

    @Test("AgentTool Creation")
    func agentToolCreation() throws {
        // Create a simple tool using createTool helper
        let addTool = createTool(
            name: "add",
            description: "Add two numbers",
            parameters: [
                AgentToolParameterProperty(
                    name: "a",
                    type: .integer,
                    description: "First number",
                ),
                AgentToolParameterProperty(
                    name: "b",
                    type: .integer,
                    description: "Second number",
                ),
            ],
            required: ["a", "b"],
        ) { args in
            let a = try args.integerValue("a")
            let b = try args.integerValue("b")
            return AnyAgentToolValue(int: a + b)
        }

        #expect(addTool.name == "add")
        #expect(addTool.description == "Add two numbers")
        #expect(addTool.parameters.properties.count == 2)
        #expect(addTool.parameters.required == ["a", "b"])
    }

    @Test("Tool Execution")
    func toolExecution() async throws {
        // Create calculator tool
        let calculatorTool = createTool(
            name: "calculate",
            description: "Perform calculation",
            parameters: [
                AgentToolParameterProperty(
                    name: "expression",
                    type: .string,
                    description: "Mathematical expression",
                ),
            ],
            required: ["expression"],
        ) { args in
            let expr = try args.stringValue("expression")
            // Simple evaluation for test
            if expr == "2 + 2" {
                return AnyAgentToolValue(string: "4")
            }
            return AnyAgentToolValue(string: "Unknown expression")
        }

        // Test execution
        let args = AgentToolArguments(["expression": AnyAgentToolValue(string: "2 + 2")])
        let context = ToolExecutionContext()
        let result = try await calculatorTool.execute(args, context: context)

        if let value = result.stringValue {
            #expect(value == "4")
        } else {
            Issue.record("Expected string result")
        }
    }

    @Test("Built-in Tools")
    func builtInTools() async throws {
        // Test weatherTool
        #expect(weatherTool.name == "get_weather")

        // Test timeTool
        #expect(timeTool.name == "get_current_time")

        // Test calculatorTool
        #expect(calculatorTool.name == "calculate")

        // Execute time tool (doesn't require external services)
        let args = AgentToolArguments([:])
        let context = ToolExecutionContext()
        let result = try await timeTool.execute(args, context: context)

        if let timeString = result.stringValue {
            #expect(!timeString.isEmpty)
        } else {
            Issue.record("Expected string result from time tool")
        }
    }

    @Test("Tool Parameter Types")
    func toolParameterTypes() {
        // Test all parameter types
        let params = [
            AgentToolParameterProperty(
                name: "string_param",
                type: .string,
                description: "A string parameter",
            ),
            AgentToolParameterProperty(
                name: "number_param",
                type: .number,
                description: "A number parameter",
            ),
            AgentToolParameterProperty(
                name: "integer_param",
                type: .integer,
                description: "An integer parameter",
            ),
            AgentToolParameterProperty(
                name: "boolean_param",
                type: .boolean,
                description: "A boolean parameter",
            ),
            AgentToolParameterProperty(
                name: "array_param",
                type: .array,
                description: "An array parameter",
            ),
            AgentToolParameterProperty(
                name: "object_param",
                type: .object,
                description: "An object parameter",
            ),
        ]

        for param in params {
            #expect(!param.name.isEmpty)
            #expect(!param.description.isEmpty)
        }
    }

    @Test("Tool Arguments")
    func toolArguments() throws {
        let args = AgentToolArguments([
            "string": AnyAgentToolValue(string: "hello"),
            "int": AnyAgentToolValue(int: 42),
            "double": AnyAgentToolValue(double: 3.14),
            "bool": AnyAgentToolValue(bool: true),
            "array": AnyAgentToolValue(array: [AnyAgentToolValue(string: "a"), AnyAgentToolValue(string: "b")]),
            "object": AnyAgentToolValue(object: ["nested": AnyAgentToolValue(string: "value")]),
        ])

        #expect(try args.stringValue("string") == "hello")
        #expect(try args.integerValue("int") == 42)
        #expect(try args.numberValue("double") == 3.14)
        #expect(try args.booleanValue("bool") == true)

        // Test array access
        if let arr = args["array"]?.arrayValue {
            #expect(arr.count == 2)
        } else {
            Issue.record("Expected array")
        }

        // Test object access
        if let obj = args["object"]?.objectValue {
            #expect(obj["nested"]?.stringValue == "value")
        } else {
            Issue.record("Expected object")
        }
    }

    @Test("Tool Error Handling")
    func toolErrorHandling() throws {
        let args = AgentToolArguments([:])

        // Test missing required argument
        do {
            _ = try args.stringValue("missing")
            Issue.record("Should have thrown error for missing argument")
        } catch {
            // Expected
        }

        // Test wrong type
        let wrongTypeArgs = AgentToolArguments(["value": AnyAgentToolValue(int: 42)])
        do {
            _ = try wrongTypeArgs.stringValue("value")
            Issue.record("Should have thrown error for wrong type")
        } catch {
            // Expected
        }
    }
}
