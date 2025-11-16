import Foundation
import Testing
@testable import Tachikoma

@Suite("AgentToolValue Protocol System Tests")
struct AgentToolValueTests {
    // MARK: - Basic Type Conformance Tests

    @Test("String conforms to AgentToolValue")
    func stringConformance() throws {
        let value = "Hello, World!"
        let json = try value.toJSON()
        #expect(json as? String == "Hello, World!")

        let recovered = try String.fromJSON(json)
        #expect(recovered == value)
        #expect(String.agentValueType == .string)
    }

    @Test("Int conforms to AgentToolValue")
    func intConformance() throws {
        let value = 42
        let json = try value.toJSON()
        #expect(json as? Int == 42)

        let recovered = try Int.fromJSON(json)
        #expect(recovered == value)
        #expect(Int.agentValueType == .integer)

        // Test conversion from Double
        let fromDouble = try Int.fromJSON(42.0)
        #expect(fromDouble == 42)
    }

    @Test("Double conforms to AgentToolValue")
    func doubleConformance() throws {
        let value = 3.141_59
        let json = try value.toJSON()
        #expect(json as? Double == 3.141_59)

        let recovered = try Double.fromJSON(json)
        #expect(recovered == value)
        #expect(Double.agentValueType == .number)

        // Test conversion from Int
        let fromInt = try Double.fromJSON(42)
        #expect(fromInt == 42.0)
    }

    @Test("Bool conforms to AgentToolValue")
    func boolConformance() throws {
        let value = true
        let json = try value.toJSON()
        #expect(json as? Bool == true)

        let recovered = try Bool.fromJSON(json)
        #expect(recovered == value)
        #expect(Bool.agentValueType == .boolean)
    }

    @Test("AgentNullValue works correctly")
    func testNullValue() throws {
        let value = AgentNullValue()
        let json = try value.toJSON()
        #expect(json is NSNull)

        let recovered = try AgentNullValue.fromJSON(NSNull())
        #expect(recovered == value)
        #expect(AgentNullValue.agentValueType == .null)
    }

    @Test("Array conforms to AgentToolValue")
    func arrayConformance() throws {
        let value = ["apple", "banana", "cherry"]
        let json = try value.toJSON()
        let jsonArray = json as? [Any]
        #expect(jsonArray?.count == 3)
        #expect(jsonArray?[0] as? String == "apple")

        let recovered = try [String].fromJSON(json)
        #expect(recovered == value)
        #expect([String].agentValueType == .array)
    }

    @Test("Dictionary conforms to AgentToolValue")
    func dictionaryConformance() throws {
        let value = ["name": "John", "city": "NYC"]
        let json = try value.toJSON()
        let jsonDict = json as? [String: Any]
        #expect(jsonDict?["name"] as? String == "John")
        #expect(jsonDict?["city"] as? String == "NYC")

        let recovered = try [String: String].fromJSON(json)
        #expect(recovered == value)
        #expect([String: String].agentValueType == .object)
    }

    // MARK: - AnyAgentToolValue Tests

    @Test("AnyAgentToolValue wraps basic types")
    func anyAgentToolValueBasicTypes() throws {
        // String
        let stringValue = AnyAgentToolValue(string: "test")
        #expect(stringValue.stringValue == "test")
        #expect(stringValue.intValue == nil)

        // Int
        let intValue = AnyAgentToolValue(int: 42)
        #expect(intValue.intValue == 42)
        #expect(intValue.doubleValue == 42.0)
        #expect(intValue.stringValue == nil)

        // Double
        let doubleValue = AnyAgentToolValue(double: 3.14)
        #expect(doubleValue.doubleValue == 3.14)
        #expect(doubleValue.intValue == nil)

        // Bool
        let boolValue = AnyAgentToolValue(bool: true)
        #expect(boolValue.boolValue == true)
        #expect(boolValue.stringValue == nil)

        // Null
        let nullValue = AnyAgentToolValue(null: ())
        #expect(nullValue.isNull == true)
        #expect(nullValue.stringValue == nil)
    }

