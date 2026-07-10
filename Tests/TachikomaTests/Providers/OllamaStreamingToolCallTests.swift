import Foundation
import Testing
@testable import Tachikoma

struct OllamaStreamingToolCallTests {
    /// Captured verbatim from a live `POST /api/chat` with `"stream": true` and a
    /// tools array (ollama 0.x, llama3.1:8b). Before this was decoded, the stream
    /// parser only read `content`/`done`, so tool calls were silently dropped and
    /// the agent reported success having executed nothing.
    private static let toolCallChunk = """
    {"model":"llama3.1:8b","created_at":"2026-07-10T09:40:30.514383Z","message":{"role":"assistant",\
    "content":"","tool_calls":[{"id":"call_icagibop","function":{"index":0,"name":"get_weather",\
    "arguments":{"city":"Paris"}}}]},"done":false}
    """

    private static let doneChunk = """
    {"model":"llama3.1:8b","created_at":"2026-07-10T09:40:30.52607Z",\
    "message":{"role":"assistant","content":""},"done":true,"done_reason":"stop"}
    """

    @Test
    func `stream chunk decodes native tool calls`() throws {
        let data = try #require(Self.toolCallChunk.data(using: .utf8))
        let chunk = try JSONDecoder().decode(OllamaStreamChunk.self, from: data)

        #expect(chunk.done == false)
        // Ollama pairs an empty content string with the tool calls.
        #expect(chunk.message.content?.isEmpty == true)
        let calls = try #require(chunk.message.toolCalls)
        #expect(calls.count == 1)
        #expect(calls[0].function.name == "get_weather")
        #expect(calls[0].function.arguments["city"] as? String == "Paris")
    }

    @Test
    func `stream chunk without tool calls still decodes`() throws {
        let data = try #require(Self.doneChunk.data(using: .utf8))
        let chunk = try JSONDecoder().decode(OllamaStreamChunk.self, from: data)

        #expect(chunk.done == true)
        #expect(chunk.message.toolCalls == nil)
    }

    @Test
    func `decoded tool call converts to an AgentToolCall`() throws {
        let data = try #require(Self.toolCallChunk.data(using: .utf8))
        let chunk = try JSONDecoder().decode(OllamaStreamChunk.self, from: data)
        let ollamaCall = try #require(chunk.message.toolCalls?.first)

        let agentCall = OllamaProvider.convertOllamaToolCall(ollamaCall)

        #expect(agentCall.name == "get_weather")
        #expect(agentCall.arguments["city"]?.stringValue == "Paris")
        #expect(agentCall.id.hasPrefix("ollama_"))
    }
}
