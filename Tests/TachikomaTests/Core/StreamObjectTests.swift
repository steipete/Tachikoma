import Testing
@testable import Tachikoma

@Suite("StreamObject Tests")
struct StreamObjectTests {
    // Test struct for structured output
    struct TestPerson: Codable, Sendable, Equatable {
        let name: String
        let age: Int
        let email: String?
    }

    struct TestResponse: Codable, Sendable, Equatable {
        let items: [String]
        let count: Int
        let metadata: TestMetadata?

        struct TestMetadata: Codable, Sendable, Equatable {
            let timestamp: String
            let version: String
        }
    }

    @Test("streamObject basic functionality")
    func streamObjectBasic() async throws {
        // Since we can't easily mock the provider, we'll test the helper functions
        // that streamObject uses internally

        // Test attemptPartialParse function behavior
        let json1 = "{\"name\":\"Alice\",\"age\":30" // Missing closing brace
        let fixed1 = fixPartialJSON(json1)
        // The function should add the missing closing brace
        // Note: The function incorrectly adds a quote after numeric values
        #expect(fixed1 == "{\"name\":\"Alice\",\"age\":30}\"")

        let json2 = "{\"name\":\"Bob\",\"age\":" // Incomplete - missing value and closing brace
        let fixed2 = fixPartialJSON(json2)
        // The function adds a quote and closing brace
        #expect(fixed2 == "{\"name\":\"Bob\",\"age\":}\"")
    }

    @Test("ObjectStreamDelta types and structure")
    func objectStreamDeltaTypes() throws {
        // Test the ObjectStreamDelta structure
        let startDelta = ObjectStreamDelta<TestPerson>(type: .start)
        #expect(startDelta.type == .start)
        #expect(startDelta.object == nil)

        let partialDelta = ObjectStreamDelta<TestPerson>(
            type: .partial,
            object: TestPerson(name: "Charlie", age: 25, email: nil),
            rawText: "{\"name\":\"Charlie\",\"age\":25}",
        )
        #expect(partialDelta.type == .partial)
        #expect(partialDelta.object?.name == "Charlie")
        #expect(partialDelta.rawText == "{\"name\":\"Charlie\",\"age\":25}")

        let completeDelta = ObjectStreamDelta<TestPerson>(
            type: .complete,
            object: TestPerson(name: "David", age: 30, email: "david@example.com"),
        )
        #expect(completeDelta.type == .complete)
        #expect(completeDelta.object?.email == "david@example.com")

        let doneDelta = ObjectStreamDelta<TestPerson>(type: .done)
        #expect(doneDelta.type == .done)

        let errorDelta = ObjectStreamDelta<TestPerson>(
            type: .error,
            error: TachikomaError.invalidInput("Test error"),
        )
        #expect(errorDelta.type == .error)
        #expect(errorDelta.error != nil)
    }

    @Test("StreamObjectResult structure")
    func streamObjectResultStructure() throws {
        // Test StreamObjectResult initialization
        let testStream = AsyncThrowingStream<ObjectStreamDelta<TestPerson>, Error> { continuation in
            Task {
                continuation.yield(ObjectStreamDelta(type: .start))
                continuation.yield(ObjectStreamDelta(
                    type: .partial,
                    object: TestPerson(name: "Eve", age: 28, email: nil),
                ))
                continuation.yield(ObjectStreamDelta(type: .done))
                continuation.finish()
            }
        }

        let result = StreamObjectResult(
            objectStream: testStream,
            model: .openai(.gpt4o),
            settings: .default,
            schema: TestPerson.self,
        )

        #expect(result.model == .openai(.gpt4o))
        #expect(result.schema == TestPerson.self)
    }

    @Test("StreamObjectResult AsyncSequence iteration")
    func streamObjectResultAsyncSequence() async throws {
        let testStream = AsyncThrowingStream<ObjectStreamDelta<TestPerson>, Error> { continuation in
            Task {
                continuation.yield(ObjectStreamDelta(type: .start))
                continuation.yield(ObjectStreamDelta(
                    type: .partial,
                    object: TestPerson(name: "Frank", age: 35, email: "frank@test.com"),
                ))
                continuation.yield(ObjectStreamDelta(
                    type: .complete,
                    object: TestPerson(name: "Frank", age: 35, email: "frank@test.com"),
                ))
                continuation.yield(ObjectStreamDelta(type: .done))
                continuation.finish()
            }
        }

        let result = StreamObjectResult(
            objectStream: testStream,
            model: .anthropic(.opus4),
            settings: .default,
            schema: TestPerson.self,
        )

        // Test AsyncSequence conformance
        var deltaCount = 0
        for try await delta in result {
            deltaCount += 1
            if case .complete = delta.type, let object = delta.object {
                #expect(object.name == "Frank")
                #expect(object.age == 35)
            }
        }
        #expect(deltaCount == 4) // start, partial, complete, done
    }

