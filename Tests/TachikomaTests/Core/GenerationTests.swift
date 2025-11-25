import Foundation
import Testing
@testable import Tachikoma

@Suite("Generation Function Tests")
struct GenerationTests {
    // MARK: - Basic Generation Tests (Placeholder Providers)

    @Test("Generate Function - OpenAI Provider")
    func generateFunctionOpenAI() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            let result = try await generate(
                "What is 2+2?",
                using: .openai(.gpt4o),
                maxTokens: 100,
                configuration: config,
            )

            self.assertOpenAIResult(
                result,
                prompt: "What is 2+2?",
                modelId: "gpt-4o",
                configuration: config,
            )
        }
    }

    @Test("Generate Function - Anthropic Provider")
    func generateFunctionAnthropic() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["anthropic": "test-key"]) { config in
            let result = try await generate(
                "Explain quantum physics",
                using: .anthropic(.sonnet4),
                system: "You are a physics teacher",
                maxTokens: 200,
                configuration: config,
            )

            // Anthropic provider uses real implementation, so we expect actual response structure
            // For now, with our placeholder, verify basic functionality
            #expect(!result.isEmpty)
        }
    }

    @Test("Generate Function - Default Model")
    func generateFunctionDefaultModel() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["anthropic": "test-key"]) { config in
            let result = try await generate("Hello world", configuration: config)

            // Should use default model (Anthropic Opus 4)
            #expect(!result.isEmpty)
        }
    }

    @Test("Generate Function - With System Prompt")
    func generateFunctionWithSystem() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            let result = try await generate(
                "Tell me a joke",
                using: .openai(.gpt4oMini),
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

    @Test("Stream Function - Basic Streaming")
    func streamFunctionBasic() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            let stream = try await stream(
                "Count to 5",
                using: .openai(.gpt4o),
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

    @Test("Stream Function - Anthropic Streaming")
    func streamFunctionAnthropic() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["anthropic": "test-key"]) { config in
            let stream = try await stream(
                "Write a haiku",
                using: .anthropic(.sonnet4),
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

    // MARK: - Image Analysis Tests

    @Test("Analyze Function - Vision Model")
    func analyzeFunctionVision() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            let testImageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
            let result = try await analyze(
                image: .base64(testImageBase64),
                prompt: "What do you see?",
                using: .openai(.gpt4o),
                configuration: config,
            )

            self.assertOpenAIResult(
                result,
                prompt: "What do you see?",
                configuration: config,
            )
        }
    }

    @Test("Analyze Function - Non-Vision Model Error")
    func analyzeFunctionNonVisionError() async {
        _ = await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            // GPT-4.1 doesn't support vision
            await #expect(throws: TachikomaError.self) {
                try await analyze(
                    image: .base64("test-image"),
                    prompt: "Describe this",
                    using: .openai(.gpt41),
                    configuration: config,
                )
            }
        }
    }

    @Test("Analyze Function - Default Vision Model")
    func analyzeFunctionDefaultVision() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            // Use base64 encoded test image (1x1 pixel PNG)
            let testImageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
            let result = try await analyze(
                image: .base64(testImageBase64),
                prompt: "Analyze this image",
                configuration: config,
            )

            // Should default to GPT-4o for vision tasks
            self.assertOpenAIResult(
                result,
                prompt: "Analyze this image",
                configuration: config,
            )
        }
    }

    // MARK: - Error Handling Tests

    @Test("Generate Function - Missing API Key")
    func generateFunctionMissingAPIKey() async {
        _ = await TestHelpers.withEmptyTestConfiguration { config in
            await #expect(throws: TachikomaError.self) {
                try await generate("Test", using: .openai(.gpt4o), configuration: config)
            }
        }
    }

    @Test("Generate Function - Invalid Configuration")
    func generateFunctionInvalidConfig() async throws {
        await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            // Test with invalid base URL format
            config.setBaseURL("not-a-url", for: .openai)

            // With mock provider (test-key), this should work even with invalid URL
            // Real implementations would fail with network error
            do {
                let result = try await generate("Test", using: .openai(.gpt4o), configuration: config)
                #expect(!result.isEmpty)
            } catch {
                // If using real provider, invalid URL will cause network error
                // This is expected behavior
                #expect(error is TachikomaError || error is URLError)
            }
        }
    }

    // MARK: - Tool Integration Tests

    @Test("Generate Function - Without Tools")
    func generateFunctionWithoutTools() async throws {
        try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
            // Test generation without tools
            let result = try await generate(
                "Hello",
                using: .openai(.gpt4o),
                configuration: config,
            )

            #expect(!result.isEmpty)
        }
    }

    @Test("Generate Function - With Custom Tools")
    func generateFunctionWithCustomTools() async throws {
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
                model: .anthropic(.sonnet4),
                messages: [.user("Use the test tool")],
                tools: [testTool],
                configuration: config,
            )

            #expect(!result.text.isEmpty)
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
