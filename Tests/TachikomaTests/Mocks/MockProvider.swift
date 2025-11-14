import Foundation
@testable import Tachikoma

/// Mock provider for testing
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class MockProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    private let model: LanguageModel

    public init(model: LanguageModel) {
        self.model = model
        self.modelId = model.modelId
        self.baseURL = "https://mock.api.example.com"
        self.apiKey = "mock-api-key"

        self.capabilities = ModelCapabilities(
            supportsVision: true,
            supportsTools: true,
            supportsStreaming: true,
            contextLength: 128_000,
            maxOutputTokens: 4096,
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        // Simulate network delay
        try await Task.sleep(for: .milliseconds(100))

        // Extract prompt text from messages
        let promptText = request.messages.compactMap { message in
            message.content.compactMap { part in
                if case let .text(text) = part {
                    return text
                }
                return nil
            }.joined()
        }.joined(separator: " ")

        // Generate mock response based on provider type
        let mockResponse = self.generateMockResponse(
            for: self.model,
            prompt: promptText,
            hasTools: request.tools?.isEmpty == false,
        )

        // Handle tool calls if requested
        var toolCalls: [AgentToolCall]?
        if let tools = request.tools, !tools.isEmpty, mockResponse.contains("tool_call") {
            toolCalls = [
                AgentToolCall(
                    id: "mock_tool_call_123",
                    name: tools.first?.name ?? "mock_tool",
                    arguments: ["query": AnyAgentToolValue(string: "mock query")],
                ),
            ]
        }

        return ProviderResponse(
            text: mockResponse,
            usage: Usage(inputTokens: 50, outputTokens: 100, cost: Usage.Cost(input: 0.0005, output: 0.0005)),
            finishReason: toolCalls != nil ? .toolCalls : .stop,
            toolCalls: toolCalls,
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await generateText(request: request)
                    let words = response.text.split(separator: " ")

                    for word in words {
                        continuation.yield(TextStreamDelta(type: .textDelta, content: String(word) + " "))
                        try await Task.sleep(for: .milliseconds(50))
                    }

                    continuation.yield(TextStreamDelta(type: .done))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func generateMockResponse(for model: LanguageModel, prompt: String, hasTools: Bool) -> String {
        switch model {
        case .openai:
            if hasTools {
                "OpenAI response for '\(prompt)' with model \(model.modelId). Using tool_call to help answer."
            } else {
                "OpenAI response for '\(prompt)' with model \(model.modelId)."
            }

        case .anthropic:
            if prompt.contains("quantum physics") {
                "Quantum physics is a fundamental theory in physics that describes the behavior of matter and energy " +
                    "at the atomic and subatomic level."
            } else if prompt.contains("2+2") {
                "2+2 equals 4."
            } else if prompt.contains("Hello world") {
                "Hello! How can I help you today?"
            } else if prompt.contains("What do you see?") {
                "I can see a test image that appears to be encoded in base64 format."
            } else {
                "I'm Claude, an AI assistant created by Anthropic. I'm here to help with a variety of tasks."
            }

        case .google:
            "Google Gemini response for '\(prompt)' with model \(model.modelId)."

        case .mistral:
            "Mistral response for '\(prompt)' with model \(model.modelId)."

        case .groq:
            "Groq response for '\(prompt)' with model \(model.modelId)."

        case .grok:
            "Grok response for '\(prompt)' with model \(model.modelId)."

        case .ollama:
            "Ollama response for '\(prompt)' with model \(model.modelId)."

        default:
            "Mock response for '\(prompt)' with model \(model.modelId)."
        }
    }
}
