//
//  AsyncErgonomicsTests.swift
//  TachikomaTests
//

import Testing
@testable import Tachikoma
import Foundation

@Suite("Async Ergonomics Tests")
struct AsyncErgonomicsTests {
    
    @Test("CancellableTask with timeout")
    func testCancellableTaskTimeout() async throws {
        let task = CancellableTask<String>(timeout: 0.1) {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return "Should timeout"
        }
        
        do {
            _ = try await task.value()
            Issue.record("Task should have timed out")
        } catch {
            // Expected timeout
            #expect(task.isCancelled)
        }
    }
    
    @Test("CancellableTask manual cancellation")
    func testCancellableTaskManualCancel() async throws {
        let task = CancellableTask<String> {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return "Should be cancelled"
        }
        
        // Cancel immediately
        task.cancel()
        
        do {
            _ = try await task.value()
            Issue.record("Task should have been cancelled")
        } catch {
            // Expected cancellation
            #expect(task.isCancelled)
        }
    }
    
    @Test("Task.withTimeout success")
    func testTaskWithTimeoutSuccess() async throws {
        let result = try await Task.withTimeout(1.0) {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            return "Success"
        }
        
        #expect(result == "Success")
    }
    
    @Test("Task.withTimeout failure")
    func testTaskWithTimeoutFailure() async throws {
        do {
            _ = try await Task.withTimeout(0.1) {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                return "Should timeout"
            }
            Issue.record("Should have timed out")
        } catch let error as TimeoutError {
            #expect(error.timeout == 0.1)
            #expect(error.errorDescription?.contains("0.1 seconds") == true)
        }
    }
    
    @Test("CancellationToken basic functionality")
    func testCancellationToken() async throws {
        let token = CancellationToken()
        
        #expect(await token.cancelled == false)
        
        await token.cancel()
        
        #expect(await token.cancelled == true)
        
        // Check that cancellation throws
        do {
            try await token.checkCancellation()
            Issue.record("Should have thrown CancellationError")
        } catch is CancellationError {
            // Expected
        }
    }
    
    @Test("CancellationToken with callbacks")
    func testCancellationTokenCallbacks() async throws {
        let token = CancellationToken()
        var callbackExecuted = false
        
        await token.onCancel {
            callbackExecuted = true
        }
        
        await token.cancel()
        
        // Give callback time to execute
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        #expect(callbackExecuted)
    }
    
    @Test("RetryConfiguration with default values")
    func testRetryConfigurationDefaults() throws {
        let config = RetryConfiguration.default
        
        #expect(config.maxAttempts == 3)
        #expect(config.delay == 1)
        #expect(config.backoffMultiplier == 2)
        #expect(config.maxDelay == 60)
        #expect(config.timeout == nil)
    }
    
    @Test("RetryConfiguration presets")
    func testRetryConfigurationPresets() throws {
        let aggressive = RetryConfiguration.aggressive
        #expect(aggressive.maxAttempts == 5)
        #expect(aggressive.delay == 0.5)
        
        let conservative = RetryConfiguration.conservative
        #expect(conservative.maxAttempts == 2)
        #expect(conservative.delay == 5)
    }
    
    @Test("Retry with cancellation - success")
    func testRetryWithCancellationSuccess() async throws {
        var attempts = 0
        
        let result = try await retryWithCancellation(
            configuration: .init(maxAttempts: 3, delay: 0.01)
        ) {
            attempts += 1
            if attempts < 2 {
                throw NSError(domain: "test", code: 1)
            }
            return "Success after \(attempts) attempts"
        }
        
        #expect(result == "Success after 2 attempts")
        #expect(attempts == 2)
    }
    
    @Test("Retry with cancellation - all attempts fail")
    func testRetryWithCancellationAllFail() async throws {
        var attempts = 0
        
        do {
            _ = try await retryWithCancellation(
                configuration: .init(maxAttempts: 2, delay: 0.01)
            ) {
                attempts += 1
                throw NSError(domain: "test", code: 1)
            }
            Issue.record("Should have failed after all attempts")
        } catch {
            #expect(attempts == 2)
        }
    }
    
    @Test("Retry with cancellation token")
    func testRetryWithCancellationToken() async throws {
        let token = CancellationToken()
        var attempts = 0
        
        // Cancel after a short delay
        Task {
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            await token.cancel()
        }
        
        do {
            _ = try await retryWithCancellation(
                configuration: .init(maxAttempts: 10, delay: 0.1),
                cancellationToken: token
            ) {
                attempts += 1
                throw NSError(domain: "test", code: 1)
            }
            Issue.record("Should have been cancelled")
        } catch is CancellationError {
            // Expected cancellation
            #expect(attempts < 10) // Should not have completed all attempts
        }
    }
    
    @Test("Async sequence collect with timeout")
    func testAsyncSequenceCollectTimeout() async throws {
        let sequence = AsyncStream<Int> { continuation in
            Task {
                for i in 1...3 {
                    continuation.yield(i)
                    try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                }
                continuation.finish()
            }
        }
        
        let results = try await sequence.collect(timeout: 1.0)
        #expect(results == [1, 2, 3])
    }
    
    @Test("Async sequence first with timeout")
    func testAsyncSequenceFirstTimeout() async throws {
        let sequence = AsyncStream<String> { continuation in
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                continuation.yield("First")
                continuation.yield("Second")
                continuation.finish()
            }
        }
        
        let first = try await sequence.first(timeout: 1.0)
        #expect(first == "First")
    }
    
    @Test("Timeout error description")
    func testTimeoutErrorDescription() throws {
        let error = TimeoutError(timeout: 5.5)
        #expect(error.errorDescription == "Operation timed out after 5.5 seconds")
    }
}