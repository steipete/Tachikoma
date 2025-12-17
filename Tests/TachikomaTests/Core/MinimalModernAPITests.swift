import Foundation
import Testing
@testable import Tachikoma
@testable import TachikomaAgent

@Suite("Minimal Modern API Tests")
struct MinimalModernAPITests {
    // MARK: - Model Tests

    @Test("Model enum construction")
    func modelEnumConstruction() {
        // Test that model enums can be constructed
        let openaiModel = Model.openai(.gpt4o)
        let anthropicModel = Model.anthropic(.opus45)
        _ = Model.grok(.grok4)
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

    @Test("Model default value")
    func modelDefaultValue() {
        let defaultModel = Model.default
        // Should compile without errors
        switch defaultModel {
        case .anthropic(.opus45):
            break // Expected default
        default:
            Issue.record("Expected default to be Anthropic Opus 4.5")
        }
    }

    // MARK: - Tool System Tests

    @Test("AgentTool creation")
    func agentToolCreation() {
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

    @Test("AgentToolArguments parsing")
    func agentToolArgumentsParsing() throws {
        let args = AgentToolArguments([
            "name": AnyAgentToolValue(string: "test"),
            "value": AnyAgentToolValue(int: 42),
        ])

        #expect(try args.stringValue("name") == "test")
        #expect(try args.integerValue("value") == 42)
        #expect(args.optionalStringValue("missing") == nil)
        #expect(args.optionalStringValue("missing") ?? "default" == "default")
    }

    @Test("Built-in tools exist")
    func builtInToolsExist() {
        // Test that built-in tools are available
        #expect(weatherTool.name == "get_weather")
        #expect(timeTool.name == "get_current_time")
        #expect(calculatorTool.name == "calculate")
    }
}

// MARK: - Additional Test Code

extension MinimalModernAPITests {
    // MARK: - Error Types

    @Test("Tool error types")
    func toolErrorTypes() {
        let toolError = AgentToolError.invalidInput("test")
        #expect(toolError.errorDescription != nil)

        let tachikomaError = TachikomaError.modelNotFound("test")
        #expect(tachikomaError.errorDescription != nil)
    }

    // MARK: - Conversation Tests

    @Test("Conversation basic functionality")
    func conversationBasic() {
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

    @Test("ConversationMessage basic properties")
    func conversationMessageBasic() {
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
}
