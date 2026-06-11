import Foundation
import Testing
@testable import Tachikoma
@testable import TachikomaAgent

struct MinimalModernAPITests {
    // MARK: - Model Tests

    @Test
    func `Model enum construction`() {
        // Test that model enums can be constructed
        let openaiModel = Model.openai(.gpt55)
        let anthropicModel = Model.anthropic(.opus48)
        _ = Model.grok(.grok43)
        _ = Model.ollama(.llama33)

        // Test that they can be used in a switch statement
        switch openaiModel {
        case .openai:
            break // Expected
        default:
            Issue.record("Expected OpenAI model")
        }

        switch anthropicModel {
        case .anthropic:
            break // Expected
        default:
            Issue.record("Expected Anthropic model")
        }
    }

    @Test
    func `Model default value`() {
        let defaultModel = Model.default
        // Should compile without errors
        switch defaultModel {
        case .anthropic(.opus48):
            break // Expected default
        default:
            Issue.record("Expected default to be Anthropic Opus 4.8")
        }
    }

    @Test
    func `Streaming default value`() {
        #expect(Model.default.supportsStreaming == false)
        #expect(Model.defaultStreaming == .openai(.gpt55))
        #expect(Model.defaultStreaming.supportsStreaming == true)
    }

    @Test
    func `Agent default model preserves execution default`() {
        let agent = Agent(name: "test", instructions: "test", context: ())

        #expect(agent.model == .default)
    }

    @Test
    func `Agent stream uses streaming fallback for execution default`() async throws {
        let seenModel = MinimalModelBox()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { model, _ in
            seenModel.model = model
            return MinimalStreamingProvider(deltas: [
                .text("ok"),
                .done(finishReason: .stop),
            ])
        }
        let agent = Agent(name: "test", instructions: "test", configuration: config, context: ())

        let stream = try await agent.stream("hi")
        var received = ""
        for try await delta in stream where delta.type == .textDelta {
            received += delta.content ?? ""
        }

        #expect(agent.model == .default)
        #expect(seenModel.model == .openai(.gpt55))
        #expect(!received.isEmpty)
    }

    @Test
    func `Agent stream rejects explicit execution default`() async throws {
        let agent = Agent(name: "test", instructions: "test", model: .default, context: ())

        await #expect(throws: TachikomaError.self) {
            _ = try await agent.stream("hi")
        }
    }

    @Test
    func `Agent stream rejects nonstreaming model after mutation`() async throws {
        let agent = Agent(name: "test", instructions: "test", context: ())
        agent.model = .anthropic(.fable5)

        await #expect(throws: TachikomaError.self) {
            _ = try await agent.stream("hi")
        }
    }

    @Test
    func `Agent stream flushes buffered text on natural completion`() async throws {
        let provider = MinimalStreamingProvider(deltas: [
            .text("ok"),
        ])
        let agent = Agent(
            name: "test",
            instructions: "test",
            model: .custom(provider: provider),
            context: (),
        )

        let stream = try await agent.stream("hi")
        var received = ""
        for try await delta in stream where delta.type == .textDelta {
            received += delta.content ?? ""
        }

        #expect(received == "ok")
    }

    @Test
    func `Agent stream flushes buffered compatible text when done has no finish reason`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            MinimalStreamingProvider(deltas: [
                .text("ok"),
                .done(),
            ])
        }
        let agent = Agent(
            name: "test",
            instructions: "test",
            model: .openaiCompatible(modelId: "gpt-compatible", baseURL: "https://example.test"),
            configuration: config,
            context: (),
        )

        let stream = try await agent.stream("hi")
        var received = ""
        for try await delta in stream where delta.type == .textDelta {
            received += delta.content ?? ""
        }

        #expect(received == "ok")
        #expect(agent.conversation.messages.map(\.content) == ["test", "hi", "ok"])
    }

    @Test
    func `Agent conversation uses agent configuration`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            MinimalStaticProvider(response: ProviderResponse(text: "configured", finishReason: .stop))
        }
        let agent = Agent(name: "test", instructions: "test", configuration: config, context: ())

        let text = try await agent.conversation.continueConversation(using: .openai(.gpt55))

        #expect(text == "configured")
    }

    // MARK: - Tool System Tests

    @Test
    func `AgentTool creation`() {
        let tool = Tachikoma.createTool(
            name: "test_tool",
            description: "A test tool",
            parameters: [],
            required: [],
        ) { _ in
            AnyAgentToolValue(string: "Tool executed")
        }

        #expect(tool.name == "test_tool")
        #expect(tool.description == "A test tool")
    }

    @Test
    func `AgentToolArguments parsing`() throws {
        let args = AgentToolArguments([
            "name": AnyAgentToolValue(string: "test"),
            "value": AnyAgentToolValue(int: 42),
        ])

        #expect(try args.stringValue("name") == "test")
        #expect(try args.integerValue("value") == 42)
        #expect(args.optionalStringValue("missing") == nil)
        #expect(args.optionalStringValue("missing") ?? "default" == "default")
    }

    @Test
    func `Built-in tools exist`() {
        // Test that built-in tools are available
        #expect(weatherTool.name == "get_weather")
        #expect(timeTool.name == "get_current_time")
        #expect(calculatorTool.name == "calculate")
    }
}

