//
//  TypeConversionTests.swift
//  TachikomaMCP
//

import Testing
import Foundation
@testable import Tachikoma
@testable import TachikomaMCP
import MCP

@Suite("Type Conversion Tests")
struct TypeConversionTests {
    
    @Test("AgentToolArgument to Any conversion")
    func testAgentToolArgumentToAny() {
        // String
        let stringArg = AgentToolArgument.string("hello")
        let stringAny = stringArg.toAny()
        #expect(stringAny as? String == "hello")
        
        // Int
        let intArg = AgentToolArgument.int(42)
        let intAny = intArg.toAny()
        #expect(intAny as? Int == 42)
        
        // Double
        let doubleArg = AgentToolArgument.double(3.14)
        let doubleAny = doubleArg.toAny()
        #expect(doubleAny as? Double == 3.14)
        
        // Bool
        let boolArg = AgentToolArgument.bool(true)
        let boolAny = boolArg.toAny()
        #expect(boolAny as? Bool == true)
        
        // Null
        let nullArg = AgentToolArgument.null
        let nullAny = nullArg.toAny()
        #expect(nullAny is NSNull)
        
        // Array
        let arrayArg = AgentToolArgument.array([.string("a"), .int(1)])
        let arrayAny = arrayArg.toAny() as? [Any]
        #expect(arrayAny?.count == 2)
        #expect(arrayAny?[0] as? String == "a")
        #expect(arrayAny?[1] as? Int == 1)
        
        // Object
        let objectArg = AgentToolArgument.object([
            "name": .string("test"),
            "count": .int(5)
        ])
        let objectAny = objectArg.toAny() as? [String: Any]
        #expect(objectAny?["name"] as? String == "test")
        #expect(objectAny?["count"] as? Int == 5)
    }
    
    @Test("Any to AgentToolArgument conversion")
    func testAnyToAgentToolArgument() {
        // String
        let stringArg = AgentToolArgument.from("hello")
        #expect(stringArg == .string("hello"))
        
        // Int
        let intArg = AgentToolArgument.from(42)
        #expect(intArg == .int(42))
        
        // Double
        let doubleArg = AgentToolArgument.from(3.14)
        #expect(doubleArg == .double(3.14))
        
        // Bool
        let boolArg = AgentToolArgument.from(true)
        #expect(boolArg == .bool(true))
        
        // NSNull
        let nullArg = AgentToolArgument.from(NSNull())
        #expect(nullArg == .null)
        
        // Array
        let array: [Any] = ["a", 1, true]
        let arrayArg = AgentToolArgument.from(array)
        if case let .array(elements) = arrayArg {
            #expect(elements.count == 3)
            #expect(elements[0] == .string("a"))
            #expect(elements[1] == .int(1))
            #expect(elements[2] == .bool(true))
        } else {
            Issue.record("Expected array argument")
        }
        
        // Dictionary
        let dict: [String: Any] = ["name": "test", "count": 5]
        let objectArg = AgentToolArgument.from(dict)
        if case let .object(properties) = objectArg {
            #expect(properties["name"] == .string("test"))
            #expect(properties["count"] == .int(5))
        } else {
            Issue.record("Expected object argument")
        }
        
        // Unsupported type (should convert to string)
        let dateArg = AgentToolArgument.from(Date())
        if case .string = dateArg {
            // Success - converted to string representation
        } else {
            Issue.record("Expected string for unsupported type")
        }
    }
    
    @Test("AgentToolArgument to Value conversion")
    func testAgentToolArgumentToValue() {
        // String
        let stringArg = AgentToolArgument.string("hello")
        let stringValue = stringArg.toValue()
        #expect(stringValue == .string("hello"))
        
        // Int
        let intArg = AgentToolArgument.int(42)
        let intValue = intArg.toValue()
        #expect(intValue == .int(42))
        
        // Double
        let doubleArg = AgentToolArgument.double(3.14)
        let doubleValue = doubleArg.toValue()
        #expect(doubleValue == .double(3.14))
        
        // Bool
        let boolArg = AgentToolArgument.bool(true)
        let boolValue = boolArg.toValue()
        #expect(boolValue == .bool(true))
        
        // Null
        let nullArg = AgentToolArgument.null
        let nullValue = nullArg.toValue()
        #expect(nullValue == .null)
        
        // Array
        let arrayArg = AgentToolArgument.array([.string("a"), .int(1)])
        let arrayValue = arrayArg.toValue()
        if case let .array(elements) = arrayValue {
            #expect(elements.count == 2)
            #expect(elements[0] == .string("a"))
            #expect(elements[1] == .int(1))
        } else {
            Issue.record("Expected array value")
        }
        
        // Object
        let objectArg = AgentToolArgument.object([
            "name": .string("test"),
            "count": .int(5)
        ])
        let objectValue = objectArg.toValue()
        if case let .object(properties) = objectValue {
            #expect(properties["name"] == .string("test"))
            #expect(properties["count"] == .int(5))
        } else {
            Issue.record("Expected object value")
        }
    }
    
