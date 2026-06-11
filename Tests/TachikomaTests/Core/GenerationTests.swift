import Foundation
import Testing
@testable import Tachikoma

struct GenerationTests {
    // MARK: - Basic Generation Tests (Placeholder Providers)

    @Test
    func `Generate Function - OpenAI Provider`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            let result = try await generate(
                "What is 2+2?",
                using: .openai(.gpt55),
                maxTokens: 100,
                configuration: config,
            )

            self.assertOpenAIResult(
                result,
                prompt: "What is 2+2?",
                modelId: "gpt-5.5",
                configuration: config,
            )
        }
    }

    @Test
    func `Generate Function - Anthropic Provider`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["anthropic": "test-key"]) { config in
            let result = try await generate(
                "Explain quantum physics",
                using: .anthropic(.sonnet46),
                system: "You are a physics teacher",
                maxTokens: 200,
                configuration: config,
            )

            // Anthropic provider uses real implementation, so we expect actual response structure
            // For now, with our placeholder, verify basic functionality
            #expect(!result.isEmpty)
        }
    }

    @Test
    func `Generate Function - Default Model`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["anthropic": "test-key"]) { config in
            let result = try await generate("Hello world", configuration: config)

            // Should use default model (Anthropic Opus 4)
            #expect(!result.isEmpty)
        }
    }

    @Test
    func `Generate Function - With System Prompt`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            let result = try await generate(
                "Tell me a joke",
                using: .openai(.gpt5Mini),
                system: "You are a comedian",
                temperature: 0.8,
                configuration: config,
            )

            self.assertOpenAIResult(
                result,
                prompt: "Tell me a joke",
                configuration: config,
            )
        }
    }

    // MARK: - Streaming Tests

    @Test
    func `Stream Function - Basic Streaming`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            let stream = try await stream(
                "Count to 5",
                using: .openai(.gpt55),
                maxTokens: 50,
                configuration: config,
            )

            var tokens: [TextStreamDelta] = []

            for try await token in stream {
                tokens.append(token)
                if token.type == .done {
                    break
                }
            }

            #expect(!tokens.isEmpty)
            #expect(tokens.last?.type == .done)

            // Verify we received some text deltas
            let textTokens = tokens.filter { $0.type == .textDelta }
            #expect(!textTokens.isEmpty)
        }
    }

    @Test
    func `Stream Function - Anthropic Streaming`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["anthropic": "test-key"]) { config in
            let stream = try await stream(
                "Write a haiku",
                using: .anthropic(.custom("claude-3-5-sonnet-20241022")),
                system: "You are a poet",
                configuration: config,
            )

            var receivedTokens = 0
            var completed = false

            for try await token in stream {
                receivedTokens += 1

                if token.type == .done {
                    completed = true
                    break
                }

                // Don't run forever in case of issues
                if receivedTokens > 100 {
                    break
                }
            }

            #expect(receivedTokens > 0)
            #expect(completed)
        }
    }

    @Test
    func `StreamText rejects refusal-prone aggregator models`() async throws {
        await #expect(throws: TachikomaError.self) {
            _ = try await streamText(
                model: .openRouter(modelId: "anthropic/claude-fable-5"),
                messages: [.user("hi")],
                configuration: TachikomaConfiguration(loadFromEnvironment: false),
            )
        }

        await #expect(throws: TachikomaError.self) {
            _ = try await streamText(
                model: .openaiCompatible(
                    modelId: "anthropic/claude-fable-5",
                    baseURL: "https://example.test",
                ),
                messages: [.user("hi")],
                configuration: TachikomaConfiguration(loadFromEnvironment: false),
            )
        }
    }

    @Test
    func `StreamObject rejects unsupported streaming models`() async throws {
        struct Payload: Codable, Sendable {
            let ok: Bool
        }

        await #expect(throws: TachikomaError.self) {
            _ = try await streamObject(
                model: .openRouter(modelId: "anthropic/claude-fable-5"),
                messages: [.user("hi")],
                schema: Payload.self,
                configuration: TachikomaConfiguration(loadFromEnvironment: false),
            )
        }
    }

    @Test
    func `StreamObject explicit terminal buffering suppresses content filter partial output`() async throws {
        struct Payload: Codable, Sendable {
            let ok: Bool
        }

        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(
                response: ProviderResponse(text: "", finishReason: .stop),
                streamDeltas: [
                    .text(#"{"ok":true}"#),
                    .done(finishReason: .contentFilter),
                ],
            )
        }

        let result = try await streamObject(
            model: .openai(.gpt55),
            messages: [.user("hi")],
            schema: Payload.self,
            settings: GenerationSettings(streamBuffering: .untilTerminal),
            configuration: config,
        )

        var publishedDeltas = 0
        do {
            for try await _ in result.objectStream {
                publishedDeltas += 1
            }
            Issue.record("Expected content filter error")
        } catch let error as TachikomaError {
            guard case let .apiError(message) = error else {
                Issue.record("Expected apiError, got \(error)")
                return
            }
            #expect(message.contains("content filter"))
            #expect(publishedDeltas == 0)
        }
    }

    @Test
    func `StreamObject completes direct custom stream without terminal status`() async throws {
        struct Payload: Codable, Sendable {
            let ok: Bool
        }

        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(
                response: ProviderResponse(text: "", finishReason: .stop),
                streamDeltas: [.text(#"{"ok":true}"#)],
            )
        }

        let result = try await streamObject(
            model: .custom(provider: StaticProvider(
                response: ProviderResponse(text: ""),
                capabilities: ModelCapabilities(supportsStreaming: true),
                streamDeltas: [],
            )),
            messages: [.user("hi")],
            schema: Payload.self,
            settings: GenerationSettings(stopConditions: StringStopCondition("ok")),
            configuration: config,
        )

        var completed = false
        for try await delta in result.objectStream {
            if delta.type == .complete {
                #expect(delta.object?.ok == true)
                completed = true
            }
        }
        #expect(completed)
    }

    @Test
    func `StreamObject stays incremental by default when terminal content filter arrives`() async throws {
        struct Payload: Codable, Sendable {
            let ok: Bool
        }

        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(
                response: ProviderResponse(text: "", finishReason: .stop),
                streamDeltas: [
                    .text(#"{"ok":true}"#),
                    .done(finishReason: .contentFilter),
                ],
            )
        }

        let result = try await streamObject(
            model: .openaiCompatible(modelId: "json-stream", baseURL: "https://example.test"),
            messages: [.user("hi")],
            schema: Payload.self,
            configuration: config,
        )

        var publishedDeltas = 0
        do {
            for try await _ in result.objectStream {
                publishedDeltas += 1
            }
            Issue.record("Expected content filter error")
        } catch let error as TachikomaError {
            guard case let .apiError(message) = error else {
                Issue.record("Expected apiError, got \(error)")
                return
            }
            #expect(message.contains("content filter"))
            #expect(publishedDeltas > 0)
        }
    }

    @Test
    func `StreamObject honors explicit terminal buffering for custom providers`() async throws {
        struct Payload: Codable, Sendable {
            let ok: Bool
        }

        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(
                response: ProviderResponse(text: "", finishReason: .stop),
                streamDeltas: [
                    .text(#"{"ok":true}"#),
                    .done(finishReason: .contentFilter),
                ],
            )
        }

        let result = try await streamObject(
            model: .custom(provider: StaticProvider(
                response: ProviderResponse(text: ""),
                capabilities: ModelCapabilities(supportsStreaming: true),
                streamDeltas: [],
            )),
            messages: [.user("hi")],
            schema: Payload.self,
            settings: GenerationSettings(streamBuffering: .untilTerminal),
            configuration: config,
        )

        var publishedDeltas = 0
        do {
            for try await _ in result.objectStream {
                publishedDeltas += 1
            }
            Issue.record("Expected content filter error")
        } catch let error as TachikomaError {
            guard case let .apiError(message) = error else {
                Issue.record("Expected apiError, got \(error)")
                return
            }
            #expect(message.contains("content filter"))
            #expect(publishedDeltas == 0)
        }
    }

    @Test
    func `StreamObject rejects length-truncated object stream`() async throws {
        struct Payload: Codable, Sendable {
            let ok: Bool
        }

        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(
                response: ProviderResponse(text: "", finishReason: .stop),
                streamDeltas: [
                    .text(#"{"ok":true}"#),
                    .text(#", "unfinished":"#),
                    .done(finishReason: .length),
                ],
            )
        }

        let result = try await streamObject(
            model: .openai(.gpt55),
            messages: [.user("hi")],
            schema: Payload.self,
            configuration: config,
        )

        do {
            for try await _ in result.objectStream {}
            Issue.record("Expected truncated stream error")
        } catch let error as TachikomaError {
            guard case let .invalidInput(message) = error else {
                Issue.record("Expected invalidInput, got \(error)")
                return
            }
            #expect(message.contains("complete object"))
        }
    }

    // MARK: - Image Analysis Tests

    @Test
    func `Analyze Function - Vision Model`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            let testImageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
            let result = try await analyze(
                image: .base64(testImageBase64),
                prompt: "What do you see?",
                using: .openai(.gpt55),
                configuration: config,
            )

            self.assertOpenAIResult(
                result,
                prompt: "What do you see?",
                configuration: config,
            )
        }
    }

    @Test
    func `Analyze Function - Non-Vision Model Error`() async {
        _ = await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            // Custom OpenAI models default to text-only capabilities
            await #expect(throws: TachikomaError.self) {
                try await analyze(
                    image: .base64("test-image"),
                    prompt: "Describe this",
                    using: .openai(.custom("text-only-openai")),
                    configuration: config,
                )
            }
        }
    }

    @Test
    func `Analyze Function - Default Vision Model`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            // Use base64 encoded test image (1x1 pixel PNG)
            let testImageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
            let result = try await analyze(
                image: .base64(testImageBase64),
                prompt: "Analyze this image",
                configuration: config,
            )

            // Should default to GPT-5.5 for vision tasks
            self.assertOpenAIResult(
                result,
                prompt: "Analyze this image",
                configuration: config,
            )
        }
    }

    // MARK: - Error Handling Tests

    @Test
    func `Generate Function - Missing API Key`() async {
        _ = await TestHelpers.withEmptyTestConfiguration { config in
            await #expect(throws: TachikomaError.self) {
                try await generate("Test", using: .openai(.gpt55), configuration: config)
            }
        }
    }

    @Test
    func `Generate Function - Invalid Configuration`() async {
        await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            // Test with invalid base URL format
            config.setBaseURL("not-a-url", for: .openai)

            // With mock provider (test-key), this should work even with invalid URL
            // Real implementations would fail with network error
            do {
                let result = try await generate("Test", using: .openai(.gpt55), configuration: config)
                #expect(!result.isEmpty)
            } catch {
                // If using real provider, invalid URL will cause network error
                // This is expected behavior
                #expect(error is TachikomaError || error is URLError)
            }
        }
    }

    // MARK: - Tool Integration Tests

    @Test
    func `Generate Function - Without Tools`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            // Test generation without tools
            let result = try await generate(
                "Hello",
                using: .openai(.gpt55),
                configuration: config,
            )

            #expect(!result.isEmpty)
        }
    }

    @Test
    func `Generate Function - With Custom Tools`() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["anthropic": "test-key"]) { config in
            // Create a simple test tool
            let testTool = createTool(
                name: "test_tool",
                description: "A test tool",
                parameters: [],
                required: [],
            ) { _ in
                AnyAgentToolValue(string: "Tool executed")
            }

            // Use generateText with tools
            let result = try await generateText(
                model: .anthropic(.sonnet46),
                messages: [.user("Use the test tool")],
                tools: [testTool],
                configuration: config,
            )

            #expect(!result.text.isEmpty)
        }
    }

    @Test
    func `GenerateText preserves ordered assistant messages from provider`() async throws {
        let call1 = AgentToolCall(id: "call-1", name: "first_tool", arguments: [:])
        let call2 = AgentToolCall(id: "call-2", name: "second_tool", arguments: [:])
        let thinking1 = ModelMessage(
            role: .assistant,
            content: [.text("thinking-1")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.signature": "sig-1",
                "anthropic.thinking.type": "thinking",
            ]),
        )
        let thinking2 = ModelMessage(
            role: .assistant,
            content: [.text("thinking-2")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.signature": "sig-2",
                "anthropic.thinking.type": "thinking",
            ]),
        )
        let providerResponse = ProviderResponse(
            text: "",
            usage: nil,
            finishReason: .toolCalls,
            toolCalls: [call1, call2],
            assistantMessages: [
                thinking1,
                ModelMessage(role: .assistant, content: [.toolCall(call1)]),
                thinking2,
                ModelMessage(role: .assistant, content: [.toolCall(call2)]),
            ],
        )
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in StaticProvider(response: providerResponse) }

        let firstTool = createTool(name: "first_tool", description: "First", parameters: [], required: []) { _ in
            AnyAgentToolValue(string: "first")
        }
        let secondTool = createTool(name: "second_tool", description: "Second", parameters: [], required: []) { _ in
            AnyAgentToolValue(string: "second")
        }

        let result = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("go")],
            tools: [firstTool, secondTool],
            maxSteps: 1,
            configuration: config,
        )

        #expect(result.messages[1] == thinking1)
        if case let .toolCall(firstCall) = result.messages[2].content.first {
            #expect(firstCall.id == "call-1")
        } else {
            Issue.record("Expected first tool call")
        }
        #expect(result.messages[3] == thinking2)
        if case let .toolCall(secondCall) = result.messages[4].content.first {
            #expect(secondCall.id == "call-2")
        } else {
            Issue.record("Expected second tool call")
        }
    }

    @Test
    func `GenerateText merges fallback fields into partial assistant messages`() async throws {
        let call = AgentToolCall(id: "call-1", name: "inspect_context", arguments: [:])
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("thinking-only")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
            ]),
        )
        let providerResponse = ProviderResponse(
            text: "visible text",
            finishReason: .toolCalls,
            toolCalls: [call],
            assistantMessages: [thinking],
        )
        let seenContext = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in StaticProvider(response: providerResponse) }
        let tool = AgentTool(
            name: "inspect_context",
            description: "Inspect context",
            parameters: AgentToolParameters(properties: [:], required: []),
        ) { _, context in
            seenContext.messages = context.messages
            return AnyAgentToolValue(string: "ok")
        }

        let result = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("go")],
            tools: [tool],
            maxSteps: 1,
            configuration: config,
        )

        #expect(result.messages[1] == thinking)
        let fallbackMessage = try #require(result.messages.first { message in
            message.role == .assistant && message.content.contains { part in
                if case let .toolCall(toolCall) = part {
                    return toolCall.id == "call-1"
                }
                return false
            }
        })
        #expect(fallbackMessage.content.contains(.text("visible text")))

        let contextMessages = try #require(seenContext.messages)
        #expect(contextMessages.contains { message in
            message.role == .assistant && message.content.contains { part in
                if case let .toolCall(toolCall) = part {
                    return toolCall.id == "call-1"
                }
                return false
            }
        })
    }

    @Test
    func `GenerateText does not duplicate concatenated native assistant text`() async throws {
        let providerResponse = ProviderResponse(
            text: "part onepart two",
            finishReason: .stop,
            assistantMessages: [
                ModelMessage(role: .assistant, content: [.text("part one")]),
                ModelMessage(role: .assistant, content: [.text("part two")]),
            ],
        )
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in StaticProvider(response: providerResponse) }

        let result = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("go")],
            configuration: config,
        )

        let assistantTexts = result.messages.flatMap { message -> [String] in
            guard message.role == .assistant, message.channel != .thinking else { return [] }
            return message.content.compactMap { part in
                if case let .text(value) = part {
                    return value
                }
                return nil
            }
        }
        #expect(assistantTexts == ["part one", "part two"])
    }

    @Test
    func `GenerateText preserves empty successful assistant turn`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: "", finishReason: .stop))
        }

        let result = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("go")],
            configuration: config,
        )

        #expect(result.messages.count == 2)
        #expect(result.messages[1].role == .assistant)
        #expect(result.messages[1].content == [.text("")])
    }

    @Test
    func `GenerateText hides Anthropic thinking messages from tool execution context`() async throws {
        let call = AgentToolCall(id: "call-1", name: "inspect_context", arguments: [:])
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("private-thinking")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
            ]),
        )
        let providerResponse = ProviderResponse(
            text: "",
            finishReason: .toolCalls,
            toolCalls: [call],
            assistantMessages: [
                thinking,
                ModelMessage(role: .assistant, content: [.toolCall(call)]),
            ],
        )
        let seenContext = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in StaticProvider(response: providerResponse) }
        let tool = AgentTool(
            name: "inspect_context",
            description: "Inspect context",
            parameters: AgentToolParameters(properties: [:], required: []),
        ) { _, context in
            seenContext.messages = context.messages
            return AnyAgentToolValue(string: "ok")
        }

        let result = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("go")],
            tools: [tool],
            maxSteps: 1,
            configuration: config,
        )

        #expect(result.messages.contains { $0.channel == .thinking })
        let contextMessages = try #require(seenContext.messages)
        #expect(contextMessages.allSatisfy { message in
            message.metadata?.customData?["anthropic.thinking.signature"] == nil
        })
        #expect(contextMessages.contains { message in
            message.content.contains { content in
                if case let .toolCall(toolCall) = content {
                    return toolCall.id == "call-1"
                }
                return false
            }
        })
    }

    @Test
    func `GenerateText strips provider-neutral thinking messages from tool execution context`() async throws {
        let call = AgentToolCall(id: "call-1", name: "inspect_context", arguments: [:])
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("visible-thinking")],
            channel: .thinking,
        )
        let providerResponse = ProviderResponse(
            text: "",
            finishReason: .toolCalls,
            toolCalls: [call],
            assistantMessages: [
                thinking,
                ModelMessage(role: .assistant, content: [.toolCall(call)]),
            ],
        )
        let seenContext = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in StaticProvider(response: providerResponse) }
        let tool = AgentTool(
            name: "inspect_context",
            description: "Inspect context",
            parameters: AgentToolParameters(properties: [:], required: []),
        ) { _, context in
            seenContext.messages = context.messages
            return AnyAgentToolValue(string: "ok")
        }

        _ = try await generateText(
            model: .openai(.gpt55),
            messages: [.user("go")],
            tools: [tool],
            maxSteps: 1,
            configuration: config,
        )

        let contextMessages = try #require(seenContext.messages)
        #expect(contextMessages.allSatisfy { $0.channel != .thinking })
    }

    @Test
    func `GenerateText skips usage tracking for non-billable refusal`() async throws {
        let providerResponse = ProviderResponse(
            text: "",
            usage: Usage(inputTokens: 123, outputTokens: 0),
            finishReason: .contentFilter,
            isBillable: false,
        )
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in StaticProvider(response: providerResponse) }
        let sessionId = "non-billable-\(UUID().uuidString)"
        _ = UsageTracker.shared.startSession(sessionId)
        defer { _ = UsageTracker.shared.endSession(sessionId) }

        let result = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("blocked")],
            configuration: config,
            sessionId: sessionId,
        )

        #expect(result.finishReason == .contentFilter)
        #expect(result.usage?.inputTokens == 123)
        #expect(UsageTracker.shared.getSession(sessionId)?.operations.isEmpty == true)
    }

    @Test
    func `GenerateText preserves content filter finish reason across client stop conditions`() async throws {
        let providerResponse = ProviderResponse(
            text: "Refused STOP by policy",
            usage: Usage(inputTokens: 10, outputTokens: 0),
            finishReason: .contentFilter,
            isBillable: false,
        )
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in StaticProvider(response: providerResponse) }

        let result = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("blocked")],
            settings: GenerationSettings(stopConditions: StringStopCondition("STOP")),
            configuration: config,
        )

        #expect(result.text.isEmpty)
        #expect(result.finishReason == .contentFilter)
    }

    @Test
    func `GenerateText persists client stop truncation across generated message history`() async throws {
        let providerResponse = ProviderResponse(
            text: "safe STOPleak",
            usage: Usage(inputTokens: 10, outputTokens: 3),
            finishReason: .stop,
            assistantMessages: [
                ModelMessage(role: .assistant, content: [.text("safe STOP")]),
                ModelMessage(role: .assistant, content: [.text("leak")]),
            ],
        )
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in StaticProvider(response: providerResponse) }

        let result = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("continue")],
            settings: GenerationSettings(stopConditions: StringStopCondition("STOP")),
            configuration: config,
        )

        #expect(result.text == "safe ")
        let generatedText = result.messages
            .dropFirst()
            .flatMap { message in
                message.content.compactMap { part in
                    if case let .text(text) = part {
                        return text
                    }
                    return nil
                }
            }
            .joined()
        #expect(generatedText == "safe ")
        #expect(!generatedText.contains("STOP"))
        #expect(!generatedText.contains("leak"))
    }

    @Test
    func `GenerateText truncates only final step after tool history`() async throws {
        let call = AgentToolCall(id: "call-1", name: "inspect_context", arguments: [:])
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            SequenceProvider(responses: [
                ProviderResponse(
                    text: "Checking...",
                    finishReason: .toolCalls,
                    toolCalls: [call],
                    assistantMessages: [
                        ModelMessage(role: .assistant, content: [.text("Checking..."), .toolCall(call)]),
                    ],
                ),
                ProviderResponse(
                    text: "answer STOP leak",
                    finishReason: .stop,
                    assistantMessages: [
                        ModelMessage(role: .assistant, content: [.text("answer STOP leak")]),
                    ],
                ),
            ])
        }
        let tool = AgentTool(
            name: "inspect_context",
            description: "Inspect context",
            parameters: AgentToolParameters(properties: [:], required: []),
        ) { _, _ in
            AnyAgentToolValue(string: "ok")
        }

        let result = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("continue")],
            tools: [tool],
            settings: GenerationSettings(stopConditions: StringStopCondition("STOP")),
            maxSteps: 2,
            configuration: config,
        )

        #expect(result.text == "answer ")
        let assistantTexts = result.messages
            .filter { $0.role == .assistant && $0.channel != .thinking }
            .flatMap { message in
                message.content.compactMap { part in
                    if case let .text(text) = part {
                        return text
                    }
                    return nil
                }
            }
        #expect(assistantTexts.contains("Checking..."))
        #expect(assistantTexts.last == "answer ")
        #expect(!assistantTexts.joined().contains("STOP"))
        #expect(!assistantTexts.joined().contains("leak"))
    }

    @Test
    func `GenerateText tracks billable refusal with generated output`() async throws {
        let providerResponse = ProviderResponse(
            text: "",
            usage: Usage(inputTokens: 123, outputTokens: 4),
            finishReason: .contentFilter,
            isBillable: true,
        )
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in StaticProvider(response: providerResponse) }
        let sessionId = "billable-\(UUID().uuidString)"
        _ = UsageTracker.shared.startSession(sessionId)
        defer { _ = UsageTracker.shared.endSession(sessionId) }

        _ = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("blocked late")],
            configuration: config,
            sessionId: sessionId,
        )

        let operation = try #require(UsageTracker.shared.getSession(sessionId)?.operations.first)
        #expect(operation.usage.inputTokens == 123)
        #expect(operation.usage.outputTokens == 4)
        #expect((operation.usage.cost?.total ?? 0) > 0)
    }

    @Test
    func `GenerateText strips Anthropic thinking before non-Anthropic providers`() async throws {
        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: "ok", finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("private")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
            ]),
        )

        _ = try await generateText(
            model: .openai(.gpt55),
            messages: [.user("hi"), thinking, .assistant("visible")],
            configuration: config,
        )

        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 2)
        #expect(messages.allSatisfy { $0.channel != .thinking })
    }

    @Test
    func `GenerateText strips Anthropic thinking from other Claude models`() async throws {
        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: "ok", finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = try ModelMessage(
            role: .assistant,
            content: [.text("private")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.model": "claude-fable-5",
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
                "tachikoma.reasoning.provider": "anthropic",
                "tachikoma.reasoning.model": "claude-fable-5",
                "tachikoma.reasoning.base_url": #require(ReasoningEndpointIdentity
                    .canonical("https://api.anthropic.com")),
            ]),
        )

        _ = try await generateText(
            model: .anthropic(.opus48),
            messages: [.user("hi"), thinking, .assistant("visible")],
            configuration: config,
        )

        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 2)
        #expect(messages.allSatisfy { $0.channel != .thinking })
    }

    @Test
    func `GenerateText strips unknown Anthropic thinking before Fable`() async throws {
        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: "ok", finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("private")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
            ]),
        )

        _ = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("hi"), thinking, .assistant("visible")],
            configuration: config,
        )

        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 2)
        #expect(messages.allSatisfy { $0.channel != .thinking })
    }

    @Test
    func `GenerateText strips unknown Anthropic thinking before custom Fable id`() async throws {
        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: "ok", finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("private")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
            ]),
        )

        _ = try await generateText(
            model: .anthropic(.custom("claude-fable-5")),
            messages: [.user("hi"), thinking, .assistant("visible")],
            configuration: config,
        )

        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 2)
        #expect(messages.allSatisfy { $0.channel != .thinking })
    }

    @Test
    func `GenerateText preserves legacy unknown Anthropic thinking for non-Fable Claude`() async throws {
        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: "ok", finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("private")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
            ]),
        )

        _ = try await generateText(
            model: .anthropic(.opus48),
            messages: [.user("hi"), thinking, .assistant("visible")],
            configuration: config,
        )

        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 3)
        #expect(messages[1].channel == .thinking)
    }

    @Test
    func `GenerateText keeps Anthropic thinking for same Claude model`() async throws {
        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: "ok", finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = try ModelMessage(
            role: .assistant,
            content: [.text("private")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.model": "claude-fable-5",
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
                "tachikoma.reasoning.provider": "anthropic",
                "tachikoma.reasoning.model": "claude-fable-5",
                "tachikoma.reasoning.base_url": #require(ReasoningEndpointIdentity
                    .canonical("https://api.anthropic.com")),
            ]),
        )

        _ = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("hi"), thinking, .assistant("visible")],
            configuration: config,
        )

        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 3)
        #expect(messages[1].channel == .thinking)
    }

    @Test
    func `GenerateText preserves direct custom Anthropic thinking for same model`() async throws {
        let seenMessages = MessageBox()
        let provider = StaticProvider(
            modelId: "claude-fable-5",
            response: ProviderResponse(text: "ok", finishReason: .stop),
        ) { request in
            seenMessages.messages = request.messages
        }
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in provider }
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("private")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.model": "claude-fable-5",
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
                "tachikoma.reasoning.provider": "custom-anthropic",
                "tachikoma.reasoning.model": "claude-fable-5",
            ]),
        )

        _ = try await generateText(
            model: .custom(provider: provider),
            messages: [.user("hi"), thinking, .assistant("visible")],
            configuration: config,
        )

        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 3)
        #expect(messages[1].channel == .thinking)
    }

    @Test
    func `GenerateText preserves direct AnthropicProvider thinking for same custom model`() async throws {
        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(apiKeys: ["anthropic": "test-key"])
        let directProvider = try AnthropicProvider(model: .fable5, configuration: config)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: "ok", finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = try ModelMessage(
            role: .assistant,
            content: [.text("private")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.model": "claude-fable-5",
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
                "tachikoma.reasoning.provider": "anthropic",
                "tachikoma.reasoning.model": "claude-fable-5",
                "tachikoma.reasoning.base_url": #require(ReasoningEndpointIdentity
                    .canonical("https://api.anthropic.com")),
            ]),
        )

        _ = try await generateText(
            model: .custom(provider: directProvider),
            messages: [.user("hi"), thinking, .assistant("visible")],
            configuration: config,
        )

        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 3)
        #expect(messages[1].channel == .thinking)
    }

    @Test
    func `GenerateText preserves Anthropic-compatible thinking for same model`() async throws {
        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: "ok", finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = try ModelMessage(
            role: .assistant,
            content: [.text("private")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.model": "claude-proxy-model",
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
                "tachikoma.reasoning.provider": "anthropic-compatible",
                "tachikoma.reasoning.model": "claude-proxy-model",
                "tachikoma.reasoning.base_url": #require(ReasoningEndpointIdentity
                    .canonical("https://example.test")),
            ]),
        )

        _ = try await generateText(
            model: .anthropicCompatible(modelId: "claude-proxy-model", baseURL: "https://example.test"),
            messages: [.user("hi"), thinking, .assistant("visible")],
            configuration: config,
        )

        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 3)
        #expect(messages[1].channel == .thinking)
    }

    @Test
    func `GenerateText tags fallback reasoning for Anthropic-compatible Fable`() async throws {
        let providerResponse = ProviderResponse(
            text: "ok",
            finishReason: .stop,
            reasoning: [ProviderReasoningBlock(text: "private", signature: "sig")],
        )
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in StaticProvider(response: providerResponse) }

        let result = try await generateText(
            model: .anthropicCompatible(modelId: "claude-fable-5", baseURL: "https://example.test"),
            messages: [.user("hi")],
            configuration: config,
        )

        let thinking = try #require(result.messages.first { $0.channel == .thinking })
        #expect(thinking.metadata?.customData?["anthropic.thinking.model"] == "claude-fable-5")
        #expect(thinking.metadata?.customData?["anthropic.thinking.signature"] == "sig")
        #expect(thinking.metadata?.customData?["tachikoma.reasoning.provider"] == "anthropic-compatible")
        #expect(thinking.metadata?.customData?["tachikoma.reasoning.base_url"] == ReasoningEndpointIdentity
            .canonical("https://example.test"))
    }

    @Test
    func `GenerateText tags fallback reasoning for direct custom Fable`() async throws {
        let provider = StaticProvider(
            modelId: "claude-fable-5",
            response: ProviderResponse(
                text: "ok",
                finishReason: .stop,
                reasoning: [ProviderReasoningBlock(text: "private", signature: "sig")],
            ),
        )
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in provider }

        let result = try await generateText(
            model: .custom(provider: provider),
            messages: [.user("hi")],
            configuration: config,
        )

        let thinking = try #require(result.messages.first { $0.channel == .thinking })
        #expect(thinking.metadata?.customData?["anthropic.thinking.model"] == "claude-fable-5")
        #expect(thinking.metadata?.customData?["anthropic.thinking.signature"] == "sig")
    }

    @Test
    func `GenerateText keeps fallback reasoning provider-neutral without Anthropic target`() async throws {
        let providerResponse = ProviderResponse(
            text: "ok",
            finishReason: .stop,
            reasoning: [ProviderReasoningBlock(text: "visible reasoning", signature: "sig")],
        )
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in StaticProvider(response: providerResponse) }

        let result = try await generateText(
            model: .openai(.gpt55),
            messages: [.user("hi")],
            configuration: config,
        )

        let thinking = try #require(result.messages.first { $0.channel == .thinking })
        #expect(thinking.metadata?.customData?["anthropic.thinking.type"] == nil)
        #expect(thinking.metadata?.customData?["anthropic.thinking.signature"] == nil)
        #expect(thinking.metadata?.customData?["tachikoma.reasoning.type"] == "thinking")
        #expect(thinking.metadata?.customData?["tachikoma.reasoning.signature"] == "sig")
        #expect(result.messages.toUIMessages().contains { $0.content == "visible reasoning" })
    }

    @Test
    func `StreamText strips provider-neutral thinking before provider replay`() async throws {
        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: "ok", finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("visible reasoning")],
            channel: .thinking,
            metadata: .init(customData: [
                "tachikoma.reasoning.type": "thinking",
                "tachikoma.reasoning.signature": "sig",
            ]),
        )

        _ = try await streamText(
            model: .openai(.gpt55),
            messages: [.user("hi"), thinking, .assistant("visible")],
            configuration: config,
        )

        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 2)
        #expect(messages.allSatisfy { $0.channel != .thinking })
    }

    @Test
    func `StreamText strips Anthropic thinking before non-Anthropic providers`() async throws {
        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: "ok", finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("private")],
            channel: .thinking,
            metadata: .init(customData: ["anthropic.thinking.signature": "sig"]),
        )

        _ = try await streamText(
            model: .openai(.gpt55),
            messages: [.user("hi"), thinking, .assistant("visible")],
            configuration: config,
        )

        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 2)
        #expect(messages.allSatisfy { $0.channel != .thinking })
    }

    @Test
    func `StreamText stop conditions preserve terminal content filter over local stop`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(
                response: ProviderResponse(text: "", finishReason: .stop),
                capabilities: ModelCapabilities(supportsStreaming: true),
                streamDeltas: [
                    .text("blocked"),
                    .done(finishReason: .contentFilter),
                ],
            )
        }

        let result = try await streamText(
            model: .openaiCompatible(modelId: "compatible-model", baseURL: "https://example.test"),
            messages: [.user("blocked")],
            settings: GenerationSettings(stopConditions: StringStopCondition("blocked")),
            configuration: config,
        )

        var deltas: [TextStreamDelta] = []
        for try await delta in result.stream {
            deltas.append(delta)
        }

        #expect(!deltas.contains { $0.type == .textDelta && $0.content == "blocked" })
        #expect(deltas.contains { $0.type == .done && $0.finishReason == .contentFilter })
    }

    @Test
    func `StreamText stays incremental by default when terminal content filter arrives`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(
                response: ProviderResponse(text: "", finishReason: .stop),
                capabilities: ModelCapabilities(supportsStreaming: true),
                streamDeltas: [
                    .text("blocked"),
                    .done(finishReason: .contentFilter),
                ],
            )
        }

        let result = try await streamText(
            model: .openaiCompatible(modelId: "compatible-model", baseURL: "https://example.test"),
            messages: [.user("blocked")],
            configuration: config,
        )

        var deltas: [TextStreamDelta] = []
        for try await delta in result.stream {
            deltas.append(delta)
        }

        #expect(deltas.contains { $0.type == .textDelta && $0.content == "blocked" })
        #expect(deltas.contains { $0.type == .done && $0.finishReason == .contentFilter })
    }

    @Test
    func `StreamText explicit terminal buffering suppresses late refused text`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(
                response: ProviderResponse(text: "", finishReason: .stop),
                capabilities: ModelCapabilities(supportsStreaming: true),
                streamDeltas: [
                    .text("blocked"),
                    .done(finishReason: .contentFilter),
                ],
            )
        }

        let result = try await streamText(
            model: .openaiCompatible(modelId: "compatible-model", baseURL: "https://example.test"),
            messages: [.user("blocked")],
            settings: GenerationSettings(streamBuffering: .untilTerminal),
            configuration: config,
        )

        var deltas: [TextStreamDelta] = []
        for try await delta in result.stream {
            deltas.append(delta)
        }

        #expect(!deltas.contains { $0.type == .textDelta && $0.content == "blocked" })
        #expect(deltas.contains { $0.type == .done && $0.finishReason == .contentFilter })
    }

    @Test
    func `StreamText counts suppressed buffered refusal tokens`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(
                response: ProviderResponse(text: "", finishReason: .stop),
                capabilities: ModelCapabilities(supportsStreaming: true),
                streamDeltas: [
                    .text("billable refused output"),
                    .done(finishReason: .contentFilter),
                ],
            )
        }
        let sessionId = "buffered-refusal-\(UUID().uuidString)"
        _ = UsageTracker.shared.startSession(sessionId)
        defer { _ = UsageTracker.shared.endSession(sessionId) }

        let result = try await streamText(
            model: .openaiCompatible(modelId: "compatible-model", baseURL: "https://example.test"),
            messages: [.user("blocked")],
            settings: GenerationSettings(streamBuffering: .untilTerminal),
            configuration: config,
            sessionId: sessionId,
        )

        for try await _ in result.stream {}

        let operation = try #require(UsageTracker.shared.getSession(sessionId)?.operations.last)
        #expect(operation.usage.outputTokens > 0)
    }

    @Test
    func `StreamText stop conditions ignore reasoning deltas`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(
                response: ProviderResponse(text: "", finishReason: .stop),
                capabilities: ModelCapabilities(supportsStreaming: true),
                streamDeltas: [
                    .reasoning("hidden STOP"),
                    .text("visible"),
                    .done(finishReason: .stop),
                ],
            )
        }

        let result = try await streamText(
            model: .openaiCompatible(modelId: "compatible-model", baseURL: "https://example.test"),
            messages: [.user("hi")],
            settings: GenerationSettings(stopConditions: StringStopCondition("STOP")),
            configuration: config,
        )

        var deltas: [TextStreamDelta] = []
        for try await delta in result.stream {
            deltas.append(delta)
        }

        #expect(deltas.contains { $0.type == .reasoning && $0.content == "hidden STOP" })
        #expect(deltas.contains { $0.type == .textDelta && $0.content == "visible" })
        #expect(deltas.contains { $0.type == .done && $0.finishReason == .stop })
    }

    @Test
    func `StreamText stop conditions can finish before provider terminal status`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        let provider = StaticProvider(
            response: ProviderResponse(text: "", finishReason: .stop),
            capabilities: ModelCapabilities(supportsStreaming: true),
            streamDeltas: [
                .text("partial"),
            ],
        )
        config.setProviderFactoryOverride { _, _ in provider }

        let result = try await streamText(
            model: .custom(provider: provider),
            messages: [.user("hi")],
            settings: GenerationSettings(stopConditions: StringStopCondition("partial")),
            configuration: config,
        )

        var deltas: [TextStreamDelta] = []
        for try await delta in result.stream {
            deltas.append(delta)
        }
        #expect(deltas.contains { $0.type == .textDelta && $0.content == "partial" })
        #expect(deltas.contains { $0.type == .done && $0.finishReason == .stop })
    }

    @Test
    func `GenerateObject strips Anthropic thinking before non-Anthropic providers`() async throws {
        struct Payload: Codable, Sendable, Equatable {
            let ok: Bool
        }

        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: #"{"ok":true}"#, finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("private")],
            channel: .thinking,
            metadata: .init(customData: ["anthropic.thinking.signature": "sig"]),
        )

        let result = try await generateObject(
            model: .openai(.gpt55),
            messages: [.user("hi"), thinking, .assistant("visible")],
            schema: Payload.self,
            configuration: config,
        )

        #expect(result.object == Payload(ok: true))
        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 2)
        #expect(messages.allSatisfy { $0.channel != .thinking })
    }

    @Test
    func `GenerateObject strips provider-neutral thinking before non-Anthropic providers`() async throws {
        struct Payload: Codable, Sendable, Equatable {
            let ok: Bool
        }

        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: #"{"ok":true}"#, finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("neutral reasoning")],
            channel: .thinking,
        )

        let result = try await generateObject(
            model: .openai(.gpt55),
            messages: [.user("hi"), thinking, .assistant("visible")],
            schema: Payload.self,
            configuration: config,
        )

        #expect(result.object == Payload(ok: true))
        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 2)
        #expect(messages.allSatisfy { $0.channel != .thinking })
    }

    @Test
    func `GenerateObject surfaces content filter before JSON parsing`() async throws {
        struct Payload: Codable, Sendable, Equatable {
            let ok: Bool
        }

        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: "", finishReason: .contentFilter))
        }

        do {
            _ = try await generateObject(
                model: .anthropic(.fable5),
                messages: [.user("blocked")],
                schema: Payload.self,
                configuration: config,
            )
            Issue.record("Expected content filter error")
        } catch let error as TachikomaError {
            guard case let .apiError(message) = error else {
                Issue.record("Expected apiError, got \(error)")
                return
            }
            #expect(message.contains("content filter"))
        }
    }

    @Test
    func `GenerateText preserves reasoning-only assistant boundary`() async throws {
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("thinking-only")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
            ]),
        )
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(
                text: "",
                finishReason: .length,
                assistantMessages: [thinking],
            ))
        }

        let result = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("think")],
            configuration: config,
        )

        #expect(result.messages.count == 3)
        #expect(result.messages[1] == thinking)
        #expect(result.messages[2].role == .assistant)
        #expect(result.messages[2].content == [.text("")])
        #expect(result.messages[2].metadata?.customData?["tachikoma.internal.boundary"] == "reasoning_only")
    }

    @Test
    func `GenerateObject strips Anthropic reasoning boundary before non-Anthropic providers`() async throws {
        struct Payload: Codable, Sendable, Equatable {
            let ok: Bool
        }

        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: #"{"ok":true}"#, finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = try ModelMessage(
            role: .assistant,
            content: [.text("private")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.model": "claude-fable-5",
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
                "tachikoma.reasoning.provider": "anthropic",
                "tachikoma.reasoning.model": "claude-fable-5",
                "tachikoma.reasoning.base_url": #require(ReasoningEndpointIdentity
                    .canonical("https://api.anthropic.com")),
            ]),
        )
        let boundary = ModelMessage(
            role: .assistant,
            content: [.text("")],
            metadata: .init(customData: ["tachikoma.internal.boundary": "reasoning_only"]),
        )

        let result = try await generateObject(
            model: .openai(.gpt55),
            messages: [.user("hi"), thinking, boundary, .assistant("visible")],
            schema: Payload.self,
            configuration: config,
        )

        #expect(result.object == Payload(ok: true))
        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 2)
        #expect(messages.allSatisfy { $0.metadata?.customData?["tachikoma.internal.boundary"] == nil })
    }

    @Test
    func `GenerateText keeps matching Anthropic reasoning boundary for replay`() async throws {
        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: "ok", finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = try ModelMessage(
            role: .assistant,
            content: [.text("private")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.model": "claude-fable-5",
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
                "tachikoma.reasoning.provider": "anthropic",
                "tachikoma.reasoning.model": "claude-fable-5",
                "tachikoma.reasoning.base_url": #require(ReasoningEndpointIdentity
                    .canonical("https://api.anthropic.com")),
            ]),
        )
        let boundary = ModelMessage(
            role: .assistant,
            content: [.text("")],
            metadata: .init(customData: ["tachikoma.internal.boundary": "reasoning_only"]),
        )

        _ = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("hi"), thinking, boundary, .assistant("visible")],
            configuration: config,
        )

        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 4)
        if messages.count >= 3 {
            #expect(messages[1].channel == .thinking)
            #expect(messages[2].metadata?.customData?["tachikoma.internal.boundary"] == "reasoning_only")
        }
    }

    @Test
    func `GenerateText strips Anthropic thinking from different configured endpoint`() async throws {
        let seenMessages = MessageBox()
        let config = TachikomaConfiguration(
            apiKeys: [:],
            baseURLs: ["anthropic": "https://user:secret@proxy.example.test?token=secret#frag"],
        )
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(text: "ok", finishReason: .stop)) { request in
                seenMessages.messages = request.messages
            }
        }
        let thinking = try ModelMessage(
            role: .assistant,
            content: [.text("private")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.model": "claude-fable-5",
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
                "tachikoma.reasoning.provider": "anthropic",
                "tachikoma.reasoning.model": "claude-fable-5",
                "tachikoma.reasoning.base_url": #require(ReasoningEndpointIdentity
                    .canonical("https://api.anthropic.com")),
            ]),
        )

        _ = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("hi"), thinking, .assistant("visible")],
            configuration: config,
        )

        let messages = try #require(seenMessages.messages)
        #expect(messages.count == 2)
        #expect(messages.allSatisfy { $0.channel != .thinking })
    }

    @Test
    func `GenerateText preserves content filter user turn`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(
                text: "Refused by policy",
                usage: Usage(inputTokens: 1, outputTokens: 0),
                finishReason: .contentFilter,
            ))
        }

        let result = try await generateText(
            model: .anthropic(.fable5),
            messages: [.user("blocked")],
            configuration: config,
        )

        #expect(result.text.isEmpty)
        #expect(result.messages.count == 1)
        #expect(result.messages.first?.role == .user)
        #expect(result.messages.first?.content == [.text("blocked")])
    }

    @Test
    func `GenerateText tags OpenRouter reasoning with configured endpoint`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setBaseURL("https://user:secret@proxy.example.test/api/v1?token=secret#frag", for: .custom("openrouter"))
        config.setProviderFactoryOverride { _, _ in
            StaticProvider(response: ProviderResponse(
                text: "",
                finishReason: .toolCalls,
                toolCalls: [AgentToolCall(id: "call-1", name: "lookup", arguments: [:])],
                reasoning: [
                    ProviderReasoningBlock(
                        text: "",
                        type: "openrouter_reasoning_details",
                        rawJSON: #"[{"type":"reasoning.encrypted","data":"sealed"}]"#,
                    ),
                ],
            ))
        }

        let result = try await generateText(
            model: .openRouter(modelId: "anthropic/claude-fable-5"),
            messages: [.user("hi")],
            configuration: config,
        )

        let thinking = try #require(result.messages.first { $0.channel == .thinking })
        #expect(thinking.metadata?.customData?["tachikoma.reasoning.provider"] == "openrouter")
        #expect(thinking.metadata?.customData?["tachikoma.reasoning.model"] == "anthropic/claude-fable-5")
        let endpointIdentity = try #require(thinking.metadata?.customData?["tachikoma.reasoning.base_url"])
        #expect(endpointIdentity == ReasoningEndpointIdentity
            .canonical("https://proxy.example.test/api/v1?token=secret"))
        #expect(endpointIdentity.contains("secret") == false)
        #expect(endpointIdentity.contains("token") == false)
        #expect(thinking.metadata?.customData?["openrouter.reasoning_details"]?.contains("sealed") == true)
    }

    // MARK: - Image Input Type Tests

    @Test
    func `Image Input Types`() {
        let base64Image = ImageInput.base64("test-data")
        let urlImage = ImageInput.url("https://example.com/image.jpg")
        let fileImage = ImageInput.filePath("/path/to/image.png")

        // Verify they're constructed correctly
        if case let .base64(data) = base64Image {
            #expect(data == "test-data")
        } else {
            Issue.record("Expected base64 image input")
        }

        if case let .url(url) = urlImage {
            #expect(url == "https://example.com/image.jpg")
        } else {
            Issue.record("Expected URL image input")
        }

        if case let .filePath(path) = fileImage {
            #expect(path == "/path/to/image.png")
        } else {
            Issue.record("Expected file path image input")
        }
    }

    private func assertOpenAIResult(
        _ result: String,
        prompt: String,
        modelId: String? = nil,
        configuration: TachikomaConfiguration,
    ) {
        if TestHelpers.isMockAPIKey(configuration.getAPIKey(for: .openai)) {
            #expect(result.contains("OpenAI response"))
            if !prompt.isEmpty {
                #expect(result.contains(prompt))
            }
            if let modelId {
                #expect(result.contains(modelId))
            }
        } else {
            #expect(!result.isEmpty)
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
private struct StaticProvider: ModelProvider {
    let modelId: String
    let response: ProviderResponse
    let capabilities: ModelCapabilities
    let onGenerate: (@Sendable (ProviderRequest) -> Void)?
    let streamDeltas: [TextStreamDelta]

    init(
        modelId: String = "static-provider",
        response: ProviderResponse,
        capabilities: ModelCapabilities = ModelCapabilities(),
        streamDeltas: [TextStreamDelta] = [],
        onGenerate: (@Sendable (ProviderRequest) -> Void)? = nil,
    ) {
        self.modelId = modelId
        self.response = response
        self.capabilities = capabilities
        self.streamDeltas = streamDeltas
        self.onGenerate = onGenerate
    }

    var baseURL: String? {
        nil
    }

    var apiKey: String? {
        nil
    }

    func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        self.onGenerate?(request)
        return self.response
    }

    func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        self.onGenerate?(request)
        return AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            for delta in self.streamDeltas {
                continuation.yield(delta)
            }
            continuation.finish()
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
private struct SequenceProvider: ModelProvider {
    let modelId = "sequence-provider"
    let baseURL: String? = nil
    let apiKey: String? = nil
    let capabilities = ModelCapabilities()
    private let queue: ResponseQueue

    init(responses: [ProviderResponse]) {
        self.queue = ResponseQueue(responses: responses)
    }

    func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
        self.queue.next()
    }

    func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            continuation.finish()
        }
    }
}

private final class ResponseQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [ProviderResponse]

    init(responses: [ProviderResponse]) {
        self.responses = responses
    }

    func next() -> ProviderResponse {
        self.lock.lock()
        defer { self.lock.unlock() }

        if self.responses.count > 1 {
            return self.responses.removeFirst()
        }
        return self.responses[0]
    }
}

private final class MessageBox: @unchecked Sendable {
    var messages: [ModelMessage]?
}
