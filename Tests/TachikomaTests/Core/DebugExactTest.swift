import Foundation
import Testing
@testable import Tachikoma

@Suite("Debug Exact Test")
struct DebugExactTests {
    @Test("Replicate failing test exactly")
    func replicateFailingTest() async throws {
        print("=== Starting exact replication ===")

        await TestHelpers.withEmptyTestConfiguration { config in
            print("Before setting keys:")
            print("  openai: \(config.getAPIKey(for: .openai) ?? "nil")")
            print("  anthropic: \(config.getAPIKey(for: .anthropic) ?? "nil")")
            print("  custom: \(config.getAPIKey(for: .custom("my-provider")) ?? "nil")")

            config.setAPIKey("test-openai-key", for: .openai)
            config.setAPIKey("test-anthropic-key", for: .anthropic)
            config.setAPIKey("test-custom-key", for: .custom("my-provider"))

            print("After setting keys:")
            print("  openai: \(config.getAPIKey(for: .openai) ?? "nil")")
            print("  anthropic: \(config.getAPIKey(for: .anthropic) ?? "nil")")
            print("  custom: \(config.getAPIKey(for: .custom("my-provider")) ?? "nil")")

            // The actual expectations from the test
            let openaiKey = config.getAPIKey(for: .openai)
            let anthropicKey = config.getAPIKey(for: .anthropic)
            let customKey = config.getAPIKey(for: .custom("my-provider"))

            print("Final check:")
            print("  openai == 'test-openai-key': \(openaiKey == "test-openai-key")")
            print("  anthropic == 'test-anthropic-key': \(anthropicKey == "test-anthropic-key")")
            print("  custom == 'test-custom-key': \(customKey == "test-custom-key")")
        }

        print("=== Test completed ===")
    }
}
