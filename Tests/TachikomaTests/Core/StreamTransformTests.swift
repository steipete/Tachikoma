import Testing
@testable import Tachikoma

@Suite("Stream Transform Pipeline Tests")
struct StreamTransformTests {
    @Test("FilterTransform filters elements correctly")
    func testFilterTransform() async throws {
        let transform = FilterTransform<Int> { $0 % 2 == 0 }

        #expect(try await transform.transform(2) == 2)
        #expect(try await transform.transform(3) == nil)
        #expect(try await transform.transform(4) == 4)
        #expect(try await transform.transform(5) == nil)
    }

    @Test("MapTransform transforms elements")
    func testMapTransform() async throws {
        let transform = MapTransform<Int, String> { "\($0 * 2)" }

        #expect(try await transform.transform(5) == "10")
        #expect(try await transform.transform(3) == "6")
    }

    @Test("BufferTransform batches elements")
    func bufferTransform() async throws {
        let transform = BufferTransform<String>(bufferSize: 3)

        // First two elements shouldn't trigger flush
        #expect(try await transform.transform("a") == nil)
        #expect(try await transform.transform("b") == nil)

        // Third element should trigger flush
        let batch = try await transform.transform("c")
        #expect(batch == ["a", "b", "c"])

        // Continue with new batch
        #expect(try await transform.transform("d") == nil)
        #expect(try await transform.transform("e") == nil)

        // Manual flush
        let remaining = await transform.flush()
        #expect(remaining == ["d", "e"])
    }

    @Test("BufferTransform with time interval")
    func bufferTransformWithInterval() async throws {
        let transform = BufferTransform<Int>(bufferSize: 10, flushInterval: 0.1)

        // Add elements
        #expect(try await transform.transform(1) == nil)
        #expect(try await transform.transform(2) == nil)

        // Wait for interval
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        // Next element should trigger flush due to time
        let batch = try await transform.transform(3)
        #expect(batch?.count == 3)
        #expect(batch?.contains(1) == true)
        #expect(batch?.contains(2) == true)
        #expect(batch?.contains(3) == true)
    }

    @Test("ThrottleTransform limits rate")
    func throttleTransform() async throws {
        let transform = ThrottleTransform<String>(interval: 0.1)

        // First element passes through
        #expect(try await transform.transform("first") == "first")

        // Immediate second element is throttled
        #expect(try await transform.transform("second") == nil)

        // Wait for interval
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        // Now element should pass through
        #expect(try await transform.transform("third") == "third")
    }

    @Test("TapTransform adds side effects")
    func tapTransform() async throws {
        actor SideEffectsCollector {
            var values: [Int] = []
            func append(_ value: Int) {
                self.values.append(value)
            }
        }

        let collector = SideEffectsCollector()
        let transform = TapTransform<Int> { await collector.append($0) }

        #expect(try await transform.transform(1) == 1)
        #expect(try await transform.transform(2) == 2)
        #expect(try await transform.transform(3) == 3)

        #expect(await collector.values == [1, 2, 3])
    }

    @Test("Stream filter extension works")
    func streamFilterExtension() async throws {
        let stream = AsyncThrowingStream<Int, Error> { continuation in
            Task {
                for i in 1...5 {
                    continuation.yield(i)
                }
                continuation.finish()
            }
        }

        let filtered = stream.filter { $0 % 2 == 0 }

        var results: [Int] = []
        for try await value in filtered {
            results.append(value)
        }

        #expect(results == [2, 4])
    }

    @Test("Stream map extension works")
    func streamMapExtension() async throws {
        let stream = AsyncThrowingStream<Int, Error> { continuation in
            Task {
                for i in 1...3 {
                    continuation.yield(i)
                }
                continuation.finish()
            }
        }

        let mapped = stream.map { $0 * $0 }

        var results: [Int] = []
        for try await value in mapped {
            results.append(value)
        }

        #expect(results == [1, 4, 9])
    }

    @Test("Stream tap extension works")
    func streamTapExtension() async throws {
        actor TapCollector {
            var values: [String] = []
            func append(_ value: String) {
                self.values.append(value)
            }
        }

        let collector = TapCollector()

        let stream = AsyncThrowingStream<String, Error> { continuation in
            Task {
                continuation.yield("a")
                continuation.yield("b")
                continuation.yield("c")
                continuation.finish()
            }
        }

        let tappedStream = stream.tap { await collector.append($0) }

        var results: [String] = []
        for try await value in tappedStream {
            results.append(value)
        }

        #expect(results == ["a", "b", "c"])
        #expect(await collector.values == ["a", "b", "c"])
    }

