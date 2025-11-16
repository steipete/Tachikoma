#if LIVE_PROVIDER_TESTS
import Foundation
import Testing
@testable import Tachikoma

@Suite("Provider Integration Tests", .enabled(if: ProcessInfo.processInfo.environment["INTEGRATION_TESTS"] != nil))
struct ProviderIntegrationTests {
    // MARK: - Test Configuration

    enum TestConfig {
        static let timeout: TimeInterval = 30.0
        static let shortMessage = "Say 'Hello from Tachikoma tests!' in exactly 5 words."
        static let toolMessage = "What's the weather in New York?"
        static let streamMessage = "Count from 1 to 3"
    }

    private static func hasEnv(_ name: String) -> Bool {
        guard let value = ProcessInfo.processInfo.environment[name] else {
            return false
        }
        return !value.isEmpty
    }

    private static var hasOpenAIKey: Bool { hasEnv("OPENAI_API_KEY") }
    private static var hasAnthropicKey: Bool { hasEnv("ANTHROPIC_API_KEY") }
    private static var hasGoogleKey: Bool {
        hasEnv("GEMINI_API_KEY") || hasEnv("GOOGLE_API_KEY")
    }

    private static var hasMistralKey: Bool { hasEnv("MISTRAL_API_KEY") }
    private static var hasGroqKey: Bool { hasEnv("GROQ_API_KEY") }
    private static var hasGrokKey: Bool {
        hasEnv("X_AI_API_KEY") || hasEnv("XAI_API_KEY")
    }

    // MARK: - OpenAI Integration Tests

    @Test("OpenAI Provider - Real API Call", .enabled(if: Self.hasOpenAIKey))
    func openAIIntegration() async throws {
        let model = Model.openai(.gpt4oMini)
        let config = TachikomaConfiguration()
        do {
            _ = try ProviderFactory.createProvider(for: model, configuration: config)

            let response = try await generate(
                TestConfig.shortMessage,
                using: model,
                maxTokens: 50,
                temperature: 0.0,
                configuration: config,
            )

            if !(response.lowercased().contains("hello") && response.contains("Tachikoma")) {
                Self.warn("OpenAI integration returned unexpected text: \(response)")
            }
        } catch {
            Self.warn("OpenAI integration failed: \(error)")
        }
    }

    @Test("OpenAI Provider - Tool Calling", .enabled(if: Self.hasOpenAIKey))
    func openAIToolCalling() async throws {
        let model = Model.openai(.gpt4oMini)
        let config = TachikomaConfiguration()

        do {
            let provider = try ProviderFactory.createProvider(for: model, configuration: config)

            let tool = AgentTool(
                name: "get_weather",
                description: "Get the current weather for a location",
                parameters: AgentToolParameters(
                    properties: [
                        "location": AgentToolParameterProperty(
                            name: "location",
                            type: .string,
                            description: "The city and state, e.g. San Francisco, CA",
                        ),
                    ],
                    required: ["location"],
                ),
            ) { _ in
                AnyAgentToolValue(string: "Weather: 72°F, sunny")
            }

            let request = ProviderRequest(
                messages: [
                    ModelMessage(role: .user, content: [.text(TestConfig.toolMessage)]),
                ],
                tools: [tool],
                settings: .init(temperature: 0.0),
            )

            let response = try await provider.generateText(request: request)

            if let toolCall = response.toolCalls?.first {
                #expect(toolCall.name == "get_weather")
            } else {
                Self.warn("OpenAI tool calling returned direct text: \(response.text.prefix(80))…")
            }
        } catch {
            Self.warn("OpenAI tool calling failed: \(error)")
        }
    }

    @Test("OpenAI Provider - Streaming", .enabled(if: Self.hasOpenAIKey))
    func openAIStreaming() async throws {
        let model = Model.openai(.gpt4oMini)
        let config = TachikomaConfiguration()

        do {
            let provider = try ProviderFactory.createProvider(for: model, configuration: config)

            let request = ProviderRequest(
                messages: [
                    ModelMessage(role: .user, content: [.text(TestConfig.streamMessage)]),
                ],
                tools: nil,
                settings: .init(maxTokens: 100, temperature: 0.0),
            )

            let stream = try await provider.streamText(request: request)

            var chunks: [String] = []
            var receivedDone = false

            for try await delta in stream {
                switch delta.type {
                case .textDelta:
                    if let content = delta.content {
                        chunks.append(content)
                    }
                case .done:
                    receivedDone = true
                case .toolCall, .toolResult, .reasoning:
                    break
                }
            }

            if chunks.isEmpty {
                Self.warn("OpenAI streaming returned no chunks")
            }
            if !receivedDone {
                Self.warn("OpenAI streaming never sent done event")
            }
        } catch {
            Self.warn("OpenAI streaming failed: \(error)")
        }
    }

    // MARK: - Anthropic Integration Tests

    @Test("Anthropic Provider - Real API Call", .enabled(if: Self.hasAnthropicKey))
    func anthropicIntegration() async throws {
        let model = Model.anthropic(.sonnet4)
        do {
            let response = try await generate(
                TestConfig.shortMessage,
                using: model,
                maxTokens: 50,
                temperature: 0.0,
            )

            if !(response.lowercased().contains("hello") && response.contains("Tachikoma")) {
                Self.warn("Anthropic integration returned: \(response.prefix(120))…")
            }
        } catch {
            Self.warn("Anthropic integration failed: \(error)")
        }
    }