    @Test("AnyAgentToolValue wraps complex types")
    func anyAgentToolValueComplexTypes() throws {
        // Array
        let array = [
            AnyAgentToolValue(string: "a"),
            AnyAgentToolValue(int: 1),
            AnyAgentToolValue(bool: true),
        ]
        let arrayValue = AnyAgentToolValue(array: array)
        #expect(arrayValue.arrayValue?.count == 3)
        #expect(arrayValue.arrayValue?[0].stringValue == "a")
        #expect(arrayValue.arrayValue?[1].intValue == 1)
        #expect(arrayValue.arrayValue?[2].boolValue == true)

        // Object
        let object = [
            "name": AnyAgentToolValue(string: "Alice"),
            "age": AnyAgentToolValue(int: 30),
            "active": AnyAgentToolValue(bool: true),
        ]
        let objectValue = AnyAgentToolValue(object: object)
        #expect(objectValue.objectValue?["name"]?.stringValue == "Alice")
        #expect(objectValue.objectValue?["age"]?.intValue == 30)
        #expect(objectValue.objectValue?["active"]?.boolValue == true)
    }

    @Test("AnyAgentToolValue JSON conversion")
    func anyAgentToolValueJSON() throws {
        // Test fromJSON with various types
        let stringValue = try AnyAgentToolValue.fromJSON("hello")
        #expect(stringValue.stringValue == "hello")

        let intValue = try AnyAgentToolValue.fromJSON(42)
        #expect(intValue.intValue == 42)

        let doubleValue = try AnyAgentToolValue.fromJSON(3.14)
        #expect(doubleValue.doubleValue == 3.14)

        let boolValue = try AnyAgentToolValue.fromJSON(true)
        #expect(boolValue.boolValue == true)

        let nullValue = try AnyAgentToolValue.fromJSON(NSNull())
        #expect(nullValue.isNull == true)

        let arrayJSON = ["a", "b", "c"]
        let arrayValue = try AnyAgentToolValue.fromJSON(arrayJSON)
        #expect(arrayValue.arrayValue?.count == 3)

        let dictJSON: [String: Any] = ["key": "value", "num": 123]
        let dictValue = try AnyAgentToolValue.fromJSON(dictJSON)
        #expect(dictValue.objectValue?["key"]?.stringValue == "value")
        #expect(dictValue.objectValue?["num"]?.intValue == 123)
    }

    @Test("AnyAgentToolValue Codable conformance")
    func anyAgentToolValueCodable() throws {
        struct TestContainer: Codable {
            let value: AnyAgentToolValue
        }

        // Test encoding and decoding various types
        let testCases: [AnyAgentToolValue] = [
            AnyAgentToolValue(string: "test"),
            AnyAgentToolValue(int: 42),
            AnyAgentToolValue(double: 3.14),
            AnyAgentToolValue(bool: true),
            AnyAgentToolValue(null: ()),
            AnyAgentToolValue(array: [
                AnyAgentToolValue(string: "item1"),
                AnyAgentToolValue(int: 2),
            ]),
            AnyAgentToolValue(object: [
                "field1": AnyAgentToolValue(string: "value1"),
                "field2": AnyAgentToolValue(int: 100),
            ]),
        ]

        for originalValue in testCases {
            let container = TestContainer(value: originalValue)
            let encoded = try JSONEncoder().encode(container)
            let decoded = try JSONDecoder().decode(TestContainer.self, from: encoded)

            // Compare by converting to JSON since Equatable comparison is exact
            let originalJSON = try originalValue.toJSON()
            let decodedJSON = try decoded.value.toJSON()

            // Use JSONSerialization to compare since Any isn't Equatable
            // Wrap in array since JSON top-level must be array or object
            let originalData = try JSONSerialization.data(withJSONObject: [originalJSON], options: [.sortedKeys])
            let decodedData = try JSONSerialization.data(withJSONObject: [decodedJSON], options: [.sortedKeys])

            #expect(originalData == decodedData)
        }
    }

    // MARK: - AgentToolCall and AgentToolResult Tests

