import Foundation
import Testing
@testable import Tachikoma

@Suite("Configuration environment loading", .serialized)
struct ConfigurationEnvironmentTests {
    @Test("Provider.environmentValue falls back to process environment")
    func providerEnvironmentValueFallback() {
        let key = "TACHIKOMA_ENV_TEST_VALUE"
        setenv(key, "env-success", 1)
        defer { unsetenv(key) }

        let value = Provider.environmentValue(for: key)
        #expect(value == "env-success")
    }

    @Test("TachikomaConfiguration picks up base URLs from environment")
    func configurationLoadsBaseURLFromEnvironment() {
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
}
