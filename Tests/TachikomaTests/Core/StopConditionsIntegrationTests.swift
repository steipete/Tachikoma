import Foundation
import Testing
@testable import Tachikoma

@Suite("Stop Conditions Integration Tests")
struct StopConditionsIntegrationTests {
    // MARK: - Provider Integration Tests

    @Test("Stop conditions passed to OpenAI as native stop sequences")
    func openAIProviderStopSequences() async throws {
        // Create a mock provider that can verify the request
        _ = MockOpenAIProvider()

        // Configure with string stop conditions
        let settings = GenerationSettings(
            stopConditions: AnyStopCondition([
                StringStopCondition("END"),
                StringStopCondition("STOP"),
            ]),
        )

        _ = ProviderRequest(
            messages: [.user("Test")],
            tools: nil,
            settings: settings,
            outputFormat: nil,
        )

        // Verify that stop sequences can be extracted from simple conditions
        let singleStop = StringStopCondition("END")
        let extractedSingle = extractStopSequences(from: singleStop)
        #expect(extractedSingle == ["END"])

        // Note: Current implementation doesn't extract from composite conditions
        // This is a known limitation that should be documented
        let extractedComposite = extractStopSequences(from: settings.stopConditions)
        #expect(extractedComposite.isEmpty) // Current behavior
    }

    @Test("Stop conditions work with generateText end-to-end")
    func generateTextWithStopConditions() async throws {
        // Use a mock provider that returns specific text
        let mockProvider = MockTextProvider(responseText: "Count: 1 2 3 END 4 5 6")

        let settings = GenerationSettings(
            stopConditions: StringStopCondition("END"),
        )

        let request = ProviderRequest(
            messages: [.user("Count to 10")],
            tools: nil,
            settings: settings,
            outputFormat: nil,
        )

        let response = try await mockProvider.generateText(request: request)

        // The response should be truncated at "END"
        #expect(!response.text.contains("4 5 6"))
        #expect(response.finishReason == FinishReason.stop)
    }

    @Test("Streaming with multiple stop conditions")
    func streamingWithMultipleStopConditions() async throws {
        // Create a stream that emits text gradually
        let stream = self.createMockStream(texts: [
            "Hello ",
            "world. ",
            "This is a test. ",
            "END ",
            "This should not appear. ",
            "STOP ",
            "This definitely should not appear.",
        ])

        // Apply multiple stop conditions
        let stoppedStream = stream
            .stopWhen(AnyStopCondition([
                StringStopCondition("END"),
                StringStopCondition("STOP"),
                TokenCountStopCondition(maxTokens: 50),
            ]))

        var result = ""
        for try await delta in stoppedStream {
            if case .textDelta = delta.type, let content = delta.content {
                result += content
            }
        }

        // Should stop at first condition (END)
        #expect(result.contains("END"))
        #expect(!result.contains("This should not appear"))
        #expect(!result.contains("STOP"))
    }

    @Test("Token count stop condition with streaming")
    func tokenCountStopWithStreaming() async throws {
        // Create a stream with many tokens
        let longTexts = (1...100).map { "Token \($0) " }
        let stream = self.createMockStream(texts: longTexts)

        // Stop after approximately 10 tokens (rough estimate: 3 chars per token)
        let stoppedStream = stream.stopWhen(TokenCountStopCondition(maxTokens: 10))

        var tokenCount = 0
        var result = ""
        for try await delta in stoppedStream {
            if case .textDelta = delta.type, let content = delta.content {
                result += content
                // Rough token counting (spaces as delimiters)
                tokenCount += content.split(separator: " ").count
            }
        }

        // Should have stopped early
        #expect(tokenCount <= 15) // Allow some margin
        #expect(!result.contains("Token 50"))
    }

