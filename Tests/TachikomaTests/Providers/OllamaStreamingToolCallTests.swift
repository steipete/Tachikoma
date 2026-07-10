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

    private static let recursiveToolCallChunk = """
    {"model":"llama3.1:8b","message":{"role":"assistant","content":"","tool_calls":[{"function":{
    "index":0,"name":"run_plan","arguments":{"enabled":true,"metadata":{"attempt":2,"note":null},
    "steps":["inspect",3,false,null,{"kind":"finish"}]}}}]},"done":false}
    """

    private static let zeroArgumentToolCallChunk = """
    {"model":"llama3.1:8b","message":{"role":"assistant","content":"","tool_calls":[{"function":{
    "index":0,"name":"get_status"}}]},"done":false}
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
        #expect(calls[0].function.arguments["city"]?.stringValue == "Paris")
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

    @Test
    func `stream chunk preserves recursive tool arguments`() throws {
        let data = try #require(Self.recursiveToolCallChunk.data(using: .utf8))
        let chunk = try JSONDecoder().decode(OllamaStreamChunk.self, from: data)
        let call = try #require(chunk.message.toolCalls?.first)

        #expect(call.function.index == 0)
        #expect(call.function.arguments["enabled"]?.boolValue == true)
        #expect(call.function.arguments["metadata"]?.objectValue?["attempt"]?.intValue == 2)
        #expect(call.function.arguments["metadata"]?.objectValue?["note"]?.isNull == true)

        let steps = try #require(call.function.arguments["steps"]?.arrayValue)
        #expect(steps[0].stringValue == "inspect")
        #expect(steps[1].intValue == 3)
        #expect(steps[2].boolValue == false)
        #expect(steps[3].isNull)
        #expect(steps[4].objectValue?["kind"]?.stringValue == "finish")

        let converted = OllamaProvider.convertOllamaToolCall(call)
        #expect(converted.arguments == call.function.arguments)
    }

    @Test
    func `stream chunk defaults omitted tool arguments to empty`() throws {
        let data = try #require(Self.zeroArgumentToolCallChunk.data(using: .utf8))
        let chunk = try JSONDecoder().decode(OllamaStreamChunk.self, from: data)
        let call = try #require(chunk.message.toolCalls?.first)

        #expect(call.function.name == "get_status")
        #expect(call.function.arguments.isEmpty)
        #expect(OllamaProvider.convertOllamaToolCall(call).arguments.isEmpty)
    }
}
