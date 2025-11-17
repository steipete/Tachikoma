import Foundation
import XCTest
@testable import Tachikoma

final class AuthManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TachikomaConfiguration.profileDirectoryName = ".tachikoma-test-\(UUID().uuidString)"
    }

    func testResolvePrefersEnvOverCredentials() throws {
        setenv("OPENAI_API_KEY", "env-key", 1)
        defer { unsetenv("OPENAI_API_KEY") }
        try TKAuthManager.shared.setCredential(key: "OPENAI_API_KEY", value: "cred-key")

        let auth = TKAuthManager.shared.resolveAuth(for: .openai)
        switch auth {
        case let .bearer(token, _)?:
            XCTAssertEqual(token, "env-key")
        default:
            XCTFail("Expected bearer from env")
        }
    }

    func testGrokAliasEnv() {
        setenv("X_AI_API_KEY", "alias-key", 1)
        defer { unsetenv("X_AI_API_KEY") }

        let auth = TKAuthManager.shared.resolveAuth(for: .grok)
        switch auth {
        case let .bearer(token, _)?:
            XCTAssertEqual(token, "alias-key")
        default:
            XCTFail("Expected bearer from alias env")
        }
    }

    func testValidatorSuccess() async throws {
        let session = URLSession.mock(status: 200)
        let req = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        let result = await HTTP.perform(request: req, timeoutSeconds: 5, session: session)
        switch result {
        case .success: break
        default: XCTFail("Expected success, got \(result)")
        }
    }

    func testValidatorFailure() async throws {
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

private final class MockURLProtocol: URLProtocol {
    static var statusCode: Int = 200
    static var responseBody: Data? = nil

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(
            url: self.request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: nil)!
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        self.client?.urlProtocol(self, didLoad: Self.responseBody ?? Data())
        self.client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private extension URLSession {
    static func mock(status: Int) -> URLSession {
        MockURLProtocol.statusCode = status
        MockURLProtocol.responseBody = nil
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
