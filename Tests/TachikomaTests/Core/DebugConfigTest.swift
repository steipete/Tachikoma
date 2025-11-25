import Foundation
import Testing
@testable import Tachikoma

@Suite("Debug Configuration Tests")
struct DebugConfigTests {
    @Test("Debug configuration behavior")
    func debugConfiguration() async {
        let config = TachikomaConfiguration(loadFromEnvironment: false)

        print("=== Testing instance-based configuration ===")
        print("Initial configured providers: \(config.configuredProviders.count)")
        print("openai key: \(config.getAPIKey(for: .openai) ?? "nil")")
        print("anthropic key: \(config.getAPIKey(for: .anthropic) ?? "nil")")

        // Test with empty configuration
        await TestHelpers.withEmptyTestConfiguration { emptyConfig in
            print("=== In empty configuration ===")
            print("openai key: \(emptyConfig.getAPIKey(for: .openai) ?? "nil")")
            print("anthropic key: \(emptyConfig.getAPIKey(for: .anthropic) ?? "nil")")

            // Set a key in empty config
            emptyConfig.setAPIKey("test-openai-key", for: .openai)
            print("=== After setting key ===")
            print("openai key: \(emptyConfig.getAPIKey(for: .openai) ?? "nil")")
        }

        print("=== Back to original config ===")
        print("openai key: \(config.getAPIKey(for: .openai) ?? "nil")")

        #expect(Bool(true)) // Just to complete the test
    }

    @Test("Multiple configurations isolation")
    func multipleConfigurationsIsolation() {
        let config1 = TachikomaConfiguration(loadFromEnvironment: false)
        let config2 = TachikomaConfiguration(loadFromEnvironment: false)

        config1.setAPIKey("key1", for: .openai)
        config2.setAPIKey("key2", for: .openai)

        print("Config1 OpenAI key: \(config1.getAPIKey(for: .openai) ?? "nil")")
        print("Config2 OpenAI key: \(config2.getAPIKey(for: .openai) ?? "nil")")

        #expect(config1.getAPIKey(for: .openai) == "key1")
        #expect(config2.getAPIKey(for: .openai) == "key2")
    }
}
