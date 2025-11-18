import Foundation
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
}

// MARK: - URLSession mocking

@MainActor
private final class AuthMockURLProtocol: URLProtocol {
    static var statusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(
            url: self.request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: nil)!
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        self.client?.urlProtocol(self, didLoad: Data())
        self.client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private extension URLSession {
    @MainActor
    static func mock(status: Int) -> URLSession {
        AuthMockURLProtocol.statusCode = status
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthMockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