// MARK: - Additional Test Code

extension MinimalModernAPITests {
    // MARK: - Error Types

    @Test
    func `Tool error types`() {
        let toolError = AgentToolError.invalidInput("test")
        #expect(toolError.errorDescription != nil)

        let tachikomaError = TachikomaError.modelNotFound("test")
        #expect(tachikomaError.errorDescription != nil)
    }

    // MARK: - Conversation Tests

    @Test
    func `Conversation basic functionality`() {
        let conversation = Conversation()
        #expect(conversation.messages.isEmpty)

        conversation.addUserMessage("Hello")
        #expect(conversation.messages.count == 1)
        #expect(conversation.messages[0].role == .user)
        #expect(conversation.messages[0].content == "Hello")

        conversation.clear()
        #expect(conversation.messages.isEmpty)
    }

    // MARK: - Basic Type Tests

    @Test
    func `ConversationMessage basic properties`() {
        let message = ConversationMessage(
            id: "test",
            role: .user,
            content: "Test",
            timestamp: Date(),
        )

        #expect(message.id == "test")
        #expect(message.role == .user)
        #expect(message.content == "Test")
    }

    @Test
    func `Conversation preserves signed thinking messages`() {
        let conversation = Conversation()
        let signedThinking = ModelMessage(
            role: .assistant,
            content: [.text("private reasoning")],
            channel: .thinking,
            metadata: .init(customData: [
                "anthropic.thinking.signature": "sig",
                "anthropic.thinking.type": "thinking",
            ]),
        )

        conversation.replaceModelMessages([.user("hi"), signedThinking, .assistant("hello")])

        let messages = conversation.getModelMessages()
        #expect(messages.count == 3)
        #expect(messages[1] == signedThinking)
        #expect(conversation.messages[1].content == "private reasoning")
    }

    @Test
    func `Conversation merge preserves messages appended after snapshot`() {
        let conversation = Conversation()
        conversation.addUserMessage("original")
        let snapshotCount = conversation.messages.count
        conversation.addUserMessage("concurrent")

        conversation.mergeGeneratedMessages(
            [.user("original"), .assistant("generated")],
            replacingPrefixCount: snapshotCount,
        )

        let messages = conversation.getModelMessages()
        #expect(messages.map(\.role) == [.user, .assistant, .user])
        if case let .text(text) = messages[2].content.first {
            #expect(text == "concurrent")
        } else {
            Issue.record("Expected preserved concurrent user message")
        }
    }

    @Test
    func `Conversation refusal rollback preserves messages appended after snapshot`() {
        let conversation = Conversation()
        conversation.addUserMessage("blocked")
        let snapshotIDs = conversation.messages.map(\.id)
        conversation.addUserMessage("concurrent")

        let didReplace = conversation.replaceModelMessages([], validatingSnapshotIDs: snapshotIDs)

        #expect(didReplace == true)
        #expect(conversation.messages.map(\.content) == ["concurrent"])
    }

