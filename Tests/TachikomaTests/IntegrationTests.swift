import Foundation
import Testing
@testable import Tachikoma
@testable import TachikomaAgent

@Suite("Integration Tests")
struct IntegrationTests {
    @Test("End-to-end UI message flow with streaming")
    func uIMessageFlowWithStreaming() async throws {
        // Create UI messages
        let uiMessages = [
            UIMessage(role: .system, content: "You are a helpful assistant"),
            UIMessage(role: .user, content: "What is 2+2?"),
        ]

        // Convert to model messages
        let modelMessages = uiMessages.toModelMessages()
        #expect(modelMessages.count == 2)

        // Create a mock stream response
        let textStream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                continuation.yield(TextStreamDelta(type: .textDelta, content: "The answer "))
                continuation.yield(TextStreamDelta(type: .textDelta, content: "is "))
                continuation.yield(TextStreamDelta(type: .textDelta, content: "4"))
                continuation.yield(TextStreamDelta(type: .done, content: nil))
                continuation.finish()
            }
        }

        let streamResult = StreamTextResult(
            stream: textStream,
            model: .openai(.gpt4o),
            settings: .default,
        )

        // Convert to UI stream
        let uiStream = streamResult.toUIMessageStream()

        // Collect the response
        let response = UIStreamResponse(stream: uiStream)
        let assistantMessage = await response.collectMessage()

        #expect(assistantMessage.role == .assistant)
        #expect(assistantMessage.content == "The answer is 4")
    }

    @Test("Tool execution with simplified builder and error handling")
    func toolExecutionWithErrorHandling() async throws {
        struct MathInput: Codable, Sendable {
            let operation: String
            let a: Double
            let b: Double
        }

        struct MathOutput: Codable, Sendable {
            let result: Double
        }

        // Create tool with simplified builder
        let calculator = SimplifiedToolBuilder.tool(
            "math",
            description: "Perform mathematical operations",
            inputSchema: MathInput.self,
        ) { (input: MathInput) async throws -> MathOutput in
            let result: Double
            switch input.operation {
            case "+": result = input.a + input.b
            case "-": result = input.a - input.b
            case "*": result = input.a * input.b
            case "/":
                if input.b == 0 {
                    throw AgentToolError.invalidInput("Division by zero")
                }
                result = input.a / input.b
            default:
                throw AgentToolError.invalidInput("Unknown operation: \(input.operation)")
            }
            return MathOutput(result: result)
        }

        // Test successful execution
        let args1 = AgentToolArguments([
            "operation": "+",
            "a": 10.0,
            "b": 5.0,
        ])

        let context = ToolExecutionContext()
        let result1 = try await calculator.execute(args1, context: context)
        if
            let obj = result1.objectValue,
            let resultValue = obj["result"]?.doubleValue
        {
            #expect(resultValue == 15.0)
        } else {
            Issue.record("Expected result in object")
        }

        // Test error handling
        let args2 = AgentToolArguments([
            "operation": "/",
            "a": 10.0,
            "b": 0.0,
        ])

        do {
            let context = ToolExecutionContext()
            _ = try await calculator.execute(args2, context: context)
            Issue.record("Should have thrown division by zero error")
        } catch let error as AgentToolError {
            let unifiedError = error.toUnifiedError()
            #expect(unifiedError.code == .invalidParameter)
            #expect(unifiedError.message.contains("Division by zero"))
        }
    }

    @Test("Async operations with timeout and cancellation")
    func asyncOperationsWithTimeoutAndCancellation() async throws {
        let token = CancellationToken()

        let task = Task {
            try await retryWithCancellation(
                configuration: .init(
                    maxAttempts: 1,
                    delay: 0.1,
                    timeout: nil,
                ),
                cancellationToken: token,
            ) {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                try Task.checkCancellation()
                return "Success"
            }
        }

        try await Task.sleep(nanoseconds: 200_000_000) // allow task to start
        await token.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
        #expect(await token.cancelled)
    }

    @Test("Provider with feature parity and caching")
    func providerWithFeatureParityAndCaching() async throws {
        // Create a mock provider with limited capabilities
        struct LimitedProvider: ModelProvider {
            let modelId = "limited-model"
            let baseURL: String? = nil
            let apiKey: String? = nil
            let capabilities = ModelCapabilities(
                supportsVision: false,
                supportsTools: false,
                supportsStreaming: false,
                contextLength: 8192,
                maxOutputTokens: 2048,
            )

            func generateText(request: ProviderRequest) async throws -> ProviderResponse {
                ProviderResponse(
                    text: {
                        if case let .text(text) = request.messages.last?.content.first {
                            return "Response for: \(text)"
                        }
                        return "Response"
                    }(),
                    usage: Usage(inputTokens: 10, outputTokens: 20),
                    finishReason: .stop,
                    toolCalls: nil,
                )
            }

            func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
                throw TachikomaError.unsupportedOperation("Streaming not supported")
            }
        }

        // Wrap with feature parity
        let provider = LimitedProvider()
        let adapter = ProviderAdapter(
            provider: provider,
            configuration: ProviderConfiguration(
                maxTokens: 2048,
                maxContextLength: 8192,
                supportsSystemRole: false,
            ),
        )

        // Test that system messages are transformed
        let messages = [
            ModelMessage.system("Be helpful"),
            ModelMessage.user("Hello"),
        ]

        let validated = try adapter.validateMessages(messages)
        #expect(validated[0].role == .user) // System message converted

        // Add caching
        let cache = ResponseCache(configuration: .aggressive)
        let cached = await cache.wrapProvider(adapter)

        let request = ProviderRequest(
            messages: [.user("Test message")],
            settings: .default,
        )

        // First call - cache miss
        let response1 = try await cached.generateText(request: request)
        #expect(response1.text.contains("Test message"))

        // Second call - should be cached
        let response2 = try await cached.generateText(request: request)
        #expect(response2.text == response1.text)

        // Stats should show hit
        let stats = await cache.getStatistics()
        #expect(stats.hits >= 1)
    }

    @Test("Complete tool workflow with context and error recovery")
    func completeToolWorkflow() async throws {
        // Create a contextual tool
        let searchTool = AgentTool.createWithContext(
            name: "contextual_search",
            description: "Search with conversation context",
            schema: { builder in
                builder
                    .string("query", description: "Search query", required: true)
                    .integer("limit", description: "Result limit")
            },
            execute: { args, context async throws -> AnyAgentToolValue in
                let query = try args.stringValue("query")
                let limit = args.optionalIntegerValue("limit") ?? 10
                let contextLength = context.messages.count

                // Simulate search with context awareness
                let results = (1...min(limit, 3)).map { i in
                    "Result \(i) for '\(query)' (context: \(contextLength) messages)"
                }

                return try AnyAgentToolValue.fromJSON([
                    "query": query,
                    "results": results,
                    "sessionId": context.sessionId,
                ])
            },
        )

        // Execute with context
        let context = ToolExecutionContext(
            messages: [
                .system("You are a search assistant"),
                .user("Find information about Swift"),
            ],
            sessionId: "test-session-123",
        )

        let args = AgentToolArguments([
            "query": "Swift programming",
            "limit": 5,
        ])

        let result = try await searchTool.execute(args, context: context)

        // Verify results
        if let obj = result.objectValue {
            #expect(obj["query"]?.stringValue == "Swift programming")
            #expect(obj["sessionId"]?.stringValue == "test-session-123")

            if let results = obj["results"]?.arrayValue {
                #expect(results.count == 3) // Limited to 3 even though we asked for 5
                #expect(results[0].stringValue?.contains("context: 2 messages") == true)
            }
        } else {
            Issue.record("Expected object result")
        }
    }
}
