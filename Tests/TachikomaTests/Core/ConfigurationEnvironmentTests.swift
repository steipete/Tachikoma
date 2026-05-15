import Foundation
import Testing
@testable import Tachikoma

@Suite(.serialized)
struct ConfigurationEnvironmentTests {
    @Test
    func `Provider.environmentValue falls back to process environment`() {
        let key = "TACHIKOMA_ENV_TEST_VALUE"
        setenv(key, "env-success", 1)
        defer { unsetenv(key) }

        let value = Provider.environmentValue(for: key)
        #expect(value == "env-success")
    }

    @Test
    func `TachikomaConfiguration picks up base URLs from environment`() {
        let key = "OPENAI_BASE_URL"
        setenv(key, "https://env.example.com", 1)
        defer { unsetenv(key) }

        if let pointer = getenv(key) {
            let manual = String(cString: pointer)
            #expect(manual == "https://env.example.com")
        } else {
            Issue.record("getenv returned nil for \(key)")
        }

        let rawValue = Provider.environmentValue(for: key)
        #expect(rawValue == "https://env.example.com")

        let configuration = TachikomaConfiguration(loadFromEnvironment: true)
        #expect(configuration.getBaseURL(for: .openai) == "https://env.example.com")
    }

    @Test
    func `TachikomaConfiguration picks up ANTHROPIC_BASE_URL from environment`() {
        let key = "ANTHROPIC_BASE_URL"
        setenv(key, "https://env.example.com", 1)
        defer { unsetenv(key) }

        let rawValue = Provider.environmentValue(for: key)
        #expect(rawValue == "https://env.example.com")

        let configuration = TachikomaConfiguration(loadFromEnvironment: true)
        #expect(configuration.getBaseURL(for: .anthropic) == "https://env.example.com")
    }
}
