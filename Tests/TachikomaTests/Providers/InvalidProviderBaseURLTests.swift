import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import Tachikoma

struct InvalidProviderBaseURLTests {
    /// Space in the host makes `URL(string:)` return nil. Force-unwrap used to crash.
    private static let malformedBaseURL = "https://exa mple.com"

    @Test
    func `Responses generate throws on malformed base URL`() async throws {
        let provider = try self.responsesProvider(baseURL: Self.malformedBaseURL)

        await self.expectInvalidBaseURL {
            _ = try await provider.generateText(request: self.sampleRequest)
        }
    }

    @Test
    func `Responses generate throws on empty base URL`() async throws {
        let provider = try self.responsesProvider(baseURL: "")

        await self.expectInvalidBaseURL {
            _ = try await provider.generateText(request: self.sampleRequest)
        }
    }

    @Test
    func `Responses stream throws on malformed base URL`() async throws {
        let provider = try self.responsesProvider(baseURL: Self.malformedBaseURL)

        await self.expectInvalidBaseURL {
            _ = try await provider.streamText(request: self.sampleRequest)
        }
    }

    @Test
    func `Embedding generate throws on malformed base URL`() async {
        let provider = OpenAIEmbeddingProvider(
            model: .small3,
            apiKey: "sk-test",
            baseURL: Self.malformedBaseURL,
        )

        await self.expectInvalidBaseURL {
            _ = try await provider.generateEmbedding(request: self.embeddingRequest)
        }
    }

    @Test
    func `Embedding generate throws on empty base URL`() async {
        let provider = OpenAIEmbeddingProvider(
            model: .small3,
            apiKey: "sk-test",
            baseURL: "",
        )

        await self.expectInvalidBaseURL {
            _ = try await provider.generateEmbedding(request: self.embeddingRequest)
        }
    }

    @Test
    func `LM Studio health check throws on malformed base URL`() async {
        let provider = LMStudioProvider(baseURL: Self.malformedBaseURL)

        await self.expectInvalidBaseURL {
            _ = try await provider.healthCheck()
        }
    }

    @Test
    func `LM Studio health check throws on empty base URL`() async {
        let provider = LMStudioProvider(baseURL: "")

        await self.expectInvalidBaseURL {
            _ = try await provider.healthCheck()
        }
    }

    @Test
    func `LM Studio list models throws on malformed base URL`() async {
        let provider = LMStudioProvider(baseURL: Self.malformedBaseURL)

        await self.expectInvalidBaseURL {
            _ = try await provider.listModels()
        }
    }

    @Test
    func `LM Studio generate throws on malformed base URL`() async {
        let provider = LMStudioProvider(baseURL: Self.malformedBaseURL)

        await self.expectInvalidBaseURL {
            _ = try await provider.generateText(request: self.sampleRequest)
        }
    }

    @Test
    func `LM Studio stream throws on malformed base URL`() async {
        let provider = LMStudioProvider(baseURL: Self.malformedBaseURL)

        await self.expectInvalidBaseURL {
            _ = try await provider.streamText(request: self.sampleRequest)
        }
    }

    private func responsesProvider(baseURL: String) throws -> OpenAIResponsesProvider {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setAPIKey("sk-test", for: .openai)
        config.setBaseURL(baseURL, for: .openai)
        return try OpenAIResponsesProvider(model: .gpt5, configuration: config)
    }

    private var sampleRequest: ProviderRequest {
        ProviderRequest(
            messages: [ModelMessage(role: .user, content: [.text("ping")])],
            settings: .init(maxTokens: 32),
        )
    }

    private var embeddingRequest: EmbeddingRequest {
        EmbeddingRequest(input: .text("hello"), settings: .default)
    }

    private func expectInvalidBaseURL(_ body: () async throws -> Void) async {
        do {
            try await body()
            Issue.record("Expected TachikomaError.invalidConfiguration for a bad base URL")
        } catch let error as TachikomaError {
            guard case let .invalidConfiguration(message) = error else {
                Issue.record("Expected invalidConfiguration, got \(error)")
                return
            }
            #expect(message.contains("Invalid base URL"))
        } catch {
            Issue.record("Expected TachikomaError, got \(error)")
        }
    }
}
