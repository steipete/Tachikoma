import Foundation
import Testing
@testable import Tachikoma

@Suite("Audio Providers Tests")
struct AudioProvidersTests {
    // MARK: - Capabilities Tests

    @Suite("Capabilities Tests")
    struct CapabilitiesTests {
        @Test("TranscriptionCapabilities initialization")
        func transcriptionCapabilitiesInit() {
            let capabilities = TranscriptionCapabilities(
                supportedFormats: [.wav, .mp3],
                supportsTimestamps: true,
                supportsLanguageDetection: true,
                supportsSpeakerDiarization: false,
                supportsSummarization: true,
                supportsWordTimestamps: true,
                maxFileSize: 25 * 1024 * 1024,
                maxDuration: 300.0,
                supportedLanguages: ["en", "es", "fr"]
            )

            #expect(capabilities.supportedFormats == [.wav, .mp3])
            #expect(capabilities.supportsTimestamps == true)
            #expect(capabilities.supportsLanguageDetection == true)
            #expect(capabilities.supportsSpeakerDiarization == false)
            #expect(capabilities.supportsSummarization == true)
            #expect(capabilities.supportsWordTimestamps == true)
            #expect(capabilities.maxFileSize == 25 * 1024 * 1024)
            #expect(capabilities.maxDuration == 300.0)
            #expect(capabilities.supportedLanguages == ["en", "es", "fr"])
        }

        @Test("TranscriptionCapabilities defaults")
        func transcriptionCapabilitiesDefaults() {
            let capabilities = TranscriptionCapabilities()

            #expect(capabilities.supportedFormats == AudioFormat.allCases)
            #expect(capabilities.supportsTimestamps == false)
            #expect(capabilities.supportsLanguageDetection == false)
            #expect(capabilities.supportsSpeakerDiarization == false)
            #expect(capabilities.supportsSummarization == false)
            #expect(capabilities.supportsWordTimestamps == false)
            #expect(capabilities.maxFileSize == nil)
            #expect(capabilities.maxDuration == nil)
            #expect(capabilities.supportedLanguages == nil)
        }

        @Test("SpeechCapabilities initialization")
        func speechCapabilitiesInit() {
            let capabilities = SpeechCapabilities(
                supportedFormats: [.mp3, .wav, .flac],
                supportedVoices: [.alloy, .nova],
                supportsVoiceInstructions: true,
                supportsSpeedControl: true,
                supportsLanguageSelection: true,
                supportsEmotionalControl: false,
                maxTextLength: 4096,
                supportedLanguages: ["en", "de"]
            )

            #expect(capabilities.supportedFormats == [.mp3, .wav, .flac])
            #expect(capabilities.supportedVoices == [.alloy, .nova])
            #expect(capabilities.supportsVoiceInstructions == true)
            #expect(capabilities.supportsSpeedControl == true)
            #expect(capabilities.supportsLanguageSelection == true)
            #expect(capabilities.supportsEmotionalControl == false)
            #expect(capabilities.maxTextLength == 4096)
            #expect(capabilities.supportedLanguages == ["en", "de"])
        }

        @Test("SpeechCapabilities defaults")
        func speechCapabilitiesDefaults() {
            let capabilities = SpeechCapabilities()

            #expect(capabilities.supportedFormats == [.mp3, .wav])
            #expect(capabilities.supportedVoices == [.alloy, .echo, .fable, .onyx, .nova, .shimmer])
            #expect(capabilities.supportsVoiceInstructions == false)
            #expect(capabilities.supportsSpeedControl == true)
            #expect(capabilities.supportsLanguageSelection == false)
            #expect(capabilities.supportsEmotionalControl == false)
            #expect(capabilities.maxTextLength == nil)
            #expect(capabilities.supportedLanguages == nil)
        }
    }

    // MARK: - Factory Tests

