import Foundation
import MCP
import Testing
@testable import Tachikoma
@testable import TachikomaMCP

@Suite("Type Conversion Tests")
struct TypeConversionTests {
    @Test("AnyAgentToolValue to JSON conversion")
    func anyAgentToolValueToJSON() throws {
        // String
        let stringVal = AnyAgentToolValue(string: "hello")
        let stringJSON = try stringVal.toJSON()
        #expect(stringJSON as? String == "hello")

        // Int
        let intVal = AnyAgentToolValue(int: 42)
        let intJSON = try intVal.toJSON()
        #expect(intJSON as? Int == 42)

        // Double
        let doubleVal = AnyAgentToolValue(double: 3.14)
        let doubleJSON = try doubleVal.toJSON()
        #expect(doubleJSON as? Double == 3.14)

        // Bool
        let boolVal = AnyAgentToolValue(bool: true)
        let boolJSON = try boolVal.toJSON()
        #expect(boolJSON as? Bool == true)

        // Null
        let nullVal = AnyAgentToolValue(null: ())
        let nullJSON = try nullVal.toJSON()
        #expect(nullJSON is NSNull)

        // Array
        let arrayVal = AnyAgentToolValue(array: [AnyAgentToolValue(string: "a"), AnyAgentToolValue(int: 1)])
        let arrayJSON = try arrayVal.toJSON() as? [Any]
        #expect(arrayJSON?.count == 2)
        #expect(arrayJSON?[0] as? String == "a")
        #expect(arrayJSON?[1] as? Int == 1)

        // Object
        let objectVal = AnyAgentToolValue(object: [
            "name": AnyAgentToolValue(string: "test"),
            "count": AnyAgentToolValue(int: 5),
        ])
        let objectJSON = try objectVal.toJSON() as? [String: Any]
        #expect(objectJSON?["name"] as? String == "test")
        #expect(objectJSON?["count"] as? Int == 5)
    }

    @Test("Any to AnyAgentToolValue conversion")
    func anyToAnyAgentToolValue() throws {
        // String
        let stringVal = AnyAgentToolValue.from("hello")
        #expect(stringVal.stringValue == "hello")

        // Int
        let intVal = AnyAgentToolValue.from(42)
        #expect(intVal.intValue == 42)

        // Double
        let doubleVal = AnyAgentToolValue.from(3.14)
        #expect(doubleVal.doubleValue == 3.14)

        // Bool
        let boolVal = AnyAgentToolValue.from(true)
        #expect(boolVal.boolValue == true)

        // NSNull
        let nullVal = AnyAgentToolValue.from(NSNull())
        #expect(nullVal.isNull == true)

        // Array
        let array: [Any] = ["a", 1, true]
        let arrayVal = AnyAgentToolValue.from(array)
        if let elements = arrayVal.arrayValue {
            #expect(elements.count == 3)
            #expect(elements[0].stringValue == "a")
            #expect(elements[1].intValue == 1)
            #expect(elements[2].boolValue == true)
        } else {
            Issue.record("Expected array value")
        }

        // Dictionary
        let dict: [String: Any] = ["name": "test", "count": 5]
        let objectVal = AnyAgentToolValue.from(dict)
        if let properties = objectVal.objectValue {
            #expect(properties["name"]?.stringValue == "test")
            #expect(properties["count"]?.intValue == 5)
        } else {
            Issue.record("Expected object value")
        }

        // Unsupported type (should convert to string)
        let dateVal = AnyAgentToolValue.from(Date())
        #expect(dateVal.stringValue != nil)
    }

