import Foundation
import Testing
@testable import Tachikoma

@Suite("Anthropic interleaved defaults")
struct AnthropicInterleavedDefaultsTests {
    @Test("Merged beta header includes required interleaved flags")
    func mergedBetaHeaderIncludesRequiredFlags() {
        let header = AnthropicProvider.mergedBetaHeader(existing: nil)
        #expect(header.contains("interleaved-thinking-2025-05-14"))
        #expect(header.contains("fine-grained-tool-streaming-2025-05-14"))

        let withExisting = AnthropicProvider.mergedBetaHeader(
            existing: "oauth-2025-04-20,interleaved-thinking-2025-05-14,oauth-2025-04-20",
        )
        let parts = withExisting
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        #expect(Set(parts).count == parts.count)
        #expect(parts.contains("oauth-2025-04-20"))
        #expect(parts.contains("interleaved-thinking-2025-05-14"))
        #expect(parts.contains("fine-grained-tool-streaming-2025-05-14"))
    }

    @Test("Provider request includes beta header and thinking payload")
    func providerRequestIncludesBetaHeaderAndThinkingPayload() throws {
        let config = TachikomaConfiguration(apiKeys: ["anthropic": "test-key"])
        let provider = try AnthropicProvider(model: .opus45, configuration: config)

        let settings = GenerationSettings(
            maxTokens: 64,
            providerOptions: .init(anthropic: .init(thinking: .enabled(budgetTokens: 12_000))),
        )

        let request = ProviderRequest(
            messages: [.user("hi")],
            settings: settings,
        )

        let urlRequest = try provider.makeURLRequest(for: request, stream: true)
        #expect(urlRequest.value(forHTTPHeaderField: "x-api-key") == "test-key")
        #expect(urlRequest.value(forHTTPHeaderField: "anthropic-beta")?.contains("interleaved-thinking-2025-05-14") == true)
        #expect(
            urlRequest.value(forHTTPHeaderField: "anthropic-beta")?.contains("fine-grained-tool-streaming-2025-05-14") ==
                true,
        )

        let body = try #require(urlRequest.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "claude-opus-4-5")
        #expect(json["stream"] as? Bool == true)

        let thinking = try #require(json["thinking"] as? [String: Any])
        #expect(thinking["type"] as? String == "enabled")
        #expect(thinking["budget_tokens"] as? Int == 12_000)
    }

    @Test("Stream delta decodes thinking_delta payload")
    func streamDeltaDecodesThinkingDeltaPayload() throws {
        let data = try #require("{\"type\":\"thinking_delta\",\"thinking\":\"ok\"}".data(using: .utf8))
        let delta = try JSONDecoder().decode(AnthropicStreamDelta.self, from: data)
        #expect(delta.type == "thinking_delta")
        #expect(delta.thinking == "ok")
        #expect(delta.text == nil)
    }
}

