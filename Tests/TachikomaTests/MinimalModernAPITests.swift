import Foundation
import Testing
@testable import TachikomaBuilders
@testable import TachikomaCore

@Suite("Minimal Modern API Tests")
struct MinimalModernAPITests {
    // MARK: - Model Tests

    @Test("Model enum construction")
    func modelEnumConstruction() {
        // Test that model enums can be constructed
        let openaiModel = Model.openai(.gpt4o)
        let anthropicModel = Model.anthropic(.opus4)
        let _ = Model.grok(.grok4)
        let _ = Model.ollama(.llama3_3)

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
        case .anthropic(.opus4):
            break // Expected default
        default:
            Issue.record("Expected default to be Anthropic Opus 4")
        }
    }

    // MARK: - Tool System Tests

    @Test("Tool creation")
    func toolCreation() {
        let tool = Tool<String>(
            name: "test_tool",
            description: "A test tool")
        { _, _ in
            .string("Tool executed")
        }

        #expect(tool.name == "test_tool")
        #expect(tool.description == "A test tool")
    }

    @Test("ToolInput JSON parsing basic")
    func toolInputBasic() throws {
        let input = try ToolInput(jsonString: "{\"name\": \"test\"}")
        #expect(try input.stringValue("name") == "test")

        let emptyInput = try ToolInput(jsonString: "{}")
        #expect(emptyInput.stringValue("missing", default: "default") == "default")
    }

    @Test("ToolOutput basic functionality")
    func toolOutputBasic() throws {
        let output = ToolOutput.string("Hello")
        #expect(try output.toJSONString() == "Hello")

        let errorOutput = ToolOutput.error(message: "Error")
        #expect(try errorOutput.toJSONString() == "Error: Error")
    }

    // MARK: - Empty ToolKit

    @Test("EmptyToolKit")
    func emptyToolKit() {
        let toolkit = EmptyToolKit()
        #expect(toolkit.tools.isEmpty)
    }

    // MARK: - Example ToolKits

    @Test("WeatherToolKit basic structure")
    func weatherToolKitStructure() {
        let toolkit = WeatherToolKit()
        #expect(toolkit.tools.count == 2)
        #expect(toolkit.toolNames.count == 2)
        #expect(toolkit.hasTool(named: "get_weather"))
    }

    @Test("MathToolKit basic structure")
    func mathToolKitStructure() {
        let toolkit = MathToolKit()
        #expect(toolkit.tools.count == 2)
        #expect(toolkit.hasTool(named: "calculate"))
    }

    // MARK: - Error Types

    @Test("Tool error types")
    func toolErrorTypes() {
        let toolError = ToolError.invalidInput("test")
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
            timestamp: Date())

        #expect(message.id == "test")
        #expect(message.role == .user)
        #expect(message.content == "Test")
    }
}