    @Test("AnyAgentToolValue to Value conversion")
    func anyAgentToolValueToValue() {
        // String
        let stringVal = AnyAgentToolValue(string: "hello")
        let stringValue = stringVal.toValue()
        #expect(stringValue == .string("hello"))

        // Int
        let intVal = AnyAgentToolValue(int: 42)
        let intValue = intVal.toValue()
        #expect(intValue == .int(42))

        // Double
        let doubleVal = AnyAgentToolValue(double: 3.14)
        let doubleValue = doubleVal.toValue()
        #expect(doubleValue == .double(3.14))

        // Bool
        let boolVal = AnyAgentToolValue(bool: true)
        let boolValue = boolVal.toValue()
        #expect(boolValue == .bool(true))

        // Null
        let nullVal = AnyAgentToolValue(null: ())
        let nullValue = nullVal.toValue()
        #expect(nullValue == .null)

        // Array
        let arrayVal = AnyAgentToolValue(array: [AnyAgentToolValue(string: "a"), AnyAgentToolValue(int: 1)])
        let arrayValue = arrayVal.toValue()
        if case let .array(elements) = arrayValue {
            #expect(elements.count == 2)
            #expect(elements[0] == .string("a"))
            #expect(elements[1] == .int(1))
        } else {
            Issue.record("Expected array value")
        }

        // Object
        let objectVal = AnyAgentToolValue(object: [
            "name": AnyAgentToolValue(string: "test"),
            "count": AnyAgentToolValue(int: 5),
        ])
        let objectValue = objectVal.toValue()
        if case let .object(properties) = objectValue {
            #expect(properties["name"] == .string("test"))
            #expect(properties["count"] == .int(5))
        } else {
            Issue.record("Expected object value")
        }
    }

    @Test("Value to AnyAgentToolValue conversion")
    func valueToAnyAgentToolValue() {
        // String
        let stringValue = Value.string("hello")
        let stringVal = stringValue.toAnyAgentToolValue()
        #expect(stringVal.stringValue == "hello")

        // Int
        let intValue = Value.int(42)
        let intVal = intValue.toAnyAgentToolValue()
        #expect(intVal.intValue == 42)

        // Double
        let doubleValue = Value.double(3.14)
        let doubleVal = doubleValue.toAnyAgentToolValue()
        #expect(doubleVal.doubleValue == 3.14)

        // Bool
        let boolValue = Value.bool(true)
        let boolVal = boolValue.toAnyAgentToolValue()
        #expect(boolVal.boolValue == true)

        // Null
        let nullValue = Value.null
        let nullVal = nullValue.toAnyAgentToolValue()
        #expect(nullVal.isNull == true)

        // Array
        let arrayValue = Value.array([.string("a"), .int(1)])
        let arrayVal = arrayValue.toAnyAgentToolValue()
        if let elements = arrayVal.arrayValue {
            #expect(elements.count == 2)
            #expect(elements[0].stringValue == "a")
            #expect(elements[1].intValue == 1)
        } else {
            Issue.record("Expected array value")
        }

        // Object
        let objectValue = Value.object([
            "name": .string("test"),
            "count": .int(5),
        ])
        let objectVal = objectValue.toAnyAgentToolValue()
        if let properties = objectVal.objectValue {
            #expect(properties["name"]?.stringValue == "test")
            #expect(properties["count"]?.intValue == 5)
        } else {
            Issue.record("Expected object value")
        }
    }

    @Test("ToolArguments initialization from AgentToolArguments")
    func toolArgumentsFromAgentToolArguments() throws {
        let agentArgs = AgentToolArguments([
            "text": AnyAgentToolValue(string: "hello"),
            "number": AnyAgentToolValue(int: 42),
            "flag": AnyAgentToolValue(bool: true),
            "nested": AnyAgentToolValue(object: ["key": AnyAgentToolValue(string: "value")]),
        ])

        let toolArgs = ToolArguments(from: agentArgs)

        #expect(toolArgs.getString("text") == "hello")
        #expect(toolArgs.getInt("number") == 42)
        #expect(toolArgs.getBool("flag") == true)

        // Check nested object
        if
            let nestedValue = toolArgs.getValue(for: "nested"),
            case let .object(nested) = nestedValue
        {
            #expect(nested["key"] == .string("value"))
        } else {
            Issue.record("Expected nested object")
        }
    }

