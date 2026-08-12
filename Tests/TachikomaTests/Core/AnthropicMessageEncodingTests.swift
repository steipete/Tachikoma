import Foundation
import Testing
@testable import Tachikoma

struct AnthropicMessageEncodingTests {
    @Test
    func `encodes string without quotes`() {
        let value = AnyAgentToolValue(string: "hello")
        #expect(AnthropicMessageEncoding.encodeToolResult(value) == "hello")
    }

    @Test
    func `encodes booleans and numbers`() {
        #expect(AnthropicMessageEncoding.encodeToolResult(AnyAgentToolValue(bool: true)) == "true")
        #expect(AnthropicMessageEncoding.encodeToolResult(AnyAgentToolValue(int: 42)) == "42")
        #expect(AnthropicMessageEncoding.encodeToolResult(AnyAgentToolValue(double: 3.5)) == "3.5")
    }

    @Test
    func `encodes objects as JSON`() {
        let object = AnyAgentToolValue(object: [
            "name": AnyAgentToolValue(string: "Peekaboo"),
            "count": AnyAgentToolValue(int: 2),
        ])
        #expect(AnthropicMessageEncoding.encodeToolResult(object) == "{\"count\":2,\"name\":\"Peekaboo\"}")
    }

    @Test
    func `encodes arrays and null values`() {
        let array = AnyAgentToolValue(array: [AnyAgentToolValue(int: 1), AnyAgentToolValue(int: 2)])
        #expect(AnthropicMessageEncoding.encodeToolResult(array) == "[1,2]")

        let nullValue = AnyAgentToolValue(null: ())
        #expect(AnthropicMessageEncoding.encodeToolResult(nullValue) == "null")
    }

    @Test
    func `encodes structured tool failures with error status`() throws {
        let failure = AgentToolExecutionFailure(
            message: "permission denied",
            content: [AnyAgentToolValue(string: "permission denied")],
            structuredValue: AnyAgentToolValue(object: ["code": AnyAgentToolValue(int: 403)]),
            metadata: AnyAgentToolValue(object: ["retrySafe": AnyAgentToolValue(bool: false)]),
        )
        let result = AgentToolResult.error(toolCallId: "call-failure", failure: failure)
        let messages = [ModelMessage(role: .tool, content: [.toolResult(result)])]

        let converted = try AnthropicMessageConversion.convertMessagesToAnthropic(
            messages,
            thinkingEnabled: false,
        ).1
        let message = try #require(converted.first)
        guard case let .toolResult(toolResult) = try #require(message.content.first) else {
            Issue.record("Expected an Anthropic tool result")
            return
        }

        #expect(toolResult.toolUseId == "call-failure")
        #expect(toolResult.isError == true)
        #expect(toolResult.content.contains("permission denied"))
        #expect(toolResult.content.contains("structuredValue"))
        #expect(toolResult.content.contains("retrySafe"))

        let encoded = try JSONEncoder().encode(message)
        let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let content = try #require(json["content"] as? [[String: Any]])
        #expect(content.first?["is_error"] as? Bool == true)
    }

    @Test
    func `keeps successful Anthropic tool result shape`() throws {
        let result = AgentToolResult.success(
            toolCallId: "call-success",
            result: AnyAgentToolValue(string: "complete"),
        )
        let messages = [ModelMessage(role: .tool, content: [.toolResult(result)])]

        let converted = try AnthropicMessageConversion.convertMessagesToAnthropic(
            messages,
            thinkingEnabled: false,
        ).1
        let message = try #require(converted.first)
        guard case let .toolResult(toolResult) = try #require(message.content.first) else {
            Issue.record("Expected an Anthropic tool result")
            return
        }

        #expect(toolResult.content == "complete")
        #expect(toolResult.isError == nil)

        let encoded = try JSONEncoder().encode(message)
        let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let content = try #require(json["content"] as? [[String: Any]])
        #expect(content.first?["is_error"] == nil)
    }
}
