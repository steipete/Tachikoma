import Foundation
import Testing
@testable import Tachikoma
@testable import Tachikoma

@Suite("Minimal Modern API Tests")
struct MinimalModernAPITests {
    // MARK: - Model Tests

    @Test("Model enum construction")
    func modelEnumConstruction() {
        // Test that model enums can be constructed
        let openaiModel = Model.openai(.gpt4o)
        let anthropicModel = Model.anthropic(.opus4)
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
            description: "A test tool"
        ) { _, _ in
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
        #expect(toolkit.tools.contains { $0.name == "get_weather" })
    }

    @Test("MathToolKit basic structure")
    func mathToolKitStructure() {
        let toolkit = MathToolKit()
        #expect(toolkit.tools.count == 2)
        #expect(toolkit.tools.contains { $0.name == "calculate" })
    }
}

// MARK: - Test ToolKit Implementations

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct WeatherToolKit: ToolKit {
    var tools: [Tool<WeatherToolKit>] {
        [
            createTool(name: "get_weather", description: "Get current weather") { input, context in
                let location = try input.stringValue("location")
                return "Weather in \(location): 72°F, sunny"
            },
            createTool(name: "get_forecast", description: "Get weather forecast") { input, context in
                let location = try input.stringValue("location")
                return "Forecast for \(location): sunny week ahead"
            }
        ]
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct MathToolKit: ToolKit {
    var tools: [Tool<MathToolKit>] {
        [
            createTool(name: "calculate", description: "Perform calculations") { input, context in
                let _ = try input.stringValue("expression")
                return "Result: 42"
            },
            createTool(name: "square", description: "Calculate square") { input, context in
                let number = try input.intValue("number")
                return "Square of \(number): \(number * number)"
            }
        ]
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
            timestamp: Date()
        )

        #expect(message.id == "test")
        #expect(message.role == .user)
        #expect(message.content == "Test")
    }
}
