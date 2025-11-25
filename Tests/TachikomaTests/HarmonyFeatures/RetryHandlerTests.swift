import Testing
@testable import Tachikoma

@Suite("Retry Handler")
struct RetryHandlerTests {
    // Helper actor for thread-safe counting
    actor CallCounter {
        private(set) var count = 0

        func increment() {
            self.count += 1
        }

        func get() -> Int {
            self.count
        }
    }

    @Test("RetryPolicy default values")
    func retryPolicyDefaults() {
        let policy = RetryPolicy()
        #expect(policy.maxAttempts == 3)
        #expect(policy.baseDelay == 1.0)
        #expect(policy.maxDelay == 30.0)
        #expect(policy.exponentialBase == 2.0)
        #expect(policy.jitterRange == 0.9...1.1)
    }

    @Test("RetryPolicy aggressive configuration")
    func retryPolicyAggressive() {
        let policy = RetryPolicy.aggressive
        #expect(policy.maxAttempts == 5)
        #expect(policy.baseDelay == 0.5)
        #expect(policy.maxDelay == 60.0)
        #expect(policy.exponentialBase == 1.5)
    }

    @Test("RetryPolicy conservative configuration")
    func retryPolicyConservative() {
        let policy = RetryPolicy.conservative
        #expect(policy.maxAttempts == 2)
        #expect(policy.baseDelay == 2.0)
        #expect(policy.maxDelay == 10.0)
        #expect(policy.exponentialBase == 2.0)
    }

    @Test("RetryPolicy delay calculation")
    func retryPolicyDelayCalculation() {
        let policy = RetryPolicy(
            baseDelay: 1.0,
            maxDelay: 10.0,
            exponentialBase: 2.0,
            jitterRange: 1.0...1.0, // No jitter for predictable testing
        )

        // First retry (attempt 0)
        let delay0 = policy.delay(for: 0)
        #expect(delay0 == 1.0) // 1.0 * 2^0 = 1.0

        // Second retry (attempt 1)
        let delay1 = policy.delay(for: 1)
        #expect(delay1 == 2.0) // 1.0 * 2^1 = 2.0

        // Third retry (attempt 2)
        let delay2 = policy.delay(for: 2)
        #expect(delay2 == 4.0) // 1.0 * 2^2 = 4.0

        // Fourth retry (attempt 3)
        let delay3 = policy.delay(for: 3)
        #expect(delay3 == 8.0) // 1.0 * 2^3 = 8.0

        // Fifth retry (attempt 4) - should be clamped to maxDelay
        let delay4 = policy.delay(for: 4)
        #expect(delay4 == 10.0) // 1.0 * 2^4 = 16.0, clamped to 10.0
    }

    @Test("RetryPolicy delay with jitter")
    func retryPolicyDelayWithJitter() {
        let policy = RetryPolicy(
            baseDelay: 1.0,
            exponentialBase: 2.0,
            jitterRange: 0.5...1.5,
        )

        // Delay should be within jitter range
        let delay = policy.delay(for: 0)
        #expect(delay >= 0.5) // 1.0 * 0.5
        #expect(delay <= 1.5) // 1.0 * 1.5
    }

    @Test("RetryPolicy default shouldRetry for rate limits")
    func retryPolicyDefaultShouldRetryRateLimits() {
        let shouldRetry = RetryPolicy.defaultShouldRetry

        // Should retry rate limits
        let rateLimitError = TachikomaError.rateLimited(retryAfter: 5.0)
        #expect(shouldRetry(rateLimitError) == true)

        let rateLimitNoRetryAfter = TachikomaError.rateLimited(retryAfter: nil)
        #expect(shouldRetry(rateLimitNoRetryAfter) == true)
    }

    @Test("RetryPolicy default shouldRetry for network errors")
    func retryPolicyDefaultShouldRetryNetworkErrors() {
        let shouldRetry = RetryPolicy.defaultShouldRetry

        // Should retry network errors
        let networkError = TachikomaError.networkError(NSError(domain: "test", code: 0))
        #expect(shouldRetry(networkError) == true)
    }

    @Test("RetryPolicy default shouldRetry for API errors")
    func retryPolicyDefaultShouldRetryAPIErrors() {
        let shouldRetry = RetryPolicy.defaultShouldRetry

        // Should retry specific API errors
        #expect(shouldRetry(TachikomaError.apiError("Rate limit exceeded")) == true)
        #expect(shouldRetry(TachikomaError.apiError("Too many requests")) == true)
        #expect(shouldRetry(TachikomaError.apiError("Service temporarily unavailable")) == true)
        #expect(shouldRetry(TachikomaError.apiError("502 Bad Gateway")) == true)
        #expect(shouldRetry(TachikomaError.apiError("504 Gateway Timeout")) == true)

        // Should not retry other API errors
        #expect(shouldRetry(TachikomaError.apiError("Invalid API key")) == false)
        #expect(shouldRetry(TachikomaError.apiError("Model not found")) == false)
    }