    @Test
    func `Conversation lock removes cancelled waiters`() async throws {
        let conversation = Conversation()
        let probe = ConversationLockProbe()

        let first = Task {
            try await conversation.withContinuationLock {
                await probe.markFirstStarted()
                await probe.waitForRelease()
            }
        }

        await probe.waitUntilFirstStarted()

        let second = Task {
            try await conversation.withContinuationLock {
                await probe.markSecondRan()
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        second.cancel()

        do {
            try await second.value
            Issue.record("Expected queued waiter to be cancelled")
        } catch is CancellationError {
            // Expected
        }

        await probe.releaseFirst()
        try await first.value

        try await conversation.withContinuationLock {
            await probe.markThirdRan()
        }

        #expect(await probe.secondRan == false)
        #expect(await probe.thirdRan == true)
    }

    @Test
    func `Conversation append generated messages preserves concurrent appends`() {
        let conversation = Conversation()
        conversation.addUserMessage("original")
        let anchorID = conversation.messages[0].id
        conversation.addUserMessage("concurrent")

        conversation.appendGeneratedMessages([.assistant("generated")], afterMessageID: anchorID)

        #expect(conversation.messages.map(\.content) == ["original", "generated", "concurrent"])
    }

    @Test
    func `Conversation continue persists generated message from empty history`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            MinimalStaticProvider(response: ProviderResponse(text: "hello", finishReason: .stop))
        }
        let conversation = Conversation(configuration: config)

        let text = try await conversation.continueConversation(using: .anthropic(.opus48))

        #expect(text == "hello")
        #expect(conversation.messages.map(\.content) == ["hello"])
    }

    @Test
    func `Conversation continue rolls back refused trailing user turn`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            MinimalStaticProvider(response: ProviderResponse(text: "Refused by policy", finishReason: .contentFilter))
        }
        let conversation = Conversation(configuration: config)
        conversation.addUserMessage("blocked")

        let text = try await conversation.continueConversation(using: .anthropic(.fable5))

        #expect(text.isEmpty)
        #expect(conversation.messages.isEmpty)
    }

    @Test
    func `Conversation continue preserves completed tool history after late refusal`() async throws {
        let provider = MinimalSequenceProvider(responses: [
            ProviderResponse(
                text: "",
                finishReason: .toolCalls,
                toolCalls: [AgentToolCall(id: "call-1", name: "side_effect", arguments: [:])],
            ),
            ProviderResponse(text: "Refused by policy", finishReason: .contentFilter),
        ])
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in provider }
        let conversation = Conversation(configuration: config)
        conversation.addUserMessage("do it")

        let text = try await conversation.continueConversation(
            using: .anthropic(.fable5),
            tools: [sideEffectTool],
            maxSteps: 2,
        )

        #expect(text.isEmpty)
        let messages = conversation.getModelMessages()
        #expect(messages.map(\.role) == [.user, .assistant, .tool])
        #expect(messages[0].content == [.text("do it")])
        #expect(messages[1].content.contains { part in
            if case let .toolCall(toolCall) = part {
                return toolCall.id == "call-1"
            }
            return false
        })
        #expect(messages[2].content.contains { part in
            if case let .toolResult(toolResult) = part {
                return toolResult.toolCallId == "call-1"
            }
            return false
        })
    }

    @Test
    func `Agent stream rejects non-streaming model before mutating conversation`() async throws {
        let agent = Agent(
            name: "test",
            instructions: "test",
            model: .anthropic(.fable5),
            context: (),
        )

        await #expect(throws: TachikomaError.self) {
            _ = try await agent.stream("hi")
        }

        #expect(agent.conversation.messages.map(\.content) == ["test"])
    }

    @Test
    func `Conversation streaming rolls back refused trailing user turn`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            MinimalStreamingProvider(deltas: [
                .text("partial"),
                .done(finishReason: .contentFilter),
            ])
        }
        let conversation = Conversation(configuration: config)
        conversation.addUserMessage("blocked")

        let stream = try await conversation.continueConversationStreaming(using: .openai(.gpt55))
        var received = ""
        for try await chunk in stream {
            received += chunk
        }

        #expect(received == "partial")
        #expect(conversation.messages.isEmpty)
    }

    @Test
    func `Conversation streaming flushes buffered text on natural completion`() async throws {
        let provider = MinimalStreamingProvider(deltas: [
            .text("ok"),
        ])
        let conversation = Conversation(configuration: TachikomaConfiguration(loadFromEnvironment: false))

        let stream = try await conversation.continueConversationStreaming(using: .custom(provider: provider))
        var received = ""
        for try await chunk in stream {
            received += chunk
        }

        #expect(received == "ok")
        #expect(conversation.messages.map(\.content) == ["ok"])
    }

    @Test
    func `Conversation streaming flushes buffered compatible text when done has no finish reason`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            MinimalStreamingProvider(deltas: [
                .text("ok"),
                .done(),
            ])
        }
        let conversation = Conversation(configuration: config)

        let stream = try await conversation.continueConversationStreaming(
            using: .openaiCompatible(modelId: "gpt-compatible", baseURL: "https://example.test"),
        )
        var received = ""
        for try await chunk in stream {
            received += chunk
        }

        #expect(received == "ok")
        #expect(conversation.messages.map(\.content) == ["ok"])
    }

    @Test
    func `Conversation streaming flushes compatible text when stream ends without done`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            MinimalStreamingProvider(deltas: [
                .text("partial"),
            ])
        }
        let conversation = Conversation(configuration: config)

        let stream = try await conversation.continueConversationStreaming(
            using: .openaiCompatible(modelId: "gpt-compatible", baseURL: "https://example.test"),
        )

        var received = ""
        for try await chunk in stream {
            received += chunk
        }

        #expect(received == "partial")
        #expect(conversation.messages.map(\.content) == ["partial"])
    }
}