    @Test("Stream buffer extension works")
    func streamBufferExtension() async throws {
        let stream = AsyncThrowingStream<Int, Error> { continuation in
            Task {
                for i in 1...7 {
                    continuation.yield(i)
                }
                continuation.finish()
            }
        }

        let buffered = stream.buffer(size: 3)

        var batches: [[Int]] = []
        for try await batch in buffered {
            batches.append(batch)
        }

        #expect(batches.count == 3)
        #expect(batches[0] == [1, 2, 3])
        #expect(batches[1] == [4, 5, 6])
        #expect(batches[2] == [7]) // Remaining element
    }

    @Test("Stream throttle extension works")
    func streamThrottleExtension() async throws {
        let stream = AsyncThrowingStream<Int, Error> { continuation in
            Task {
                for i in 1...5 {
                    continuation.yield(i)
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                continuation.finish()
            }
        }

        let throttled = stream.throttle(interval: 0.03) // 30ms

        var results: [Int] = []
        for try await value in throttled {
            results.append(value)
        }

        // Should get fewer elements due to throttling
        #expect(results.count < 5)
        #expect(results.contains(1)) // First element always passes
    }

    @Test("StreamTextResult filter extension works")
    func streamTextResultFilter() async throws {
        let stream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                continuation.yield(TextStreamDelta(type: .textDelta, content: "Hello"))
                continuation.yield(TextStreamDelta(type: .reasoning, content: "Thinking..."))
                continuation.yield(TextStreamDelta(type: .textDelta, content: "World"))
                continuation.yield(TextStreamDelta(type: .done))
                continuation.finish()
            }
        }

        let result = StreamTextResult(
            stream: stream,
            model: .openai(.gpt4o),
            settings: .default,
        )

        let filtered = result.stream.filter { delta in
            if case .textDelta = delta.type {
                return true
            }
            return false
        }

        var count = 0
        for try await _ in filtered {
            count += 1
        }

        #expect(count == 2) // Only text deltas
    }

    @Test("StreamTextResult collectText works")
    func streamTextResultCollectText() async throws {
        let stream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                continuation.yield(TextStreamDelta(type: .textDelta, content: "Hello"))
                continuation.yield(TextStreamDelta(type: .textDelta, content: " "))
                continuation.yield(TextStreamDelta(type: .textDelta, content: "World"))
                continuation.yield(TextStreamDelta(type: .done))
                continuation.finish()
            }
        }

        let result = StreamTextResult(
            stream: stream,
            model: .openai(.gpt4o),
            settings: .default,
        )

        var texts: [String] = []
        for try await text in result.collectText() {
            texts.append(text)
        }

        #expect(texts == ["Hello", " ", "World"])
    }

    @Test("StreamTextResult fullText works")
    func streamTextResultFullText() async throws {
        let stream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                continuation.yield(TextStreamDelta(type: .textDelta, content: "The"))
                continuation.yield(TextStreamDelta(type: .textDelta, content: " quick"))
                continuation.yield(TextStreamDelta(type: .textDelta, content: " brown"))
                continuation.yield(TextStreamDelta(type: .textDelta, content: " fox"))
                continuation.yield(TextStreamDelta(type: .done))
                continuation.finish()
            }
        }

        let result = StreamTextResult(
            stream: stream,
            model: .openai(.gpt4o),
            settings: .default,
        )

        let fullText = try await result.fullText()
        #expect(fullText == "The quick brown fox")
    }

    @Test("CombinedTransform chains transforms")
    func combinedTransform() async throws {
        let filterTransform = FilterTransform<Int> { $0 % 2 == 0 }
        let mapTransform = MapTransform<Int, String> { "\($0 * 10)" }

        let combined = CombinedTransform(
            first: filterTransform,
            second: mapTransform,
        )

        #expect(try await combined.transform(2) == "20")
        #expect(try await combined.transform(3) == nil) // Filtered out
        #expect(try await combined.transform(4) == "40")
    }

    @Test("Transform chain with complex pipeline")
    func complexTransformPipeline() async throws {
        let stream = AsyncThrowingStream<Int, Error> { continuation in
            Task {
                for i in 1...10 {
                    continuation.yield(i)
                }
                continuation.finish()
            }
        }

        // Complex pipeline: filter evens, square them, convert to string
        let transformed = stream
            .filter { $0 % 2 == 0 }
            .map { $0 * $0 }
            .map { "Number: \($0)" }

        var results: [String] = []
        for try await value in transformed {
            results.append(value)
        }

        #expect(results == [
            "Number: 4", // 2^2
            "Number: 16", // 4^2
            "Number: 36", // 6^2
            "Number: 64", // 8^2
            "Number: 100", // 10^2
        ])
    }
}