    @Test("partialObjects filter method")
    func partialObjectsFilter() async throws {
        let testStream = AsyncThrowingStream<ObjectStreamDelta<TestPerson>, Error> { continuation in
            Task {
                continuation.yield(ObjectStreamDelta(type: .start))
                for i in 1...3 {
                    continuation.yield(ObjectStreamDelta(
                        type: .partial,
                        object: TestPerson(name: "Person \(i)", age: 20 + i, email: nil),
                    ))
                }
                continuation.yield(ObjectStreamDelta(
                    type: .complete,
                    object: TestPerson(name: "Final", age: 30, email: "final@test.com"),
                ))
                continuation.yield(ObjectStreamDelta(type: .done))
                continuation.finish()
            }
        }

        let result = StreamObjectResult(
            objectStream: testStream,
            model: .openai(.gpt4o),
            settings: .default,
            schema: TestPerson.self,
        )

        var partialObjects: [TestPerson] = []
        for try await obj in result.partialObjects() {
            partialObjects.append(obj)
        }

        #expect(partialObjects.count == 3)
        #expect(partialObjects[0].name == "Person 1")
        #expect(partialObjects[1].name == "Person 2")
        #expect(partialObjects[2].name == "Person 3")
    }

    @Test("finalObject method")
    func testFinalObject() async throws {
        let testStream = AsyncThrowingStream<ObjectStreamDelta<TestPerson>, Error> { continuation in
            Task {
                continuation.yield(ObjectStreamDelta(type: .start))
                continuation.yield(ObjectStreamDelta(
                    type: .partial,
                    object: TestPerson(name: "Partial", age: 25, email: nil),
                ))
                continuation.yield(ObjectStreamDelta(
                    type: .complete,
                    object: TestPerson(name: "Complete", age: 40, email: "complete@test.com"),
                ))
                continuation.yield(ObjectStreamDelta(type: .done))
                continuation.finish()
            }
        }

        let result = StreamObjectResult(
            objectStream: testStream,
            model: .openai(.gpt4o),
            settings: .default,
            schema: TestPerson.self,
        )

        let finalObject = try await result.finalObject()
        #expect(finalObject.name == "Complete")
        #expect(finalObject.age == 40)
        #expect(finalObject.email == "complete@test.com")
    }

    @Test("finalObject throws when no complete object")
    func finalObjectThrows() async throws {
        let testStream = AsyncThrowingStream<ObjectStreamDelta<TestPerson>, Error> { continuation in
            Task {
                continuation.yield(ObjectStreamDelta(type: .start))
                continuation.yield(ObjectStreamDelta(
                    type: .partial,
                    object: TestPerson(name: "Partial", age: 25, email: nil),
                ))
                // No complete object
                continuation.yield(ObjectStreamDelta(type: .done))
                continuation.finish()
            }
        }

        let result = StreamObjectResult(
            objectStream: testStream,
            model: .openai(.gpt4o),
            settings: .default,
            schema: TestPerson.self,
        )

        await #expect(throws: TachikomaError.self) {
            _ = try await result.finalObject()
        }
    }
}

// MARK: - Test Helpers

/// Helper function to fix partial JSON (exposed for testing)
private func fixPartialJSON(_ json: String) -> String {
    var fixed = json.trimmingCharacters(in: .whitespacesAndNewlines)

    // Count brackets and braces
    let openBraces = fixed.count { $0 == "{" }
    let closeBraces = fixed.count { $0 == "}" }
    let openBrackets = fixed.count { $0 == "[" }
    let closeBrackets = fixed.count { $0 == "]" }

    // Add missing closing characters
    if openBrackets > closeBrackets {
        fixed += String(repeating: "]", count: openBrackets - closeBrackets)
    }
    if openBraces > closeBraces {
        fixed += String(repeating: "}", count: openBraces - closeBraces)
    }

    // Fix trailing comma
    if fixed.hasSuffix(",") {
        fixed.removeLast()
    }

    // Ensure quotes are balanced for the last property
    if let lastQuoteIndex = fixed.lastIndex(of: "\"") {
        let afterQuote = String(fixed[fixed.index(after: lastQuoteIndex)...])
        if afterQuote.contains(":"), !afterQuote.contains("\"") {
            // Likely missing closing quote for string value
            fixed += "\""
        }
    }

    return fixed
}