@Suite(.serialized)
private struct AgentRefusalTests {
    @Test
    func `Agent execute rolls back refused user turn`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            MinimalStaticProvider(response: ProviderResponse(text: "Refused by policy", finishReason: .contentFilter))
        }

        let agent = Agent(
            name: "test",
            instructions: "test",
            model: .anthropic(.fable5),
            configuration: config,
            context: (),
        )

        let response = try await agent.execute("blocked")

        #expect(response.text.isEmpty)
        #expect(response.finishReason == .contentFilter)
        #expect(agent.conversation.messages.map(\.content) == ["test"])
    }

    @Test
    func `Agent stream stays incremental by default when terminal content filter arrives`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            MinimalStreamingProvider(deltas: [
                .text("partial"),
                .done(finishReason: .contentFilter),
            ])
        }

        let agent = Agent(
            name: "test",
            instructions: "test",
            model: .openai(.gpt55),
            configuration: config,
            context: (),
        )

        let stream = try await agent.stream("blocked")
        var received: [TextStreamDelta] = []
        for try await delta in stream {
            received.append(delta)
        }

        #expect(received.contains { $0.type == .textDelta && $0.content == "partial" })
        #expect(received.contains { $0.type == .done && $0.finishReason == .contentFilter })
        #expect(agent.conversation.messages.map(\.content) == ["test"])
    }

    @Test
    func `Agent stream explicit terminal buffering errors when stream ends without done`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            MinimalStreamingProvider(deltas: [
                .text("partial"),
            ])
        }

        let agent = Agent(
            name: "test",
            instructions: "test",
            model: .openaiCompatible(modelId: "gpt-compatible", baseURL: "https://example.test"),
            settings: GenerationSettings(streamBuffering: .untilTerminal),
            configuration: config,
            context: (),
        )

        let stream = try await agent.stream("hi")
        do {
            for try await _ in stream {}
            Issue.record("Expected missing terminal status error")
        } catch let error as TachikomaError {
            guard case let .apiError(message) = error else {
                Issue.record("Expected apiError, got \(error)")
                return
            }
            #expect(message.contains("completion status"))
        }

        #expect(!agent.conversation.messages.map(\.content).contains("partial"))
    }

    @Test
    func `Agent stream explicit terminal buffering suppresses Azure OpenAI refusals`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            MinimalStreamingProvider(deltas: [
                .text("partial"),
                .done(finishReason: .contentFilter),
            ])
        }

        let agent = Agent(
            name: "test",
            instructions: "test",
            model: .azureOpenAI(deployment: "gpt-compatible", endpoint: "https://example.openai.azure.com"),
            settings: GenerationSettings(streamBuffering: .untilTerminal),
            configuration: config,
            context: (),
        )

        let stream = try await agent.stream("blocked")
        var received: [TextStreamDelta] = []
        for try await delta in stream {
            received.append(delta)
        }

        #expect(!received.contains { $0.type == .textDelta && $0.content == "partial" })
        #expect(received.contains { $0.type == .done && $0.finishReason == .contentFilter })
        #expect(agent.conversation.messages.map(\.content) == ["test"])
    }

    @Test
    func `Agent stream explicit terminal buffering suppresses Google refusals`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            MinimalStreamingProvider(deltas: [
                .text("partial"),
                .done(finishReason: .contentFilter),
            ])
        }

        let agent = Agent(
            name: "test",
            instructions: "test",
            model: .google(.gemini25Flash),
            settings: GenerationSettings(streamBuffering: .untilTerminal),
            configuration: config,
            context: (),
        )

        let stream = try await agent.stream("blocked")
        var received: [TextStreamDelta] = []
        for try await delta in stream {
            received.append(delta)
        }

        #expect(!received.contains { $0.type == .textDelta && $0.content == "partial" })
        #expect(received.contains { $0.type == .done && $0.finishReason == .contentFilter })
        #expect(agent.conversation.messages.map(\.content) == ["test"])
    }

    @Test
    func `Agent stream explicit terminal buffering suppresses registered custom OpenAI refusals`() async throws {
        try await self.withRegisteredCustomProvider(
            """
            {
              "customProviders": {
                "proxy": {
                  "type": "openai",
                  "options": { "baseURL": "https://example.test/v1" }
                }
              }
            }
            """,
        ) {
            let config = TachikomaConfiguration(loadFromEnvironment: false)
            config.setProviderFactoryOverride { _, _ in
                MinimalStreamingProvider(
                    modelId: "proxy/gpt-compatible",
                    deltas: [
                        .text("partial"),
                        .done(finishReason: .contentFilter),
                    ],
                )
            }

            let agent = Agent(
                name: "test",
                instructions: "test",
                model: .custom(provider: MinimalStreamingProvider(modelId: "proxy/gpt-compatible", deltas: [])),
                settings: GenerationSettings(streamBuffering: .untilTerminal),
                configuration: config,
                context: (),
            )

            let stream = try await agent.stream("blocked")
            var received: [TextStreamDelta] = []
            for try await delta in stream {
                received.append(delta)
            }

            #expect(!received.contains { $0.type == .textDelta && $0.content == "partial" })
            #expect(received.contains { $0.type == .done && $0.finishReason == .contentFilter })
            #expect(agent.conversation.messages.map(\.content) == ["test"])
        }
    }

    @Test
    func `Agent stream releases continuation gate when consumer stops early`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StallingStreamingProvider()
        }
        let agent = Agent(
            name: "test",
            instructions: "test",
            model: .custom(provider: StallingStreamingProvider()),
            configuration: config,
            context: (),
        )

        do {
            let stream = try await agent.stream("first")
            var iterator = stream.makeAsyncIterator()
            let firstDelta = try await iterator.next()
            #expect(firstDelta?.type == .textDelta)
            #expect(firstDelta?.content == "partial")
        }
        try await Task.sleep(nanoseconds: 10_000_000)

        let response = try await withTimeout(0.2) {
            try await agent.execute("second")
        }
        #expect(response.text == "after")
    }

    @Test
    func `Agent execute preserves completed tool history after late refusal`() async throws {
        let provider = MinimalSequenceProvider(responses: [
            ProviderResponse(
                text: "",
                finishReason: .toolCalls,
                toolCalls: [AgentToolCall(id: "call-1", name: "side_effect", arguments: [:])],
            ),
            ProviderResponse(text: "Refused by policy", finishReason: .contentFilter),
        ])
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in provider }

        let agent = Agent(
            name: "test",
            instructions: "test",
            model: .anthropic(.fable5),
            tools: [sideEffectTool],
            configuration: config,
            context: (),
        )

        let response = try await agent.execute("do it")

        #expect(response.text.isEmpty)
        #expect(response.finishReason == .contentFilter)
        let messages = agent.conversation.getModelMessages()
        #expect(messages.map(\.role) == [.system, .user, .assistant, .tool])
        #expect(messages[1].content == [.text("do it")])
        #expect(messages[2].content.contains { part in
            if case let .toolCall(toolCall) = part {
                return toolCall.id == "call-1"
            }
            return false
        })
        #expect(messages[3].content.contains { part in
            if case let .toolResult(toolResult) = part {
                return toolResult.toolCallId == "call-1"
            }
            return false
        })
    }

    private func withRegisteredCustomProvider(
        _ configJSON: String,
        operation: () async throws -> Void,
    ) async throws {
        let originalProfile = TachikomaConfiguration.profileDirectoryName
        let tempProfile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let emptyProfile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempProfile, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: emptyProfile, withIntermediateDirectories: true)
        try configJSON.write(to: tempProfile.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        try #"{"customProviders":{}}"#.write(
            to: emptyProfile.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8,
        )

        TachikomaConfiguration.profileDirectoryName = tempProfile.path
        CustomProviderRegistry.shared.loadFromProfile()

        do {
            try await operation()
            TachikomaConfiguration.profileDirectoryName = emptyProfile.path
            CustomProviderRegistry.shared.loadFromProfile()
            TachikomaConfiguration.profileDirectoryName = originalProfile
        } catch {
            TachikomaConfiguration.profileDirectoryName = emptyProfile.path
            CustomProviderRegistry.shared.loadFromProfile()
            TachikomaConfiguration.profileDirectoryName = originalProfile
            throw error
        }
    }
}

