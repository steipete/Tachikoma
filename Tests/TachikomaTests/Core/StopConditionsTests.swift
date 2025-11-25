import Testing
@testable import Tachikoma

@Suite("Stop Conditions Tests")
struct StopConditionsTests {
    // MARK: - String Stop Condition Tests

    @Test("StringStopCondition should stop on exact match")
    func stringStopCondition() async throws {
        let condition = StringStopCondition("STOP")

        // Should not stop before the stop string
        #expect(await condition.shouldStop(text: "Hello world", delta: nil) == false)

        // Should stop when stop string is present
        #expect(await condition.shouldStop(text: "Hello STOP world", delta: nil) == true)

        // Should stop when stop string is in delta
        #expect(await condition.shouldStop(text: "Hello", delta: "STOP") == true)
    }

    @Test("StringStopCondition case-insensitive matching")
    func stringStopConditionCaseInsensitive() async throws {
        let condition = StringStopCondition("stop", caseSensitive: false)

        // Should match regardless of case
        #expect(await condition.shouldStop(text: "Hello STOP", delta: nil) == true)
        #expect(await condition.shouldStop(text: "Hello Stop", delta: nil) == true)
        #expect(await condition.shouldStop(text: "Hello stop", delta: nil) == true)
    }

    // MARK: - Regex Stop Condition Tests

    @Test("RegexStopCondition should match patterns")
    func regexStopCondition() async throws {
        let condition = RegexStopCondition(pattern: "END.*SESSION")

        // Should not match without pattern
        #expect(await condition.shouldStop(text: "Hello world", delta: nil) == false)

        // Should match pattern
        #expect(await condition.shouldStop(text: "END OF SESSION", delta: nil) == true)
        #expect(await condition.shouldStop(text: "END_SESSION", delta: nil) == true)

        // Should match in delta
        #expect(await condition.shouldStop(text: "Hello", delta: "END SESSION") == true)
    }

    // MARK: - Token Count Stop Condition Tests

    @Test("TokenCountStopCondition should stop after limit")
    func tokenCountStopCondition() async throws {
        let condition = TokenCountStopCondition(maxTokens: 10)

        // Reset to start fresh
        await condition.reset()

        // Short text should not trigger stop (approx 3 tokens)
        #expect(await condition.shouldStop(text: "", delta: "Hello world") == false)

        // Adding more text should eventually trigger stop
        // Each call with delta accumulates tokens
        for _ in 0..<5 {
            _ = await condition.shouldStop(text: "", delta: "More text here")
        }

        // Should be over limit now
        #expect(await condition.shouldStop(text: "", delta: "Final text") == true)
    }

    // MARK: - Timeout Stop Condition Tests

    @Test("TimeoutStopCondition should stop after duration")
    func timeoutStopCondition() async throws {
        let condition = TimeoutStopCondition(timeout: 0.1) // 100ms

        // Should not stop immediately
        #expect(await condition.shouldStop(text: "Hello", delta: nil) == false)

        // Wait for timeout
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        // Should stop after timeout
        #expect(await condition.shouldStop(text: "Hello", delta: nil) == true)
    }

    // MARK: - Predicate Stop Condition Tests

    @Test("PredicateStopCondition with custom logic")
    func predicateStopCondition() async throws {
        let condition = PredicateStopCondition { text, _ in
            text.count > 20
        }

        // Short text should not stop
        #expect(await condition.shouldStop(text: "Short", delta: nil) == false)

        // Long text should stop
        #expect(await condition.shouldStop(text: "This is a much longer text string", delta: nil) == true)
    }

    // MARK: - Composite Stop Conditions Tests

    @Test("AnyStopCondition should stop when any condition is met")
    func anyStopCondition() async throws {
        let conditions: [any StopCondition] = [
            StringStopCondition("STOP"),
            TokenCountStopCondition(maxTokens: 100),
        ]
        let anyCondition = AnyStopCondition(conditions)

        // Should stop when string is found (first condition)
        #expect(await anyCondition.shouldStop(text: "Hello STOP", delta: nil) == true)

        // Reset and test with text that doesn't contain STOP
        await anyCondition.reset()
        #expect(await anyCondition.shouldStop(text: "Hello world", delta: nil) == false)
    }

    @Test("AllStopCondition should stop only when all conditions are met")
    func allStopCondition() async throws {
        let conditions: [any StopCondition] = [
            StringStopCondition("END"),
            PredicateStopCondition { text, _ in text.count > 10 },
        ]
        let allCondition = AllStopCondition(conditions)

        // Should not stop with just one condition met
        #expect(await allCondition.shouldStop(text: "END", delta: nil) == false) // Too short
        #expect(await allCondition.shouldStop(text: "This is a long text", delta: nil) == false) // No END

        // Should stop when both conditions are met
        #expect(await allCondition.shouldStop(text: "Long text with END", delta: nil) == true)
    }

    // MARK: - Integration Tests with Generation

    @Test("Stop conditions in generateText")
    func stopConditionsInGenerateText() async throws {
        // Create a mock provider that returns text with a stop marker
        let mockText = "This is the response. STOP HERE. This should be truncated."
        _ = createMockProvider(responseText: mockText)

        // Configure with stop condition
        let settings = GenerationSettings(
            stopConditions: StringStopCondition("STOP HERE"),
        )

        // This test would require a mock provider setup
        // For now, we're testing the concept
        #expect(settings.stopConditions != nil)
    }

