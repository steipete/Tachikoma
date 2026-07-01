import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import Tachikoma

#if os(Linux)
@Suite(.disabled("URLProtocol mocking unavailable on Linux"))
struct OpenAICompatibleHelperTests {}
#else

@Suite(.serialized)
struct OpenAICompatibleHelperTests {
    @Test
    func `generateText encodes stop sequences, headers, and tool definitions`() async throws {
        let tool = AgentTool(
            name: "lookup",
            description: "Lookup a value",
            parameters: AgentToolParameters(
                properties: [
                    "query": AgentToolParameterProperty(
                        name: "query",
                        type: .string,
                        description: "Query string",
                    ),
                ],
                required: ["query"],
            ),
        ) { _ in AnyAgentToolValue(string: "unused") }

        let request = ProviderRequest(
            messages: [ModelMessage(role: .user, content: [.text("ping")])],
            tools: [tool],
            settings: GenerationSettings(
                maxTokens: 64,
                temperature: 0.2,
                stopConditions: StringStopCondition("END"),
            ),
        )

        let capture = CapturedRequest()

        let response = try await withMockedSession { urlRequest in
            #expect(urlRequest.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true)
            capture.body = self.bodyData(from: urlRequest)
            return self.jsonResponse(for: urlRequest, data: Self.chatCompletionPayload(text: "pong"))
        } operation: { session in
            try await OpenAICompatibleHelper.generateText(
                request: request,
                modelId: "compatible-model",
                baseURL: "https://mock.compatible",
                apiKey: "sk-test",
                providerName: "TestProvider",
                additionalHeaders: ["X-Test": "1"],
                session: session,
            )
        }

        #expect(response.text == "pong")

        let bodyJSON = try #require(capture.body).jsonObject()
        let stop = bodyJSON["stop"] as? [String]
        #expect(stop == ["END"])
        #expect(bodyJSON["temperature"] as? Double == 0.2)
        let tools = bodyJSON["tools"] as? [[String: Any]]
        let firstTool = try #require(tools?.first)
        #expect(firstTool["type"] as? String == "function")
        let function = firstTool["function"] as? [String: Any]
        let parameters = try #require(function?["parameters"] as? [String: Any])
        let properties = try #require(parameters["properties"] as? [String: Any])
        let query = try #require(properties["query"] as? [String: Any])
        #expect(query["type"] as? String == "string")
        let required = parameters["required"] as? [String]
        #expect(required == ["query"])
    }

    @Test
    func `streamText emits deltas as SSE chunks arrive`() async throws {
        let request = ProviderRequest(
            messages: [ModelMessage(role: .user, content: [.text("stream")])],
        )

        let deltas = try await withMockedSession { urlRequest in
            let sse = """
            data: {\"id\":\"chunk_1\",\"choices\":[{\"delta\":{\"content\":\"Hello\"},\"index\":0,\"finish_reason\":null}]}

            data: {\"id\":\"chunk_2\",\"choices\":[{\"delta\":{\"content\":\" world\"},\"index\":0,\"finish_reason\":null}]}

            data: {\"id\":\"chunk_3\",\"choices\":[{\"delta\":{},\"index\":0,\"finish_reason\":\"stop\"}]}

            data: [DONE]

            """.utf8Data()
            let response = HTTPURLResponse(
                url: urlRequest.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"],
            )!
            return (response, sse)
        } operation: { session in
            let stream = try await OpenAICompatibleHelper.streamText(
                request: request,
                modelId: "compatible-model",
                baseURL: "https://mock.compatible",
                apiKey: "sk-test",
                providerName: "TestProvider",
                session: session,
            )

            var collected = ""
            for try await delta in stream {
                if delta.type == .textDelta {
                    collected += delta.content ?? ""
                }
            }
            return collected
        }

        #expect(deltas == "Hello world")
    }

