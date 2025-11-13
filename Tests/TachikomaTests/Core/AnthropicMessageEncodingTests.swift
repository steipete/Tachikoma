import Testing
@testable import Tachikoma

@Suite
struct AnthropicMessageEncodingTests {
    @Test
    func encodesStringWithoutQuotes() {
        let value = AnyAgentToolValue(string: "hello")
        #expect(AnthropicMessageEncoding.encodeToolResult(value) == "hello")
    }

    @Test
    func encodesBooleansAndNumbers() {
        #expect(AnthropicMessageEncoding.encodeToolResult(AnyAgentToolValue(bool: true)) == "true")
        #expect(AnthropicMessageEncoding.encodeToolResult(AnyAgentToolValue(int: 42)) == "42")
        #expect(AnthropicMessageEncoding.encodeToolResult(AnyAgentToolValue(double: 3.5)) == "3.5")
    }

    @Test
    func encodesObjectsAsJSON() {
        let object = AnyAgentToolValue(object: [
            "name": AnyAgentToolValue(string: "Peekaboo"),
            "count": AnyAgentToolValue(int: 2),
        ])
        #expect(AnthropicMessageEncoding.encodeToolResult(object) == "{\"count\":2,\"name\":\"Peekaboo\"}")
    }

    @Test
    func encodesArraysAndNullValues() {
        let array = AnyAgentToolValue(array: [AnyAgentToolValue(int: 1), AnyAgentToolValue(int: 2)])
        #expect(AnthropicMessageEncoding.encodeToolResult(array) == "[1,2]")

        let nullValue = AnyAgentToolValue(null: ())
        #expect(AnthropicMessageEncoding.encodeToolResult(nullValue) == "null")
    }
}
