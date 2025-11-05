import MCP
import Tachikoma
import Testing
@testable import TachikomaMCP

@Suite("MCP Tool Adapter Tests")
struct MCPToolAdapterTests {
    @Test("ToolArguments getString")
    func toolArgumentsGetString() {
        let args = ToolArguments(raw: [
            "name": "Alice",
            "count": 42,
            "ratio": 3.14,
            "active": true,
        ])

        #expect(args.getString("name") == "Alice")
        #expect(args.getString("count") == "42")
        #expect(args.getString("ratio") == "3.14")
        #expect(args.getString("active") == "true")
        #expect(args.getString("missing") == nil)
    }

    @Test("ToolArguments getNumber")
    func toolArgumentsGetNumber() {
        let args = ToolArguments(raw: [
            "int": 42,
            "double": 3.14,
            "string": "2.5",
            "invalid": "abc",
        ])

        #expect(args.getNumber("int") == 42.0)
        #expect(args.getNumber("double") == 3.14)
        #expect(args.getNumber("string") == 2.5)
        #expect(args.getNumber("invalid") == nil)
        #expect(args.getNumber("missing") == nil)
    }

    @Test("ToolArguments getInt")
    func toolArgumentsGetInt() {
        let args = ToolArguments(raw: [
            "int": 42,
            "double": 3.14,
            "string": "25",
            "invalid": "abc",
        ])

        #expect(args.getInt("int") == 42)
        #expect(args.getInt("double") == 3)
        #expect(args.getInt("string") == 25)
        #expect(args.getInt("invalid") == nil)
        #expect(args.getInt("missing") == nil)
    }

    @Test("ToolArguments getBool")
    func toolArgumentsGetBool() {
        let args = ToolArguments(raw: [
            "bool": true,
            "stringTrue": "true",
            "stringYes": "yes",
            "string1": "1",
            "stringFalse": "false",
            "int0": 0,
            "int1": 1,
        ])

        #expect(args.getBool("bool") == true)
        #expect(args.getBool("stringTrue") == true)
        #expect(args.getBool("stringYes") == true)
        #expect(args.getBool("string1") == true)
        #expect(args.getBool("stringFalse") == false)
        #expect(args.getBool("int0") == false)
        #expect(args.getBool("int1") == true)
        #expect(args.getBool("missing") == nil)
    }

    @Test("ToolArguments getStringArray")
    func toolArgumentsGetStringArray() {
        let args = ToolArguments(raw: [
            "array": ["a", "b", "c"],
            "mixed": ["string", 123, true],
            "notArray": "single",
        ])

        #expect(args.getStringArray("array") == ["a", "b", "c"])
        #expect(args.getStringArray("mixed") == ["string"]) // Only strings extracted
        #expect(args.getStringArray("notArray") == nil)
        #expect(args.getStringArray("missing") == nil)
    }

    @Test("ToolArguments isEmpty")
    func toolArgumentsIsEmpty() {
        let emptyArgs = ToolArguments(raw: [:])
        #expect(emptyArgs.isEmpty == true)

        let nonEmptyArgs = ToolArguments(raw: ["key": "value"])
        #expect(nonEmptyArgs.isEmpty == false)
    }

    @Test("ToolResponse text creation")
    func toolResponseText() {
        let response = ToolResponse.text("Hello, world!")

        #expect(response.isError == false)
        #expect(response.content.count == 1)
        if case let .text(text) = response.content[0] {
            #expect(text == "Hello, world!")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("ToolResponse error creation")
    func toolResponseError() {
        let response = ToolResponse.error("Something went wrong")

        #expect(response.isError == true)
        #expect(response.content.count == 1)
        if case let .text(text) = response.content[0] {
            #expect(text == "Something went wrong")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("ToolResponse image creation")
    func toolResponseImage() {
        let imageData = Data([0xFF, 0xD8, 0xFF]) // JPEG header
        let response = ToolResponse.image(data: imageData, mimeType: "image/jpeg")

        #expect(response.isError == false)
        #expect(response.content.count == 1)
        if case let .image(data, mimeType, _) = response.content[0] {
            #expect(data == imageData.base64EncodedString())
            #expect(mimeType == "image/jpeg")
        } else {
            Issue.record("Expected image content")
        }
    }
}
