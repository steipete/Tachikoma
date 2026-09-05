import Foundation
import Testing
@testable import Tachikoma

struct AsyncErgonomicsTests {
    @Test
    func `Timeout error description`() {
        let error = TimeoutError(timeout: 5.5)
        #expect(error.errorDescription == "Operation timed out after 5.5 seconds")
    }

    @Test
    func `Cancellation token basic operations`() async {
        let token = CancellationToken()

        #expect(await token.cancelled == false)

        await token.cancel()

        #expect(await token.cancelled == true)

        // Canceling again should be idempotent
        await token.cancel()
        #expect(await token.cancelled == true)
    }

    @Test
    func `Cancellation token with handlers`() async throws {
        let token = CancellationToken()

        class Flag: @unchecked Sendable {
            var value = false
        }

        let flag = Flag()

        await token.onCancel {
            flag.value = true
        }

        #expect(flag.value == false)

        await token.cancel()

        // Give handler time to execute
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        #expect(flag.value == true)
    }

    @Test
    func `Retry configuration defaults`() {
        let config = RetryConfiguration.default

        #expect(config.maxAttempts == 3)
        #expect(config.delay == 1.0)
        #expect(config.backoffMultiplier == 2.0)
        #expect(config.maxDelay == 60.0)
        #expect(config.timeout == nil)
    }

    @Test
    func `Retry configuration presets`() {
        let aggressive = RetryConfiguration.aggressive
        #expect(aggressive.maxAttempts == 5)
        #expect(aggressive.delay == 0.5)

        let conservative = RetryConfiguration.conservative
        #expect(conservative.maxAttempts == 3)
        #expect(conservative.delay == 2.0)
    }

    @Test
    func `Retry with cancellation - immediate success`() async throws {
        let result = try await retryWithCancellation(
            configuration: .init(maxAttempts: 3, delay: 0.01),
        ) {
            "Success"
        }

        #expect(result == "Success")
    }

    @Test
    func `With timeout basic functionality`() async throws {
        let result = try await withTimeout(0.1) {
            "Quick result"
        }

        #expect(result == "Quick result")
    }

    @Test
    func `With timeout throws on timeout`() async throws {
        do {
            _ = try await withTimeout(0.01) {
                try await Task<Never, Never>.sleep(nanoseconds: 1_000_000_000) // 1 second
                return "Should timeout"
            }
            Issue.record("Should have timed out")
        } catch is TimeoutError {
            // Expected
        }
    }

    @Test
    func `Timeout nanoseconds converts finite positive seconds`() throws {
        #expect(try TimeoutNanoseconds.fromSeconds(1) == 1_000_000_000)
        #expect(try TimeoutNanoseconds.fromSeconds(0.5) == 500_000_000)
        #expect(try TimeoutNanoseconds.fromSeconds(TimeoutNanoseconds.maximumSeconds) > 0)
    }

    @Test(arguments: [
        0,
        -1,
        .infinity,
        -.infinity,
        .nan,
        TimeoutNanoseconds.maximumSeconds.nextUp,
        .greatestFiniteMagnitude,
    ])
    func `Timeout nanoseconds rejects values that trap UInt64`(timeout: TimeInterval) {
        do {
            _ = try TimeoutNanoseconds.fromSeconds(timeout)
            Issue.record("Should have rejected timeout \(timeout)")
        } catch let error as TachikomaError {
            guard case let .invalidConfiguration(message) = error else {
                Issue.record("Expected invalidConfiguration, got \(error)")
                return
            }
            #expect(message.contains("Invalid timeout"))
        } catch {
            Issue.record("Expected TachikomaError, got \(error)")
        }
    }

    @Test(arguments: [
        0,
        -1,
        .infinity,
        -.infinity,
        .nan,
        TimeoutNanoseconds.maximumSeconds.nextUp,
        .greatestFiniteMagnitude,
    ])
    func `With timeout rejects invalid values before starting work`(timeout: TimeInterval) async {
        let probe = TimeoutStartProbe()

        do {
            _ = try await withTimeout(timeout) {
                await probe.markStarted()
                return "should not run"
            }
            Issue.record("Should have rejected timeout \(timeout)")
        } catch let error as TachikomaError {
            guard case let .invalidConfiguration(message) = error else {
                Issue.record("Expected invalidConfiguration, got \(error)")
                return
            }
            #expect(message.contains("Invalid timeout"))
        } catch {
            Issue.record("Expected TachikomaError, got \(error)")
        }

        #expect(await probe.didStart() == false)
    }

    @Test
    func `Async stream collect basic`() async throws {
        let stream = AsyncThrowingStream<Int, Error> { continuation in
            continuation.yield(1)
            continuation.yield(2)
            continuation.yield(3)
            continuation.finish()
        }

        let results = try await stream.collect()
        #expect(results == [1, 2, 3])
    }

    @Test
    func `Task group with auto cancellation`() async throws {
        class Flag: @unchecked Sendable {
            var cancelled = false
        }

        let flag = Flag()

        do {
            try await withAutoCancellationTaskGroup(of: Void.self) { group in
                group.addTask {
                    defer { flag.cancelled = true }
                    try await Task<Never, Never>.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                }

                group.addTask {
                    throw NSError(domain: "test", code: 1)
                }

                // Wait for all tasks
                try await group.waitForAll()
            }
        } catch {
            // Expected error
        }

        // Give time for cancellation
        try await Task<Never, Never>.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        // The long task should have been cancelled
        #expect(flag.cancelled == true)
    }
}

private actor TimeoutStartProbe {
    private var started = false

    func markStarted() {
        self.started = true
    }

    func didStart() -> Bool {
        self.started
    }
}