    @Test
    func `streamText maps content filter finish reasons`() async throws {
        let request = ProviderRequest(
            messages: [ModelMessage(role: .user, content: [.text("blocked")])],
        )

        let deltas = try await withMockedSession { urlRequest in
            let sse = """
            data: {\"id\":\"chunk_1\",\"choices\":[{\"delta\":{\"content\":\"partial\"},\"index\":0,\"finish_reason\":null}]}

            data: {\"id\":\"chunk_2\",\"choices\":[{\"delta\":{},\"index\":0,\"finish_reason\":\"content_filter\"}]}

            data: [DONE]

            """.utf8Data()
            let response = HTTPURLResponse(
                url: urlRequest.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"],
            )!
            return (response, sse)
        } operation: { session in
            let stream = try await OpenAICompatibleHelper.streamText(
                request: request,
                modelId: "compatible-model",
                baseURL: "https://mock.compatible",
                apiKey: "sk-test",
                providerName: "TestProvider",
                session: session,
            )

            var deltas: [TextStreamDelta] = []
            for try await delta in stream {
                deltas.append(delta)
            }
            return deltas
        }

        #expect(deltas.contains { $0.type == .textDelta && $0.content == "partial" })
        #expect(deltas.contains { $0.type == .done && $0.finishReason == .contentFilter })
    }

