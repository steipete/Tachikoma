import Foundation
import Testing
@testable import Tachikoma

struct StreamTransformTests {
    @Test
    func `FilterTransform filters elements correctly`() async throws {
        let transform = FilterTransform<Int> { $0 % 2 == 0 }

        #expect(try await transform.transform(2) == 2)
        #expect(try await transform.transform(3) == nil)
        #expect(try await transform.transform(4) == 4)
        #expect(try await transform.transform(5) == nil)
    }

    @Test
    func `MapTransform transforms elements`() async throws {
        let transform = MapTransform<Int, String> { "\($0 * 2)" }

        #expect(try await transform.transform(5) == "10")
        #expect(try await transform.transform(3) == "6")
    }

    @Test
    func `BufferTransform batches elements`() async throws {
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

    @Test
    func `BufferTransform with time interval`() async throws {
        var lastFlushStarted = Date()
        let transform = BufferTransform<Int>(bufferSize: 10, flushInterval: 0.1)
        var pending: [Int] = []

        for value in 1...2 {
            let callStarted = Date()
            pending.append(value)
            if let batch = try await transform.transform(value) {
                // A delayed call may flush, but never before the interval or with missing values.
                #expect(Date().timeIntervalSince(lastFlushStarted) >= 0.1)
                #expect(batch == pending)
                pending = []
                lastFlushStarted = callStarted
            }
        }

        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        pending.append(3)
        #expect(try await transform.transform(3) == pending)
        #expect(await transform.flush() == nil)
    }

    @Test
    func `ThrottleTransform limits rate`() async throws {
        let transform = ThrottleTransform<String>(interval: 0.1)
        var previousEmissionStarted: Date?
        var emitted: [String] = []

        for value in ["first", "second", "third"] {
            let callStarted = Date()
            if let output = try await transform.transform(value) {
                if let previousEmissionStarted {
                    // These bounds enclose the actual emission times, including actor scheduling.
                    #expect(Date().timeIntervalSince(previousEmissionStarted) >= 0.1)
                }
                #expect(output == value)
                previousEmissionStarted = callStarted
                emitted.append(output)
            }
        }

        #expect(emitted.first == "first")
    }

    @Test
    func `ThrottleTransform suppresses until its window reopens`() async throws {
        // A window that never reopens proves suppression without a scheduling deadline.
        let transform = ThrottleTransform<String>(interval: .infinity)

        // First element passes through
        #expect(try await transform.transform("first") == "first")

        // Later elements are throttled regardless of executor delays.
        #expect(try await transform.transform("second") == nil)
        #expect(try await transform.transform("third") == nil)
    }

    @Test
    func `ThrottleTransform reopens after its interval`() async throws {
        let transform = ThrottleTransform<String>(interval: 0.1)
        #expect(try await transform.transform("first") == "first")

        // Start waiting after the first emission, so the next call cannot be too early.
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        #expect(try await transform.transform("second") == "second")
    }

    @Test
    func `TapTransform adds side effects`() async throws {
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

    @Test
    func `Stream filter extension works`() async throws {
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

    @Test
    func `Stream map extension works`() async throws {
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

    @Test
    func `Stream tap extension works`() async throws {
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

    @Test
    func `Stream buffer extension works`() async throws {
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

    @Test(arguments: [0.0, Double.infinity])
    func `Stream throttle extension works`(interval: Double) async throws {
        let stream = AsyncThrowingStream<Int, Error> { continuation in
            for i in 1...5 {
                continuation.yield(i)
            }
            continuation.finish()
        }

        let throttled = stream.throttle(interval: interval)

        var results: [Int] = []
        for try await value in throttled {
            results.append(value)
        }

        // Exact outputs for both boundaries, independent of producer/consumer scheduling.
        #expect(results == (interval == 0 ? [1, 2, 3, 4, 5] : [1]))
    }

    @Test
    func `Stream throttle reopens after its interval`() async throws {
        let source = ThrottleIntervalSource()
        let stream = AsyncThrowingStream<Int, any Error> { try await source.next() }
        var results: [Int] = []

        for try await value in stream.throttle(interval: 0.03) {
            results.append(value)
        }

        #expect(results == [1, 2, 3, 4, 5])
    }

    @Test
    func `StreamTextResult filter extension works`() async throws {
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
            model: .openai(.gpt55),
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

    @Test
    func `StreamTextResult collectText works`() async throws {
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
            model: .openai(.gpt55),
            settings: .default,
        )

        var texts: [String] = []
        for try await text in result.collectText() {
            texts.append(text)
        }

        #expect(texts == ["Hello", " ", "World"])
    }

    @Test
    func `StreamTextResult fullText works`() async throws {
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
            model: .openai(.gpt55),
            settings: .default,
        )

        let fullText = try await result.fullText()
        #expect(fullText == "The quick brown fox")
    }

    @Test
    func `CombinedTransform chains transforms`() async throws {
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

    @Test
    func `Transform chain with complex pipeline`() async throws {
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

private actor ThrottleIntervalSource {
    private var value = 0

    func next() async throws -> Int? {
        guard self.value < 5 else { return nil }
        if self.value > 0 {
            // Unfolding is pulled again only after the previous transform has completed.
            try await Task.sleep(for: .milliseconds(30))
        }
        self.value += 1
        return self.value
    }
}