private struct StallingStreamingProvider: ModelProvider {
    let modelId = "stalling-streaming"
    let baseURL: String? = nil
    let apiKey: String? = nil
    let capabilities = ModelCapabilities(supportsStreaming: true)

    func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
        ProviderResponse(text: "after")
    }

    func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.text("partial"))
        }
    }
}

private actor ConversationLockProbe {
    var secondRan = false
    var thirdRan = false
    private var firstStarted = false
    private var firstStartedWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func markFirstStarted() {
        self.firstStarted = true
        let waiters = self.firstStartedWaiters
        self.firstStartedWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    func waitUntilFirstStarted() async {
        if self.firstStarted {
            return
        }

        await withCheckedContinuation { continuation in
            self.firstStartedWaiters.append(continuation)
        }
    }

    func waitForRelease() async {
        await withCheckedContinuation { continuation in
            self.releaseWaiters.append(continuation)
        }
    }

    func releaseFirst() {
        let waiters = self.releaseWaiters
        self.releaseWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    func markSecondRan() {
        self.secondRan = true
    }

    func markThirdRan() {
        self.thirdRan = true
    }
}

private final class MinimalModelBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _model: LanguageModel?

    var model: LanguageModel? {
        get {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self._model
        }
        set {
            self.lock.lock()
            self._model = newValue
            self.lock.unlock()
        }
    }
}

private struct MinimalStaticProvider: ModelProvider {
    let modelId = "minimal-static"
    let baseURL: String? = nil
    let apiKey: String? = nil
    let capabilities = ModelCapabilities()
    let response: ProviderResponse

    func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
        self.response
    }

    func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

private struct MinimalStreamingProvider: ModelProvider {
    let modelId: String
    let baseURL: String? = nil
    let apiKey: String? = nil
    let capabilities = ModelCapabilities(supportsStreaming: true)
    let deltas: [TextStreamDelta]

    init(modelId: String = "minimal-streaming", deltas: [TextStreamDelta]) {
        self.modelId = modelId
        self.deltas = deltas
    }

    func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
        ProviderResponse(text: "")
    }

    func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, any Error> {
        AsyncThrowingStream { continuation in
            for delta in self.deltas {
                continuation.yield(delta)
            }
            continuation.finish()
        }
    }
}

private struct MinimalSequenceProvider: ModelProvider {
    let modelId = "minimal-sequence"
    let baseURL: String? = nil
    let apiKey: String? = nil
    let capabilities = ModelCapabilities()
    private let queue: MinimalResponseQueue

    init(responses: [ProviderResponse]) {
        self.queue = MinimalResponseQueue(responses: responses)
    }

    func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
        self.queue.next()
    }

    func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

private final class MinimalResponseQueue: @unchecked Sendable {
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

private let sideEffectTool = Tachikoma.createTool(
    name: "side_effect",
    description: "Records an external action",
    parameters: [],
    required: [],
) { _ in
    AnyAgentToolValue(string: "done")
}
