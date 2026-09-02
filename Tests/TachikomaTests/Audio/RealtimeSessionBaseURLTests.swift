import Foundation
import Testing
@testable import Tachikoma
@testable import TachikomaAudio

@Suite("Realtime session base URL")
@MainActor
struct RealtimeSessionBaseURLTests {
    /// Space in the host makes `URLComponents(string:)` return nil. Force-unwrap used to crash.
    private static let malformedBaseURL = "https://exa mple.com"

    @Test
    func `connect throws on malformed base URL`() async {
        let session = RealtimeSession(
            apiKey: "sk-test",
            baseURL: Self.malformedBaseURL,
            transport: NeverConnectTransport(),
        )

        await self.expectInvalidBaseURL(session)
    }

    @Test
    func `connect throws on empty base URL`() async {
        let session = RealtimeSession(
            apiKey: "sk-test",
            baseURL: "",
            transport: NeverConnectTransport(),
        )

        await self.expectInvalidBaseURL(session)
    }

    @Test
    func `connect throws on whitespace-only base URL`() async {
        let session = RealtimeSession(
            apiKey: "sk-test",
            baseURL: "   ",
            transport: NeverConnectTransport(),
        )

        await self.expectInvalidBaseURL(session)
    }

    @Test
    func `connect still reaches transport for a well-formed websocket URL`() async {
        let session = RealtimeSession(
            apiKey: "sk-test",
            baseURL: "wss://api.openai.com/v1/realtime",
            transport: NeverConnectTransport(),
        )

        do {
            try await session.connect()
            Issue.record("Expected the transport to be invoked after URL validation")
        } catch let error as TachikomaError {
            guard case let .apiError(message) = error else {
                Issue.record("Expected transport apiError, got \(error)")
                return
            }
            #expect(message.contains("transport connect invoked"))
        } catch {
            Issue.record("Expected TachikomaError, got \(error)")
        }
    }

    private func expectInvalidBaseURL(_ session: RealtimeSession) async {
        for _ in 0..<2 {
            do {
                try await session.connect()
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
            #expect(session.state == .disconnected)
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
private final class NeverConnectTransport: RealtimeTransport, @unchecked Sendable {
    func connect(url _: URL, headers _: [String: String]) async throws {
        throw TachikomaError.apiError("transport connect invoked")
    }

    func send(_: Data) async throws {}

    func receive() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func disconnect() async {}

    var isConnected: Bool {
        false
    }
}
