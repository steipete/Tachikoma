//
//  AsyncErgonomicsTests.swift
//  TachikomaTests
//

import Testing
@testable import Tachikoma
import Foundation

@Suite("Async Ergonomics Tests")
struct AsyncErgonomicsTests {
    
    @Test("Timeout error description")
    func testTimeoutErrorDescription() throws {
        let error = TimeoutError(timeout: 5.5)
        #expect(error.errorDescription == "Operation timed out after 5.5 seconds")
    }
    
    @Test("Cancellation token basic operations")
    func testCancellationTokenBasic() async throws {
        let token = CancellationToken()
        
        #expect(await token.cancelled == false)
        
        await token.cancel()
        
        #expect(await token.cancelled == true)
        
        // Canceling again should be idempotent
        await token.cancel()
        #expect(await token.cancelled == true)
    }
    
    @Test("Cancellation token with handlers")
    func testCancellationTokenHandlers() async throws {
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
    
    @Test("Retry configuration defaults")
    func testRetryConfigurationDefaults() throws {
        let config = RetryConfiguration.default
        
        #expect(config.maxAttempts == 3)
        #expect(config.delay == 1.0)
        #expect(config.backoffMultiplier == 2.0)
        #expect(config.maxDelay == 60.0)
        #expect(config.timeout == nil)
    }
    
    @Test("Retry configuration presets")
    func testRetryConfigurationPresets() throws {
        let aggressive = RetryConfiguration.aggressive
        #expect(aggressive.maxAttempts == 5)
        #expect(aggressive.delay == 0.5)
        
        let conservative = RetryConfiguration.conservative
        #expect(conservative.maxAttempts == 3)
        #expect(conservative.delay == 2.0)
    }
    
    @Test("Retry with cancellation - immediate success")
    func testRetryWithCancellationImmediateSuccess() async throws {
        let result = try await retryWithCancellation(
            configuration: .init(maxAttempts: 3, delay: 0.01)
        ) {
            return "Success"
        }
        
        #expect(result == "Success")
    }
    
    @Test("With timeout basic functionality")
    func testWithTimeoutBasic() async throws {
        let result = try await withTimeout(0.1) {
            return "Quick result"
        }
        
        #expect(result == "Quick result")
    }
    
    @Test("With timeout throws on timeout")
    func testWithTimeoutThrows() async throws {
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
    
    @Test("Async stream collect basic")
    func testAsyncStreamCollectBasic() async throws {
        let stream = AsyncThrowingStream<Int, Error> { continuation in
            continuation.yield(1)
            continuation.yield(2)
            continuation.yield(3)
            continuation.finish()
        }
        
        let results = try await stream.collect()
        #expect(results == [1, 2, 3])
    }
    
    @Test("Task group with auto cancellation")
    func testTaskGroupAutoCancellation() async throws {
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