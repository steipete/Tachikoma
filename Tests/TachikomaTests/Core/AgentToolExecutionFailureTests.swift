import Testing
@testable import Tachikoma

struct AgentToolExecutionFailureTests {
    @Test
    func `GenerateText preserves typed tool failures`() async throws {
        let call = AgentToolCall(id: "call-failure", name: "failing_tool", arguments: [:])
        let providerResponse = ProviderResponse(
            text: "",
            finishReason: .toolCalls,
            toolCalls: [call],
            assistantMessages: [ModelMessage(role: .assistant, content: [.toolCall(call)])],
        )
        let configuration = TachikomaConfiguration(loadFromEnvironment: false)
        configuration.setProviderFactoryOverride { _, _ in FailureProvider(response: providerResponse) }
        let failure = AgentToolExecutionFailure(
            message: "Background action denied",
            content: [AnyAgentToolValue(string: "Background action denied")],
            structuredValue: AnyAgentToolValue(object: ["code": AnyAgentToolValue(string: "denied")]),
            metadata: AnyAgentToolValue(object: ["retrySafe": AnyAgentToolValue(bool: false)]),
        )
        let tool = AgentTool(
            name: "failing_tool",
            description: "Fail with structured context",
            parameters: AgentToolParameters(),
        ) { _ in
            throw failure
        }

        let result = try await generateText(
            model: .openai(.gpt55),
            messages: [.user("run")],
            tools: [tool],
            maxSteps: 1,
            configuration: configuration,
        )

        let toolResult = try #require(result.steps.first?.toolResults.first)
        #expect(toolResult.isError == true)
        #expect(toolResult.failure == failure)
        #expect(toolResult.result == failure.resultValue)
        #expect(result.messages.contains { message in
            message.content.contains { part in
                if case let .toolResult(messageResult) = part {
                    return messageResult == toolResult
                }
                return false
            }
        })
    }
}

private struct FailureProvider: ModelProvider {
    let response: ProviderResponse
    let modelId = "failure-provider"
    let baseURL: String? = nil
    let apiKey: String? = nil
    let capabilities = ModelCapabilities()

    func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
        self.response
    }

    func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
