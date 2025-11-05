import Foundation
import Testing
@testable import Tachikoma

@Suite("Simple Configuration Tests")
struct SimpleConfigurationTests {
    @Test("Provider enum basic functionality")
    func providerEnumBasics() {
        #expect(Provider.openai.identifier == "openai")
        #expect(Provider.anthropic.identifier == "anthropic")
        #expect(Provider.custom("test").identifier == "test")
    }

    @Test("Provider factory method")
    func providerFactory() {
        #expect(Provider.from(identifier: "openai") == .openai)
        #expect(Provider.from(identifier: "custom-provider") == .custom("custom-provider"))
    }

    @Test("Configuration instance basic functionality")
    func configurationInstance() {
        let config = TachikomaConfiguration(loadFromEnvironment: false)

        // Set keys directly
        config.setAPIKey("test-key", for: .openai)

        // Should get configured key
        #expect(config.getAPIKey(for: .openai) == "test-key")
        #expect(config.hasConfiguredAPIKey(for: .openai))

        // Should not have keys for other providers
        #expect(config.getAPIKey(for: .anthropic) == nil)
    }

    @Test("Multiple configuration instances are isolated")
    func multipleInstancesIsolated() {
        let config1 = TachikomaConfiguration(loadFromEnvironment: false)
        let config2 = TachikomaConfiguration(loadFromEnvironment: false)

        config1.setAPIKey("key1", for: .openai)
        config2.setAPIKey("key2", for: .openai)

        #expect(config1.getAPIKey(for: .openai) == "key1")
        #expect(config2.getAPIKey(for: .openai) == "key2")
    }
}