    @Test("AgentToolCall uses AnyAgentToolValue")
    func agentToolCall() throws {
        let arguments = [
            "prompt": AnyAgentToolValue(string: "Hello"),
            "temperature": AnyAgentToolValue(double: 0.7),
            "maxTokens": AnyAgentToolValue(int: 100),
        ]

        let toolCall = AgentToolCall(
            id: "call_123",
            name: "generate",
            arguments: arguments,
        )

        #expect(toolCall.id == "call_123")
        #expect(toolCall.name == "generate")
        #expect(toolCall.arguments["prompt"]?.stringValue == "Hello")
        #expect(toolCall.arguments["temperature"]?.doubleValue == 0.7)
        #expect(toolCall.arguments["maxTokens"]?.intValue == 100)
    }

    @Test("AgentToolCall legacy init with Any")
    func agentToolCallLegacyInit() throws {
        let arguments: [String: Any] = [
            "text": "Hello",
            "count": 42,
            "enabled": true,
        ]

        let toolCall = try AgentToolCall(
            id: "call_456",
            name: "process",
            arguments: arguments,
        )

        #expect(toolCall.arguments["text"]?.stringValue == "Hello")
        #expect(toolCall.arguments["count"]?.intValue == 42)
        #expect(toolCall.arguments["enabled"]?.boolValue == true)
    }

    @Test("AgentToolResult uses AnyAgentToolValue")
    func agentToolResult() {
        let successResult = AgentToolResult.success(
            toolCallId: "call_123",
            result: AnyAgentToolValue(string: "Success!"),
        )

        #expect(successResult.toolCallId == "call_123")
        #expect(successResult.isError == false)
        #expect(successResult.result.stringValue == "Success!")

        let errorResult = AgentToolResult.error(
            toolCallId: "call_456",
            error: "Something went wrong",
        )

        #expect(errorResult.toolCallId == "call_456")
        #expect(errorResult.isError == true)
        #expect(errorResult.result.stringValue == "Something went wrong")
    }

    // MARK: - AgentToolArguments Tests

    @Test("AgentToolArguments accessor methods")
    func agentToolArgumentsAccessors() throws {
        let args = AgentToolArguments([
            "string": AnyAgentToolValue(string: "text"),
            "number": AnyAgentToolValue(double: 42.5),
            "integer": AnyAgentToolValue(int: 100),
            "boolean": AnyAgentToolValue(bool: true),
            "array": AnyAgentToolValue(array: [
                AnyAgentToolValue(string: "item1"),
                AnyAgentToolValue(string: "item2"),
            ]),
            "object": AnyAgentToolValue(object: [
                "nested": AnyAgentToolValue(string: "value"),
            ]),
        ])

        // Test required accessors
        #expect(try args.stringValue("string") == "text")
        #expect(try args.numberValue("number") == 42.5)
        #expect(try args.integerValue("integer") == 100)
        #expect(try args.booleanValue("boolean") == true)

        // Test array accessor
        let array = try args.arrayValue("array") { $0.stringValue ?? "" }
        #expect(array == ["item1", "item2"])

        // Test object accessor
        let object = try args.objectValue("object")
        #expect(object["nested"]?.stringValue == "value")

        // Test optional accessors
        #expect(args.optionalStringValue("missing") == nil)
        #expect(args.optionalNumberValue("string") == nil)
        #expect(args.optionalIntegerValue("missing") == nil)
        #expect(args.optionalBooleanValue("missing") == nil)
    }

    @Test("AgentToolArguments error handling")
    func agentToolArgumentsErrors() throws {
        let args = AgentToolArguments([
            "text": AnyAgentToolValue(string: "hello"),
        ])

        // Test missing parameter error
        #expect(throws: (any Error).self) {
            try args.stringValue("missing")
        }

