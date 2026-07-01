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
@Suite(.disabled("URLProtocol mocking unavailable on Linux"))
struct ProviderEndToEndTests {}
#else

@Suite(.serialized, .enabled(if: !_isLiveSuite))
struct ProviderEndToEndTests {
    // MARK: - OpenAI Responses (GPT-5)

    @Test
    func `OpenAI Responses provider returns text`() async throws {
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

    @Test
    func `OpenAI chat provider hits /chat/completions`() async throws {
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
            let provider = try OpenAIProvider(model: .gpt55, configuration: config)
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "OpenAI chat success")
        }
    }

    // MARK: - Anthropic

    @Test
    func `Anthropic provider decodes Claude responses`() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            self.expectPath(request, endsWith: "/messages")
            return NetworkMocking.jsonResponse(for: request, data: Self.anthropicPayload(text: "Claude says hello"))
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("live-anthropic", for: .anthropic)
            }
            let provider = try AnthropicProvider(model: .sonnet46, configuration: config)
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "Claude says hello")
        }
    }

    // MARK: - Google Gemini

    @Test
    func `Google provider processes streamed SSE content`() async throws {
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

    @Test
    func `Google provider encodes tool results as user function responses`() async throws {
        let toolCall = AgentToolCall(
            id: "call_weather",
            name: "get_weather",
            arguments: ["location": AnyAgentToolValue(string: "Vienna")],
        )
        let toolResult = AgentToolResult.success(
            toolCallId: "call_weather",
            result: AnyAgentToolValue(object: ["temperature": AnyAgentToolValue(int: 21)]),
        )
        let providerRequest = ProviderRequest(
            messages: [
                .user("Weather?"),
                ModelMessage(role: .assistant, content: [.text("Checking."), .toolCall(toolCall)]),
                ModelMessage(role: .tool, content: [.toolResult(toolResult)]),
            ],
            settings: .init(maxTokens: 32),
        )

        try await NetworkMocking.withMockedNetwork { request in
            let body = try #require(self.bodyData(from: request))
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let contents = try #require(json["contents"] as? [[String: Any]])

            #expect(contents.count == 3)
            #expect(contents.compactMap { $0["role"] as? String } == ["user", "model", "user"])

            let modelParts = try #require(contents[1]["parts"] as? [[String: Any]])
            #expect(modelParts.count == 2)
            #expect(modelParts[1]["functionCall"] != nil)

            let toolParts = try #require(contents[2]["parts"] as? [[String: Any]])
            let functionResponse = try #require(toolParts.first?["functionResponse"] as? [String: Any])
            #expect(functionResponse["id"] as? String == "call_weather")
            #expect(functionResponse["name"] as? String == "get_weather")

            return NetworkMocking.streamResponse(for: request, data: Self.googleStreamPayload(text: "Done"))
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("google-live", for: .google)
            }
            let provider = try GoogleProvider(model: .gemini25Flash, configuration: config)
            let response = try await provider.generateText(request: providerRequest)
            #expect(response.text.contains("Done"))
        }
    }

    @Test
    func `Google provider drops orphan required tool parameters`() async throws {
        let tool = AgentTool(
            name: "search",
            description: "Search files",
            parameters: AgentToolParameters(
                properties: [
                    "query": AgentToolParameterProperty(
                        name: "query",
                        type: .string,
                        description: "Search query",
                    ),
                ],
                required: ["query", "mode"],
            ),
        ) { _ in
            AnyAgentToolValue(string: "ok")
        }
        let orphanOnlyTool = AgentTool(
            name: "noop",
            description: "No-op",
            parameters: AgentToolParameters(
                properties: [
                    "reason": AgentToolParameterProperty(
                        name: "reason",
                        type: .string,
                        description: "Reason",
                    ),
                ],
                required: ["missing"],
            ),
        ) { _ in
            AnyAgentToolValue(string: "ok")
        }

        let providerRequest = ProviderRequest(
            messages: [ModelMessage(role: .user, content: [.text("Find it")])],
            tools: [tool, orphanOnlyTool],
            settings: .init(maxTokens: 32),
        )

        try await NetworkMocking.withMockedNetwork { request in
            let body = try #require(self.bodyData(from: request))
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let tools = try #require(json["tools"] as? [[String: Any]])
            let declarations = try #require(tools.first?["functionDeclarations"] as? [[String: Any]])
            var parametersByName: [String: [String: Any]] = [:]
            for declaration in declarations {
                let name = try #require(declaration["name"] as? String)
                let parameters = try #require(declaration["parameters"] as? [String: Any])
                #expect(!parametersByName.keys.contains(name))
                parametersByName[name] = parameters
            }
            let searchParameters = try #require(parametersByName["search"])
            let noopParameters = try #require(parametersByName["noop"])

            #expect(searchParameters["properties"] is [String: Any])
            #expect(searchParameters["required"] as? [String] == ["query"])
            #expect(noopParameters["properties"] is [String: Any])
            #expect(noopParameters["required"] == nil)

            return NetworkMocking.streamResponse(for: request, data: Self.googleStreamPayload(text: "Done"))
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("google-live", for: .google)
            }
            let provider = try GoogleProvider(model: .gemini25Flash, configuration: config)
            let response = try await provider.generateText(request: providerRequest)
            #expect(response.text.contains("Done"))
        }
    }

    // MARK: - OpenAI-compatible providers

    @Test
    func `Mistral provider uses OpenAI-compatible flow`() async throws {
        try await self.assertOpenAICompatibleProvider(.mistral(.smallLatest), provider: .mistral)
    }

    @Test
    func `Groq provider uses OpenAI-compatible flow`() async throws {
        try await self.assertOpenAICompatibleProvider(.groq(.llama318b), provider: .groq)
    }

    @Test
    func `Grok provider uses OpenAI-compatible flow`() async throws {
        try await self.assertOpenAICompatibleProvider(.grok(.grok43), provider: .grok)
    }

    @Test
    func `All Grok catalog models share the same OpenAI-compatible flow`() async throws {
        for grokModel in Model.Grok.allCases {
            try await self.assertOpenAICompatibleProvider(.grok(grokModel), provider: .grok)
        }
    }

    // MARK: - Ollama

    @Test
    func `Ollama provider handles local responses`() async throws {
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

    @Test
    func `Ollama provider encodes vision images as messages[].images`() async throws {
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

    @Test
    func `LMStudio provider maps OpenAI-style responses`() async throws {
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

    @Test
    func `OpenRouter provider uses OpenAI-compatible flow`() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            self.expectPath(request, endsWith: "/chat/completions")
            #expect(request.value(forHTTPHeaderField: "HTTP-Referer") == "https://peekaboo.app")
            #expect(request.value(forHTTPHeaderField: "X-OpenRouter-Title") == "Peekaboo")
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

    @Test
    func `Together provider uses OpenAI-compatible flow`() async throws {
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

    @Test
    func `Replicate provider uses OpenAI-compatible flow`() async throws {
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

    @Test
    func `OpenAI-compatible provider hits custom base URL`() async throws {
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

    @Test
    func `Anthropic-compatible provider decodes responses`() async throws {
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

    @Test
    func `Anthropic-compatible provider accepts auth override`() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            self.expectPath(request, endsWith: "/messages")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer compat-token")
            #expect(request.value(forHTTPHeaderField: "x-api-key") == nil)
            return NetworkMocking.jsonResponse(for: request, data: Self.anthropicPayload(text: "Compat bearer"))
        } operation: {
            let provider = try AnthropicCompatibleProvider(
                modelId: "claude-compat-4",
                baseURL: "https://compat.anthropic.test",
                configuration: Self.makeConfiguration { _ in },
                auth: .bearer("compat-token", betaHeader: nil),
            )
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "Compat bearer")
        }
    }

    @Test
    func `MiniMax provider uses bearer auth`() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            self.expectPath(request, endsWith: "/messages")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer live-minimax")
            #expect(request.value(forHTTPHeaderField: "x-api-key") == nil)
            return NetworkMocking.jsonResponse(for: request, data: Self.anthropicPayload(text: "MiniMax ok"))
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("live-minimax", for: .minimax)
            }
            let provider = try ProviderFactory.createProvider(for: .minimax(.m27), configuration: config)
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "MiniMax ok")
        }
    }

    @Test
    func `MiniMax M3 sends multimodal requests to the Anthropic endpoint`() async throws {
        let image = ModelMessage.ContentPart.ImageContent(
            data: Data("test-image".utf8).base64EncodedString(),
            mimeType: "image/png",
        )
        let request = ProviderRequest(messages: [ModelMessage.user(text: "Describe this", images: [image])])

        try await NetworkMocking.withMockedNetwork { request in
            #expect(request.url?.host == "api.minimax.io")
            self.expectPath(request, endsWith: "/anthropic/v1/messages")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer live-minimax")

            let body = try #require(self.bodyData(from: request))
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(json["model"] as? String == "MiniMax-M3")
            let messages = try #require(json["messages"] as? [[String: Any]])
            let content = try #require(messages.first?["content"] as? [[String: Any]])
            let source = try #require(content.first { $0["type"] as? String == "image" }?["source"] as? [String: Any])
            #expect(source["media_type"] as? String == "image/png")
            #expect(source["data"] as? String == image.data)

            return NetworkMocking.jsonResponse(for: request, data: Self.anthropicPayload(text: "MiniMax M3 ok"))
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("live-minimax", for: .minimax)
            }
            let provider = try ProviderFactory.createProvider(for: .minimax(.m3), configuration: config)
            #expect(provider.capabilities.supportsVision)
            #expect(provider.capabilities.contextLength == 1_000_000)

            let response = try await provider.generateText(request: request)
            #expect(response.text == "MiniMax M3 ok")
        }
    }

    @Test
    func `MiniMax reasoning metadata is bound to configured endpoint`() async throws {
        let baseURL = "https://minimax-proxy.test/anthropic?tenant=a"
        try await NetworkMocking.withMockedNetwork { request in
            #expect(request.url?.host == "minimax-proxy.test")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer live-minimax")
            return NetworkMocking.jsonResponse(
                for: request,
                data: Self.anthropicPayloadWithThinking(
                    text: "MiniMax ok",
                    thinking: "native-thought",
                    signature: "sig-mm",
                ),
            )
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("live-minimax", for: .minimax)
                config.setBaseURL(baseURL, for: .minimax)
            }
            let provider = try ProviderFactory.createProvider(for: .minimax(.m27), configuration: config)
            let response = try await provider.generateText(request: Self.basicRequest)
            let thinkingMessage = try #require(response.assistantMessages.first { $0.channel == .thinking })
            let metadata = try #require(thinkingMessage.metadata?.customData)

            #expect(metadata["tachikoma.reasoning.provider"] == "minimax")
            #expect(metadata["tachikoma.reasoning.model"] == "MiniMax-M2.7")
            #expect(metadata["anthropic.thinking.signature"] == "sig-mm")
            #expect(metadata["tachikoma.reasoning.base_url"] == ReasoningEndpointIdentity.canonical(baseURL))
        }
    }

    @Test
    func `MiniMax China provider uses China endpoint and bearer auth`() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            #expect(request.url?.host == "api.minimaxi.com")
            self.expectPath(request, endsWith: "/messages")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer live-minimax-cn")
            #expect(request.value(forHTTPHeaderField: "x-api-key") == nil)
            return NetworkMocking.jsonResponse(for: request, data: Self.anthropicPayload(text: "MiniMax China ok"))
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("live-minimax-cn", for: .minimaxCN)
            }
            let provider = try ProviderFactory.createProvider(for: .minimaxCN(.m27), configuration: config)
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "MiniMax China ok")
        }
    }

    @Test
    func `MiniMax China provider falls back to MiniMax API key`() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            #expect(request.url?.host == "api.minimaxi.com")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer shared-minimax")
            return NetworkMocking.jsonResponse(
                for: request,
                data: Self.anthropicPayload(text: "MiniMax China fallback ok"),
            )
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("shared-minimax", for: .minimax)
            }
            let provider = try ProviderFactory.createProvider(for: .minimaxCN(.m27), configuration: config)
            let response = try await provider.generateText(request: Self.basicRequest)
            #expect(response.text == "MiniMax China fallback ok")
        }
    }

    @Test
    func `Kimi provider uses official endpoint and preserves reasoning content`() async throws {
        let image = ModelMessage.ContentPart.ImageContent(data: "aW1hZ2U=", mimeType: "image/png")
        let request = ProviderRequest(messages: [ModelMessage.user(text: "Inspect", images: [image])])

        try await NetworkMocking.withMockedNetwork { request in
            #expect(request.url?.absoluteString == "https://api.moonshot.ai/v1/chat/completions")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer live-kimi")
            let body = try #require(self.bodyData(from: request))
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(json["model"] as? String == "kimi-k2.7-code")
            let messages = try #require(json["messages"] as? [[String: Any]])
            let content = try #require(messages.first?["content"] as? [[String: Any]])
            #expect(content.contains { $0["type"] as? String == "image_url" })
            return NetworkMocking.jsonResponse(
                for: request,
                data: Self.kimiPayload(text: "", reasoning: "native Kimi thought"),
            )
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("live-kimi", for: .kimi)
            }
            let provider = try KimiProvider(model: .k27Code, configuration: config)
            let response = try await provider.generateText(request: request)
            #expect(response.reasoning.first?.type == "kimi_reasoning_content")
            #expect(response.reasoning.first?.text == "native Kimi thought")
            #expect(response.toolCalls?.first?.name == "lookup")
            #expect(provider.capabilities.contextLength == 262_144)
            #expect(provider.capabilities.maxOutputTokens == 32768)
        }
    }

    @Test
    func `MiniMax rate limit does not contaminate Kimi routing`() async throws {
        try await NetworkMocking.withMockedNetwork { request in
            switch request.url?.host {
            case "api.minimax.io":
                return NetworkMocking.jsonResponse(
                    for: request,
                    data: #"{"error":{"message":"rate limited","type":"rate_limit_error"}}"#.utf8Data(),
                    statusCode: 429,
                )
            case "api.moonshot.ai":
                return NetworkMocking.jsonResponse(
                    for: request,
                    data: Self.chatCompletionPayload(text: "Kimi remained available"),
                )
            default:
                throw TachikomaError.invalidConfiguration("Unexpected host")
            }
        } operation: {
            let config = Self.makeConfiguration { config in
                config.setAPIKey("live-minimax", for: .minimax)
                config.setAPIKey("live-kimi", for: .kimi)
            }
            let miniMax = try ProviderFactory.createProvider(for: .minimax(.m27), configuration: config)
            let kimi = try ProviderFactory.createProvider(for: .kimi(.k26), configuration: config)

            await #expect(throws: TachikomaError.self) {
                _ = try await miniMax.generateText(request: Self.basicRequest)
            }
            let response = try await kimi.generateText(request: Self.basicRequest)
            #expect(response.text == "Kimi remained available")
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
            "model": "gpt-5.5",
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

    private static func kimiPayload(text: String, reasoning: String) -> Data {
        let dict: [String: Any] = [
            "id": "chatcmpl-kimi",
            "choices": [
                [
                    "index": 0,
                    "message": [
                        "role": "assistant",
                        "content": text,
                        "reasoning_content": reasoning,
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
            "usage": ["prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15],
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
            "model": "claude-sonnet-4-6",
            "stop_reason": "end_turn",
            "usage": [
                "input_tokens": 12,
                "output_tokens": 6,
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: dict)
    }

    private static func anthropicPayloadWithThinking(text: String, thinking: String, signature: String) -> Data {
        let dict: [String: Any] = [
            "id": "msg_1",
            "type": "message",
            "role": "assistant",
            "content": [
                ["type": "thinking", "thinking": thinking, "signature": signature],
                ["type": "text", "text": text],
            ],
            "model": "MiniMax-M2.7",
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