    @Suite("Factory Tests")
    struct FactoryTests {
        @Test("TranscriptionProviderFactory creates OpenAI provider")
        func transcriptionFactoryOpenAI() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))

                #expect(provider.modelId == "whisper-1")
                #expect(provider.capabilities.supportedFormats.contains(.wav))
                #expect(provider.capabilities.supportedFormats.contains(.mp3))
                #expect(provider.capabilities.supportsTimestamps == true)
                #expect(provider.capabilities.supportsLanguageDetection == true)
                #expect(provider.capabilities.maxFileSize == 25 * 1024 * 1024)
            }
        }

        @Test("TranscriptionProviderFactory fails without API key")
        func transcriptionFactoryNoAPIKey() async throws {
            try await TestHelpers.withNoAPIKeys {
                #expect(throws: TachikomaError.self) {
                    _ = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))
                }
            }
        }

        @Test("TranscriptionProviderFactory creates all provider types")
        func transcriptionFactoryAllProviders() async throws {
            try await TestHelpers.withStandardTestKeys {
                // Test that we can create providers for all supported types
                let openaiProvider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))
                #expect(openaiProvider.modelId == "whisper-1")

                let groqProvider = try TranscriptionProviderFactory.createProvider(for: .groq(.whisperLargeV3))
                #expect(groqProvider.modelId == "whisper-large-v3")

                let deepgramProvider = try TranscriptionProviderFactory.createProvider(for: .deepgram(.nova3))
                #expect(deepgramProvider.modelId == "nova-3")

                let assemblyaiProvider = try TranscriptionProviderFactory.createProvider(for: .assemblyai(.best))
                #expect(assemblyaiProvider.modelId == "best")

                let elevenlabsProvider = try TranscriptionProviderFactory.createProvider(for: .elevenlabs(.scribeV1))
                #expect(elevenlabsProvider.modelId == "scribe_v1")

                let revaiProvider = try TranscriptionProviderFactory.createProvider(for: .revai(.machine))
                #expect(revaiProvider.modelId == "machine")

                let azureProvider = try TranscriptionProviderFactory.createProvider(for: .azure(.whisper1))
                #expect(azureProvider.modelId == "whisper-1")
            }
        }

        @Test("SpeechProviderFactory creates OpenAI provider")
        func speechFactoryOpenAI() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let provider = try SpeechProviderFactory.createProvider(for: .openai(.tts1))

                #expect(provider.modelId == "tts-1")
                #expect(provider.capabilities.supportedFormats.contains(.mp3))
                #expect(provider.capabilities.supportedFormats.contains(.wav))
                #expect(provider.capabilities.supportedVoices.contains(.alloy))
                #expect(provider.capabilities.supportedVoices.contains(.nova))
                #expect(provider.capabilities.supportsSpeedControl == true)
                #expect(provider.capabilities.maxTextLength == 4096)
            }
        }

        @Test("SpeechProviderFactory fails without API key")
        func speechFactoryNoAPIKey() async throws {
            try await TestHelpers.withNoAPIKeys {
                #expect(throws: TachikomaError.self) {
                    _ = try SpeechProviderFactory.createProvider(for: .openai(.tts1))
                }
            }
        }

        @Test("SpeechProviderFactory creates all provider types")
        func speechFactoryAllProviders() async throws {
            try await TestHelpers.withStandardTestKeys {
                let openaiProvider = try SpeechProviderFactory.createProvider(for: .openai(.tts1))
                #expect(openaiProvider.modelId == "tts-1")

                let lmntProvider = try SpeechProviderFactory.createProvider(for: .lmnt(.aurora))
                #expect(lmntProvider.modelId == "aurora")

                let humeProvider = try SpeechProviderFactory.createProvider(for: .hume(.default))
                #expect(humeProvider.modelId == "default")

                let elevenlabsProvider = try SpeechProviderFactory.createProvider(for: .elevenlabs(.multilingualV1))
                #expect(elevenlabsProvider.modelId == "eleven_multilingual_v1")
            }
        }
    }

    // MARK: - AudioConfiguration Tests

    @Suite("AudioConfiguration Tests")
    struct AudioConfigurationTests {
        @Test("AudioConfiguration gets API key from test environment")
        func audioConfigurationTestEnvironment() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-openai-key"]) {
                let key = AudioConfiguration.getAPIKey(for: "openai")
                #expect(key == "test-openai-key")
            }
        }

        @Test("AudioConfiguration returns nil for missing key")
        func audioConfigurationMissingKey() async throws {
            try await TestHelpers.withNoAPIKeys {
                let key = AudioConfiguration.getAPIKey(for: "nonexistent")
                #expect(key == nil)
            }
        }

        @Test("AudioConfiguration handles different provider names")
        func audioConfigurationProviderNames() async throws {
            let testKeys = [
                "openai": "openai-key",
                "groq": "groq-key",
                "deepgram": "deepgram-key",
                "assemblyai": "assemblyai-key",
                "elevenlabs": "elevenlabs-key",
                "revai": "revai-key",
                "azure": "azure-key",
                "lmnt": "lmnt-key",
                "hume": "hume-key",
            ]

            try await TestHelpers.withTestEnvironment(apiKeys: testKeys) {
                #expect(AudioConfiguration.getAPIKey(for: "openai") == "openai-key")
                #expect(AudioConfiguration.getAPIKey(for: "groq") == "groq-key")
                #expect(AudioConfiguration.getAPIKey(for: "deepgram") == "deepgram-key")
                #expect(AudioConfiguration.getAPIKey(for: "assemblyai") == "assemblyai-key")
                #expect(AudioConfiguration.getAPIKey(for: "elevenlabs") == "elevenlabs-key")
                #expect(AudioConfiguration.getAPIKey(for: "revai") == "revai-key")
                #expect(AudioConfiguration.getAPIKey(for: "azure") == "azure-key")
                #expect(AudioConfiguration.getAPIKey(for: "lmnt") == "lmnt-key")
                #expect(AudioConfiguration.getAPIKey(for: "hume") == "hume-key")
            }
        }
    }

    // MARK: - Provider Implementation Tests

    @Suite("Provider Implementation Tests")
    struct ProviderImplementationTests {
        @Test("OpenAITranscriptionProvider configuration")
        func openAITranscriptionProviderConfig() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let provider = try OpenAITranscriptionProvider(model: .whisper1)

                #expect(provider.modelId == "whisper-1")
                #expect(provider.apiKey == "test-key")

                // Test capabilities are correctly configured based on model
                let capabilities = provider.capabilities
                #expect(capabilities.supportedFormats.contains(.mp3))
                #expect(capabilities.supportedFormats.contains(.wav))
                #expect(capabilities.supportedFormats.contains(.flac))
                #expect(capabilities.supportsTimestamps == true)
                #expect(capabilities.supportsLanguageDetection == true)
                #expect(capabilities.supportsWordTimestamps == true)
                #expect(capabilities.maxFileSize == 25 * 1024 * 1024)
            }
        }

        @Test("OpenAITranscriptionProvider different models")
        func openAITranscriptionProviderModels() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let whisperProvider = try OpenAITranscriptionProvider(model: .whisper1)
                #expect(whisperProvider.capabilities.supportsTimestamps == true)
                #expect(whisperProvider.capabilities.supportsLanguageDetection == true)

                let gpt4oProvider = try OpenAITranscriptionProvider(model: .gpt4oTranscribe)
                #expect(gpt4oProvider.capabilities.supportsTimestamps == false)
                #expect(gpt4oProvider.capabilities.supportsLanguageDetection == false)
            }
        }

        @Test("OpenAISpeechProvider configuration")
        func openAISpeechProviderConfig() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let provider = try OpenAISpeechProvider(model: .tts1)

                #expect(provider.modelId == "tts-1")
                #expect(provider.apiKey == "test-key")

                let capabilities = provider.capabilities
                #expect(capabilities.supportedFormats.contains(.mp3))
                #expect(capabilities.supportedFormats.contains(.wav))
                #expect(capabilities.supportedVoices.contains(.alloy))
                #expect(capabilities.supportedVoices.contains(.nova))
                #expect(capabilities.supportsSpeedControl == true)
                #expect(capabilities.maxTextLength == 4096)
            }
        }

        @Test("OpenAISpeechProvider different models")
        func openAISpeechProviderModels() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let tts1Provider = try OpenAISpeechProvider(model: .tts1)
                #expect(tts1Provider.capabilities.supportsVoiceInstructions == false)

                let gpt4oMiniProvider = try OpenAISpeechProvider(model: .gpt4oMiniTTS)
                #expect(gpt4oMiniProvider.capabilities.supportsVoiceInstructions == true)
            }
        }

        @Test("Provider stubs throw not implemented errors")
        func providerStubsThrowErrors() async throws {
            try await TestHelpers.withStandardTestKeys {
                // Test that stub providers throw appropriate errors
                let groqProvider = try GroqTranscriptionProvider(model: .whisperLargeV3)
                let audioData = AudioData(data: Data(), format: .wav)
                let request = TranscriptionRequest(audio: audioData)

                await #expect(throws: TachikomaError.self) {
                    _ = try await groqProvider.transcribe(request: request)
                }

                let lmntProvider = try LMNTSpeechProvider(model: .aurora)
                let speechRequest = SpeechRequest(text: "test")

                await #expect(throws: TachikomaError.self) {
                    _ = try await lmntProvider.generateSpeech(request: speechRequest)
                }
            }
        }
    }

    // MARK: - Provider Capabilities Integration Tests

    @Suite("Provider Capabilities Integration Tests")
    struct ProviderCapabilitiesIntegrationTests {
        @Test("Groq provider capabilities")
        func groqProviderCapabilities() throws {
            let provider = try GroqTranscriptionProvider(model: .whisperLargeV3Turbo)

            #expect(provider.modelId == "whisper-large-v3-turbo")
            #expect(provider.capabilities.supportsTimestamps == true)
            #expect(provider.capabilities.supportsLanguageDetection == true)
        }

        @Test("Deepgram provider capabilities")
        func deepgramProviderCapabilities() throws {
            let provider = try DeepgramTranscriptionProvider(model: .nova3)

            #expect(provider.modelId == "nova-3")
            #expect(provider.capabilities.supportsTimestamps == true)
            #expect(provider.capabilities.supportsLanguageDetection == true)
            #expect(provider.capabilities.supportsSummarization == true)
        }

        @Test("AssemblyAI provider capabilities")
        func assemblyAIProviderCapabilities() throws {
            let provider = try AssemblyAITranscriptionProvider(model: .best)

            #expect(provider.modelId == "best")
            #expect(provider.capabilities.supportsTimestamps == true)
            #expect(provider.capabilities.supportsLanguageDetection == true)
            #expect(provider.capabilities.supportsSpeakerDiarization == true)
        }

        @Test("ElevenLabs transcription provider capabilities")
        func elevenLabsTranscriptionProviderCapabilities() throws {
            let provider = try ElevenLabsTranscriptionProvider(model: .scribeV1)

            #expect(provider.modelId == "scribe_v1")
            #expect(provider.capabilities.supportsTimestamps == false)
            #expect(provider.capabilities.supportsLanguageDetection == true)
        }

        @Test("LMNT speech provider capabilities")
        func lmntSpeechProviderCapabilities() throws {
            let provider = try LMNTSpeechProvider(model: .aurora)

            #expect(provider.modelId == "aurora")
            #expect(provider.capabilities.supportedFormats == [.wav, .mp3])
            #expect(provider.capabilities.supportsLanguageSelection == true)
        }

        @Test("Hume speech provider capabilities")
        func humeSpeechProviderCapabilities() throws {
            let provider = try HumeSpeechProvider(model: .default)

            #expect(provider.modelId == "default")
            #expect(provider.capabilities.supportedFormats == [.wav])
            #expect(provider.capabilities.supportsEmotionalControl == true)
        }

        @Test("ElevenLabs speech provider capabilities")
        func elevenLabsSpeechProviderCapabilities() throws {
            let provider = try ElevenLabsSpeechProvider(model: .multilingualV2)

            #expect(provider.modelId == "eleven_multilingual_v2")
            #expect(provider.capabilities.supportedFormats == [.mp3, .wav, .pcm])
            #expect(provider.capabilities.supportsVoiceInstructions == true)
        }
    }
}