    @Test("Value to AgentToolArgument conversion")
    func testValueToAgentToolArgument() {
        // String
        let stringValue = Value.string("hello")
        let stringArg = stringValue.toAgentToolArgument()
        #expect(stringArg == .string("hello"))
        
        // Int
        let intValue = Value.int(42)
        let intArg = intValue.toAgentToolArgument()
        #expect(intArg == .int(42))
        
        // Double
        let doubleValue = Value.double(3.14)
        let doubleArg = doubleValue.toAgentToolArgument()
        #expect(doubleArg == .double(3.14))
        
        // Bool
        let boolValue = Value.bool(true)
        let boolArg = boolValue.toAgentToolArgument()
        #expect(boolArg == .bool(true))
        
        // Null
        let nullValue = Value.null
        let nullArg = nullValue.toAgentToolArgument()
        #expect(nullArg == .null)
        
        // Array
        let arrayValue = Value.array([.string("a"), .int(1)])
        let arrayArg = arrayValue.toAgentToolArgument()
        if case let .array(elements) = arrayArg {
            #expect(elements.count == 2)
            #expect(elements[0] == .string("a"))
            #expect(elements[1] == .int(1))
        } else {
            Issue.record("Expected array argument")
        }
        
        // Object
        let objectValue = Value.object([
            "name": .string("test"),
            "count": .int(5)
        ])
        let objectArg = objectValue.toAgentToolArgument()
        if case let .object(properties) = objectArg {
            #expect(properties["name"] == .string("test"))
            #expect(properties["count"] == .int(5))
        } else {
            Issue.record("Expected object argument")
        }
    }
    
    @Test("ToolArguments initialization from AgentToolArguments")
    func testToolArgumentsFromAgentToolArguments() {
        let agentArgs = AgentToolArguments([
            "text": .string("hello"),
            "number": .int(42),
            "flag": .bool(true),
            "nested": .object(["key": .string("value")])
        ])
        
        let toolArgs = ToolArguments(from: agentArgs)
        
        #expect(toolArgs.getString("text") == "hello")
        #expect(toolArgs.getInt("number") == 42)
        #expect(toolArgs.getBool("flag") == true)
        
        // Check nested object
        if let nestedValue = toolArgs.getValue(for: "nested"),
           case let .object(nested) = nestedValue {
            #expect(nested["key"] == .string("value"))
        } else {
            Issue.record("Expected nested object")
        }
    }
    
    @Test("ToolResponse to AgentToolArgument conversion via toAgentToolResult")
    func testToolResponseToAgentToolResult() {
        // Text response
        let textResponse = ToolResponse.text("Success message")
        let textResult = textResponse.toAgentToolResult()
        #expect(textResult == .string("Success message"))
        
        // Error response
        let errorResponse = ToolResponse.error("Something went wrong")
        let errorResult = errorResponse.toAgentToolResult()
        #expect(errorResult == .string("Error: Something went wrong"))
        
        // Image response
        let imageData = Data("fake image data".utf8)
        let imageResponse = ToolResponse.image(data: imageData, mimeType: "image/png")
        let imageResult = imageResponse.toAgentToolResult()
        if case let .string(str) = imageResult {
            #expect(str.contains("Image: image/png"))
        } else {
            Issue.record("Expected string result for image")
        }
        
        // Empty response
        let emptyResponse = ToolResponse(content: [], isError: false)
        let emptyResult = emptyResponse.toAgentToolResult()
        #expect(emptyResult == .string("Success"))
    }
    
    @Test("ToolResponse to AgentToolArgument conversion")
    func testToolResponseToAgentToolArgument() {
        // Single text content
        let textResponse = ToolResponse.text("Hello")
        let textArg = textResponse.toAgentToolArgument()
        #expect(textArg == .string("Hello"))
        
        // Multiple content items
        let multiResponse = ToolResponse.multiContent([
            .text("Part 1"),
            .text("Part 2")
        ])
        let multiArg = multiResponse.toAgentToolArgument()
        if case let .array(elements) = multiArg {
            #expect(elements.count == 2)
            #expect(elements[0] == .string("Part 1"))
            #expect(elements[1] == .string("Part 2"))
        } else {
            Issue.record("Expected array for multiple content")
        }
        
        // Image content
        let imageResponse = ToolResponse(content: [
            .image(data: "base64data", mimeType: "image/png", metadata: nil)
        ])
        let imageArg = imageResponse.toAgentToolArgument()
        if case let .object(props) = imageArg {
            #expect(props["type"] == .string("image"))
            #expect(props["mimeType"] == .string("image/png"))
            #expect(props["data"] == .string("base64data"))
        } else {
            Issue.record("Expected object for image content")
        }
        
        // Resource content
        let resourceResponse = ToolResponse(content: [
            .resource(uri: "https://example.com", mimeType: "text/html", text: "content")
        ])
        let resourceArg = resourceResponse.toAgentToolArgument()
        if case let .object(props) = resourceArg {
            #expect(props["type"] == .string("resource"))
            #expect(props["uri"] == .string("https://example.com"))
            #expect(props["mimeType"] == .string("text/html"))
            #expect(props["text"] == .string("content"))
        } else {
            Issue.record("Expected object for resource content")
        }
    }
    
    @Test("Round-trip conversions")
    func testRoundTripConversions() {
        // AgentToolArgument -> Value -> AgentToolArgument
        let originalArg = AgentToolArgument.object([
            "string": .string("test"),
            "number": .int(123),
            "float": .double(45.67),
            "bool": .bool(false),
            "null": .null,
            "array": .array([.string("a"), .string("b")]),
            "nested": .object(["key": .string("value")])
        ])
        
        let value = originalArg.toValue()
        let roundTripArg = value.toAgentToolArgument()
        
        #expect(originalArg == roundTripArg)
        
        // Any -> AgentToolArgument -> Any
        let originalDict: [String: Any] = [
            "name": "test",
            "count": 42,
            "active": true,
            "tags": ["swift", "testing"]
        ]
        
        let argument = AgentToolArgument.from(originalDict)
        let roundTripAny = argument.toAny()
        
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