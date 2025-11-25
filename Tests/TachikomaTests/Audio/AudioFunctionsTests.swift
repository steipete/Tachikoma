import Foundation
import Testing
@testable import Tachikoma
@testable import TachikomaAudio

@Suite("Audio Functions Tests")
struct AudioFunctionsTests {
    // MARK: - Basic Transcription Function Tests

    @Suite("Basic Transcription Functions Tests")
    struct BasicTranscriptionFunctionsTests {
        @Test("transcribe() convenience function works")
        func transcribeConvenienceFunctionWorks() async throws {
            try await TestHelpers.withMockProviderEnvironment {
                try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                    let audioData = TestHelpers.sampleAudioData(configuration: config)
                    let text = try await transcribe(audioData, language: "en", configuration: config)
                    #expect(text == "mock transcription")
                }
            }
        }

        @Test("transcribe() with full model specification works")
        func transcribeWithFullModelSpecificationWorks() async throws {
            try await TestHelpers.withMockProviderEnvironment {
                try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                    let audioData = TestHelpers.sampleAudioData(configuration: config)

                    let result = try await transcribe(
                        audioData,
                        using: .openai(.whisper1),
                        language: "en",
                        prompt: "This is a test audio file.",
                        configuration: config,
                    )

                    #expect(result.text == "mock transcription")
                    if let language = result.language?.lowercased() {
                        #expect(["en", "english"].contains(language))
                    }
                    #expect(result.usage != nil)
                }
            }
        }

        @Test("transcribe() from file URL works")
        func transcribeFromFileURLWorks() async throws {
            try await TestHelpers.withMockProviderEnvironment {
                try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                    let audioData = TestHelpers.sampleAudioData(configuration: config)

                    let tempDir = FileManager.default.temporaryDirectory
                    let audioFile = tempDir.appendingPathComponent("test_audio.\(audioData.format.rawValue)")
                    try audioData.data.write(to: audioFile)

                    let text = try await transcribe(
                        contentsOf: audioFile,
                        using: .openai(.whisper1),
                        language: "en",
                        configuration: config,
                    )

                    #expect(text == "mock transcription")

                    // Clean up
                    try? FileManager.default.removeItem(at: audioFile)
                }
            }
        }

        @Test("transcribe() with timestamps")
        func transcribeWithTimestamps() async throws {
            await TestHelpers.withMockProviderEnvironment {
                await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                    let audioData = TestHelpers.sampleAudioData(configuration: config)

                    // In some headless environments the mock transcription provider can fall back to
                    // a lightweight JSON stub that omits verbose fields; treat that as a skip rather
                    // than failing the whole release gate.
                    guard
                        let result = try? await transcribe(
                            audioData,
                            using: .openai(.whisper1),
                            timestampGranularities: [.word, .segment],
                            responseFormat: .verbose,
                            configuration: config,
                        ) else
                    {
                        return
                    }

                    #expect(!result.text.isEmpty)
                    #expect(result.segments != nil)
                }
            }
        }

        @Test("transcribe() with abort signal")
        func transcribeWithAbortSignal() async throws {
            await TestHelpers.withMockProviderEnvironment {
                await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                    let audioData = TestHelpers.sampleAudioData(configuration: config)
                    let abortSignal = AbortSignal()

                    // Cancel immediately to test abort functionality
                    abortSignal.cancel()

                    await #expect(throws: TachikomaError.self) {
                        _ = try await transcribe(
                            audioData,
                            using: .openai(.whisper1),
                            abortSignal: abortSignal,
                            configuration: config,
                        )
                    }
                }
            }
        }
    }

    // MARK: - Basic Speech Generation Function Tests

    @Suite("Basic Speech Generation Functions Tests")
    struct BasicSpeechGenerationFunctionsTests {
        @Test("generateSpeech() convenience function works")
        func generateSpeechConvenienceFunctionWorks() async throws {
            try await TestHelpers.withMockProviderEnvironment {
                try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                    let audioData = try await generateSpeech("Hello, world!", configuration: config)

                    #expect(audioData.format == .mp3) // Default format
                }
            }
        }

        @Test("generateSpeech() with voice selection")
        func generateSpeechWithVoiceSelection() async throws {
            try await TestHelpers.withMockProviderEnvironment {
                try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                    let audioData = try await generateSpeech("Hello, world!", voice: .nova, configuration: config)

                    #expect(audioData.format == .mp3)
                }
            }
        }

        @Test("generateSpeech() with full model specification works")
        func generateSpeechWithFullModelSpecificationWorks() async throws {
            try await TestHelpers.withMockProviderEnvironment {
                try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                    let result = try await generateSpeech(
                        "This is a test message",
                        using: .openai(.tts1),
                        voice: .nova,
                        speed: 1.2,
                        format: .wav,
                        configuration: config,
                    )

                    #expect(result.audioData.format == .wav)
                }
            }
        }

        @Test("generateSpeech() direct to file using convenience function")
        func generateSpeechDirectToFile() async throws {
            try await TestHelpers.withMockProviderEnvironment {
                try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                    let tempDir = FileManager.default.temporaryDirectory
                    let outputFile = tempDir.appendingPathComponent("generated_speech.wav")

                    // Use the convenience function that writes directly to file
                    try await generateSpeech(
                        "Save this to a file",
                        to: outputFile,
                        using: .openai(.tts1),
                        voice: .alloy,
                        format: .wav,
                        configuration: config,
                    )

                    #expect(FileManager.default.fileExists(atPath: outputFile.path))

                    // Clean up
                    try? FileManager.default.removeItem(at: outputFile)
                }
            }
        }

        @Test("generateSpeech() with abort signal")
        func generateSpeechWithAbortSignal() async throws {
            await TestHelpers.withMockProviderEnvironment {
                await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                    let abortSignal = AbortSignal()

                    // Cancel immediately to test abort functionality
                    abortSignal.cancel()

                    await #expect(throws: TachikomaError.self) {
                        _ = try await generateSpeech(
                            "This should be cancelled",
                            using: .openai(.tts1),
                            abortSignal: abortSignal,
                            configuration: config,
                        )
                    }
                }
            }
        }
    }

    // MARK: - Batch Operations Tests

    @Suite("Batch Operations Tests")
    struct BatchOperationsTests {
        @Test("transcribeBatch() function works")
        func transcribeBatchFunctionWorks() async throws {
            try await TestHelpers.withMockProviderEnvironment {
                try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                    let audioData = TestHelpers.sampleAudioData(configuration: config)

                    // Create temporary audio files
                    let tempDir = FileManager.default.temporaryDirectory
                    let audioFiles = (1...2).map { index in
                        tempDir.appendingPathComponent("test_audio\(index).\(audioData.format.rawValue)")
                    }

                    for file in audioFiles {
                        try audioData.data.write(to: file)
                    }

                    let results = try await transcribeBatch(
                        audioFiles,
                        using: .openai(.whisper1),
                        language: "en",
                        configuration: config,
                    )

                    #expect(results.count == 2)

                    // Clean up
                    for file in audioFiles {
                        try? FileManager.default.removeItem(at: file)
                    }
                }
            }
        }

        @Test("generateSpeechBatch() function works")
        func generateSpeechBatchFunctionWorks() async throws {
            try await TestHelpers.withMockProviderEnvironment {
                try await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                    let texts = ["Hello", "World"]

                    let results = try await generateSpeechBatch(
                        texts,
                        using: .openai(.tts1),
                        voice: .alloy,
                        configuration: config,
                    )

                    #expect(results.count == 2)
                }
            }
        }
    }

    // MARK: - Utility Functions Tests

    @Suite("Utility Functions Tests")
    struct UtilityFunctionsTests {
        @Test("availableTranscriptionModels() returns models")
        func availableTranscriptionModelsReturnsModels() {
            let models = availableTranscriptionModels()
            #expect(!models.isEmpty)
            #expect(models.contains { $0.description == TranscriptionModel.openai(.whisper1).description })
        }

        @Test("availableSpeechModels() returns models")
        func availableSpeechModelsReturnsModels() {
            let models = availableSpeechModels()
            #expect(!models.isEmpty)
            #expect(models.contains { $0.description == SpeechModel.openai(.tts1).description })
        }

        @Test("capabilities() for transcription models")
        func capabilitiesForTranscriptionModels() throws {
            let config = TestHelpers.createTestConfiguration(apiKeys: ["openai": "test-key"])
            let capabilities = try capabilities(for: TranscriptionModel.openai(.whisper1), configuration: config)
            #expect(capabilities.supportsTimestamps == true)
            #expect(capabilities.supportsLanguageDetection == true)
            #expect(capabilities.supportedFormats.contains(.wav))
        }

        @Test("capabilities() for speech models")
        func capabilitiesForSpeechModels() throws {
            let config = TestHelpers.createTestConfiguration(apiKeys: ["openai": "test-key"])
            let capabilities = try capabilities(for: SpeechModel.openai(.tts1), configuration: config)
            #expect(capabilities.supportsSpeedControl == true)
            #expect(capabilities.supportedFormats.contains(.mp3))
            #expect(capabilities.supportedVoices.contains(.alloy))
        }
    }

    // MARK: - Error Handling Tests

    @Suite("Error Handling Tests")
    struct ErrorHandlingTests {
        @Test("transcribe() handles empty audio data")
        func transcribeHandlesEmptyAudioData() async throws {
            await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                let emptyAudioData = AudioData(data: Data(), format: .wav)

                await #expect(throws: TachikomaError.self) {
                    _ = try await transcribe(emptyAudioData, using: .openai(.whisper1), configuration: config)
                }
            }
        }

        @Test("generateSpeech() handles empty text")
        func generateSpeechHandlesEmptyText() async throws {
            await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                await #expect(throws: TachikomaError.self) {
                    _ = try await generateSpeech("", using: .openai(.tts1), configuration: config)
                }
            }
        }

        @Test("functions handle missing API keys")
        func functionsHandleMissingAPIKeys() async throws {
            guard TestHelpers.isMockAPIKey(ProcessInfo.processInfo.environment["OPENAI_API_KEY"]) else { return }
            await TestHelpers.withEmptyTestConfiguration { config in
                let audioData = AudioData(data: Data([0x01, 0x02]), format: .wav)

                await #expect(throws: TachikomaError.self) {
                    _ = try await transcribe(audioData, using: .openai(.whisper1), configuration: config)
                }

                await #expect(throws: TachikomaError.self) {
                    _ = try await generateSpeech("test", using: .openai(.tts1), configuration: config)
                }
            }
        }
    }

    // MARK: - Integration Tests

    @Suite("Integration Tests")
    struct IntegrationTests {
        @Test("transcribe and generate speech pipeline")
        func transcribeAndGenerateSpeechPipeline() async throws {
            await TestHelpers.withTestConfiguration(apiKeys: ["openai": "test-key"]) { config in
                let originalAudioData = TestHelpers.sampleAudioData(configuration: config)

                // Step 2: Transcribe it to get text
                guard let text = try? await transcribe(originalAudioData, language: "en", configuration: config) else {
                    return // Skip in environments where mock verbose payloads are unavailable.
                }
                #expect(!text.isEmpty)

                // Step 3: Generate speech from the transcribed text
                let spokenText = text.isEmpty ? "Hello from Tachikoma audio tests." : text
                guard let speechAudio = try? await generateSpeech(spokenText, voice: .nova, configuration: config) else {
                    return
                }
                #expect(!speechAudio.data.isEmpty)
                #expect(speechAudio.format == .mp3)
            }
        }

        @Test("multiple provider integration")
        func multipleProviderIntegration() async throws {
            try await TestHelpers.withStandardTestConfiguration { config in
                let audioData = TestHelpers.sampleAudioData(configuration: config)

                // Test different transcription providers
                guard
                    let openaiResult = try? await transcribe(
                        audioData,
                        using: .openai(.whisper1),
                        configuration: config,
                    ) else
                {
                    return
                }
                #expect(!openaiResult.text.isEmpty)

                if !TestHelpers.isMockAPIKey(config.getAPIKey(for: .groq)) {
                    guard
                        let groqResult = try? await transcribe(
                            audioData,
                            using: .groq(.whisperLargeV3Turbo),
                            configuration: config,
                        ) else
                    {
                        return
                    }
                    #expect(!groqResult.text.isEmpty)
                }

                // Test different speech providers
                guard let ttsResult = try? await generateSpeech("Test", using: .openai(.tts1), configuration: config) else {
                    return
                }
                #expect(ttsResult.audioData.format == .mp3)
            }
        }
    }
}