        // Test wrong type error
        #expect(throws: (any Error).self) {
            try args.numberValue("text")
        }
    }

    // MARK: - Type-Safe Tool Protocol Tests

    @Test("AgentToolProtocol implementation")
    func agentToolProtocol() async throws {
        // Define a concrete tool
        struct WeatherTool: AgentToolProtocol {
            struct Input: AgentToolValue, Equatable {
                let location: String
                let units: String

                static var agentValueType: AgentValueType { .object }

                func toJSON() throws -> Any {
                    ["location": self.location, "units": self.units]
                }

                static func fromJSON(_ json: Any) throws -> Input {
                    guard
                        let dict = json as? [String: Any],
                        let location = dict["location"] as? String,
                        let units = dict["units"] as? String else
                    {
                        throw TachikomaError.invalidInput("Invalid weather input")
                    }
                    return Input(location: location, units: units)
                }
            }

            struct Output: AgentToolValue, Equatable {
                let temperature: Double
                let conditions: String

                static var agentValueType: AgentValueType { .object }

                func toJSON() throws -> Any {
                    ["temperature": self.temperature, "conditions": self.conditions]
                }

                static func fromJSON(_ json: Any) throws -> Output {
                    guard
                        let dict = json as? [String: Any],
                        let temperature = dict["temperature"] as? Double,
                        let conditions = dict["conditions"] as? String else
                    {
                        throw TachikomaError.invalidInput("Invalid weather output")
                    }
                    return Output(temperature: temperature, conditions: conditions)
                }
            }

            var name: String { "get_weather" }
            var description: String { "Get current weather" }
            var schema: AgentToolSchema {
                AgentToolSchema(
                    properties: [
                        "location": AgentPropertySchema(type: .string, description: "City name"),
                        "units": AgentPropertySchema(
                            type: .string,
                            description: "Temperature units",
                            enumValues: ["celsius", "fahrenheit"],
                        ),
                    ],
                    required: ["location", "units"],
                )
            }

            func execute(_: Input, context _: ToolExecutionContext) async throws -> Output {
                // Mock implementation
                Output(temperature: 22.5, conditions: "Sunny")
            }
        }

        let tool = WeatherTool()
        let input = WeatherTool.Input(location: "NYC", units: "celsius")
        let context = ToolExecutionContext()

        let output = try await tool.execute(input, context: context)
        #expect(output.temperature == 22.5)
        #expect(output.conditions == "Sunny")

        // Test AnyAgentTool wrapper
        let anyTool = AnyAgentTool(tool)
        #expect(anyTool.name == "get_weather")
        #expect(anyTool.description == "Get current weather")

        let result = try await anyTool.execute(
            ["location": "NYC", "units": "celsius"],
            context: context,
        )
        #expect(result.objectValue?["temperature"]?.doubleValue == 22.5)
    }

    // MARK: - Edge Cases and Error Handling

    @Test("Handle integer/double ambiguity")
    func integerDoubleAmbiguity() throws {
        // Test that whole numbers can be treated as integers
        let wholeDouble = try AnyAgentToolValue.fromJSON(42.0)
        #expect(wholeDouble.intValue == 42)
        #expect(wholeDouble.doubleValue == 42.0)

        // Test that fractional numbers are only doubles
        let fractional = try AnyAgentToolValue.fromJSON(42.5)
        #expect(fractional.intValue == nil)
        #expect(fractional.doubleValue == 42.5)

        // Test large integers near the Double precision boundary
        let safeInteger = (1 << 53) - 1000
        let largeInt = try AnyAgentToolValue.fromJSON(Double(safeInteger))
        #expect(largeInt.intValue == safeInteger)
    }

    @Test("Handle nested structures")
    func nestedStructures() throws {
        let nested = [
            "level1": [
                "level2": [
                    "level3": ["value": "deep"],
                ],
            ],
        ]

        let value = try AnyAgentToolValue.fromJSON(nested)
        let level1 = value.objectValue?["level1"]?.objectValue
        let level2 = level1?["level2"]?.objectValue
        let level3 = level2?["level3"]?.objectValue
        #expect(level3?["value"]?.stringValue == "deep")
    }

    @Test("Handle mixed-type arrays")
    func mixedTypeArrays() throws {
        let mixed: [Any] = ["string", 42, true, NSNull(), ["nested": "object"]]
        let value = try AnyAgentToolValue.fromJSON(mixed)

        let array = value.arrayValue
        #expect(array?.count == 5)
        #expect(array?[0].stringValue == "string")
        #expect(array?[1].intValue == 42)
        #expect(array?[2].boolValue == true)
        #expect(array?[3].isNull == true)
        #expect(array?[4].objectValue?["nested"]?.stringValue == "object")
    }
}
