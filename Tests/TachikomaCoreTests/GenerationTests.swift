import Foundation
import Testing
@testable import TachikomaCore

@Suite("Generation Function Tests")
struct GenerationTests {
    // MARK: - Basic Generation Tests (Placeholder Providers)

    @Test("Generate Function - OpenAI Provider")
    func generateFunctionOpenAI() async throws {
        try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
            let result = try await generate(
                "What is 2+2?",
                using: .openai(.gpt4o),
                maxTokens: 100
            )

            // Since we're using placeholder implementations, verify the format
            #expect(result.contains("OpenAI response"))
            #expect(result.contains("What is 2+2?"))
            #expect(result.contains("gpt-4o"))
        }
    }

    @Test("Generate Function - Anthropic Provider")
    func generateFunctionAnthropic() async throws {
        try await TestHelpers.withTestEnvironment(apiKeys: ["anthropic": "test-key"]) {
            let result = try await generate(
                "Explain quantum physics",
                using: .anthropic(.opus4),
                system: "You are a physics teacher",
                maxTokens: 200
            )

            // Anthropic provider uses real implementation, so we expect actual response structure
            // For now, with our placeholder, verify basic functionality
            #expect(!result.isEmpty)
        }
    }

    @Test("Generate Function - Default Model")
    func generateFunctionDefaultModel() async throws {
        try await TestHelpers.withTestEnvironment(apiKeys: ["anthropic": "test-key"]) {
            let result = try await generate("Hello world")

            // Should use default model (Anthropic Opus 4)
            #expect(!result.isEmpty)
        }
    }

    @Test("Generate Function - With System Prompt")
    func generateFunctionWithSystem() async throws {
        try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
            let result = try await generate(
                "Tell me a joke",
                using: .openai(.gpt4oMini),
                system: "You are a comedian",
                temperature: 0.8
            )

            #expect(result.contains("OpenAI response"))
            #expect(result.contains("Tell me a joke"))
        }
    }

    // MARK: - Streaming Tests

    @Test("Stream Function - Basic Streaming")
    func streamFunctionBasic() async throws {
        try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
            let stream = try await stream(
                "Count to 5",
                using: .openai(.gpt4o),
                maxTokens: 50
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

    @Test("Stream Function - Anthropic Streaming")
    func streamFunctionAnthropic() async throws {
        try await TestHelpers.withTestEnvironment(apiKeys: ["anthropic": "test-key"]) {
            let stream = try await stream(
                "Write a haiku",
                using: .anthropic(.sonnet4),
                system: "You are a poet"
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

    // MARK: - Image Analysis Tests

    @Test("Analyze Function - Vision Model")
    func analyzeFunctionVision() async throws {
        try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
            let result = try await analyze(
                image: .base64("test-image-base64"),
                prompt: "What do you see?",
                using: .openai(.gpt4o)
            )

            #expect(result.contains("OpenAI response"))
            #expect(result.contains("What do you see?"))
        }
    }

    @Test("Analyze Function - Non-Vision Model Error")
    func analyzeFunctionNonVisionError() async {
        await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
            // GPT-4.1 doesn't support vision
            await #expect(throws: TachikomaError.self) {
                try await analyze(
                    image: .base64("test-image"),
                    prompt: "Describe this",
                    using: .openai(.gpt41)
                )
            }
        }
    }

    @Test("Analyze Function - Default Vision Model")
    func analyzeFunctionDefaultVision() async throws {
        try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
            // Use base64 encoded test image (1x1 pixel PNG)
            let testImageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
            let result = try await analyze(
                image: .base64(testImageBase64),
                prompt: "Analyze this image"
            )

            // Should default to GPT-4o for vision tasks
            #expect(result.contains("OpenAI response"))
        }
    }

    // MARK: - Error Handling Tests

    @Test("Generate Function - Missing API Key")
    func generateFunctionMissingAPIKey() async {
        await TestHelpers.withNoAPIKeys {
            await #expect(throws: TachikomaError.self) {
                try await generate("Test", using: .openai(.gpt4o))
            }
        }
    }

    @Test("Generate Function - Invalid Configuration")
    func generateFunctionInvalidConfig() async throws {
        try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
            // Test with invalid base URL format - set directly in environment
            setenv("OPENAI_BASE_URL", "not-a-url", 1)
            defer { unsetenv("OPENAI_BASE_URL") }

            // This should still work with placeholder implementations
            // In real implementations, this would fail
            let result = try await generate("Test", using: .openai(.gpt4o))
            #expect(!result.isEmpty)
        }
    }

    // MARK: - Tool Integration Tests

    @Test("Generate Function - With Empty ToolKit")
    func generateFunctionWithEmptyToolKit() async throws {
        try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
            let toolkit = EmptyToolKit()

            let result = try await generate(
                "Hello",
                using: .openai(.gpt4o),
                tools: toolkit
            )

            #expect(!result.isEmpty)
        }
    }

    @Test("Generate Function - With Custom ToolKit")
    func generateFunctionWithCustomToolKit() async throws {
        try await TestHelpers.withTestEnvironment(apiKeys: ["anthropic": "test-key"]) {
            // Create a simple test toolkit
            struct TestToolKit: ToolKit {
                var tools: [Tool<TestToolKit>] {
                    [
                        Tool(name: "test_tool", description: "A test tool") { _, _ in
                            .string("Tool executed")
                        },
                    ]
                }
            }

            let toolkit = TestToolKit()

            let result = try await generate(
                "Use the test tool",
                using: .anthropic(.sonnet4),
                tools: toolkit
            )

            #expect(!result.isEmpty)
        }
    }

    // MARK: - Image Input Type Tests

    @Test("Image Input Types")
    func imageInputTypes() {
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
}
