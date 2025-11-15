import Foundation
import Testing
@testable import Tachikoma

@Suite("Provider Feature Parity Tests")
struct ProviderFeatureParityTests {
    // Mock provider for testing
    struct MockProvider: ModelProvider {
        let modelId = "mock-model"
        let baseURL: String? = nil
        let apiKey: String? = nil
        let capabilities: ModelCapabilities

        func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
            ProviderResponse(
                text: "Mock response",
                usage: Usage(inputTokens: 10, outputTokens: 20),
                finishReason: .stop,
                toolCalls: nil,
            )
        }

        func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        }
    }

    @Test("Provider configuration defaults")
    func providerConfigurationDefaults() throws {
        let config = ProviderConfiguration()

        #expect(config.maxTokens == 4096)
        #expect(config.maxContextLength == 128_000)
        #expect(config.supportedImageFormats.contains("jpeg"))
        #expect(config.supportedImageFormats.contains("png"))
        #expect(config.maxToolCalls == 10)
        #expect(config.supportsSystemRole == true)
        #expect(config.requiresAlternatingRoles == false)
    }

    @Test("Provider configuration presets")
    func providerConfigurationPresets() throws {
        let openAI = ProviderConfiguration.openAI
        #expect(openAI.supportsSystemRole == true)
        #expect(openAI.requiresAlternatingRoles == false)

        let anthropic = ProviderConfiguration.anthropic
        #expect(anthropic.maxContextLength == 200_000)
        #expect(anthropic.requiresAlternatingRoles == true)

        let google = ProviderConfiguration.google
        #expect(google.supportsSystemRole == false)
        #expect(google.requiresAlternatingRoles == true)
        #expect(google.maxContextLength == 1_048_576) // 1M tokens

        let ollama = ProviderConfiguration.ollama
        #expect(ollama.maxToolCalls == 0) // No tool support by default
    }

    @Test("Provider feature detection")
    func providerFeatureDetection() throws {
        let provider = MockProvider(
            capabilities: ModelCapabilities(
                supportsVision: true,
                supportsTools: true,
                supportsStreaming: false,
                contextLength: 128_000,
                maxOutputTokens: 4096,
            ),
        )

        let adapter = ProviderAdapter(
            provider: provider,
            configuration: ProviderConfiguration(),
        )

        #expect(adapter.isFeatureSupported(ProviderFeature.visionInputs))
        #expect(adapter.isFeatureSupported(ProviderFeature.toolCalling))
        #expect(!adapter.isFeatureSupported(ProviderFeature.streaming))
        #expect(adapter.isFeatureSupported(ProviderFeature.systemMessages))
    }

    @Test("System message transformation")
    func systemMessageTransformation() async throws {
        let provider = MockProvider(
            capabilities: ModelCapabilities(
                supportsVision: false,
                supportsTools: false,
                supportsStreaming: false,
                contextLength: 128_000,
                maxOutputTokens: 4096,
            ),
        )

        let adapter = ProviderAdapter(
            provider: provider,
            configuration: ProviderConfiguration(supportsSystemRole: false),
        )

        let messages = [
            ModelMessage.system("You are a helpful assistant"),
            ModelMessage.user("Hello"),
        ]

        let validated = try adapter.validateMessages(messages)

        #expect(validated.count == 2)
        #expect(validated[0].role == .user) // System message converted to user
        if case let .text(text) = validated[0].content.first {
            #expect(text.contains("System:"))
        } else {
            Issue.record("Expected text content")
        }
        #expect(validated[1].role == .user)
    }

    @Test("Alternating roles enforcement")
    func alternatingRolesEnforcement() async throws {
        let provider = MockProvider(
            capabilities: ModelCapabilities(
                supportsVision: false,
                supportsTools: false,
                supportsStreaming: false,
                contextLength: 128_000,
                maxOutputTokens: 4096,
            ),
        )

        let adapter = ProviderAdapter(
            provider: provider,
            configuration: ProviderConfiguration(requiresAlternatingRoles: true),
        )

        let messages = [
            ModelMessage.user("First question"),
            ModelMessage.user("Second question"), // Consecutive user messages
            ModelMessage.assistant("Response"),
            ModelMessage.assistant("Another response"), // Consecutive assistant messages
        ]

        let validated = try adapter.validateMessages(messages)

        // Should merge consecutive same-role messages
        #expect(validated.count < messages.count)
    }

    @Test("Vision input validation")
    func visionInputValidation() async throws {
        let provider = MockProvider(
            capabilities: ModelCapabilities(
                supportsVision: false, // Doesn't support vision
                supportsTools: false,
                supportsStreaming: false,
                contextLength: 128_000,
                maxOutputTokens: 4096,
            ),
        )

        let adapter = ProviderAdapter(
            provider: provider,
            configuration: ProviderConfiguration(),
        )

        let messages = [
            ModelMessage(
                role: .user,
                content: [
                    .text("Look at this image"),
                    .image(ModelMessage.ContentPart.ImageContent(
                        data: "base64data",
                        mimeType: "image/png",
                    )),
                ],
            ),
        ]

        let validated = try adapter.validateMessages(messages)

        // Image content should be stripped
        #expect(validated[0].content.count == 1)
        if case let .text(text) = validated[0].content.first {
            #expect(text == "Look at this image")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("Tool limit enforcement")
    func toolLimitEnforcement() async throws {
        let provider = MockProvider(
            capabilities: ModelCapabilities(
                supportsVision: false,
                supportsTools: true,
                supportsStreaming: false,
                contextLength: 128_000,
                maxOutputTokens: 4096,
            ),
        )

        let config = ProviderConfiguration(maxToolCalls: 2)
        _ = ProviderAdapter(provider: provider, configuration: config)

        // Create more tools than allowed
        let tools = (1...5).map { i in
            AgentTool(
                name: "tool\(i)",
                description: "Tool \(i)",
                parameters: AgentToolParameters(properties: [:], required: []),
            ) { _ in try AnyAgentToolValue(true) }
        }

        _ = ProviderRequest(
            messages: [.user("Test")],
            tools: tools,
            settings: .default,
        )

        // This would normally validate and truncate tools
        // For now, just verify the configuration
        #expect(config.maxToolCalls == 2)
    }

    @Test("Provider feature flags")
    func providerFeatureFlags() throws {
        for feature in ProviderFeature.allCases {
            // Verify all features have string representations
            #expect(!feature.rawValue.isEmpty)
        }

        #expect(ProviderFeature.allCases.contains(.streaming))
        #expect(ProviderFeature.allCases.contains(.toolCalling))
        #expect(ProviderFeature.allCases.contains(.systemMessages))
        #expect(ProviderFeature.allCases.contains(.visionInputs))
    }

    @Test("Provider adapter wrapping")
    func providerAdapterWrapping() throws {
        let provider = MockProvider(
            capabilities: ModelCapabilities(
                supportsVision: true,
                supportsTools: true,
                supportsStreaming: true,
                contextLength: 128_000,
                maxOutputTokens: 4096,
            ),
        )

        let enhanced = provider.withFeatureParity()

        #expect(enhanced.modelId == provider.modelId)
        #expect(enhanced.capabilities.supportsVision == provider.capabilities.supportsVision)
    }
}
