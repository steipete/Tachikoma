import Foundation
import Testing
@testable import Tachikoma

@Suite("Provider Integration Tests", .enabled(if: ProcessInfo.processInfo.environment["INTEGRATION_TESTS"] != nil))
struct ProviderIntegrationTests {
    // MARK: - Test Configuration
    
    struct TestConfig {
        static let timeout: TimeInterval = 30.0
        static let shortMessage = "Say 'Hello from Tachikoma tests!' in exactly 5 words."
        static let toolMessage = "What's the weather in New York?"
        static let streamMessage = "Count from 1 to 3"
    }
    
    // MARK: - OpenAI Integration Tests
    
    @Test("OpenAI Provider - Real API Call")
    func openAIIntegration() async throws {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            Issue.record("OPENAI_API_KEY not set, skipping integration test")
            return
        }
        
        let model = Model.openai(.gpt4oMini)
        let config = TachikomaConfiguration()
        let _ = try ProviderFactory.createProvider(for: model, configuration: config)
        
        let response = try await generate(TestConfig.shortMessage, using: model, maxTokens: 50, temperature: 0.0, configuration: config)
        
        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }
    
    @Test("OpenAI Provider - Tool Calling")
    func openAIToolCalling() async throws {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            Issue.record("OPENAI_API_KEY not set, skipping integration test")
            return
        }
        
        let model = Model.openai(.gpt4oMini)
        let config = TachikomaConfiguration()
        let provider = try ProviderFactory.createProvider(for: model, configuration: config)
        
        let tool = AgentTool(
            name: "get_weather",
            description: "Get the current weather for a location",
            parameters: AgentToolParameters(
                properties: [
                    "location": AgentToolParameterProperty(
                        name: "location",
                        type: .string,
                        description: "The city and state, e.g. San Francisco, CA"
                    )
                ],
                required: ["location"]
            )
        ) { args in
            .string("Weather: 72°F, sunny")
        }
        
        let request = ProviderRequest(
            messages: [
                ModelMessage(role: .user, content: [.text(TestConfig.toolMessage)])
            ],
            tools: [tool],
            settings: .init(temperature: 0.0)
        )
        
        let response = try await provider.generateText(request: request)
        
        #expect(response.toolCalls != nil)
        #expect(response.toolCalls?.first?.name == "get_weather")
        #expect(response.finishReason == .toolCalls)
    }
    
    @Test("OpenAI Provider - Streaming")
    func openAIStreaming() async throws {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            Issue.record("OPENAI_API_KEY not set, skipping integration test")
            return
        }
        
        let model = Model.openai(.gpt4oMini)
        let config = TachikomaConfiguration()
        let provider = try ProviderFactory.createProvider(for: model, configuration: config)
        
        let request = ProviderRequest(
            messages: [
                ModelMessage(role: .user, content: [.text(TestConfig.streamMessage)])
            ],
            tools: nil,
            settings: .init(maxTokens: 100, temperature: 0.0)
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
                break
            case .channelStart, .channelEnd, .toolCallStart, .toolCallDelta, .toolCallEnd, .toolResult, .stepStart, .stepEnd, .error:
                // Ignore other delta types for this test
                break
            }
        }
        
        #expect(!chunks.isEmpty)
        #expect(receivedDone)
        
        let fullText = chunks.joined()
        #expect(fullText.contains("1"))
        #expect(fullText.contains("3"))
    }
    
    // MARK: - Anthropic Integration Tests
    
    @Test("Anthropic Provider - Real API Call")
    func anthropicIntegration() async throws {
        guard ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil else {
            Issue.record("ANTHROPIC_API_KEY not set, skipping integration test")
            return
        }
        
        let model = Model.anthropic(.haiku35)
        let response = try await generate(TestConfig.shortMessage, using: model, maxTokens: 50, temperature: 0.0)
        
        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }
    
    @Test("Anthropic Provider - Tool Calling")
    func anthropicToolCalling() async throws {
        guard ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil else {
            Issue.record("ANTHROPIC_API_KEY not set, skipping integration test")
            return
        }
        
        let model = Model.anthropic(.haiku35)
        let config = TachikomaConfiguration()
        let provider = try ProviderFactory.createProvider(for: model, configuration: config)
        
        let tool = AgentTool(
            name: "calculate",
            description: "Perform basic arithmetic calculations",
            parameters: AgentToolParameters(
                properties: [
                    "expression": AgentToolParameterProperty(
                        name: "expression",
                        type: .string,
                        description: "The arithmetic expression to evaluate"
                    )
                ],
                required: ["expression"]
            )
        ) { args in
            .string("59")
        }
        
        let request = ProviderRequest(
            messages: [
                ModelMessage(role: .user, content: [.text("What is 42 plus 17?")])
            ],
            tools: [tool],
            settings: .init(temperature: 0.0)
        )
        
        let response = try await provider.generateText(request: request)
        
        #expect(response.toolCalls != nil || response.text.contains("59"))
    }
    
    // MARK: - Ollama Integration Tests
    
    @Test("Ollama Provider - Real API Call")
    func ollamaIntegration() async throws {
        // Check if Ollama is running
        let ollamaRunning = await self.isOllamaRunning()
        guard ollamaRunning else {
            Issue.record("Ollama not running, skipping integration test")
            return
        }
        
        // Check if llama3.3 model is available
        let modelAvailable = await self.isOllamaModelAvailable("llama3.3")
        guard modelAvailable else {
            Issue.record("llama3.3 model not available, skipping integration test. Run: ollama pull llama3.3")
            return
        }
        
        let model = Model.ollama(.llama33)
        let response = try await generate(TestConfig.shortMessage, using: model, maxTokens: 50, temperature: 0.0)
        
        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }
    
    // MARK: - Grok Integration Tests
    
    @Test("Grok Provider - Real API Call")
    func grokIntegration() async throws {
        guard ProcessInfo.processInfo.environment["X_AI_API_KEY"] != nil ||
              ProcessInfo.processInfo.environment["XAI_API_KEY"] != nil else {
            Issue.record("X_AI_API_KEY/XAI_API_KEY not set, skipping integration test")
            return
        }
        
        let model = Model.grok(.grokBeta)
        let response = try await generate(TestConfig.shortMessage, using: model, maxTokens: 50, temperature: 0.0)
        
        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }
    
    // MARK: - Google Integration Tests
    
    @Test("Google Provider - Real API Call")
    func googleIntegration() async throws {
        guard ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] != nil else {
            Issue.record("GOOGLE_API_KEY not set, skipping integration test")
            return
        }
        
        let model = Model.google(.gemini15Flash)
        let response = try await generate(TestConfig.shortMessage, using: model, maxTokens: 50, temperature: 0.0)
        
        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }
    
    // MARK: - Mistral Integration Tests
    
    @Test("Mistral Provider - Real API Call")
    func mistralIntegration() async throws {
        guard ProcessInfo.processInfo.environment["MISTRAL_API_KEY"] != nil else {
            Issue.record("MISTRAL_API_KEY not set, skipping integration test")
            return
        }
        
        let model = Model.mistral(.small)
        let response = try await generate(TestConfig.shortMessage, using: model, maxTokens: 50, temperature: 0.0)
        
        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }
    
    // MARK: - Groq Integration Tests
    
    @Test("Groq Provider - Real API Call")
    func groqIntegration() async throws {
        guard ProcessInfo.processInfo.environment["GROQ_API_KEY"] != nil else {
            Issue.record("GROQ_API_KEY not set, skipping integration test")
            return
        }
        
        let model = Model.groq(.llama38b)
        let response = try await generate(TestConfig.shortMessage, using: model, maxTokens: 50, temperature: 0.0)
        
        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }
    
    // MARK: - Multi-Modal Integration Tests
    
    @Test("Multi-Modal Provider - Vision Support")
    func multiModalVision() async throws {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            Issue.record("OPENAI_API_KEY not set, skipping integration test")
            return
        }
        
        let model = Model.openai(.gpt4o)
        let config = TachikomaConfiguration()
        let provider = try ProviderFactory.createProvider(for: model, configuration: config)
        
        // Create a simple base64 encoded 1x1 red pixel PNG
        let redPixelPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
        
        let imageContent = ModelMessage.ContentPart.ImageContent(
            data: redPixelPNG,
            mimeType: "image/png"
        )
        
        let request = ProviderRequest(
            messages: [
                ModelMessage(role: .user, content: [
                    .text("What color is this image?"),
                    .image(imageContent)
                ])
            ],
            tools: nil,
            settings: .init(maxTokens: 50, temperature: 0.0)
        )
        
        let response = try await provider.generateText(request: request)
        
        #expect(response.text.lowercased().contains("red"))
    }
    
    // MARK: - Helper Methods
    
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
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = json["models"] as? [[String: Any]] {
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