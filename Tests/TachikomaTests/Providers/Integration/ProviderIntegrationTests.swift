#if LIVE_PROVIDER_TESTS
import Foundation
import Testing
@testable import Tachikoma

@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["INTEGRATION_TESTS"] != nil))
struct ProviderIntegrationTests {
    // MARK: - Test Configuration

    enum TestConfig {
        static let timeout: TimeInterval = 30.0
        static let shortMessage = "Say 'Hello from Tachikoma tests!' in exactly 5 words."
        static let toolMessage = "What's the weather in New York?"
        static let streamMessage = "Count from 1 to 3"
    }

    private struct LiveCredentials {
        var openAI: String?
        var anthropic: String?
        var google: String?
        var mistral: String?
        var groq: String?
        var grok: String?

        var hasProviderCredential: Bool {
            self.openAI != nil || self.anthropic != nil || self.google != nil ||
                self.mistral != nil || self.groq != nil || self.grok != nil
        }

        static func capture() -> Self {
            let environment = ProcessInfo.processInfo.environment
            return Self(
                openAI: Self.validKey(environment["OPENAI_API_KEY"]),
                anthropic: Self.validKey(environment["ANTHROPIC_API_KEY"]),
                google: Self.validKey(environment["GEMINI_API_KEY"]) ?? Self.validKey(environment["GOOGLE_API_KEY"]),
                mistral: Self.validKey(environment["MISTRAL_API_KEY"]),
                groq: Self.validKey(environment["GROQ_API_KEY"]),
                grok: Self.validKey(environment["X_AI_API_KEY"])
                    ?? Self.validKey(environment["XAI_API_KEY"])
                    ?? Self.validKey(environment["GROK_API_KEY"]),
            )
        }

