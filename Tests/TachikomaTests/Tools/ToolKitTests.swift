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
                    description: "First number"
                ),
                AgentToolParameterProperty(
                    name: "b", 
                    type: .integer,
                    description: "Second number"
                )
            ],
            required: ["a", "b"]
        ) { args in
            let a = try args.integerValue("a")
            let b = try args.integerValue("b")
            return AgentToolArgument.int(a + b)
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
                    description: "Mathematical expression"
                )
            ],
            required: ["expression"]
        ) { args in
            let expr = try args.stringValue("expression")
            // Simple evaluation for test
            if expr == "2 + 2" {
                return AgentToolArgument.string("4")
            }
            return AgentToolArgument.string("Unknown expression")
        }
        
        // Test execution
        let args = AgentToolArguments(["expression": .string("2 + 2")])
        let result = try await calculatorTool.execute(args)
        
        if case .string(let value) = result {
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
        let result = try await timeTool.execute(args)
        
        if case .string(let timeString) = result {
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
                description: "A string parameter"
            ),
            AgentToolParameterProperty(
                name: "number_param",
                type: .number,
                description: "A number parameter"
            ),
            AgentToolParameterProperty(
                name: "integer_param",
                type: .integer,
                description: "An integer parameter"
            ),
            AgentToolParameterProperty(
                name: "boolean_param",
                type: .boolean,
                description: "A boolean parameter"
            ),
            AgentToolParameterProperty(
                name: "array_param",
                type: .array,
                description: "An array parameter"
            ),
            AgentToolParameterProperty(
                name: "object_param",
                type: .object,
                description: "An object parameter"
            )
        ]
        
        for param in params {
            #expect(!param.name.isEmpty)
            #expect(!param.description.isEmpty)
        }
    }
    
    @Test("Tool Arguments")
    func toolArguments() throws {
        let args = AgentToolArguments([
            "string": .string("hello"),
            "int": .int(42),
            "double": .double(3.14),
            "bool": .bool(true),
            "array": .array([.string("a"), .string("b")]),
            "object": .object(["nested": .string("value")])
        ])
        
        #expect(try args.stringValue("string") == "hello")
        #expect(try args.integerValue("int") == 42)
        #expect(try args.numberValue("double") == 3.14)
        #expect(try args.booleanValue("bool") == true)
        
        // Test array access
        if case .array(let arr) = args["array"] {
            #expect(arr.count == 2)
        } else {
            Issue.record("Expected array")
        }
        
        // Test object access
        if case .object(let obj) = args["object"] {
            #expect(obj["nested"] == .string("value"))
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
        let wrongTypeArgs = AgentToolArguments(["value": .int(42)])
        do {
            _ = try wrongTypeArgs.stringValue("value")
            Issue.record("Should have thrown error for wrong type")
        } catch {
            // Expected
        }
    }
}