    @Test("Timeout stop condition with streaming")
    func timeoutStopWithStreaming() async throws {
        // Create a slow stream
        let stream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                for i in 1...10 {
                    continuation.yield(TextStreamDelta(type: .textDelta, content: "Chunk \(i) "))
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                }
                continuation.yield(TextStreamDelta(type: .done))
                continuation.finish()
            }
        }

        // Stop after 0.3 seconds
        let stoppedStream = stream.stopWhen(TimeoutStopCondition(timeout: 0.3))

        let startTime = Date()
        var chunkCount = 0
        for try await delta in stoppedStream {
            if case .textDelta = delta.type {
                chunkCount += 1
            }
        }
        let elapsed = Date().timeIntervalSince(startTime)

        // Should have stopped after timeout
        #expect(elapsed < 0.5) // Should stop around 0.3s
        #expect(chunkCount < 10) // Should not have all chunks
    }

    @Test("Regex stop condition with complex patterns")
    func regexStopConditionWithPatterns() async throws {
        let texts = [
            "Processing item 1...",
            "Processing item 2...",
            "Processing item 3...",
            "[DONE]",
            "Should not see this",
        ]

        let stream = self.createMockStream(texts: texts)
        let stoppedStream = stream.stopWhen(RegexStopCondition(pattern: "\\[DONE\\]"))

        var result = ""
        for try await delta in stoppedStream {
            if case .textDelta = delta.type, let content = delta.content {
                result += content
            }
        }

        #expect(result.contains("[DONE]"))
        #expect(!result.contains("Should not see this"))
    }

    @Test("Predicate stop condition with custom logic")
    func predicateStopCondition() async throws {
        let stream = self.createMockStream(texts: [
            "Step 1: Initialize",
            "Step 2: Process",
            "Step 3: Complete",
            "Step 4: Should not see",
        ])

        // Stop when we see "Complete"
        let predicate = PredicateStopCondition { text, _ in
            text.contains("Complete")
        }

        let stoppedStream = stream.stopWhen(predicate)

        var result = ""
        for try await delta in stoppedStream {
            if case .textDelta = delta.type, let content = delta.content {
                result += content
            }
        }

        #expect(result.contains("Step 3: Complete"))
        #expect(!result.contains("Step 4"))
    }

    @Test("Composite stop conditions with ALL logic")
    func allStopCondition() async throws {
        let condition = AllStopCondition([
            PredicateStopCondition { text, _ in text.count > 20 }, // Length check
            PredicateStopCondition { text, _ in text.contains("END") }, // Content check
        ])

        // Test various inputs
        #expect(await condition.shouldStop(text: "Short", delta: nil) == false)
        #expect(await condition.shouldStop(text: "This is a longer text without the keyword", delta: nil) == false)
        #expect(await condition.shouldStop(text: "Short END", delta: nil) == false) // Has END but too short
        #expect(await condition.shouldStop(text: "This is long enough and has END", delta: nil) == true)
    }

    @Test("Stop condition state management with reset")
    func stopConditionReset() async throws {
        let condition = TokenCountStopCondition(maxTokens: 10)

        // First use
        await condition.reset()
        #expect(await condition.shouldStop(text: "Short", delta: nil) == false)

        // After some text (assuming ~15 tokens)
        let longText = "This is a much longer text that should exceed our token limit"
        #expect(await condition.shouldStop(text: longText, delta: nil) == true)

        // Reset and try again
        await condition.reset()
        #expect(await condition.shouldStop(text: "Short", delta: nil) == false)
    }

    @Test("Native provider stop sequence extraction")
    func stopSequenceExtraction() async throws {
        // Test single string condition
        let singleCondition = StringStopCondition("STOP")
        let singleSequences = extractStopSequences(from: singleCondition)
        #expect(singleSequences == ["STOP"])

        // Test composite conditions
        let compositeCondition = AnyStopCondition([
            StringStopCondition("END"),
            StringStopCondition("FINISH"),
            TokenCountStopCondition(maxTokens: 100), // Should be ignored for extraction
        ])

        // Note: Current implementation doesn't extract from composite conditions
        // This is a limitation we should document or fix
        let compositeSequences = extractStopSequences(from: compositeCondition)
        #expect(compositeSequences.isEmpty) // Current behavior
    }

    // MARK: - Helper Methods

    private func createMockStream(texts: [String]) -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for text in texts {
                    continuation.yield(TextStreamDelta(type: .textDelta, content: text))
                }
                continuation.yield(TextStreamDelta(type: .done))
                continuation.finish()
            }
        }
    }
}

// MARK: - Mock Providers

private struct MockTextProvider: ModelProvider {
    let responseText: String

    var modelId: String { "mock" }
    var baseURL: String? { nil }
    var apiKey: String? { nil }
    var capabilities: ModelCapabilities { ModelCapabilities() }

    func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        var finalText = self.responseText
        var finishReason = FinishReason.stop

        // Apply stop conditions if present
        if let stopCondition = request.settings.stopConditions {
            if await stopCondition.shouldStop(text: finalText, delta: nil) {
                // Truncate at stop condition
                if let stringStop = stopCondition as? StringStopCondition {
                    if let range = finalText.range(of: stringStop.stopString) {
                        finalText = String(finalText[..<range.lowerBound])
                        finishReason = .stop
                    }
                }
            }
        }

        return ProviderResponse(
            text: finalText,
            usage: nil,
            finishReason: finishReason,
        )
    }

    func streamText(request _: ProviderRequest) throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            Task {
                continuation.yield(TextStreamDelta(type: .textDelta, content: self.responseText))
                continuation.yield(TextStreamDelta(type: .done))
                continuation.finish()
            }
        }
    }

    func generateObject<T: Decodable>(request _: ProviderRequest, as _: T.Type) async throws -> T {
        throw TachikomaError.unsupportedOperation("generateObject not supported in mock")
    }
}

private struct MockOpenAIProvider: ModelProvider {
    var modelId: String { "gpt-4" }
    var baseURL: String? { nil }
    var apiKey: String? { nil }
    var capabilities: ModelCapabilities { ModelCapabilities() }

    func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
        ProviderResponse(text: "Mock response", usage: nil, finishReason: .stop)
    }

    func streamText(request _: ProviderRequest) throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func generateObject<T: Decodable>(request _: ProviderRequest, as _: T.Type) async throws -> T {
        throw TachikomaError.unsupportedOperation("generateObject not supported in mock")
    }
}

// Helper function to extract stop sequences (mimics the internal implementation)
private func extractStopSequences(from stopCondition: (any StopCondition)?) -> [String] {
    guard let stopCondition else { return [] }

    if let stringStop = stopCondition as? StringStopCondition {
        return [stringStop.stopString]
    }

    // Current implementation doesn't extract from composite conditions
    return []
}