    @Test("Stop conditions with streaming")
    func stopConditionsInStreamText() async throws {
        // Create a simple text stream
        let stream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                continuation.yield(TextStreamDelta(type: .textDelta, content: "Hello "))
                continuation.yield(TextStreamDelta(type: .textDelta, content: "world "))
                continuation.yield(TextStreamDelta(type: .textDelta, content: "STOP "))
                continuation.yield(TextStreamDelta(type: .textDelta, content: "ignored"))
                continuation.yield(TextStreamDelta(type: .done))
                continuation.finish()
            }
        }

        // Apply stop condition
        let stoppedStream = stream.stopWhen(StringStopCondition("STOP"))

        // Collect results
        var collectedText = ""
        for try await delta in stoppedStream {
            if case .textDelta = delta.type, let content = delta.content {
                collectedText += content
            }
        }

        // Should have stopped at "STOP"
        #expect(collectedText.contains("STOP"))
        #expect(!collectedText.contains("ignored"))
    }

    // MARK: - Builder Pattern Tests

    @Test("StopConditionBuilder creates correct conditions")
    func stopConditionBuilder() async throws {
        let condition = StopConditionBuilder()
            .whenContains("END")
            .afterTokens(100)
            .build()

        // Should create an AnyStopCondition with both conditions
        #expect(condition is AnyStopCondition)

        // Should stop when END is found
        let nilDelta: String? = nil
        #expect(await condition.shouldStop(text: "Test END", delta: nilDelta) == true)
    }

    @Test("GenerationSettings with stop conditions factory")
    func generationSettingsWithStopConditions() {
        let settings = GenerationSettings.withStopConditions(
            StringStopCondition("STOP"),
            TokenCountStopCondition(maxTokens: 100),
            maxTokens: 500,
            temperature: 0.7,
        )

        #expect(settings.stopConditions != nil)
        #expect(settings.maxTokens == 500)
        #expect(settings.temperature == 0.7)
    }

    // MARK: - Pattern Detection Tests

    @Test("ConsecutivePatternStopCondition detects repeating patterns")
    func consecutivePatternStopCondition() async throws {
        let condition = ConsecutivePatternStopCondition(pattern: "loop", count: 3)

        await condition.reset()

        // First occurrence
        #expect(await condition.shouldStop(text: "loop", delta: "loop") == false)

        // Second occurrence
        #expect(await condition.shouldStop(text: "loop loop", delta: "loop") == false)

        // Third occurrence should trigger stop
        #expect(await condition.shouldStop(text: "loop loop loop", delta: "loop") == true)
    }

    @Test("RepetitionStopCondition detects repeating content")
    func repetitionStopCondition() async throws {
        let condition = RepetitionStopCondition(
            windowSize: 50, // Increased to ensure we don't hit the window limit
            threshold: 0.8,
        )

        // Similar content should trigger after threshold
        let repeatedText = "The same content. "

        await condition.reset()

        let nilDelta: String? = nil

        // First time (no delta, nothing added to chunks)
        #expect(await condition.shouldStop(text: repeatedText, delta: nilDelta) == false)

        // Second similar content (adds first chunk)
        #expect(await condition.shouldStop(text: repeatedText + repeatedText, delta: repeatedText) == false)

        // Third time should trigger (adds second identical chunk)
        #expect(await condition.shouldStop(
            text: repeatedText + repeatedText + repeatedText,
            delta: repeatedText,
        ) == true)
    }

    // MARK: - Edge Cases

    @Test("Empty text and nil delta handling")
    func emptyAndNilHandling() async throws {
        let condition = StringStopCondition("STOP")

        // Empty text with nil delta
        #expect(await condition.shouldStop(text: "", delta: nil) == false)

        // Non-empty text with nil delta
        #expect(await condition.shouldStop(text: "No stop here", delta: nil) == false)

        // Empty text with non-nil delta containing stop
        #expect(await condition.shouldStop(text: "", delta: "STOP") == true)
    }

    @Test("Reset functionality")
    func resetFunctionality() async throws {
        let condition = TokenCountStopCondition(maxTokens: 5)

        // Add tokens until stop
        for _ in 0..<3 {
            _ = await condition.shouldStop(text: "", delta: "word ")
        }

        #expect(await condition.shouldStop(text: "", delta: "more") == true)

        // Reset should clear state
        await condition.reset()

        // Should not stop after reset
        #expect(await condition.shouldStop(text: "", delta: "word") == false)
    }
}

// MARK: - Test Helpers

private func createMockProvider(responseText: String) -> ModelProvider {
    // This would be a mock provider for testing
    // Implementation would depend on the testing infrastructure
    StopConditionTestMockProvider(responseText: responseText)
}

// Mock provider for testing (simplified)
private struct StopConditionTestMockProvider: ModelProvider {
    let responseText: String

    var modelId: String { "mock-model" }
    var baseURL: String? { nil }
    var apiKey: String? { nil }
    var capabilities: ModelCapabilities { ModelCapabilities() }

    func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
        ProviderResponse(text: self.responseText)
    }

    func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            Task {
                continuation.yield(TextStreamDelta(type: .textDelta, content: self.responseText))
                continuation.yield(TextStreamDelta(type: .done))
                continuation.finish()
            }
        }
    }
}
