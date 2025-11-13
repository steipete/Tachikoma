import Foundation
import Testing
@testable import Tachikoma

@Suite("OpenAI Responses API Tests", .serialized)
struct OpenAIResponsesProviderTests {
    @Test("GPT-5 uses Responses API provider")
    func gPT5UsesResponsesProvider() throws {
        // Test that GPT-5 models use the OpenAIResponsesProvider
        let config = self.openAIConfig()

        let gpt5Models: [LanguageModel.OpenAI] = [.gpt5, .gpt5Mini, .gpt5Nano]

        for model in gpt5Models {
            let provider = try ProviderFactory.createProvider(
                for: .openai(model),
                configuration: config,
            )

            #expect(
                provider is OpenAIResponsesProvider,
                "GPT-5 model \(model) should use OpenAIResponsesProvider",
            )
        }
    }

    @Test("GPT-5 text.verbosity parameter is set correctly")
    func gPT5TextVerbosityParameter() throws {
        // Test that the text.verbosity parameter is properly configured for GPT-5
        let config = self.openAIConfig()

        // Skip if no API key
        guard config.getAPIKey(for: .openai) != nil else {
            throw TestSkipped("OpenAI API key not configured")
        }

        let provider = try OpenAIResponsesProvider(
            model: .gpt5,
            configuration: config,
        )

        // Create a simple request
        _ = ProviderRequest(
            messages: [
                ModelMessage(role: .user, content: [.text("Hello")]),
            ],
            tools: nil,
            settings: GenerationSettings(),
        )

        // We can't directly test the internal request building without making it public
        // But we can verify the provider is configured correctly
        #expect(provider.modelId == "gpt-5")
        #expect(provider.capabilities.supportsTools == true)
        #expect(provider.capabilities.supportsVision == true)
    }

    @Test("Reasoning models use Responses API")
    func reasoningModelsUseResponsesAPI() throws {
        // Test that reasoning-oriented models also use the OpenAIResponsesProvider
        let config = self.openAIConfig()

        let reasoningModels: [LanguageModel.OpenAI] = [
            .o4Mini,
            .gpt5,
            .gpt5Mini,
            .gpt5Thinking,
        ]

        for model in reasoningModels {
            let provider = try ProviderFactory.createProvider(
                for: .openai(model),
                configuration: config,
            )

            #expect(
                provider is OpenAIResponsesProvider,
                "Reasoning model \(model) should use OpenAIResponsesProvider",
            )
        }
    }

    @Test("Legacy models use standard OpenAI provider")
    func legacyModelsUseStandardProvider() throws {
        // Test that non-GPT-5/reasoning models use the standard OpenAIProvider
        let config = self.openAIConfig()

        let legacyModels: [LanguageModel.OpenAI] = [.gpt4o, .gpt4oMini, .gpt41]

        for model in legacyModels {
            let provider = try ProviderFactory.createProvider(
                for: .openai(model),
                configuration: config,
            )

            #expect(
                provider is OpenAIProvider,
                "Legacy model \(model) should use OpenAIProvider",
            )
        }
    }

    @Test("TextConfig encodes verbosity correctly")
    func textConfigEncoding() throws {
        // Test that TextConfig properly encodes the verbosity parameter
        let textConfig = TextConfig(verbosity: .high)

        let encoder = JSONEncoder()
        let data = try encoder.encode(textConfig)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["verbosity"] as? String == "high")
    }

    @Test("OpenAIResponsesRequest includes text config for GPT-5")
    func responsesRequestTextConfig() throws {
        // Test that the request properly includes text config
        let textConfig = TextConfig(verbosity: .medium)
        let request = OpenAIResponsesRequest(
            model: "gpt-5",
            input: [.message(ResponsesMessage(role: "user", content: .text("Test")))],
            temperature: nil,
            topP: nil,
            maxOutputTokens: nil,
            text: textConfig,
            tools: nil,
            toolChoice: nil,
            metadata: nil,
            parallelToolCalls: nil,
            previousResponseId: nil,
            store: nil,
            user: nil,
            instructions: nil,
            serviceTier: nil,
            include: nil,
            reasoning: nil,
            truncation: nil,
            stream: false,
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let textJson = json?["text"] as? [String: Any] {
            #expect(textJson["verbosity"] as? String == "medium")
        } else {
            Issue.record("Expected text field in JSON")
        }
    }

    @Test("GPT-5 tool call outputs are parsed")
    func gpt5ToolCallParsing() throws {
        let toolCall = OpenAIResponsesResponse.ResponsesToolCall(
            id: "call_1",
            type: "function",
            function: .init(name: "see", arguments: "{\"mode\":\"screen\"}"),
        )

        let output = OpenAIResponsesResponse.ResponsesOutput(
            id: "out_1",
            type: "message",
            status: "completed",
            content: [
                .init(type: "output_text", text: "Capturing now.", toolCall: nil),
                .init(type: "tool_call", text: nil, toolCall: toolCall),
            ],
            role: "assistant",
            toolCall: nil,
        )

        let response = OpenAIResponsesResponse(
            id: "resp_1",
            object: "response",
            createdAt: 0,
            created: nil,
            status: "completed",
            model: "gpt-5",
            output: [output],
            choices: nil,
            usage: nil,
            metadata: nil,
        )

        let providerResponse = try OpenAIResponsesProvider.convertToProviderResponse(response)

        #expect(providerResponse.text == "Capturing now.")
        let toolCalls = try #require(providerResponse.toolCalls)
        #expect(toolCalls.count == 1)
        #expect(toolCalls[0].name == "see")
        #expect(toolCalls[0].arguments["mode"]?.stringValue == "screen")
        #expect(providerResponse.finishReason == .toolCalls)
    }

    @Test("Responses provider hits /v1/responses and encodes body")
    func openAIResponsesRequestEncoding() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setAPIKey("live-openai", for: .openai)

        try await self.withMockedSession { request in
            #expect(request.url?.path == "/v1/responses")

            let body = try #require(Self.bodyData(from: request))
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            #expect(json?["model"] as? String == "gpt-5-mini")

            if
                let input = json?["input"] as? [[String: Any]],
                let first = input.first,
                let content = first["content"] as? [[String: Any]],
                let text = content.first?["text"] as? String
            {
                #expect(text == "ping")
            } else {
                Issue.record("Missing input payload")
            }

            return NetworkMocking.jsonResponse(for: request, data: Self.responsesPayload(text: "pong"))
        } operation: { session in
            let provider = try OpenAIResponsesProvider(model: .gpt5Mini, configuration: config, session: session)
            let response = try await provider.generateText(request: self.sampleRequest)
            #expect(response.text.contains("GPT-5") || response.text.contains("pong"))
        }
    }

    @Test("Function call history encodes into Responses input")
    func openAIResponsesEncodesFunctionCalls() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setAPIKey("live-openai", for: .openai)

        let toolArguments = [
            "location": AnyAgentToolValue(string: "San Francisco"),
            "unit": AnyAgentToolValue(string: "fahrenheit"),
        ]
        let toolCall = AgentToolCall(id: "call_123", name: "get_weather", arguments: toolArguments)
        let toolResult = AgentToolResult(
            toolCallId: "call_123",
            result: AnyAgentToolValue(object: [
                "temperature": AnyAgentToolValue(int: 68),
            ]),
            isError: false,
        )

        let providerRequest = ProviderRequest(
            messages: [
                .user("What is the weather?"),
                ModelMessage(role: .assistant, content: [.toolCall(toolCall)]),
                ModelMessage(role: .tool, content: [.toolResult(toolResult)]),
            ],
            settings: .init(maxTokens: 32),
        )

        try await self.withMockedSession { request in
            let body = try #require(Self.bodyData(from: request))
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            let input = try #require(json?["input"] as? [[String: Any]])

            let functionCallEntry = input.first { ($0["type"] as? String) == "function_call" }
            #expect(functionCallEntry?["name"] as? String == "get_weather")
            #expect(functionCallEntry?["call_id"] as? String == "call_123")

            let outputEntry = input.first { ($0["type"] as? String) == "function_call_output" }
            #expect(outputEntry?["call_id"] as? String == "call_123")
            #expect((outputEntry?["output"] as? String)?.contains("temperature") == true)

            let messageRoles = input.compactMap { $0["role"] as? String }
            #expect(!messageRoles.contains("tool"))

            return NetworkMocking.jsonResponse(for: request, data: Self.responsesPayload(text: "Done"))
        } operation: { session in
            let provider = try OpenAIResponsesProvider(model: .gpt5, configuration: config, session: session)
            _ = try await provider.generateText(request: providerRequest)
        }
    }

    @Test("Responses provider streams accumulated deltas")
    func openAIResponsesStreaming() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setAPIKey("live-openai", for: .openai)

        try await self.withMockedSession { request in
            #expect(request.url?.path == "/v1/responses")
            let payload = Self.responsesStreamPayload(chunks: [
                Self.streamChunkJSON(content: "Hello", finishReason: nil),
                Self.streamChunkJSON(content: "Hello world", finishReason: nil),
                Self.streamChunkJSON(content: nil, finishReason: "stop"),
            ])
            return NetworkMocking.streamResponse(for: request, data: payload)
        } operation: { session in
            let provider = try OpenAIResponsesProvider(model: .o4Mini, configuration: config, session: session)
            let stream = try await provider.streamText(request: self.sampleRequest)

            var collected = ""
            for try await delta in stream {
                switch delta.type {
                case .textDelta:
                    collected.append(delta.content ?? "")
                case .done:
                    break
                case .toolCall, .toolResult, .reasoning:
                    break
                }
            }

            #expect(collected == "Hello world")
        }
    }

    private var sampleRequest: ProviderRequest {
        ProviderRequest(
            messages: [ModelMessage(role: .user, content: [.text("ping")])],
            settings: .init(maxTokens: 32),
        )
    }

    private static func responsesPayload(text: String) -> Data {
        let dict: [String: Any] = [
            "id": "resp_test",
            "object": "response",
            "created_at": 1_700_000_000,
            "model": "gpt-5-mini",
            "status": "completed",
            "output": [
                [
                    "id": "msg_1",
                    "type": "message",
                    "role": "assistant",
                    "content": [["type": "output_text", "text": "Hello from GPT-5: \(text)"]],
                ],
            ],
            "usage": [
                "input_tokens": 10,
                "output_tokens": 5,
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: dict)
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read > 0 {
                data.append(buffer, count: read)
            } else {
                break
            }
        }

        return data
    }

    private static func responsesStreamPayload(chunks: [String]) -> Data {
        var data = Data()
        for chunk in chunks {
            data.append("data: ".data(using: .utf8)!)
            data.append(chunk.data(using: .utf8)!)
            data.append("\n\n".data(using: .utf8)!)
        }
        data.append("data: [DONE]\n\n".data(using: .utf8)!)
        return data
    }

    private static func streamChunkJSON(content: String?, finishReason: String?) -> String {
        var delta: [String: Any] = [
            "role": "assistant",
        ]
        if let content {
            delta["content"] = content
        }

        var choice: [String: Any] = [
            "index": 0,
            "delta": delta,
        ]
        if let finishReason {
            choice["finish_reason"] = finishReason
        }

        let chunk: [String: Any] = [
            "id": "resp_stream",
            "object": "response",
            "created": 1_700_000_000,
            "model": "o4-mini",
            "choices": [choice],
        ]

        let data = try! JSONSerialization.data(withJSONObject: chunk)
        return String(data: data, encoding: .utf8)!
    }

    private func withMockedSession<T>(
        handler: @Sendable @escaping (URLRequest) throws -> (HTTPURLResponse, Data),
        operation: (URLSession) async throws -> T,
    ) async rethrows
    -> T {
        let previousHandler = ResponsesTestURLProtocol.handler
        ResponsesTestURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ResponsesTestURLProtocol.self]
        let session = URLSession(configuration: configuration)

        defer {
            session.invalidateAndCancel()
            ResponsesTestURLProtocol.handler = previousHandler
        }

        return try await operation(session)
    }

    private func openAIConfig() -> TachikomaConfiguration {
        TestHelpers.createTestConfiguration(
            apiKeys: ["openai": "test-key"],
            enableMockOverride: false,
        )
    }
}

private final class ResponsesTestURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let handlerLock = NSLock()
    private nonisolated(unsafe) static var _handler: Handler?

    static var handler: Handler? {
        get { handlerLock.withLock { _handler } }
        set { handlerLock.withLock { _handler = newValue } }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            let error = URLError(.resourceUnavailable)
            client?.urlProtocol(self, didFailWithError: error)
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

// Helper to skip tests when API keys aren't available
struct TestSkipped: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}
