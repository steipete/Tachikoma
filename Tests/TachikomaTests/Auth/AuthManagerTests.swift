import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import Tachikoma

final class AuthManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        unsetenv("XAI_API_KEY")
        unsetenv("X_AI_API_KEY")
        unsetenv("GROK_API_KEY")
        unsetenv("OPENAI_API_KEY")
        unsetenv("ANTHROPIC_API_KEY")
    }

    func testEnvPreferredOverCreds() throws {
        setenv("OPENAI_API_KEY", "env-key", 1)
        defer { unsetenv("OPENAI_API_KEY") }
        try TKAuthManager.shared.setCredential(key: "OPENAI_API_KEY", value: "cred-key")
        let auth = TKAuthManager.shared.resolveAuth(for: .openai)
        switch auth {
        case let .bearer(token, _):
            XCTAssertEqual(token, "env-key")
        default:
            XCTFail("Expected bearer from env")
        }
    }

    func testGrokAliasEnv() {
        setenv("X_AI_API_KEY", "alias-key", 1)
        unsetenv("XAI_API_KEY")
        unsetenv("GROK_API_KEY")
        defer { unsetenv("X_AI_API_KEY") }
        let auth = TKAuthManager.shared.resolveAuth(for: .grok)
        switch auth {
        case let .bearer(token, _):
            XCTAssertEqual(token, "alias-key")
        default:
            XCTFail("Expected bearer from alias env")
        }
    }

    @MainActor
    func testValidateSuccessMock() async {
        let session = URLSession.mock(status: 200)
        let req = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        let result = await HTTP.perform(request: req, timeoutSeconds: 5, session: session)
        switch result {
        case .success: break
        default: XCTFail("Expected success")
        }
    }

    @MainActor
    func testValidateFailureMock() async {
        let session = URLSession.mock(status: 401)
        let req = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        let result = await HTTP.perform(request: req, timeoutSeconds: 5, session: session)
        switch result {
        case let .failure(reason):
            XCTAssertTrue(reason.contains("401"))
        default:
            XCTFail("Expected failure")
        }
    }

    @MainActor
    func testOAuthTokenExchangeUsesFormEncoding() async {
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
            XCTFail("Expected success but got \(result)")
            return
        }

        guard let request = OAuthMockURLProtocol.lastRequest else {
            XCTFail("No request captured")
            return
        }

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")

        let bodyString = String(data: OAuthMockURLProtocol.lastBody ?? Data(), encoding: .utf8) ?? ""
        let items = URLComponents(string: "https://example.com?\(bodyString)")?.queryItems ?? []
        let params = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(params["grant_type"], "authorization_code")
        XCTAssertEqual(params["client_id"], "client-id")
        XCTAssertEqual(params["code"], "abc123")
        XCTAssertEqual(params["redirect_uri"], "https://example.com/callback")
        XCTAssertEqual(params["code_verifier"], config.pkce.verifier)
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
