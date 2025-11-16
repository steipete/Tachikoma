import Foundation
import Testing
@testable import Tachikoma

private final class AzureTestURLProtocol: URLProtocol {
    private actor Store {
        private(set) var lastRequest: URLRequest?

        func store(_ request: URLRequest) {
            self.lastRequest = request
        }
    }

    private static let store = Store()
    static let responseBody: Data = {
        """
        {
          "id": "chatcmpl-azure",
          "model": "gpt-4o",
          "choices": [
            {
              "index": 0,
              "message": { "role": "assistant", "content": "hello azure" },
              "finish_reason": "stop"
            }
          ],
          "usage": { "prompt_tokens": 1, "completion_tokens": 2 }
        }
        """.utf8Data()
    }()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Task { await Self.storeMedia(request) }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func storeMedia(_ request: URLRequest) async {
        await self.store.store(request)
    }

    static func fetchLastRequest() async -> URLRequest? {
        await self.store.lastRequest
    }
}

@Suite("Azure OpenAI Provider")
struct AzureOpenAIProviderTests {
    @Test("Builds Azure chat URL with api-version and api-key header")
    func buildsAzureURLAndHeaders() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setAPIKey("test-key", for: .azureOpenAI)

        URLProtocol.registerClass(AzureTestURLProtocol.self)
        defer { URLProtocol.unregisterClass(AzureTestURLProtocol.self) }

        let provider = try AzureOpenAIProvider(
            deploymentId: "gpt-4o",
            resource: "my-aoai",
            apiVersion: "2025-04-01-preview",
            endpoint: nil,
            configuration: config
        )

        let request = ProviderRequest(messages: [ModelMessage(role: .user, content: [.text("hi")])])
        let response = try await provider.generateText(request: request)

        #expect(response.text == "hello azure")

        let sentRequest = await AzureTestURLProtocol.fetchLastRequest()
        #expect(sentRequest?.url?.path == "/openai/deployments/gpt-4o/chat/completions")

        if let components = sentRequest?.url.flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) {
            let apiVersion = components.queryItems?.first(where: { $0.name == "api-version" })?.value
            #expect(apiVersion == "2025-04-01-preview")
        } else {
            Issue.record("Expected valid URL components")
        }

        #expect(sentRequest?.value(forHTTPHeaderField: "api-key") == "test-key")
    }

    @Test("Prefers bearer token auth and explicit endpoint")
    func prefersBearerToken() async throws {
        setenv("AZURE_OPENAI_BEARER_TOKEN", "bearer-123", 1)
        setenv("AZURE_OPENAI_ENDPOINT", "https://custom.azure.example.com", 1)
        defer {
            unsetenv("AZURE_OPENAI_BEARER_TOKEN")
            unsetenv("AZURE_OPENAI_ENDPOINT")
        }

        URLProtocol.registerClass(AzureTestURLProtocol.self)
        defer { URLProtocol.unregisterClass(AzureTestURLProtocol.self) }

        let provider = try AzureOpenAIProvider(
            deploymentId: "gpt-4o-mini",
            resource: nil,
            apiVersion: "2025-04-01-preview",
            endpoint: nil,
            configuration: TachikomaConfiguration(loadFromEnvironment: true)
        )

        let request = ProviderRequest(messages: [ModelMessage(role: .user, content: [.text("hi")])])
        _ = try await provider.generateText(request: request)

        let sentRequest = await AzureTestURLProtocol.fetchLastRequest()
        #expect(sentRequest?.url?.host == "custom.azure.example.com")
        #expect(
            sentRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer bearer-123",
            "Should use bearer token when present"
        )
    }
}