    @Test("ToolResponse to AnyAgentToolValue conversion via toAgentToolResult")
    func toolResponseToAgentToolResult() {
        // Text response
        let textResponse = ToolResponse.text("Success message")
        let textResult = textResponse.toAgentToolResult()
        #expect(textResult.stringValue == "Success message")

        // Error response
        let errorResponse = ToolResponse.error("Something went wrong")
        let errorResult = errorResponse.toAgentToolResult()
        #expect(errorResult.stringValue == "Error: Something went wrong")

        // Image response
        let imageData = Data("fake image data".utf8)
        let imageResponse = ToolResponse.image(data: imageData, mimeType: "image/png")
        let imageResult = imageResponse.toAgentToolResult()
        if let str = imageResult.stringValue {
            #expect(str.contains("Image: image/png"))
        } else {
            Issue.record("Expected string result for image")
        }

        // Empty response
        let emptyResponse = ToolResponse(content: [], isError: false)
        let emptyResult = emptyResponse.toAgentToolResult()
        #expect(emptyResult.stringValue == "Success")
    }

    @Test("ToolResponse to AnyAgentToolValue conversion")
    func toolResponseToAnyAgentToolValue() {
        // Single text content
        let textResponse = ToolResponse.text("Hello")
        let textVal = textResponse.toAnyAgentToolValue()
        #expect(textVal.stringValue == "Hello")

        // Multiple content items
        let multiResponse = ToolResponse.multiContent([
            .text("Part 1"),
            .text("Part 2"),
        ])
        let multiVal = multiResponse.toAnyAgentToolValue()
        if let elements = multiVal.arrayValue {
            #expect(elements.count == 2)
            #expect(elements[0].stringValue == "Part 1")
            #expect(elements[1].stringValue == "Part 2")
        } else {
            Issue.record("Expected array for multiple content")
        }

        // Image content
        let imageResponse = ToolResponse(content: [
            .image(data: "base64data", mimeType: "image/png", metadata: nil),
        ])
        let imageVal = imageResponse.toAnyAgentToolValue()
        if let props = imageVal.objectValue {
            #expect(props["type"]?.stringValue == "image")
            #expect(props["mimeType"]?.stringValue == "image/png")
            #expect(props["data"]?.stringValue == "base64data")
        } else {
            Issue.record("Expected object for image content")
        }

        // Resource content
        let resourceResponse = ToolResponse(content: [
            .resource(uri: "https://example.com", mimeType: "text/html", text: "content"),
        ])
        let resourceVal = resourceResponse.toAnyAgentToolValue()
        if let props = resourceVal.objectValue {
            #expect(props["type"]?.stringValue == "resource")
            #expect(props["uri"]?.stringValue == "https://example.com")
            #expect(props["mimeType"]?.stringValue == "text/html")
            #expect(props["text"]?.stringValue == "content")
        } else {
            Issue.record("Expected object for resource content")
        }
    }

    @Test("Round-trip conversions")
    func roundTripConversions() throws {
        // AnyAgentToolValue -> Value -> AnyAgentToolValue
        let originalVal = AnyAgentToolValue(object: [
            "string": AnyAgentToolValue(string: "test"),
            "number": AnyAgentToolValue(int: 123),
            "float": AnyAgentToolValue(double: 45.67),
            "bool": AnyAgentToolValue(bool: false),
            "null": AnyAgentToolValue(null: ()),
            "array": AnyAgentToolValue(array: [AnyAgentToolValue(string: "a"), AnyAgentToolValue(string: "b")]),
            "nested": AnyAgentToolValue(object: ["key": AnyAgentToolValue(string: "value")]),
        ])

        let value = originalVal.toValue()
        let roundTripVal = value.toAnyAgentToolValue()

        #expect(originalVal == roundTripVal)

        // Any -> AnyAgentToolValue -> Any
        let originalDict: [String: Any] = [
            "name": "test",
            "count": 42,
            "active": true,
            "tags": ["swift", "testing"],
        ]

        let toolValue = AnyAgentToolValue.from(originalDict)
        let roundTripAny = try toolValue.toJSON()

        if let dict = roundTripAny as? [String: Any] {
            #expect(dict["name"] as? String == "test")
            #expect(dict["count"] as? Int == 42)
            #expect(dict["active"] as? Bool == true)
            #expect((dict["tags"] as? [Any])?.count == 2)
        } else {
            Issue.record("Expected dictionary after round trip")
        }
    }
}

// Note: Helper extensions are now provided by TachikomaMCP/Bridge/TypeConversions.swift
