import Foundation
import Testing
@testable import Tachikoma

@Suite("ToolKit System Tests")
struct ToolKitTests {
    // MARK: - Basic ToolKit Tests

    @Test("EmptyToolKit Implementation")
    func emptyToolKitImplementation() throws {
        let toolkit = EmptyToolKit()

        #expect(toolkit.tools.isEmpty)

        let providerTools = try toolkit.toProviderTools()
        #expect(providerTools.isEmpty)
    }

    @Test("Custom ToolKit Implementation")
    func customToolKitImplementation() throws {
        struct MathToolKit: ToolKit {
            var tools: [Tool<MathToolKit>] {
                [
                    Tool(name: "add", description: "Add two numbers") { input, _ in
                        let firstValue = try input.intValue("a")
                        let secondValue = try input.intValue("b")
                        return .string("\(firstValue + secondValue)")
                    },
                    Tool(name: "multiply", description: "Multiply two numbers") { input, _ in
                        let firstValue = try input.intValue("a")
                        let secondValue = try input.intValue("b")
                        return .string("\(firstValue * secondValue)")
                    },
                ]
            }
        }

        let toolkit = MathToolKit()

        #expect(toolkit.tools.count == 2)
        #expect(toolkit.tools[0].name == "add")
        #expect(toolkit.tools[1].name == "multiply")

        let providerTools = try toolkit.toProviderTools()
        #expect(providerTools.count == 2)
        #expect(providerTools[0].name == "add")
        #expect(providerTools[1].name == "multiply")
    }

    // MARK: - Tool Execution Tests

    @Test("Tool Execution Through Provider Tools")
    func toolExecutionThroughProviderTools() async throws {
        struct CalculatorToolKit: ToolKit {
            var tools: [Tool<CalculatorToolKit>] {
                [
                    Tool(name: "calculate", description: "Perform calculation") { input, _ in
                        let operation = try input.stringValue("operation")
                        let firstValue = try input.intValue("a")
                        let secondValue = try input.intValue("b")

                        switch operation {
                        case "add":
                            return .string("\(firstValue + secondValue)")
                        case "subtract":
                            return .string("\(firstValue - secondValue)")
                        default:
                            return .error(message: "Unknown operation")
                        }
                    },
                ]
            }
        }

        let toolkit = CalculatorToolKit()
        let providerTools = try toolkit.toProviderTools()

        #expect(providerTools.count == 1)

        let calculateTool = providerTools[0]
        #expect(calculateTool.name == "calculate")

        // Note: ProviderTool is for schema only, not execution
        // Tool execution would be done through the original Tool<Context> objects
        // TODO: Update tests to properly test tool execution vs schema conversion
    }

    // MARK: - ToolInput Parsing Tests

    @Test("ToolInput JSON Parsing")
    func toolInputJSONParsing() throws {
        let input = try ToolInput(jsonString: """
        {
            "name": "test",
            "age": 25,
            "score": 95.5,
            "active": true,
            "missing": null
        }
        """)

        #expect(try input.stringValue("name") == "test")
        #expect(try input.intValue("age") == 25)
        #expect(try input.doubleValue("score") == 95.5)
        #expect(input.boolValue("active", default: false) == true)
        #expect(input.stringValue("missing", default: "default") == "default")
    }

    @Test("ToolInput Edge Cases")
    func toolInputEdgeCases() throws {
        // Empty JSON
        let emptyInput = try ToolInput(jsonString: "{}")
        #expect(emptyInput.stringValue("nonexistent", default: "default") == "default")
        #expect(emptyInput.intValue("nonexistent", default: 42) == 42)
        #expect(emptyInput.boolValue("nonexistent", default: true) == true)

        // Number conversions
        let numberInput = try ToolInput(jsonString: "{\"float_as_int\": 42.0, \"int_as_double\": 10}")
        #expect(try numberInput.intValue("float_as_int") == 42)
        #expect(try numberInput.doubleValue("int_as_double") == 10.0)

        // Error cases
        #expect(throws: ToolError.self) {
            try emptyInput.stringValue("nonexistent")
        }

        #expect(throws: ToolError.self) {
            try emptyInput.intValue("nonexistent")
        }

        #expect(throws: ToolError.self) {
            try emptyInput.doubleValue("nonexistent")
        }
    }

    @Test("ToolInput Invalid JSON")
    func toolInputInvalidJSON() {
        #expect(throws: ToolError.self) {
            try ToolInput(jsonString: "invalid json")
        }

        #expect(throws: ToolError.self) {
            try ToolInput(jsonString: "{unclosed")
        }
    }

    // MARK: - ToolOutput Tests

    @Test("ToolOutput Formatting")
    func toolOutputFormatting() throws {
        let stringOutput = ToolOutput.string("Hello, world!")
        #expect(try stringOutput.toJSONString() == "Hello, world!")

        let errorOutput = ToolOutput.error(message: "Something went wrong")
        #expect(try errorOutput.toJSONString() == "Error: Something went wrong")
    }

    // MARK: - Complex ToolKit Test

    @Test("Complex ToolKit with State")
    func complexToolKitWithState() async throws {
        // ToolKit that maintains internal state
        struct CounterToolKit: ToolKit {
            private var count = 0

            var tools: [Tool<CounterToolKit>] {
                [
                    Tool(name: "increment", description: "Increment counter") { input, _ in
                        // Note: In real usage, this would need proper state management
                        // since context is passed by value. This is just for testing the interface.
                        let amount = input.intValue("amount", default: 1 as Int)
                        return .string("Incremented by \(amount)")
                    },
                    Tool(name: "get_count", description: "Get current count") { _, _ in
                        .string("Count is 0") // Simplified for testing
                    },
                ]
            }
        }

        let toolkit = CounterToolKit()
        let providerTools = try toolkit.toProviderTools()

        #expect(providerTools.count == 2)

        // Test that provider tools have the correct schema
        let incrementTool = providerTools.first { $0.name == "increment" }!
        #expect(incrementTool.name == "increment")

        let getCountTool = providerTools.first { $0.name == "get_count" }!
        #expect(getCountTool.name == "get_count")

        // Note: ProviderTool is for schema conversion only
        // Actual tool execution would use the original Tool<Context> objects
    }

    // MARK: - Tool Error Tests

    @Test("Tool Error Descriptions")
    func toolErrorDescriptions() {
        let invalidInputError = ToolError.invalidInput("Bad parameter")
        #expect(invalidInputError.errorDescription == "Invalid tool input: Bad parameter")

        let executionError = ToolError.executionFailed("Network timeout")
        #expect(executionError.errorDescription == "Tool execution failed: Network timeout")

        let notFoundError = ToolError.toolNotFound("nonexistent_tool")
        #expect(notFoundError.errorDescription == "Tool not found: nonexistent_tool")
    }
}
