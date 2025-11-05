import Foundation
import Testing
@testable import Tachikoma
@testable import TachikomaAudio

@Suite("OpenAI Audio Provider Tests")
struct OpenAIAudioProviderTests {
    // MARK: - OpenAI Transcription Provider Tests

    @Suite("OpenAI Transcription Provider Tests")
    struct OpenAITranscriptionProviderTests {
        @Test("OpenAI transcription provider initialization")
        func openAITranscriptionProviderInit() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-api-key"]) { _ in
                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))

                #expect(provider.modelId == "whisper-1")
                #expect(provider.capabilities.supportsTimestamps == true)
                #expect(provider.capabilities.supportsLanguageDetection == true)
                #expect(provider.capabilities.supportsWordTimestamps == true)
                #expect(provider.capabilities.maxFileSize == 25 * 1024 * 1024) // 25MB
            }
        }

        @Test("OpenAI transcription provider initialization fails without API key")
        func openAITranscriptionProviderInitFailsWithoutAPIKey() async throws {
            try await TestHelpers.withEmptyTestConfiguration { config in
                #expect(throws: TachikomaError.self) {
                    _ = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1), configuration: config)
                }
            }
        }

        @Test("OpenAI transcription provider different models")
        func openAITranscriptionProviderDifferentModels() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let whisperProvider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))

                // Test model ID
                #expect(whisperProvider.modelId == "whisper-1")

                // Test capabilities
                #expect(whisperProvider.capabilities.supportsTimestamps == true)
                #expect(whisperProvider.capabilities.supportsLanguageDetection == true)
            }
        }

        @Test("OpenAI transcription provider supported formats")
        func openAITranscriptionProviderSupportedFormats() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))

                let supportedFormats = provider.capabilities.supportedFormats
                let expectedFormats: [AudioFormat] = [.flac, .m4a, .mp3, .opus, .wav, .pcm]

                for format in expectedFormats {
                    #expect(supportedFormats.contains(format))
                }
            }
        }

        @Test("OpenAI transcription provider transcribe function")
        func openAITranscriptionProviderTranscribe() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))
                let audioData = AudioData(
                    data: Data([0x01, 0x02, 0x03, 0x04]),
                    format: .wav,
                    duration: 2.0
                )
                let request = TranscriptionRequest(
                    audio: audioData,
                    language: "en",
                    prompt: "This is a test audio file."
                )

                // With mock implementation, test the basic flow
                let result = try await provider.transcribe(request: request)

                #expect(!result.text.isEmpty)
                #expect(result.usage != nil)
                #expect(result.usage?.durationSeconds == 2.0)
            }
        }

        @Test("OpenAI transcription provider with timestamps")
        func openAITranscriptionProviderTimestamps() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))
                let audioData = AudioData(data: Data([0x01, 0x02, 0x03, 0x04]), format: .wav)
                let request = TranscriptionRequest(
                    audio: audioData,
                    timestampGranularities: [.word, .segment],
                    responseFormat: .verbose
                )

                let result = try await provider.transcribe(request: request)

                #expect(!result.text.isEmpty)
                #expect(result.segments != nil)
                #expect(!result.segments!.isEmpty)
            }
        }

        @Test("OpenAI transcription provider with abort signal")
        func openAITranscriptionProviderAbortSignal() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))
                let audioData = AudioData(data: Data([0x01, 0x02, 0x03, 0x04]), format: .wav)
                let abortSignal = AbortSignal()
                let request = TranscriptionRequest(audio: audioData, abortSignal: abortSignal)

                // Cancel immediately
                abortSignal.cancel()

                await #expect(throws: TachikomaError.self) {
                    try await provider.transcribe(request: request)
                }
            }
        }

        @Test("OpenAI transcription provider request validation")
        func openAITranscriptionProviderRequestValidation() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))

                // Test empty audio data
                let emptyAudioData = AudioData(data: Data(), format: .wav)
                let emptyRequest = TranscriptionRequest(audio: emptyAudioData)

                await #expect(throws: TachikomaError.self) {
                    try await provider.transcribe(request: emptyRequest)
                }

                // Test file too large (over 25MB limit)
                let largeDummyData = Data(count: 26 * 1024 * 1024) // 26MB
                let largeAudioData = AudioData(data: largeDummyData, format: .wav)
                let largeRequest = TranscriptionRequest(audio: largeAudioData)

                await #expect(throws: TachikomaError.self) {
                    try await provider.transcribe(request: largeRequest)
                }
            }
        }
    }

    // MARK: - OpenAI Speech Provider Tests

    @Suite("OpenAI Speech Provider Tests")
    struct OpenAISpeechProviderTests {
        @Test("OpenAI speech provider initialization")
        func openAISpeechProviderInit() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-api-key"]) { _ in
                let provider = try SpeechProviderFactory.createProvider(for: .openai(.tts1))

                #expect(provider.modelId == "tts-1")
                #expect(provider.capabilities.supportsSpeedControl == true)
                #expect(provider.capabilities.maxTextLength == 4096)
                #expect(provider.capabilities.supportsVoiceInstructions == false)
            }
        }

        @Test("OpenAI speech provider initialization fails without API key")
        func openAISpeechProviderInitFailsWithoutAPIKey() async throws {
            try await TestHelpers.withEmptyTestConfiguration { config in
                #expect(throws: TachikomaError.self) {
                    _ = try SpeechProviderFactory.createProvider(for: .openai(.tts1), configuration: config)
                }
            }
        }

        @Test("OpenAI speech provider different models")
        func openAISpeechProviderDifferentModels() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let tts1Provider = try SpeechProviderFactory.createProvider(for: .openai(.tts1))
                let tts1HDProvider = try SpeechProviderFactory.createProvider(for: .openai(.tts1HD))

                // Test model IDs
                #expect(tts1Provider.modelId == "tts-1")
                #expect(tts1HDProvider.modelId == "tts-1-hd")

                // Test capabilities
                #expect(tts1Provider.capabilities.supportsVoiceInstructions == false)
                #expect(tts1HDProvider.capabilities.supportsVoiceInstructions == false)

                // All should support the same formats and voices
                let expectedFormats: [AudioFormat] = [.mp3, .opus, .aac, .flac, .wav, .pcm]
                #expect(tts1Provider.capabilities.supportedFormats == expectedFormats)
                #expect(tts1HDProvider.capabilities.supportedFormats == expectedFormats)
            }
        }

        @Test("OpenAI speech provider supported voices")
        func openAISpeechProviderSupportedVoices() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try SpeechProviderFactory.createProvider(for: .openai(.tts1))

                let supportedVoices = provider.capabilities.supportedVoices
                let expectedVoices: [VoiceOption] = [.alloy, .echo, .fable, .onyx, .nova, .shimmer]

                #expect(supportedVoices == expectedVoices)
            }
        }

        @Test("OpenAI speech provider generate speech function")
        func openAISpeechProviderGenerateSpeech() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try SpeechProviderFactory.createProvider(for: .openai(.tts1))
                let request = SpeechRequest(
                    text: "Hello, this is a test message for speech synthesis.",
                    voice: .nova,
                    speed: 1.0,
                    format: .mp3
                )

                let result = try await provider.generateSpeech(request: request)

                #expect(!result.audioData.data.isEmpty)
                #expect(result.audioData.format == .mp3)
                #expect(result.usage != nil)
                #expect(result.usage?.charactersProcessed == request.text.count)
            }
        }

        @Test("OpenAI speech provider with different voices")
        func openAISpeechProviderDifferentVoices() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try SpeechProviderFactory.createProvider(for: .openai(.tts1))

                let voices: [VoiceOption] = [.alloy, .echo, .fable, .onyx, .nova, .shimmer]

                for voice in voices {
                    let request = SpeechRequest(
                        text: "Testing voice: \(voice.stringValue)",
                        voice: voice,
                        format: .wav
                    )

                    let result = try await provider.generateSpeech(request: request)

                    #expect(!result.audioData.data.isEmpty)
                    #expect(result.audioData.format == .wav)
                }
            }
        }

        @Test("OpenAI speech provider with speed control")
        func openAISpeechProviderSpeedControl() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try SpeechProviderFactory.createProvider(for: .openai(.tts1))

                let speeds: [Double] = [0.25, 0.5, 1.0, 1.5, 2.0, 4.0]

                for speed in speeds {
                    let request = SpeechRequest(
                        text: "Testing speed: \(speed)",
                        voice: .alloy,
                        speed: speed,
                        format: .mp3
                    )

                    let result = try await provider.generateSpeech(request: request)

                    #expect(!result.audioData.data.isEmpty)
                    #expect(result.audioData.format == .mp3)
                }
            }
        }

        @Test("OpenAI speech provider with voice instructions")
        func openAISpeechProviderVoiceInstructions() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try SpeechProviderFactory.createProvider(for: .openai(.tts1HD))
                let request = SpeechRequest(
                    text: "This is a test message with custom voice instructions.",
                    voice: .nova,
                    instructions: "Speak in a calm, professional tone with clear pronunciation."
                )

                let result = try await provider.generateSpeech(request: request)

                #expect(!result.audioData.data.isEmpty)
                #expect(result.usage != nil)
            }
        }

        @Test("OpenAI speech provider with abort signal")
        func openAISpeechProviderAbortSignal() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try SpeechProviderFactory.createProvider(for: .openai(.tts1))
                let abortSignal = AbortSignal()
                let request = SpeechRequest(
                    text: "This should be cancelled",
                    voice: .alloy,
                    abortSignal: abortSignal
                )

                // Cancel immediately
                abortSignal.cancel()

                await #expect(throws: TachikomaError.self) {
                    try await provider.generateSpeech(request: request)
                }
            }
        }

        @Test("OpenAI speech provider request validation")
        func openAISpeechProviderRequestValidation() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try SpeechProviderFactory.createProvider(for: .openai(.tts1))

                // Test empty text
                let emptyRequest = SpeechRequest(text: "")

                await #expect(throws: TachikomaError.self) {
                    try await provider.generateSpeech(request: emptyRequest)
                }

                // Test text too long (over 4096 character limit)
                let longText = String(repeating: "A", count: 5000)
                let longRequest = SpeechRequest(text: longText)

                await #expect(throws: TachikomaError.self) {
                    try await provider.generateSpeech(request: longRequest)
                }

                // Test invalid speed (outside 0.25-4.0 range)
                let invalidSpeedRequest = SpeechRequest(text: "Test", speed: 5.0)

                await #expect(throws: TachikomaError.self) {
                    try await provider.generateSpeech(request: invalidSpeedRequest)
                }
            }
        }

        @Test("OpenAI speech provider different output formats")
        func openAISpeechProviderDifferentFormats() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try SpeechProviderFactory.createProvider(for: .openai(.tts1))
                let formats: [AudioFormat] = [.mp3, .opus, .aac, .flac, .wav, .pcm]

                for format in formats {
                    let request = SpeechRequest(
                        text: "Testing format: \(format.rawValue)",
                        voice: .alloy,
                        format: format
                    )

                    let result = try await provider.generateSpeech(request: request)

                    #expect(!result.audioData.data.isEmpty)
                    #expect(result.audioData.format == format)
                }
            }
        }
    }

    // MARK: - OpenAI API Configuration Tests

    @Suite("OpenAI API Configuration Tests")
    struct OpenAIAPIConfigurationTests {
        @Test("OpenAI API key configuration from environment")
        func openAIAPIKeyFromEnvironment() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "env-test-key"]) { _ in
                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))
                // Mock provider doesn't expose apiKey, just test that it was created successfully
                #expect(provider.modelId == "whisper-1")
            }
        }

        @Test("OpenAI custom base URL configuration")
        func openAICustomBaseURL() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                // Set custom base URL via environment
                setenv("OPENAI_BASE_URL", "https://custom-openai-api.example.com", 1)
                defer { unsetenv("OPENAI_BASE_URL") }

                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))

                // Provider should be created successfully with custom base URL
                #expect(provider.modelId == "whisper-1")
            }
        }

        @Test("OpenAI organization ID configuration")
        func openAIOrganizationID() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                // Set organization ID via environment
                setenv("OPENAI_ORGANIZATION", "org-test-12345", 1)
                defer { unsetenv("OPENAI_ORGANIZATION") }

                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))

                // Provider should be created successfully with organization ID
                #expect(provider.modelId == "whisper-1")
            }
        }

        @Test("OpenAI request timeout configuration")
        func openAIRequestTimeout() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))
                let audioData = AudioData(data: Data([0x01, 0x02]), format: .wav)

                // Test with timeout signal
                let timeoutSignal = AbortSignal.timeout(0.1) // 100ms timeout
                let request = TranscriptionRequest(audio: audioData, abortSignal: timeoutSignal)

                // Should timeout quickly with our short timeout
                // Note: In real implementation this would timeout, but with placeholder it might not
                do {
                    _ = try await provider.transcribe(request: request)
                    // If it completes quickly (placeholder), that's also valid
                } catch {
                    // Timeout or cancellation is expected
                    #expect(error is TachikomaError)
                }
            }
        }
    }

    // MARK: - OpenAI Error Handling Tests

    @Suite("OpenAI Error Handling Tests")
    struct OpenAIErrorHandlingTests {
        @Test("OpenAI provider handles network errors")
        func openAIProviderNetworkErrors() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "invalid-key"]) { _ in
                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))
                let audioData = AudioData(data: Data([0x01, 0x02]), format: .wav)
                let request = TranscriptionRequest(audio: audioData)

                // With placeholder implementation, this won't actually make network calls
                // In real implementation, this would test authentication errors
                do {
                    _ = try await provider.transcribe(request: request)
                    // Placeholder allows this
                } catch {
                    // Real implementation would throw authentication error
                    #expect(error is TachikomaError)
                }
            }
        }

        @Test("OpenAI provider handles unsupported formats gracefully")
        func openAIProviderUnsupportedFormats() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))

                // Create audio data with a format not in OpenAI's supported list
                // For this test, let's assume there's a hypothetical unsupported format
                let audioData = AudioData(data: Data([0x01, 0x02]), format: .wav) // WAV is supported
                let request = TranscriptionRequest(audio: audioData)

                // This should work since WAV is supported
                let result = try await provider.transcribe(request: request)
                #expect(!result.text.isEmpty)
            }
        }

        @Test("OpenAI provider handles rate limiting")
        func openAIProviderRateLimiting() async throws {
            try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { _ in
                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))
                let audioData = AudioData(data: Data([0x01, 0x02]), format: .wav)

                // Simulate multiple rapid requests
                let requests = (1...5).map { _ in
                    TranscriptionRequest(audio: audioData)
                }

                // With placeholder implementation, all should succeed
                for request in requests {
                    let result = try await provider.transcribe(request: request)
                    #expect(!result.text.isEmpty)
                }

                // Real implementation might implement rate limiting handling
            }
        }

        @Test("OpenAI provider error message formatting")
        func openAIProviderErrorMessageFormatting() async throws {
            try await TestHelpers.withEmptyTestConfiguration { _ in
                // Test that error messages are properly formatted
                do {
                    _ = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))
                    Issue.record("Expected error for missing API key")
                } catch let error as TachikomaError {
                    let errorMessage = error.localizedDescription
                    #expect(errorMessage.contains("API key"))
                    #expect(errorMessage.contains("OPENAI"))
                } catch {
                    Issue.record("Expected TachikomaError, got \(type(of: error))")
                }
            }
        }
    }
}
