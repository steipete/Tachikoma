import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import Tachikoma

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

#if os(Linux)
@Suite("Provider Network E2E Tests", .disabled("URLProtocol mocking unavailable on Linux"))
struct ProviderEndToEndTests {}
#else

@Suite("Provider Network E2E Tests", .serialized, .enabled(if: !_isLiveSuite))
struct ProviderEndToEndTests {
    // MARK: - OpenAI Responses (GPT-5)

    @Test("OpenAI Responses provider returns text")
    func openAIResponsesProvider() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            self.expectPath(
                request,
                endsWithAny: ["/responses", "/chat/completions"],
                allowAudioTranscriptions: true,
            )
            return NetworkMocking.jsonResponse(
                for: request,
                data: Self.openAIResponsesPayload(text: "Hello from GPT-5"),
            )
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("sk-live-openai", for: .openai)
            }
            let provider = try OpenAIResponsesProvider(model: .gpt5Mini, configuration: config)
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text.contains("GPT-5"))
            #expect(response.usage?.outputTokens == 5)
        }
    }

    // MARK: - OpenAI Chat Provider

    @Test("OpenAI chat provider hits /chat/completions")
    func openAIChatProvider() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            self.expectPath(request, endsWith: "/chat/completions")
            return NetworkMocking.jsonResponse(
                for: request,
                data: Self.chatCompletionPayload(text: "OpenAI chat success"),
            )
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("sk-live-openai", for: .openai)
            }
            let provider = try OpenAIProvider(model: .gpt4o, configuration: config)
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "OpenAI chat success")
        }
    }

    // MARK: - Anthropic

    @Test("Anthropic provider decodes Claude responses")
    func anthropicProvider() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            self.expectPath(request, endsWith: "/messages")
            return NetworkMocking.jsonResponse(for: request, data: Self.anthropicPayload(text: "Claude says hello"))
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("live-anthropic", for: .anthropic)
            }
            let provider = try AnthropicProvider(model: .sonnet4, configuration: config)
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "Claude says hello")
        }
    }

    // MARK: - Google Gemini

    @Test("Google provider processes streamed SSE content")
    func googleProvider() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            #expect(request.url?.path.contains(":streamGenerateContent") == true)
            return NetworkMocking.streamResponse(for: request, data: Self.googleStreamPayload(text: "Gemini streaming"))
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("google-live", for: .google)
            }
            let provider = try GoogleProvider(model: .gemini25Flash, configuration: config)
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text.contains("Gemini streaming"))
        }
    }

    // MARK: - OpenAI-compatible providers

    @Test("Mistral provider uses OpenAI-compatible flow")
    func mistralProvider() async throws {
        try await self.assertOpenAICompatibleProvider(.mistral(.small), provider: .mistral)
    }

    @Test("Groq provider uses OpenAI-compatible flow")
    func groqProvider() async throws {
        try await self.assertOpenAICompatibleProvider(.groq(.llama38b), provider: .groq)
    }

    @Test("Grok provider uses OpenAI-compatible flow")
    func grokProvider() async throws {
        try await self.assertOpenAICompatibleProvider(.grok(.grok4FastReasoning), provider: .grok)
    }

    @Test("All Grok catalog models share the same OpenAI-compatible flow")
    func grokCatalogUsesSameFlow() async throws {
        for grokModel in Model.Grok.allCases {
            try await self.assertOpenAICompatibleProvider(.grok(grokModel), provider: .grok)
        }
    }

    // MARK: - Ollama

    @Test("Ollama provider handles local responses")
    func ollamaProvider() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            self.expectPath(request, endsWith: "/api/chat")
            return NetworkMocking.jsonResponse(for: request, data: Self.ollamaPayload(text: "Ollama local reply"))
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setBaseURL("http://localhost:11434", for: .ollama)
            }
            let provider = try OllamaProvider(model: .llama33, configuration: config)
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "Ollama local reply")
        }
    }

    @Test("Ollama provider encodes vision images as messages[].images")
    func ollamaProviderEncodesImages() async throws {
        let imageBase64 = Data("test-image".utf8).base64EncodedString()
        let image = ModelMessage.ContentPart.ImageContent(data: imageBase64, mimeType: "image/png")

        let request = ProviderRequest(
            messages: [
                ModelMessage.user(text: "What's in this image?", images: [image]),
            ],
            tools: nil,
            settings: GenerationSettings(maxTokens: 64, temperature: 0.0),
        )

        try await NetworkMocking.withMockedNetwork { urlRequest in
            self.expectPath(urlRequest, endsWith: "/api/chat")

            let body = self.bodyData(from: urlRequest)
            #expect(body != nil)
            if let body {
                let decoded = try JSONDecoder().decode(OllamaChatRequest.self, from: body)
                #expect(decoded.model == "qwen2.5vl:latest")
                #expect(decoded.stream == false)
                #expect(decoded.messages.count == 1)
                #expect(decoded.messages.first?.role == "user")
                #expect(decoded.messages.first?.content == "What's in this image?")
                #expect(decoded.messages.first?.images == [imageBase64])
            }

            return NetworkMocking.jsonResponse(for: urlRequest, data: Self.ollamaPayload(text: "Vision ok"))
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setBaseURL("http://localhost:11434", for: .ollama)
            }

            let provider = try OllamaProvider(model: .custom("qwen2.5vl:latest"), configuration: config)
            let response = try await provider.generateText(request: request)
            #expect(response.text == "Vision ok")
        }
    }

    // MARK: - LMStudio

    @Test("LMStudio provider maps OpenAI-style responses")
    func lmstudioProvider() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            let path = request.url?.path ?? ""
            #expect(path.contains("chat/completions"))
            return NetworkMocking.jsonResponse(for: request, data: Self.chatCompletionPayload(text: "LMStudio result"))
        } operation: {
            let provider = LMStudioProvider(
                baseURL: "http://localhost:1234/v1",
                modelId: "local",
                sessionConfiguration: Self.mockedSessionConfiguration(),
            )
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "LMStudio result")
        }
    }

    // MARK: - Aggregators & Compatible Providers

    @Test("OpenRouter provider uses OpenAI-compatible flow")
    func openRouterProvider() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            self.expectPath(request, endsWith: "/chat/completions")
            #expect(request.value(forHTTPHeaderField: "HTTP-Referer") == "https://peekaboo.app")
            return NetworkMocking.jsonResponse(for: request, data: Self.chatCompletionPayload(text: "OpenRouter reply"))
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("live-openrouter", for: "openrouter")
                config.setBaseURL("https://mock.openrouter.test/api/v1", for: "openrouter")
            }
            let provider = try OpenRouterProvider(modelId: "openrouter/google/gemma-2", configuration: config)
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "OpenRouter reply")
        }
    }

    @Test("Together provider uses OpenAI-compatible flow")
    func togetherProvider() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            let path = request.url?.path ?? ""
            #expect(path.hasSuffix("/chat/completions"))
            return NetworkMocking.jsonResponse(for: request, data: Self.chatCompletionPayload(text: "Together result"))
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("live-together", for: "together")
            }
            let provider = try TogetherProvider(modelId: "togethercomputer/llama-3.1", configuration: config)
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "Together result")
        }
    }

    @Test("Replicate provider uses OpenAI-compatible flow")
    func replicateProvider() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            let path = request.url?.path ?? ""
            #expect(path.hasSuffix("/chat/completions"))
            return NetworkMocking.jsonResponse(for: request, data: Self.chatCompletionPayload(text: "Replicate result"))
        } operation: {
            setenv("REPLICATE_PREFERRED_OUTPUT", "turbo", 1)
            defer { unsetenv("REPLICATE_PREFERRED_OUTPUT") }

            let config = Self.makeConfiguration { config in
                config.setAPIKey("live-replicate", for: "replicate")
            }
            let provider = try ReplicateProvider(modelId: "meta/llama-guard", configuration: config)
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "Replicate result")
        }
    }

    @Test("OpenAI-compatible provider hits custom base URL")
    func openAICompatibleProvider() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            #expect(request.url?.absoluteString == "https://compatible.test/chat/completions")
            return NetworkMocking.jsonResponse(
                for: request,
                data: Self.chatCompletionPayload(text: "Compatible success"),
            )
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("live-compatible", for: "openai_compatible")
            }
            let provider = try OpenAICompatibleProvider(
                modelId: "any-model",
                baseURL: "https://compatible.test",
                configuration: config,
            )
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "Compatible success")
        }
    }

    @Test("Anthropic-compatible provider decodes responses")
    func anthropicCompatibleProvider() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            self.expectPath(request, endsWith: "/messages")
            return NetworkMocking.jsonResponse(for: request, data: Self.anthropicPayload(text: "Compat Claude"))
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("live-anthropic-compat", for: "anthropic_compatible")
            }
            let provider = try AnthropicCompatibleProvider(
                modelId: "claude-compat-4",
                baseURL: "https://compat.anthropic.test",
                configuration: config,
            )
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "Compat Claude")
        }
    }

    // MARK: - Helpers

    private func assertOpenAICompatibleProvider(_ model: LanguageModel, provider: Provider) async throws {
        try await NetworkMocking.withMockedNetwork { request in
            let path = request.url?.path ?? ""
            #expect(path.contains("chat/completions"))
            return NetworkMocking.jsonResponse(
                for: request,
                data: Self.chatCompletionPayload(text: "Response for \(provider.identifier)"),
            )
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("live-\(provider.identifier)", for: provider)
            }

            let providerInstance: any ModelProvider = switch model {
            case let .mistral(sub): try MistralProvider(model: sub, configuration: config)
            case let .groq(sub): try GroqProvider(model: sub, configuration: config)
            case let .grok(sub): try GrokProvider(model: sub, configuration: config)
            default:
                fatalError("Unsupported model: \(model)")
            }

            let response = try await providerInstance.generateText(request: Self.basicRequest)
            #expect(response.text.contains(provider.identifier))
        }
    }

    private static var basicRequest: ProviderRequest {
        ProviderRequest(
            messages: [ModelMessage(role: .user, content: [.text("Hello there")])],
        )
    }

    private static func makeConfiguration(_ builder: (TachikomaConfiguration) -> Void) -> TachikomaConfiguration {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        builder(config)
        return config
    }

    private static func openAIResponsesPayload(text: String) -> Data {
        let dict: [String: Any] = [
            "id": "resp_123",
            "object": "response",
            "created_at": 1_723_000_000,
            "model": "gpt-5-mini",
            "status": "completed",
            "output": [
                [
                    "id": "msg_1",
                    "type": "message",
                    "role": "assistant",
                    "content": [
                        ["type": "output_text", "text": text],
                    ],
                ],
            ],
            "usage": [
                "input_tokens": 10,
                "output_tokens": 5,
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: dict)
    }

    private static func chatCompletionPayload(text: String) -> Data {
        let dict: [String: Any] = [
            "id": "chatcmpl-123",
            "object": "chat.completion",
            "created": 1_723_000_000,
            "model": "gpt-4o",
            "choices": [
                [
                    "index": 0,
                    "message": ["role": "assistant", "content": text],
                    "finish_reason": "stop",
                ],
            ],
            "usage": [
                "prompt_tokens": 10,
                "completion_tokens": 5,
                "total_tokens": 15,
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: dict)
    }

    private static func anthropicPayload(text: String) -> Data {
        let dict: [String: Any] = [
            "id": "msg_1",
            "type": "message",
            "role": "assistant",
            "content": [
                ["type": "text", "text": text],
            ],
            "model": "claude-sonnet-4-20250514",
            "stop_reason": "end_turn",
            "usage": [
                "input_tokens": 12,
                "output_tokens": 6,
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: dict)
    }

    private static func googleStreamPayload(text: String) -> Data {
        let json: [String: Any] = [
            "candidates": [
                [
                    "content": [
                        "parts": [["text": text]],
                    ],
                ],
            ],
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        var body = Data()
        body.append("data: ".utf8Data())
        body.append(data)
        body.append("\n\n".utf8Data())
        return body
    }

    private static func ollamaPayload(text: String) -> Data {
        let dict: [String: Any] = [
            "model": "llama3",
            "created_at": "2025-01-01T00:00:00Z",
            "message": ["role": "assistant", "content": text],
            "done": true,
        ]
        return try! JSONSerialization.data(withJSONObject: dict)
    }

    private static func mockedSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        var classes = config.protocolClasses ?? []
        classes.insert(MockURLProtocol.self, at: 0)
        config.protocolClasses = classes
        return config
    }

    private func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

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

    private func expectPath(
        _ request: URLRequest,
        endsWithAny suffixes: [String],
        allowAudioTranscriptions: Bool = false,
    ) {
        let path = request.url?.path ?? ""
        var allowed = suffixes
        if allowAudioTranscriptions {
            allowed.append(contentsOf: ["/audio/transcriptions", "/audio/speech"])
        }
        let matches = allowed.contains { path.hasSuffix($0) }
        #expect(matches, "Expected path to end with one of \(suffixes.joined(separator: ", ")) but found \(path)")
    }

    private func expectPath(
        _ request: URLRequest,
        endsWith suffix: String,
        allowAudioTranscriptions: Bool = false,
    ) {
        self.expectPath(request, endsWithAny: [suffix], allowAudioTranscriptions: allowAudioTranscriptions)
    }
}
#endif

private let _isLiveSuite: Bool = {
    #if LIVE_PROVIDER_TESTS
    true
    #else
    false
    #endif
}()

// MARK: - Network Mock Helper

enum NetworkMocking {
    static func withMockedNetwork<T>(
        handler: @Sendable @escaping (URLRequest) throws -> (HTTPURLResponse, Data),
        operation: () async throws -> T,
    ) async throws
        -> T
    {
        let previousHandler = MockURLProtocol.handler
        MockURLProtocol.handler = handler
        URLProtocol.registerClass(MockURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(MockURLProtocol.self)
            MockURLProtocol.handler = previousHandler
        }
        return try await operation()
    }

    static func jsonResponse(for request: URLRequest, data: Data, statusCode: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://mock.api.test")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"],
        )!
        return (response, data)
    }

    static func streamResponse(for request: URLRequest, data: Data, statusCode: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://mock.api.test/stream")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/event-stream"],
        )!
        return (response, data)
    }
}