    @Test
    func `streamText emits Kimi reasoning content`() async throws {
        let request = ProviderRequest(messages: [.user("stream")])

        let deltas = try await self.withMockedSession { urlRequest in
            let sse = """
            data: {"id":"chunk_1","choices":[{"delta":{"reasoning_content":"thinking"},"index":0,"finish_reason":null}]}

            data: {"id":"chunk_2","choices":[{"delta":{"content":"answer"},"index":0,"finish_reason":null}]}

            data: {"id":"chunk_3","choices":[{"delta":{},"index":0,"finish_reason":"stop"}]}

            data: [DONE]

            """.utf8Data()
            let response = HTTPURLResponse(
                url: urlRequest.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"],
            )!
            return (response, sse)
        } operation: { session in
            let stream = try await OpenAICompatibleHelper.streamText(
                request: request,
                modelId: "kimi-k2.7-code",
                baseURL: "https://api.moonshot.cn/v1",
                apiKey: "sk-test",
                providerName: "Kimi",
                session: session,
            )

            var deltas: [TextStreamDelta] = []
            for try await delta in stream {
                deltas.append(delta)
            }
            return deltas
        }

        #expect(deltas.contains {
            $0.type == .reasoning && $0.content == "thinking" && $0.reasoningType == "kimi_reasoning_content"
        })
        #expect(deltas.contains { $0.type == .textDelta && $0.content == "answer" })
    }

    @Test
    func `OpenAI-compatible provider forwards configured headers`() async throws {
        let request = ProviderRequest(
            messages: [ModelMessage(role: .user, content: [.text("ping")])],
        )

        try await self.withMockedSession { urlRequest in
            #expect(urlRequest.value(forHTTPHeaderField: "client_id") == "proxy-client")
            #expect(urlRequest.value(forHTTPHeaderField: "client_secret") == "proxy-secret")
            return self.jsonResponse(for: urlRequest, data: Self.chatCompletionPayload(text: "pong"))
        } operation: { session in
            let configuration = TachikomaConfiguration(apiKeys: ["openai_compatible": "sk-test"])
            let provider = try OpenAICompatibleProvider(
                modelId: "compatible-model",
                baseURL: "https://mock.compatible",
                configuration: configuration,
                additionalHeaders: [
                    "client_id": "proxy-client",
                    "client_secret": "proxy-secret",
                ],
                session: session,
            )

            let response = try await provider.generateText(request: request)
            #expect(response.text == "pong")
        }
    }

    @Test
    func `generateText decodes OpenRouter reasoning details`() async throws {
        let response = try await withMockedSession { urlRequest in
            let reasoningDetails: [[String: String]] = [["type": "reasoning.encrypted", "data": "sealed"]]
            let toolCall: [String: Any] = [
                "id": "call-1",
                "type": "function",
                "function": ["name": "lookup", "arguments": "{}"],
            ]
            let toolCalls = [toolCall]
            let choice: [String: Any] = [
                "index": 0,
                "message": [
                    "role": "assistant",
                    "content": NSNull(),
                    "reasoning_details": reasoningDetails,
                    "tool_calls": toolCalls,
                ],
                "finish_reason": "tool_calls",
            ]
            let payload: [String: Any] = [
                "id": "chatcmpl-test",
                "object": "chat.completion",
                "created": 1_700_000_000,
                "model": "anthropic/claude-fable-5",
                "choices": [choice],
            ]
            return try self.jsonResponse(for: urlRequest, data: JSONSerialization.data(withJSONObject: payload))
        } operation: { session in
            try await OpenAICompatibleHelper.generateText(
                request: ProviderRequest(messages: [.user("hi")]),
                modelId: "anthropic/claude-fable-5",
                baseURL: "https://mock.compatible",
                apiKey: "sk-test",
                providerName: "OpenRouter",
                session: session,
            )
        }

        let reasoning = try #require(response.reasoning.first)
        #expect(reasoning.type == "openrouter_reasoning_details")
        #expect(reasoning.rawJSON?.contains("reasoning.encrypted") == true)
        #expect(response.toolCalls?.first?.id == "call-1")
    }

    @Test
    func `generateText decodes Kimi reasoning content`() async throws {
        let response = try await self.withMockedSession { urlRequest in
            let payload: [String: Any] = [
                "id": "chatcmpl-kimi",
                "choices": [
                    [
                        "index": 0,
                        "message": [
                            "role": "assistant",
                            "content": NSNull(),
                            "reasoning_content": "native Kimi thought",
                            "tool_calls": [
                                [
                                    "id": "call-1",
                                    "type": "function",
                                    "function": ["name": "lookup", "arguments": "{}"],
                                ],
                            ],
                        ],
                        "finish_reason": "tool_calls",
                    ],
                ],
            ]
            return try self.jsonResponse(for: urlRequest, data: JSONSerialization.data(withJSONObject: payload))
        } operation: { session in
            try await OpenAICompatibleHelper.generateText(
                request: ProviderRequest(messages: [.user("hi")]),
                modelId: "kimi-k2.7-code",
                baseURL: "https://api.moonshot.cn/v1",
                apiKey: "sk-test",
                providerName: "Kimi",
                session: session,
            )
        }

        let reasoning = try #require(response.reasoning.first)
        #expect(reasoning.type == "kimi_reasoning_content")
        #expect(reasoning.text == "native Kimi thought")
        #expect(response.toolCalls?.first?.id == "call-1")
    }

    @Test
    func `generateText replays Kimi reasoning only for matching model and endpoint`() async throws {
        let capture = CapturedRequest()
        let call = AgentToolCall(id: "call-1", name: "lookup", arguments: [:])
        let endpoint = "https://api.moonshot.cn/v1"
        let request = try ProviderRequest(messages: [
            .user("hi"),
            ModelMessage(
                role: .assistant,
                content: [.text("native Kimi thought")],
                channel: .thinking,
                metadata: .init(customData: [
                    "kimi.reasoning_content": "native Kimi thought",
                    "tachikoma.reasoning.provider": "kimi",
                    "tachikoma.reasoning.model": "kimi-k2.7-code",
                    "tachikoma.reasoning.base_url": #require(ReasoningEndpointIdentity.canonical(endpoint)),
                ]),
            ),
            ModelMessage(role: .assistant, content: [.toolCall(call)]),
            ModelMessage(
                role: .tool,
                content: [.toolResult(.success(toolCallId: "call-1", result: AnyAgentToolValue(string: "ok")))],
            ),
        ])

        _ = try await self.withMockedSession { urlRequest in
            capture.body = self.bodyData(from: urlRequest)
            return self.jsonResponse(for: urlRequest, data: Self.chatCompletionPayload(text: "done"))
        } operation: { session in
            try await OpenAICompatibleHelper.generateText(
                request: request,
                modelId: "kimi-k2.7-code",
                baseURL: endpoint,
                apiKey: "sk-test",
                providerName: "Kimi",
                session: session,
            )
        }

        let bodyJSON = try #require(capture.body).jsonObject()
        let messages = try #require(bodyJSON["messages"] as? [[String: Any]])
        let assistant = try #require(messages.first { $0["role"] as? String == "assistant" })
        #expect(assistant["reasoning_content"] as? String == "native Kimi thought")
        #expect(assistant["tool_calls"] != nil)
        #expect(bodyJSON["thinking"] == nil)
    }

    @Test
    func `generateText enables preserved thinking when replaying Kimi K2_6 reasoning`() async throws {
        let capture = CapturedRequest()
        let endpoint = "https://api.moonshot.cn/v1"
        let request = try ProviderRequest(messages: [
            .user("first"),
            ModelMessage(
                role: .assistant,
                content: [.text("native Kimi thought")],
                channel: .thinking,
                metadata: .init(customData: [
                    "kimi.reasoning_content": "native Kimi thought",
                    "tachikoma.reasoning.provider": "kimi",
                    "tachikoma.reasoning.model": "kimi-k2.6",
                    "tachikoma.reasoning.base_url": #require(ReasoningEndpointIdentity.canonical(endpoint)),
                ]),
            ),
            .assistant("answer"),
            .user("continue"),
        ])

        _ = try await self.withMockedSession { urlRequest in
            capture.body = self.bodyData(from: urlRequest)
            return self.jsonResponse(for: urlRequest, data: Self.chatCompletionPayload(text: "done"))
        } operation: { session in
            try await OpenAICompatibleHelper.generateText(
                request: request,
                modelId: "kimi-k2.6",
                baseURL: endpoint,
                apiKey: "sk-test",
                providerName: "Kimi",
                session: session,
            )
        }

        let bodyJSON = try #require(capture.body).jsonObject()
        let thinking = try #require(bodyJSON["thinking"] as? [String: String])
        #expect(thinking["type"] == "enabled")
        #expect(thinking["keep"] == "all")
        let messages = try #require(bodyJSON["messages"] as? [[String: Any]])
        let assistant = try #require(messages.first { $0["role"] as? String == "assistant" })
        #expect(assistant["reasoning_content"] as? String == "native Kimi thought")
    }

    @Test
    func `generateText strips unsupported Fable sampling for OpenRouter route`() async throws {
        let capture = CapturedRequest()
        let request = ProviderRequest(
            messages: [ModelMessage(role: .user, content: [.text("ping")])],
            settings: GenerationSettings(maxTokens: 128, temperature: 0.7),
        )

        _ = try await self.withMockedSession { urlRequest in
            capture.body = self.bodyData(from: urlRequest)
            return self.jsonResponse(for: urlRequest, data: Self.chatCompletionPayload(text: "pong"))
        } operation: { session in
            try await OpenAICompatibleHelper.generateText(
                request: request,
                modelId: "anthropic/claude-fable-5",
                baseURL: "https://mock.compatible",
                apiKey: "sk-test",
                providerName: "OpenRouter",
                session: session,
            )
        }

        let bodyJSON = try #require(capture.body).jsonObject()
        #expect(bodyJSON["temperature"] == nil)
        #expect(bodyJSON["max_tokens"] as? Int == 128)
    }

    @Test
    func `generateText replays OpenRouter reasoning details on assistant tool messages`() async throws {
        let capture = CapturedRequest()
        let rawReasoning = #"[{"type":"reasoning.encrypted","data":"sealed"}]"#
        let call = AgentToolCall(id: "call-1", name: "lookup", arguments: [:])
        let request = try ProviderRequest(messages: [
            .user("hi"),
            ModelMessage(
                role: .assistant,
                content: [.text("")],
                channel: .thinking,
                metadata: .init(customData: [
                    "openrouter.reasoning_details": rawReasoning,
                    "tachikoma.reasoning.provider": "openrouter",
                    "tachikoma.reasoning.model": "anthropic/claude-fable-5",
                    "tachikoma.reasoning.base_url": #require(ReasoningEndpointIdentity
                        .canonical("https://mock.compatible")),
                ]),
            ),
            ModelMessage(role: .assistant, content: [.toolCall(call)]),
            ModelMessage(
                role: .tool,
                content: [.toolResult(.success(toolCallId: "call-1", result: AnyAgentToolValue(string: "ok")))],
            ),
        ])

        _ = try await self.withMockedSession { urlRequest in
            capture.body = self.bodyData(from: urlRequest)
            return self.jsonResponse(for: urlRequest, data: Self.chatCompletionPayload(text: "done"))
        } operation: { session in
            try await OpenAICompatibleHelper.generateText(
                request: request,
                modelId: "anthropic/claude-fable-5",
                baseURL: "https://mock.compatible",
                apiKey: "sk-test",
                providerName: "OpenRouter",
                session: session,
            )
        }

        let bodyJSON = try #require(capture.body).jsonObject()
        let messages = try #require(bodyJSON["messages"] as? [[String: Any]])
        let assistant = try #require(messages.first { $0["role"] as? String == "assistant" })
        let details = try #require(assistant["reasoning_details"] as? [[String: Any]])
        #expect(details.first?["type"] as? String == "reasoning.encrypted")
        #expect(details.first?["data"] as? String == "sealed")
        #expect(assistant["tool_calls"] != nil)
    }

    @Test
    func `generateText replays OpenRouter reasoning details on reasoning-only assistant boundary`() async throws {
        let capture = CapturedRequest()
        let rawReasoning = #"[{"type":"reasoning.encrypted","data":"sealed"}]"#
        let request = try ProviderRequest(messages: [
            .user("first"),
            ModelMessage(
                role: .assistant,
                content: [.text("")],
                channel: .thinking,
                metadata: .init(customData: [
                    "openrouter.reasoning_details": rawReasoning,
                    "tachikoma.reasoning.provider": "openrouter",
                    "tachikoma.reasoning.model": "anthropic/claude-fable-5",
                    "tachikoma.reasoning.base_url": #require(ReasoningEndpointIdentity
                        .canonical("https://mock.compatible")),
                ]),
            ),
            ModelMessage(
                role: .assistant,
                content: [.text("")],
                metadata: .init(customData: ["tachikoma.internal.boundary": "reasoning_only"]),
            ),
            .user("next"),
        ])

        _ = try await self.withMockedSession { urlRequest in
            capture.body = self.bodyData(from: urlRequest)
            return self.jsonResponse(for: urlRequest, data: Self.chatCompletionPayload(text: "done"))
        } operation: { session in
            try await OpenAICompatibleHelper.generateText(
                request: request,
                modelId: "anthropic/claude-fable-5",
                baseURL: "https://mock.compatible",
                apiKey: "sk-test",
                providerName: "OpenRouter",
                session: session,
            )
        }

        let bodyJSON = try #require(capture.body).jsonObject()
        let messages = try #require(bodyJSON["messages"] as? [[String: Any]])
        let assistantIndex = try #require(messages.firstIndex { $0["role"] as? String == "assistant" })
        let assistant = messages[assistantIndex]
        let details = try #require(assistant["reasoning_details"] as? [[String: Any]])
        #expect(details.first?["data"] as? String == "sealed")
        let nextMessage = try #require(messages.indices
            .contains(assistantIndex + 1) ? messages[assistantIndex + 1] : nil)
        #expect(nextMessage["role"] as? String == "user")
    }

    @Test
    func `generateText does not replay OpenRouter reasoning from another endpoint`() async throws {
        let capture = CapturedRequest()
        let rawReasoning = #"[{"type":"reasoning.encrypted","data":"sealed"}]"#
        let call = AgentToolCall(id: "call-1", name: "lookup", arguments: [:])
        let request = try ProviderRequest(messages: [
            .user("hi"),
            ModelMessage(
                role: .assistant,
                content: [.text("")],
                channel: .thinking,
                metadata: .init(customData: [
                    "openrouter.reasoning_details": rawReasoning,
                    "tachikoma.reasoning.provider": "openrouter",
                    "tachikoma.reasoning.model": "anthropic/claude-fable-5",
                    "tachikoma.reasoning.base_url": #require(ReasoningEndpointIdentity
                        .canonical("https://other.example.test")),
                ]),
            ),
            ModelMessage(role: .assistant, content: [.toolCall(call)]),
            ModelMessage(
                role: .tool,
                content: [.toolResult(.success(toolCallId: "call-1", result: AnyAgentToolValue(string: "ok")))],
            ),
        ])

        _ = try await self.withMockedSession { urlRequest in
            capture.body = self.bodyData(from: urlRequest)
            return self.jsonResponse(for: urlRequest, data: Self.chatCompletionPayload(text: "done"))
        } operation: { session in
            try await OpenAICompatibleHelper.generateText(
                request: request,
                modelId: "anthropic/claude-fable-5",
                baseURL: "https://mock.compatible",
                apiKey: "sk-test",
                providerName: "OpenRouter",
                session: session,
            )
        }

        let bodyJSON = try #require(capture.body).jsonObject()
        let messages = try #require(bodyJSON["messages"] as? [[String: Any]])
        let assistantMessages = messages.filter { $0["role"] as? String == "assistant" }
        #expect(assistantMessages.allSatisfy { $0["reasoning_details"] == nil })
    }

    @Test
    func `generateText drops unmatched OpenRouter reasoning instead of serializing it as text`() async throws {
        let capture = CapturedRequest()
        let request = try ProviderRequest(messages: [
            .user("hi"),
            ModelMessage(
                role: .assistant,
                content: [.text("private reasoning")],
                channel: .thinking,
                metadata: .init(customData: [
                    "openrouter.reasoning": "private reasoning",
                    "tachikoma.reasoning.provider": "openrouter",
                    "tachikoma.reasoning.model": "other-model",
                    "tachikoma.reasoning.base_url": #require(ReasoningEndpointIdentity
                        .canonical("https://mock.compatible")),
                ]),
            ),
            .assistant("visible"),
        ])

        _ = try await self.withMockedSession { urlRequest in
            capture.body = self.bodyData(from: urlRequest)
            return self.jsonResponse(for: urlRequest, data: Self.chatCompletionPayload(text: "done"))
        } operation: { session in
            try await OpenAICompatibleHelper.generateText(
                request: request,
                modelId: "anthropic/claude-fable-5",
                baseURL: "https://mock.compatible",
                apiKey: "sk-test",
                providerName: "OpenRouter",
                session: session,
            )
        }

        let bodyJSON = try #require(capture.body).jsonObject()
        let messages = try #require(bodyJSON["messages"] as? [[String: Any]])
        let assistantMessages = messages.filter { $0["role"] as? String == "assistant" }
        #expect(assistantMessages.count == 1)
        #expect(assistantMessages.first?["content"] as? String == "visible")
        #expect(try String(data: #require(capture.body), encoding: .utf8)?.contains("private reasoning") == false)
    }

    @Test
    func `non-200 responses surface TachikomaError.apiError`() async {
        await self.withMockedSession { urlRequest in
            let errorJSON = """
            {"error":{"message":"bad request","type":"invalid_request_error"}}
            """.utf8Data()
            let response = HTTPURLResponse(
                url: urlRequest.url!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"],
            )!
            return (response, errorJSON)
        } operation: { session in
            do {
                _ = try await OpenAICompatibleHelper.generateText(
                    request: ProviderRequest(messages: [ModelMessage(role: .user, content: [.text("fail")])]),
                    modelId: "compatible-model",
                    baseURL: "https://mock.compatible",
                    apiKey: "sk-test",
                    providerName: "TestProvider",
                    session: session,
                )
                Issue.record("Expected error to be thrown")
            } catch let error as TachikomaError {
                switch error {
                case let .apiError(message):
                    #expect(message.contains("bad request"))
                default:
                    Issue.record("Unexpected TachikomaError: \(error)")
                }
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func withMockedSession<T>(
        handler: @Sendable @escaping (URLRequest) throws -> (HTTPURLResponse, Data),
        operation: (URLSession) async throws -> T,
    ) async rethrows
        -> T
    {
        let previousHandler = OpenAIHelperURLProtocol.handler
        OpenAIHelperURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        var classes = configuration.protocolClasses ?? []
        classes.insert(OpenAIHelperURLProtocol.self, at: 0)
        configuration.protocolClasses = classes
        let session = URLSession(configuration: configuration)

        defer {
            session.invalidateAndCancel()
            OpenAIHelperURLProtocol.handler = previousHandler
        }

        return try await operation(session)
    }

    private func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read > 0 {
                data.append(buffer, count: read)
            } else {
                break
            }
        }
        return data
    }

    private func jsonResponse(for request: URLRequest, data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://mock.compatible/chat/completions")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"],
        )!
        return (response, data)
    }

    private static func chatCompletionPayload(text: String) -> Data {
        let dict: [String: Any] = [
            "id": "chatcmpl-test",
            "object": "chat.completion",
            "created": 1_700_000_000,
            "model": "compatible-model",
            "choices": [
                [
                    "index": 0,
                    "message": ["role": "assistant", "content": text],
                    "finish_reason": "stop",
                ],
            ],
            "usage": [
                "prompt_tokens": 12,
                "completion_tokens": 3,
                "total_tokens": 15,
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: dict)
    }
}

extension Data {
    fileprivate func jsonObject() throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: self) as? [String: Any] ?? [:]
    }
}

private final class CapturedRequest: @unchecked Sendable {
    var body: Data?
}

private final class OpenAIHelperURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let handlerLock = NSLock()
    private nonisolated(unsafe) static var _handler: Handler?

    static var handler: Handler? {
        get { handlerLock.withLock { _handler } }
        set { handlerLock.withLock { _handler = newValue } }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
#endif
