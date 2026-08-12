import Foundation
import Testing
@testable import TachikomaMCP

@Suite("SSE transport lifecycle")
struct SSETransportTests {
    private enum TestFailure: Error {
        case streamClosed
    }

    @Test
    func `A superseded reader cannot mutate or fail replacement state`() async throws {
        let state = SSEState()
        let firstGeneration = await state.replaceReadingTask { _ in }
        let secondGeneration = await state.replaceReadingTask { _ in }
        let staleEndpoint = try #require(URL(string: "https://stale.example/rpc"))
        let currentEndpoint = try #require(URL(string: "https://current.example/rpc"))

        #expect(await state.setEndpoint(staleEndpoint, readerGeneration: firstGeneration) == false)
        #expect(await state.setEndpoint(currentEndpoint, readerGeneration: secondGeneration) == true)
        #expect(await state.getEndpoint() == currentEndpoint)

        let pendingRequest = Task<Data, Swift.Error> {
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    await state.addPending(42, continuation)
                }
            }
        }
        while await state.pendingRequestCount() == 0 {
            await Task.yield()
        }

        #expect(await state.cancelAll(TestFailure.streamClosed, readerGeneration: firstGeneration) == false)
        #expect(await state.pendingRequestCount() == 1)
        #expect(await state.cancelAll(TestFailure.streamClosed, readerGeneration: secondGeneration) == true)
        await #expect(throws: TestFailure.self) {
            try await pendingRequest.value
        }
    }
}
