#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Testing
@testable import Tachikoma
@testable import TachikomaAudio

@Suite("Audio Provider Factories", .serialized)
struct AudioProviderFactoryTests {
    @Test("TranscriptionProviderFactory returns mock provider in test mode")
    func transcriptionFactoryReturnsMockInTestMode() throws {
        let previousTestMode = getenv("TACHIKOMA_TEST_MODE").flatMap { String(cString: $0) }
        setenv("TACHIKOMA_TEST_MODE", "mock", 1)
        defer {
            if let previousTestMode {
                setenv("TACHIKOMA_TEST_MODE", previousTestMode, 1)
            } else {
                unsetenv("TACHIKOMA_TEST_MODE")
            }
        }

        let configuration = TachikomaConfiguration(loadFromEnvironment: false)
        configuration.setAPIKey("test-key", for: "openai")

        let provider = try TranscriptionProviderFactory.createProvider(
            for: .openai(.whisper1),
            configuration: configuration,
        )

        #expect(provider is MockTranscriptionProvider)
    }

    @Test("TranscriptionProviderFactory requires API key in test mode")
    func transcriptionFactoryRequiresAPIKeyInTestMode() {
        let previousTestMode = getenv("TACHIKOMA_TEST_MODE").flatMap { String(cString: $0) }
        setenv("TACHIKOMA_TEST_MODE", "mock", 1)
        defer {
            if let previousTestMode {
                setenv("TACHIKOMA_TEST_MODE", previousTestMode, 1)
            } else {
                unsetenv("TACHIKOMA_TEST_MODE")
            }
        }

        let configuration = TachikomaConfiguration(loadFromEnvironment: false)

        do {
            _ = try TranscriptionProviderFactory
                .createProvider(for: .openai(.whisper1), configuration: configuration)
            Issue.record("Expected authentication failure when API key missing")
        } catch let TachikomaError.authenticationFailed(message) {
            #expect(message.contains("OPENAI_API_KEY"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("SpeechProviderFactory returns mock provider in test mode")
    func speechFactoryReturnsMockInTestMode() throws {
        let previousTestMode = getenv("TACHIKOMA_TEST_MODE").flatMap { String(cString: $0) }
        setenv("TACHIKOMA_TEST_MODE", "mock", 1)
        defer {
            if let previousTestMode {
                setenv("TACHIKOMA_TEST_MODE", previousTestMode, 1)
            } else {
                unsetenv("TACHIKOMA_TEST_MODE")
            }
        }

        let configuration = TachikomaConfiguration()
        configuration.setAPIKey("speech-key", for: "openai")

        let provider = try SpeechProviderFactory.createProvider(
            for: .openai(.tts1),
            configuration: configuration,
        )

        #expect(provider is MockSpeechProvider)
    }

    @Test("AudioConfiguration reads configuration keys before environment")
    func audioConfigurationPrefersExplicitConfiguration() {
        let previousOpenAIKey = getenv("OPENAI_API_KEY").flatMap { String(cString: $0) }
        unsetenv("OPENAI_API_KEY")
        defer {
            if let previousOpenAIKey {
                setenv("OPENAI_API_KEY", previousOpenAIKey, 1)
            }
        }

        let configuration = TachikomaConfiguration()
        configuration.setAPIKey("configured-key", for: "openai")

        let resolvedKey = AudioConfiguration.getAPIKey(for: "openai", configuration: configuration)
        #expect(resolvedKey == "configured-key")
    }

    @Test("AudioConfiguration falls back to environment variable")
    func audioConfigurationFallsBackToEnvironment() {
        let previousOpenAIKey = getenv("OPENAI_API_KEY").flatMap { String(cString: $0) }
        setenv("OPENAI_API_KEY", "env-key-123", 1)
        defer {
            if let previousOpenAIKey {
                setenv("OPENAI_API_KEY", previousOpenAIKey, 1)
            } else {
                unsetenv("OPENAI_API_KEY")
            }
        }

        let expectedKey = getenv("OPENAI_API_KEY").map { String(cString: $0) }
        let resolvedKey = AudioConfiguration.getAPIKey(
            for: "openai",
            configuration: TachikomaConfiguration(loadFromEnvironment: false),
        )
        if let expectedKey {
            #expect(resolvedKey == expectedKey)
        } else {
            Issue.record("Expected environment override for OPENAI_API_KEY")
        }
    }
}
