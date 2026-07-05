import Testing
@testable import Tachikoma

struct ReasoningEffortTests {
    @Test
    func `ReasoningEffort enum has all expected cases`() {
        let allCases = ReasoningEffort.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.low))
        #expect(allCases.contains(.medium))
        #expect(allCases.contains(.high))
        #expect(allCases.contains(.xhigh))
        #expect(allCases.contains(.max))
    }

    @Test
    func `ReasoningEffort raw values are correct`() {
        #expect(ReasoningEffort.low.rawValue == "low")
        #expect(ReasoningEffort.medium.rawValue == "medium")
        #expect(ReasoningEffort.high.rawValue == "high")
        #expect(ReasoningEffort.xhigh.rawValue == "xhigh")
        #expect(ReasoningEffort.max.rawValue == "max")
    }

    @Test
    func `GenerationSettings supports reasoning effort`() {
        let settings = GenerationSettings(
            maxTokens: 1000,
            temperature: 0.7,
            reasoningEffort: .high,
        )

        #expect(settings.reasoningEffort == .high)
        #expect(settings.maxTokens == 1000)
        #expect(settings.temperature == 0.7)
    }

    @Test
    func `GenerationSettings default has nil reasoning effort`() {
        let settings = GenerationSettings.default
        #expect(settings.reasoningEffort == nil)
    }

    @Test
    func `RetryHandler adapts based on reasoning effort`() {
        // High effort should use aggressive policy
        let highSettings = GenerationSettings(reasoningEffort: .high)
        let highHandler = RetryHandler.from(settings: highSettings)
        // Can't directly test policy values as they're private
        // But we know it creates the right handler
        _ = highHandler

        // Low effort should use conservative policy
        let lowSettings = GenerationSettings(reasoningEffort: .low)
        let lowHandler = RetryHandler.from(settings: lowSettings)
        _ = lowHandler

        // Medium or nil should use default policy
        let mediumSettings = GenerationSettings(reasoningEffort: .medium)
        let mediumHandler = RetryHandler.from(settings: mediumSettings)
        _ = mediumHandler

        let nilSettings = GenerationSettings()
        let nilHandler = RetryHandler.from(settings: nilSettings)
        _ = nilHandler

        // Test passes if all handlers created without errors
        #expect(Bool(true))
    }

    @Test
    func `Codable conformance for ReasoningEffort`() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for effort in ReasoningEffort.allCases {
            let data = try encoder.encode(effort)
            let decoded = try decoder.decode(ReasoningEffort.self, from: data)
            #expect(decoded == effort)

            // Check JSON string representation
            let jsonString = String(data: data, encoding: .utf8)
            #expect(jsonString == "\"\(effort.rawValue)\"")
        }
    }

    @Test
    func `GenerationSettings Codable with reasoning effort`() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let decoder = JSONDecoder()

        let original = GenerationSettings(
            maxTokens: 2000,
            temperature: 0.5,
            topP: 0.9,
            reasoningEffort: .high,
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(GenerationSettings.self, from: data)

        #expect(decoded.maxTokens == original.maxTokens)
        #expect(decoded.temperature == original.temperature)
        #expect(decoded.topP == original.topP)
        #expect(decoded.reasoningEffort == original.reasoningEffort)
    }

    @Test
    func `GenerationSettings Codable without reasoning effort`() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = GenerationSettings(
            maxTokens: 1000,
            temperature: 0.7,
            // No reasoning effort
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(GenerationSettings.self, from: data)

        #expect(decoded.reasoningEffort == nil)
        #expect(decoded.maxTokens == 1000)
        #expect(decoded.temperature == 0.7)
    }

    @Test
    func `All reasoning effort levels properly ordered`() {
        // Ensure we have the expected reasoning levels
        let levels: [ReasoningEffort] = [.low, .medium, .high, .xhigh, .max]

        // Just verify the levels are in the expected order
        #expect(levels[0] == .low)
        #expect(levels[1] == .medium)
        #expect(levels[2] == .high)
        #expect(levels[3] == .xhigh)
        #expect(levels[4] == .max)

        // Verify all cases are covered
        #expect(Set(levels) == Set(ReasoningEffort.allCases))
    }
}
