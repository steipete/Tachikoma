import Foundation
import Testing
@testable import Tachikoma

@Suite("Test Helpers Tests", .serialized)
struct TestHelpersTests {
    @Test("Test helper create configuration")
    func helperCreateConfiguration() {
        let config = TestHelpers.createTestConfiguration(apiKeys: ["openai": "test-key"])
        let expected = TestHelpers.standardTestKeys["openai"]

        #expect(config.getAPIKey(for: .openai) == expected)
        #expect(config.hasConfiguredAPIKey(for: .openai))
    }

    @Test("Test helper with empty configuration")
    func helperEmptyConfiguration() async {
        let result = await TestHelpers.withEmptyTestConfiguration { config in
            config.getAPIKey(for: .openai)
        }

        // Should be nil in empty configuration
        #expect(result == nil)
    }

    @Test("Test helper with standard test configuration")
    func helperStandardConfiguration() async {
        let result = await TestHelpers.withStandardTestConfiguration { config in
            config.getAPIKey(for: .openai)
        }

        let expected = TestHelpers.standardTestKeys["openai"] ?? "test-key"
        #expect(result == expected || result == "test-key")
    }

    @Test("Test helper with selective configuration")
    func helperSelectiveConfiguration() async {
        let result = await TestHelpers.withSelectiveTestConfiguration(present: ["openai"]) { config in
            (config.getAPIKey(for: .openai), config.getAPIKey(for: .anthropic))
        }

        // Should have OpenAI key (resolved against current env if present) but not Anthropic
        let expected = TestHelpers.standardTestKeys["openai"] ?? "test-key"
        #expect(result.0 == expected || result.0 == "test-key")
        #expect(result.1 == nil)
    }
}