    @Test("RetryPolicy default shouldRetry for non-retryable errors")
    func retryPolicyDefaultShouldRetryNonRetryableErrors() {
        let shouldRetry = RetryPolicy.defaultShouldRetry

        // Should not retry authentication failures
        #expect(shouldRetry(TachikomaError.authenticationFailed("Invalid key")) == false)

        // Should not retry invalid input
        #expect(shouldRetry(TachikomaError.invalidInput("Bad data")) == false)

        // Should not retry unsupported operations
        #expect(shouldRetry(TachikomaError.unsupportedOperation("Not implemented")) == false)
    }

    @Test("RetryHandler execute with success")
    func retryHandlerExecuteSuccess() async throws {
        let handler = RetryHandler()
        let callCounter = CallCounter()

        let result = try await handler.execute {
            await callCounter.increment()
            return "Success"
        }

        #expect(result == "Success")
        #expect(await callCounter.count == 1) // Should succeed on first try
    }

    @Test("RetryHandler execute with retries")
    func retryHandlerExecuteWithRetries() async throws {
        let policy = RetryPolicy(
            maxAttempts: 3,
            baseDelay: 0.01,
        ) // Short delay for testing
            { _ in true }
        let handler = RetryHandler(policy: policy)

        let callCounter = CallCounter()
        let retryCounter = CallCounter()

        do {
            _ = try await handler.execute(
                operation: {
                    await callCounter.increment()
                    let count = await callCounter.count
                    if count < 3 {
                        throw TachikomaError.rateLimited(retryAfter: nil)
                    }
                    return "Success after retries"
                },
                onRetry: { attempt, delay, _ in
                    await retryCounter.increment()
                    let retryCount = await retryCounter.count
                    #expect(attempt == retryCount)
                    #expect(delay >= 0.009) // Allow for timing precision
                },
            )

            #expect(await callCounter.count == 3)
            #expect(await retryCounter.count == 2)
        } catch {
            Issue.record("Should have succeeded after retries")
        }
    }

    @Test("RetryHandler execute exhausts retries")
    func retryHandlerExecuteExhaustsRetries() async throws {
        let policy = RetryPolicy(
            maxAttempts: 2,
            baseDelay: 0.01,
        ) { _ in true }
        let handler = RetryHandler(policy: policy)

        let callCounter = CallCounter()

        await #expect(throws: TachikomaError.self) {
            try await handler.execute {
                await callCounter.increment()
                throw TachikomaError.rateLimited(retryAfter: nil)
            }
        }

        #expect(await callCounter.count == 2) // Should try maxAttempts times
    }

    @Test("RetryHandler execute with non-retryable error")
    func retryHandlerExecuteNonRetryableError() async throws {
        let handler = RetryHandler()
        let callCounter = CallCounter()

        await #expect(throws: TachikomaError.self) {
            try await handler.execute {
                await callCounter.increment()
                throw TachikomaError.authenticationFailed("Invalid key")
            }
        }

        #expect(await callCounter.count == 1) // Should not retry
    }

    @Test("RetryHandler executeStream success")
    func retryHandlerExecuteStreamSuccess() async throws {
        let handler = RetryHandler()
        let callCounter = CallCounter()

        let stream = try await handler.executeStream {
            await callCounter.increment()
            return AsyncThrowingStream { continuation in
                continuation.yield("Item 1")
                continuation.yield("Item 2")
                continuation.finish()
            }
        }

        var items: [String] = []
        for try await item in stream {
            items.append(item)
        }

        #expect(items == ["Item 1", "Item 2"])
        #expect(await callCounter.count == 1)
    }

    @Test("RetryHandler from GenerationSettings")
    func retryHandlerFromGenerationSettings() {
        // High effort uses aggressive policy
        let highSettings = GenerationSettings(reasoningEffort: .high)
        let highHandler = RetryHandler.from(settings: highSettings)
        _ = highHandler // Just verify it creates successfully

        // Low effort uses conservative policy
        let lowSettings = GenerationSettings(reasoningEffort: .low)
        let lowHandler = RetryHandler.from(settings: lowSettings)
        _ = lowHandler // Just verify it creates successfully

        // Medium effort uses default policy
        let mediumSettings = GenerationSettings(reasoningEffort: .medium)
        let mediumHandler = RetryHandler.from(settings: mediumSettings)
        _ = mediumHandler // Just verify it creates successfully

        // Nil effort uses default policy
        let nilSettings = GenerationSettings()
        let nilHandler = RetryHandler.from(settings: nilSettings)
        _ = nilHandler // Just verify it creates successfully

        // Test passes if all handlers created without errors
        #expect(Bool(true))
    }
}
