import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import Tachikoma

@Suite(.serialized)
struct AuthManagerTests {
    private func resetAuthEnv() {
        unsetenv("XAI_API_KEY")
        unsetenv("X_AI_API_KEY")
        unsetenv("GROK_API_KEY")
        unsetenv("OPENAI_API_KEY")
        unsetenv("ANTHROPIC_API_KEY")
    }

    @Test
    func envPreferredOverCreds() async throws {
        try await TestEnvironmentMutex.shared.withLock {
            self.resetAuthEnv()
            setenv("OPENAI_API_KEY", "env-key", 1)
            defer { unsetenv("OPENAI_API_KEY") }
            try TKAuthManager.shared.setCredential(key: "OPENAI_API_KEY", value: "cred-key")
            let auth = TKAuthManager.shared.resolveAuth(for: .openai)
            guard case let .bearer(token, _) = auth else {
                Issue.record("Expected bearer from env")
                return
            }
            #expect(token == "env-key")
        }
    }

    @Test
    func grokAliasEnv() async {
        await TestEnvironmentMutex.shared.withLock {
            self.resetAuthEnv()
            setenv("X_AI_API_KEY", "alias-key", 1)
            unsetenv("XAI_API_KEY")
            unsetenv("GROK_API_KEY")
            defer { unsetenv("X_AI_API_KEY") }
            let auth = TKAuthManager.shared.resolveAuth(for: .grok)
            guard case let .bearer(token, _) = auth else {
                Issue.record("Expected bearer from alias env")
                return
            }
            #expect(token == "alias-key")
        }
    }

    @Test
    @MainActor
    func validateSuccessMock() async {
        let session = URLSession.mock(status: 200)
        let req = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        let result = await HTTP.perform(request: req, timeoutSeconds: 5, session: session)
        switch result {
        case .success: break
        default: Issue.record("Expected success")
        }
    }

    @Test
    @MainActor
    func validateFailureMock() async {
        let session = URLSession.mock(status: 401)
        let req = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        let result = await HTTP.perform(request: req, timeoutSeconds: 5, session: session)
        switch result {
        case let .failure(reason):
            #expect(reason.contains("401"))
        default:
            Issue.record("Expected failure")
        }
    }

    @Test
    @MainActor
    func oAuthTokenExchangeUsesFormEncoding() async throws {
        OAuthMockURLProtocol.reset()
        let config = OAuthConfig(
            prefix: "TEST",
            authorize: "https://example.com/auth",
            token: "https://example.com/token",
            clientId: "client-id",
            scope: "scope",
            redirect: "https://example.com/callback",
            extraAuthorize: [:],
            extraToken: [:],
            betaHeader: nil,
            pkce: PKCE(),
        )
        let result = await OAuthTokenExchanger.exchange(
            config: config,
            code: "abc123",
            pkce: config.pkce,
            timeout: 5,
            session: .oauthMock(),
        )
        guard case .success = result else {
            Issue.record("Expected success but got \(result)")
            return
        }

        let request = try #require(OAuthMockURLProtocol.lastRequest, "No request captured")

        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")

        let bodyString = String(data: OAuthMockURLProtocol.lastBody ?? Data(), encoding: .utf8) ?? ""
        let items = URLComponents(string: "https://example.com?\(bodyString)")?.queryItems ?? []
        let params = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        #expect(params["grant_type"] == "authorization_code")
        #expect(params["client_id"] == "client-id")
        #expect(params["code"] == "abc123")
        #expect(params["redirect_uri"] == "https://example.com/callback")
        #expect(params["code_verifier"] == config.pkce.verifier)
    }

    @Test
    @MainActor
    func oAuthTokenExchangeUsesJSONEncodingAndStateWhenRequired() async throws {
        OAuthMockURLProtocol.reset()
        let config = OAuthConfig(
            prefix: "TEST",
            authorize: "https://example.com/auth",
            token: "https://example.com/token",
            clientId: "client-id",
            scope: "scope",
            redirect: "https://example.com/callback",
            extraAuthorize: [:],
            extraToken: [:],
            betaHeader: nil,
            tokenEncoding: .json,
            requiresStateInTokenExchange: true,
            pkce: PKCE(),
        )
        let result = await OAuthTokenExchanger.exchange(
            config: config,
            code: "abc123",
            state: "state123",
            pkce: config.pkce,
            timeout: 5,
            session: .oauthMock(),
        )
        guard case .success = result else {
            Issue.record("Expected success but got \(result)")
            return
        }

        let request = try #require(OAuthMockURLProtocol.lastRequest, "No request captured")

        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let bodyData = try #require(OAuthMockURLProtocol.lastBody, "No request body captured")
        let json = try #require(
            JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
            "Expected JSON request body",
        )

        #expect(json["grant_type"] as? String == "authorization_code")
        #expect(json["client_id"] as? String == "client-id")
        #expect(json["code"] as? String == "abc123")
        #expect(json["state"] as? String == "state123")
        #expect(json["redirect_uri"] as? String == "https://example.com/callback")
        #expect(json["code_verifier"] as? String == config.pkce.verifier)
    }
}

// MARK: - URLSession mocking

@MainActor
private final class AuthMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var statusCode: Int = 200

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(
            url: self.request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: nil,
        )!
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        self.client?.urlProtocol(self, didLoad: Data())
        self.client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension URLSession {
    @MainActor
    fileprivate static func mock(status: Int) -> URLSession {
        AuthMockURLProtocol.statusCode = status
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthMockURLProtocol.self]
        return URLSession(configuration: config)
    }

    @MainActor
    fileprivate static func oauthMock() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OAuthMockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

@MainActor
private final class OAuthMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    static func reset() {
        self.lastRequest = nil
        self.lastBody = nil
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        OAuthMockURLProtocol.lastRequest = self.request
        if let body = self.request.httpBody {
            OAuthMockURLProtocol.lastBody = body
        } else if let stream = self.request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            let bufferSize = 1024
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: bufferSize)
                if read > 0 {
                    data.append(buffer, count: read)
                } else { break }
            }
            OAuthMockURLProtocol.lastBody = data
        }
        let body: [String: Any] = [
            "access_token": "access",
            "refresh_token": "refresh",
            "expires_in": 3600,
        ]
        let data = try! JSONSerialization.data(withJSONObject: body)
        let response = HTTPURLResponse(
            url: self.request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"],
        )!
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        self.client?.urlProtocol(self, didLoad: data)
        self.client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