        private static func validKey(_ value: String?) -> String? {
            guard let key = value?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
                return nil
            }
            let lowercased = key.lowercased()
            guard
                key != "env-key",
                key != "cred-key",
                key != "test-key",
                !lowercased.hasPrefix("test-") else
            {
                return nil
            }
            return key
        }
    }

    private static let liveCredentials = LiveCredentials.capture()

    @Test
    func `Live provider run has an eligible credential`() {
        #expect(Self.liveCredentials.hasProviderCredential)
    }

    private static var hasOpenAIKey: Bool {
        liveCredentials.openAI != nil
    }

    private static var hasAnthropicKey: Bool {
        liveCredentials.anthropic != nil
    }

    private static var hasGoogleKey: Bool {
        liveCredentials.google != nil
    }

    private static var hasMistralKey: Bool {
        liveCredentials.mistral != nil
    }

    private static var hasGroqKey: Bool {
        liveCredentials.groq != nil
    }

    private static var hasGrokKey: Bool {
        liveCredentials.grok != nil
    }

    private static func liveConfiguration() -> TachikomaConfiguration {
        let credentials = Self.liveCredentials
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        if let openAI = credentials.openAI {
            config.setAPIKey(openAI, for: .openai)
        }
        if let anthropic = credentials.anthropic {
            config.setAPIKey(anthropic, for: .anthropic)
        }
        if let google = credentials.google {
            config.setAPIKey(google, for: .google)
        }
        if let mistral = credentials.mistral {
            config.setAPIKey(mistral, for: .mistral)
        }
        if let groq = credentials.groq {
            config.setAPIKey(groq, for: .groq)
        }
        if let grok = credentials.grok {
            config.setAPIKey(grok, for: .grok)
        }
        return config
    }

    // MARK: - OpenAI Integration Tests

    @Test(.enabled(if: Self.hasOpenAIKey))
    func `OpenAI Provider - Real API Call`() async throws {
        let model = Model.openai(.gpt5Mini)
        let config = Self.liveConfiguration()
        _ = try ProviderFactory.createProvider(for: model, configuration: config)

        let response = try await generate(
            TestConfig.shortMessage,
            using: model,
            maxTokens: 300,
            temperature: 0.0,
            configuration: config,
        )

        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }

    @Test(.enabled(if: Self.hasOpenAIKey))
    func `OpenAI Provider - Tool Calling`() async throws {
        let model = Model.openai(.gpt5Mini)
        let config = Self.liveConfiguration()

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

        guard let toolCall = response.toolCalls?.first else {
            Issue.record("OpenAI tool calling returned direct text: \(response.text.prefix(80))…")
            return
        }
        #expect(toolCall.name == "get_weather")
    }

    @Test(.enabled(if: Self.hasOpenAIKey))
    func `OpenAI Provider - Streaming`() async throws {
        let model = Model.openai(.gpt5Mini)
        let config = Self.liveConfiguration()

        let provider = try ProviderFactory.createProvider(for: model, configuration: config)

        let request = ProviderRequest(
            messages: [
                ModelMessage(role: .user, content: [.text(TestConfig.streamMessage)]),
            ],
            tools: nil,
            settings: .init(maxTokens: 300, temperature: 0.0),
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

        #expect(!chunks.isEmpty)
        #expect(receivedDone)
    }

    // MARK: - Anthropic Integration Tests

    @Test(.enabled(if: Self.hasAnthropicKey))
    func `Anthropic Provider - Real API Call`() async throws {
        let model = Model.anthropic(.sonnet46)
        let config = Self.liveConfiguration()
        let response = try await generate(
            TestConfig.shortMessage,
            using: model,
            maxTokens: 50,
            temperature: 0.0,
            configuration: config,
        )

        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }

    @Test(.enabled(if: Self.hasAnthropicKey))
    func `Anthropic Provider - Tool Calling`() async throws {
        let model = Model.anthropic(.sonnet46)
        let config = Self.liveConfiguration()

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
        #expect(response.toolCalls?.isEmpty == false || response.text.contains("59"))
    }

    // MARK: - Ollama Integration Tests

    @Test
    func `Ollama Provider - Real API Call`() async throws {
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

    @Test(.enabled(if: Self.hasGrokKey))
    func `Grok Provider - Real API Call`() async throws {
        let model = Model.grok(.grok43)
        let config = Self.liveConfiguration()
        let response = try await generate(
            TestConfig.shortMessage,
            using: model,
            maxTokens: 50,
            temperature: 0.0,
            configuration: config,
        )
        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }

    // MARK: - Google Integration Tests

    @Test(.enabled(if: Self.hasGoogleKey))
    func `Google Provider - Real API Call`() async throws {
        let model = Model.google(.gemini25Flash)
        let config = Self.liveConfiguration()
        let response = try await generate(
            TestConfig.shortMessage,
            using: model,
            maxTokens: 50,
            temperature: 0.0,
            configuration: config,
        )
        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }

    // MARK: - Mistral Integration Tests

    @Test(.enabled(if: Self.hasMistralKey))
    func `Mistral Provider - Real API Call`() async throws {
        let model = Model.mistral(.smallLatest)
        let config = Self.liveConfiguration()
        let response = try await generate(
            TestConfig.shortMessage,
            using: model,
            maxTokens: 50,
            temperature: 0.0,
            configuration: config,
        )

        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }

    // MARK: - Groq Integration Tests

    @Test(.enabled(if: Self.hasGroqKey))
    func `Groq Provider - Real API Call`() async throws {
        let model = Model.groq(.llama318b)
        let config = Self.liveConfiguration()
        let response = try await generate(
            TestConfig.shortMessage,
            using: model,
            maxTokens: 50,
            temperature: 0.0,
            configuration: config,
        )

        #expect(response.lowercased().contains("hello"))
        #expect(response.contains("Tachikoma"))
    }

    // MARK: - Multi-Modal Integration Tests

    @Test(.enabled(if: Self.hasOpenAIKey))
    func `Multi-Modal Provider - Vision Support`() async throws {
        let model = Model.openai(.gpt55)
        let config = Self.liveConfiguration()
        let provider = try ProviderFactory.createProvider(for: model, configuration: config)

        // Create a simple base64 encoded 16x16 red square PNG
        let redPixelPNG = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAF0lEQVR4nGP4z8BAEiJN9aiGUQ1DSgMAkPn/Afnh+ngAAAAASUVORK5CYII="

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
            settings: .init(maxTokens: 300, temperature: 0.0),
        )

        let response = try await provider.generateText(request: request)

        let normalized = response.text.lowercased()
        #expect(normalized.contains("red"))
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["TACHIKOMA_INTEGRATION_PROFILE_DIR"]?.isEmpty == false))
    func `OpenAI Codex OAuth - GPT-5_6 Sol Vision Support`() async throws {
        let previousProfileDirectory = TachikomaConfiguration.profileDirectoryName
        if let profileDirectory = ProcessInfo.processInfo.environment["TACHIKOMA_INTEGRATION_PROFILE_DIR"] {
            TachikomaConfiguration.profileDirectoryName = profileDirectory
        }
        defer {
            TachikomaConfiguration.profileDirectoryName = previousProfileDirectory
        }

        guard TKAuthManager.shared.hasOpenAICodexCredentials() else {
            throw TestSkipped("OpenAI Codex OAuth credentials are not configured")
        }
        guard TKAuthManager.shared.resolveAuth(for: .openai) == nil else {
            throw TestSkipped("A configured OpenAI API key would take precedence over Codex OAuth")
        }

        let config = TachikomaConfiguration(loadFromEnvironment: false)
        let provider = try OpenAIResponsesProvider(model: .gpt56Sol, configuration: config)
        let redPixelPNG =
            "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAF0lEQVR4nGP4z8BAEiJN9aiGUQ1DSgMAkPn/Afnh+ngAAAAASUVORK5CYII="
        let request = ProviderRequest(
            messages: [
                ModelMessage.user(
                    text: "Reply with the single lowercase word red if this image is red.",
                    images: [.init(data: redPixelPNG, mimeType: "image/png")],
                ),
            ],
            settings: .init(maxTokens: 32),
        )

        let response = try await provider.generateText(request: request)

        #expect(response.text.lowercased().contains("red"))
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
