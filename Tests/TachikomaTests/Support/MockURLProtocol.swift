import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Simple URL protocol that lets tests stub network responses for providers.
final class MockURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let handlerLock = NSLock()
    private nonisolated(unsafe) static var _handler: Handler?

    static var handler: Handler? {
        get { handlerLock.withLock { _handler } }
        set { handlerLock.withLock { _handler = newValue } }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            let error = URLError(.resourceUnavailable)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // Nothing to clean up.
    }
}