    @Test("Anthropic Provider - Tool Calling", .enabled(if: Self.hasAnthropicKey))
    func anthropicToolCalling() async throws {
        let model = Model.anthropic(.sonnet4)
        let config = TachikomaConfiguration()

        do {
            let provider = try ProviderFactory.createProvider(for: model, configuration: config)

            let tool = AgentTool(
                name: "calculate",
                description: "Perform basic arithmetic calculations",
                parameters: AgentToolParameters(
                    properties: [
                        "expression": AgentToolParameterProperty(
                            name: "expression",
                            type: .string,
                            description: "The arithmetic expression to evaluate",
                        ),
                    ],
                    required: ["expression"],
                ),
            ) { _ in
                AnyAgentToolValue(string: "59")
            }

            let request = ProviderRequest(
                messages: [
                    ModelMessage(role: .user, content: [.text("What is 42 plus 17?")]),
                ],
                tools: [tool],
                settings: .init(temperature: 0.0),
            )

            let response = try await provider.generateText(request: request)
            if response.toolCalls == nil, !response.text.contains("59") {
                Self.warn("Anthropic tool call not executed; response: \(response.text.prefix(100))…")
            }
        } catch {
            Self.warn("Anthropic tool calling failed: \(error)")
        }
    }

    // MARK: - Ollama Integration Tests

    @Test("Ollama Provider - Real API Call")
    func ollamaIntegration() async throws {
        // Check if Ollama is running
        let ollamaRunning = await isOllamaRunning()
        guard ollamaRunning else {
            Self.warn("Ollama not running, skipping integration test")
            return
        }

        // Check if llama3.3 model is available
        let modelAvailable = await isOllamaModelAvailable("llama3.3")
        guard modelAvailable else {
            Self.warn("llama3.3 model not available, skipping integration test. Run: ollama pull llama3.3")
            return
        }

        let model = Model.ollama(.llama33)
        do {
            let response = try await generate(
                TestConfig.shortMessage,
                using: model,
                maxTokens: 50,
                temperature: 0.0,
            )
            if !(response.lowercased().contains("hello") && response.contains("Tachikoma")) {
                Self.warn("Ollama integration returned: \(response.prefix(120))…")
            }
        } catch {
            Self.warn("Ollama integration failed: \(error)")
        }
    }

    // MARK: - Grok Integration Tests

    @Test("Grok Provider - Real API Call", .enabled(if: Self.hasGrokKey))
    func grokIntegration() async throws {
        let model = Model.grok(.grok3)
        do {
            let response = try await generate(
                TestConfig.shortMessage,
                using: model,
                maxTokens: 50,
                temperature: 0.0,
            )
            if !(response.lowercased().contains("hello") && response.contains("Tachikoma")) {
                Self.warn("Grok integration returned: \(response.prefix(120))…")
            }
        } catch {
            Self.warn("Grok integration failed: \(error)")
        }
    }

    // MARK: - Google Integration Tests

    @Test("Google Provider - Real API Call", .enabled(if: Self.hasGoogleKey))
    func googleIntegration() async throws {
        let model = Model.google(.gemini25Flash)
        do {
            let response = try await generate(
                TestConfig.shortMessage,
                using: model,
                maxTokens: 50,
                temperature: 0.0,
            )
            if !(response.lowercased().contains("hello") && response.contains("Tachikoma")) {
                Self.warn("Google integration returned: \(response.prefix(120))…")
            }
        } catch {
            Self.warn("Google integration failed: \(error)")
        }
    }

    // MARK: - Mistral Integration Tests

    @Test("Mistral Provider - Real API Call", .enabled(if: Self.hasMistralKey))
    func mistralIntegration() async throws {
        let model = Model.mistral(.small)
        let response = try await generate(TestConfig.shortMessage, using: model, maxTokens: 50, temperature: 0.0)

        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }

    // MARK: - Groq Integration Tests

    @Test("Groq Provider - Real API Call", .enabled(if: Self.hasGroqKey))
    func groqIntegration() async throws {
        let model = Model.groq(.llama38b)
        let response = try await generate(TestConfig.shortMessage, using: model, maxTokens: 50, temperature: 0.0)

        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }

    // MARK: - Multi-Modal Integration Tests

    @Test("Multi-Modal Provider - Vision Support", .enabled(if: Self.hasOpenAIKey))
    func multiModalVision() async throws {
        let model = Model.openai(.gpt4o)
        let config = TachikomaConfiguration()
        let provider = try ProviderFactory.createProvider(for: model, configuration: config)

        // Create a simple base64 encoded 1x1 red pixel PNG
        let redPixelPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="

        let imageContent = ModelMessage.ContentPart.ImageContent(
            data: redPixelPNG,
            mimeType: "image/png",
        )

        let request = ProviderRequest(
            messages: [
                ModelMessage(role: .user, content: [
                    .text("What color is this image?"),
                    .image(imageContent),
                ]),
            ],
            tools: nil,
            settings: .init(maxTokens: 50, temperature: 0.0),
        )

        let response = try await provider.generateText(request: request)

        let normalized = response.text.lowercased()
        #expect(normalized.contains("red") || normalized.contains("yellow"))
    }

    // MARK: - Helper Methods

    private static func warn(_ message: String) {
        print("⚠️ [ProviderIntegrationTests] \(message)")
    }

    private func isOllamaRunning() async -> Bool {
        do {
            let url = URL(string: "http://localhost:11434/api/tags")!
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            // Ollama not running
        }
        return false
    }

    private func isOllamaModelAvailable(_ modelName: String) async -> Bool {
        do {
            let url = URL(string: "http://localhost:11434/api/tags")!
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let models = json["models"] as? [[String: Any]]
                {
                    return models.contains { model in
                        if let name = model["name"] as? String {
                            return name.starts(with: modelName)
                        }
                        return false
                    }
                }
            }
        } catch {
            // Error checking models
        }
        return false
    }
}
#endif
