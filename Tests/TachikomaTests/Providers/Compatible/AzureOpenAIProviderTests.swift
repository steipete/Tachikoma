import Foundation
#if !os(Linux)
import Testing
@testable import Tachikoma

private final class AzureTestURLProtocol: URLProtocol {
    private final class Store: @unchecked Sendable {
        private let lock = NSLock()
        private var lastRequest: URLRequest?

        func store(_ request: URLRequest) {
            self.lock.lock()
            defer { self.lock.unlock() }
            self.lastRequest = request
        }

        func fetch() -> URLRequest? {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.lastRequest
        }

        func reset() {
            self.lock.lock()
            defer { self.lock.unlock() }
            self.lastRequest = nil
        }
    }

    private static let store = Store()
    static let responseBody: Data = """
    {
      "id": "chatcmpl-azure",
      "model": "gpt-5.5",
      "choices": [
        {
          "index": 0,
          "message": { "role": "assistant", "content": "hello azure" },
          "finish_reason": "stop"
        }
      ],
      "usage": { "object": "list", "prompt_tokens": 1, "completion_tokens": 2, "total_tokens": 3 }
    }
    """.utf8Data()

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.store.store(self.request)

        let response = HTTPURLResponse(
            url: self.request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"],
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func fetchLastRequest() -> URLRequest? {
        self.store.fetch()
    }

    static func reset() {
        self.store.reset()
    }
}

@Suite(.serialized)
struct AzureOpenAIProviderTests {
    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AzureTestURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    @Test
    func `Builds Azure chat URL with api-version and api-key header`() async throws {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setAPIKey("test-key", for: .azureOpenAI)
        AzureTestURLProtocol.reset()

        let provider = try AzureOpenAIProvider(
            deploymentId: "gpt-5.5",
            resource: "my-aoai",
            apiVersion: "2025-04-01-preview",
            endpoint: nil,
            configuration: config,
            session: self.makeSession(),
        )

        let request = ProviderRequest(messages: [ModelMessage(role: .user, content: [.text("hi")])])
        let response = try await provider.generateText(request: request)

        #expect(response.text == "hello azure")

        let sentRequest = AzureTestURLProtocol.fetchLastRequest()
        #expect(sentRequest?.url?.path == "/openai/deployments/gpt-5.5/chat/completions")

        if let components = sentRequest?.url.flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) {
            let apiVersion = components.queryItems?.first { $0.name == "api-version" }?.value
            #expect(apiVersion == "2025-04-01-preview")
        } else {
            Issue.record("Expected valid URL components")
        }

        #expect(sentRequest?.value(forHTTPHeaderField: "api-key") == "test-key")
    }

    @Test
    func `Prefers bearer token auth and explicit endpoint`() async throws {
        setenv("AZURE_OPENAI_BEARER_TOKEN", "bearer-123", 1)
        setenv("AZURE_OPENAI_ENDPOINT", "https://custom.azure.example.com", 1)
        defer {
            unsetenv("AZURE_OPENAI_BEARER_TOKEN")
            unsetenv("AZURE_OPENAI_ENDPOINT")
        }
        AzureTestURLProtocol.reset()

        let provider = try AzureOpenAIProvider(
            deploymentId: "gpt-5-mini",
            resource: nil,
            apiVersion: "2025-04-01-preview",
            endpoint: nil,
            configuration: TachikomaConfiguration(loadFromEnvironment: true),
            session: self.makeSession(),
        )

        let request = ProviderRequest(messages: [ModelMessage(role: .user, content: [.text("hi")])])
        _ = try await provider.generateText(request: request)

        let sentRequest = AzureTestURLProtocol.fetchLastRequest()
        #expect(sentRequest?.url?.host == "custom.azure.example.com")
        #expect(
            sentRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer bearer-123",
            "Should use bearer token when present",
        )
    }
}
#endif
