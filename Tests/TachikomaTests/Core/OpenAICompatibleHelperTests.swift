import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import Tachikoma

#if os(Linux)
@Suite("OpenAICompatibleHelper Tests", .disabled("URLProtocol mocking unavailable on Linux"))
struct OpenAICompatibleHelperTests {}
#else

@Suite("OpenAICompatibleHelper Tests", .serialized)
struct OpenAICompatibleHelperTests {
    @Test("generateText encodes stop sequences, headers, and tool definitions")
    func generateTextEncodesPayload() async throws {
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

    @Test("streamText emits deltas as SSE chunks arrive")
    func streamTextEmitsDeltas() async throws {
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

    @Test("non-200 responses surface TachikomaError.apiError")
    func apiErrorsSurface() async throws {
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
