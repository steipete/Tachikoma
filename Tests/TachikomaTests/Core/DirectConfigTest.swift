import Foundation
import Testing
@testable import Tachikoma

@Suite("Direct Configuration Tests")
struct DirectConfigTests {
    @Test("Direct configuration access")
    func directConfigAccess() {
        let config = TachikomaConfiguration(loadFromEnvironment: false)

        // Just test basic access without test helpers
        _ = config.configuredProviders

        #expect(Bool(true)) // If we get here, no infinite loop
    }

    @Test("Provider enum direct access")
    func providerEnumDirect() {
        let provider = Provider.openai
        #expect(provider.identifier == "openai")
        #expect(provider.displayName == "OpenAI")
    }

    @Test("Configuration instance creation")
    func configurationInstanceCreation() {
        let config1 = TachikomaConfiguration()
        let config2 = TachikomaConfiguration(loadFromEnvironment: false)
        let config3 = TachikomaConfiguration(apiKeys: ["openai": "test"])

        // All should be valid instances; explicit config ignores environment
        #expect(config2.configuredProviders.isEmpty)
        #expect(config3.hasAPIKey(for: .openai))
        #expect(!config3.configuredProviders.isEmpty)
        _ = config1.summary // Access to ensure no crashes with environment-loaded values
    }
}
