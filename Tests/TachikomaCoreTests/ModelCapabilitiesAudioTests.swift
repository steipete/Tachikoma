import Foundation
@testable import TachikomaCore
import Testing

@Suite("Model Audio Capabilities Tests")
struct ModelAudioCapabilitiesTests {
    // MARK: - Basic Model Audio Support Tests

    @Suite("Basic Model Audio Support Tests")
    struct BasicModelAudioSupportTests {
        @Test("LanguageModel has audio support properties")
        func languageModelHasAudioSupportProperties() {
            // Test that LanguageModel includes audio capability information
            let gpt4oModel = Model.openai(.gpt4o)
            #expect(gpt4oModel.supportsAudioInput == true) // GPT-4o supports audio
            #expect(gpt4oModel.supportsAudioOutput == false) // Not direct TTS

            let claudeModel = Model.anthropic(.opus4)
            #expect(claudeModel.supportsAudioInput == false) // Claude doesn't support audio input
            #expect(claudeModel.supportsAudioOutput == false) // Claude doesn't support audio output

            // Test Gemini models
            let geminiModel = Model.google(.gemini2Flash)
            #expect(geminiModel.supportsAudioInput == true) // Gemini 2.0 supports audio
            #expect(geminiModel.supportsAudioOutput == true) // Gemini Live

            // Test non-audio models
            let groqModel = Model.groq(.llama31_70b)
            #expect(groqModel.supportsAudioInput == false)
            #expect(groqModel.supportsAudioOutput == false)
        }

        @Test("Audio models are separate from language models")
        func audioModelsAreSeparateFromLanguageModels() {
            // Test that we have separate audio-specific model types
            let transcriptionModel = TranscriptionModel.openai(.whisper1)
            #expect(transcriptionModel.modelId == "whisper-1")
            #expect(transcriptionModel.supportsTimestamps == true)
            #expect(transcriptionModel.supportsLanguageDetection == true)

            let speechModel = SpeechModel.openai(.tts1)
            #expect(speechModel.modelId == "tts-1")
            #expect(speechModel.supportedFormats.contains(.mp3))
            #expect(speechModel.supportedFormats.contains(.wav))
        }

        @Test("Audio model provider names are consistent")
        func audioModelProviderNamesAreConsistent() {
            // Test that provider names are consistent between audio and language models
            let openaiTranscription = TranscriptionModel.openai(.whisper1)
            let openaiSpeech = SpeechModel.openai(.tts1)
            let openaiLanguage = Model.openai(.gpt4o)

            #expect(openaiTranscription.providerName == "OpenAI")
            #expect(openaiSpeech.providerName == "OpenAI")
            #expect(openaiLanguage.providerName == "OpenAI")

            // Test other providers
            let groqTranscription = TranscriptionModel.groq(.whisperLargeV3Turbo)
            let groqLanguage = Model.groq(.llama31_70b)

            #expect(groqTranscription.providerName == "Groq")
            #expect(groqLanguage.providerName == "Groq")
        }

        @Test("Model capabilities are accessible")
        func modelCapabilitiesAreAccessible() {
            // Test that model capabilities are properly exposed
            let gpt4oModel = Model.openai(.gpt4o)

            #expect(gpt4oModel.supportsVision == true)
            #expect(gpt4oModel.supportsTools == true)
            #expect(gpt4oModel.supportsStreaming == true)
            #expect(gpt4oModel.contextLength == 128_000)

            // Test that we can distinguish between different model types
            let whisperModel = TranscriptionModel.openai(.whisper1)

            #expect(whisperModel.supportsTimestamps == true)
            #expect(whisperModel.supportsLanguageDetection == true)
        }
    }

    // MARK: - Audio Model Default Selection Tests

    @Suite("Audio Model Default Selection Tests")
    struct AudioModelDefaultSelectionTests {
        @Test("Default transcription models are defined")
        func defaultTranscriptionModelsAreDefined() {
            // Test that we have sensible defaults for transcription
            #expect(TranscriptionModel.default.description == "OpenAI/whisper-1")

            // Test individual models exist
            let whisper1 = TranscriptionModel.openai(.whisper1)
            let groqModel = TranscriptionModel.groq(.whisperLargeV3Turbo)

            #expect(whisper1.description == "OpenAI/whisper-1")
            #expect(groqModel.description.contains("Groq"))
        }

        @Test("Default speech models are defined")
        func defaultSpeechModelsAreDefined() {
            // Test that we have sensible defaults for speech synthesis
            #expect(SpeechModel.default.description == "OpenAI/tts-1")

            // Test individual models exist
            let tts1 = SpeechModel.openai(.tts1)
            let tts1HD = SpeechModel.openai(.tts1HD)

            #expect(tts1.description == "OpenAI/tts-1")
            #expect(tts1HD.description == "OpenAI/tts-1-hd")
        }

        @Test("Default language models are defined")
        func defaultLanguageModelsAreDefined() {
            // Test that we have sensible defaults for language models
            // Note: Actual model defaults may vary based on implementation
            let defaultModel = Model.default
            let openaiModel = Model.openai(.gpt4o)
            let anthropicModel = Model.anthropic(.opus4)

            #expect(!defaultModel.description.isEmpty)
            #expect(openaiModel.description.contains("OpenAI"))
            #expect(anthropicModel.description.contains("Anthropic"))
        }
    }

    // MARK: - Model Capability Integration Tests

    @Suite("Model Capability Integration Tests")
    struct ModelCapabilityIntegrationTests {
        @Test("Audio and language models have complementary capabilities")
        func audioAndLanguageModelsHaveComplementaryCapabilities() {
            // Test that audio models fill the gaps left by language models

            // Language models are good at text but not audio processing
            let gpt4o = Model.openai(.gpt4o)
            #expect(gpt4o.supportsAudioInput == true) // GPT-4o native audio
            #expect(gpt4o.supportsAudioOutput == false) // No direct TTS

            // Audio models specialize in audio processing
            let whisper = TranscriptionModel.openai(.whisper1)
            let tts = SpeechModel.openai(.tts1)

            #expect(whisper.supportsTimestamps == true)
            #expect(whisper.supportsLanguageDetection == true)
            #expect(!tts.supportedFormats.isEmpty)
        }

        @Test("Provider consistency across model types")
        func providerConsistencyAcrossModelTypes() {
            // Test that providers offer consistent capabilities across model types

            // OpenAI provider should have comprehensive offerings
            let openaiLanguage = Model.openai(.gpt4o)
            let openaiTranscription = TranscriptionModel.openai(.whisper1)
            let openaiSpeech = SpeechModel.openai(.tts1)

            #expect(openaiLanguage.providerName == "OpenAI")
            #expect(openaiTranscription.providerName == "OpenAI")
            #expect(openaiSpeech.providerName == "OpenAI")

            // Groq provider should have good transcription but limited other capabilities
            let groqLanguage = Model.groq(.llama31_70b)
            let groqTranscription = TranscriptionModel.groq(.whisperLargeV3Turbo)

            #expect(groqLanguage.providerName == "Groq")
            #expect(groqTranscription.providerName == "Groq")

            // Groq focuses on speed
            #expect(groqTranscription.description.contains("turbo"))
        }

        @Test("Model descriptions are informative")
        func modelDescriptionsAreInformative() {
            // Test that language model descriptions provide useful information
            let languageModels = [
                Model.openai(.gpt4o),
                Model.anthropic(.opus4),
                Model.google(.gemini2Flash),
            ]

            for model in languageModels {
                let description = model.description
                #expect(!description.isEmpty)
                #expect(description.contains("/")) // Should have "Provider/Model" format

                let components = description.split(separator: "/")
                #expect(components.count == 2) // Should have exactly provider and model
                #expect(!components[0].isEmpty) // Provider name shouldn't be empty
                #expect(!components[1].isEmpty) // Model name shouldn't be empty
            }

            // Test audio model descriptions separately
            let transcriptionModels = [
                TranscriptionModel.openai(.whisper1),
                TranscriptionModel.groq(.whisperLargeV3Turbo),
            ]

            for model in transcriptionModels {
                let description = model.description
                #expect(!description.isEmpty)
                #expect(description.contains("/")) // Should have "Provider/Model" format
            }

            let speechModels = [
                SpeechModel.openai(.tts1),
                SpeechModel.elevenlabs(.multilingualV1),
            ]

            for model in speechModels {
                let description = model.description
                #expect(!description.isEmpty)
                #expect(description.contains("/")) // Should have "Provider/Model" format
            }
        }

        @Test("Model IDs are valid")
        func modelIDsAreValid() {
            // Test that model IDs are properly formatted
            let transcriptionModels = [
                TranscriptionModel.openai(.whisper1),
                TranscriptionModel.groq(.whisperLargeV3Turbo),
                TranscriptionModel.deepgram(.nova3),
            ]

            for model in transcriptionModels {
                let modelId = model.modelId
                #expect(!modelId.isEmpty)
                #expect(!modelId.contains(" ")) // Model IDs shouldn't have spaces
                #expect(!modelId.contains("/")) // Model IDs shouldn't have slashes
            }

            let speechModels = [
                SpeechModel.openai(.tts1),
                SpeechModel.openai(.tts1HD),
                SpeechModel.elevenlabs(.multilingualV1),
            ]

            for model in speechModels {
                let modelId = model.modelId
                #expect(!modelId.isEmpty)
                // Speech model IDs may have different formatting conventions
            }
        }
    }

    // MARK: - Model Format Support Tests

    @Suite("Model Format Support Tests")
    struct ModelFormatSupportTests {
        @Test("Speech models support expected formats")
        func speechModelsSupportExpectedFormats() {
            // Test that speech models support common audio formats
            let openaiTTS = SpeechModel.openai(.tts1)
            let supportedFormats = openaiTTS.supportedFormats

            #expect(supportedFormats.contains(.mp3))
            #expect(supportedFormats.contains(.wav))
            #expect(supportedFormats.contains(.opus))
            #expect(supportedFormats.contains(.aac))
            #expect(supportedFormats.contains(.flac))
            #expect(supportedFormats.contains(.pcm))

            // Test that different models may have different format support
            let lmntModel = SpeechModel.lmnt(.aurora)
            let lmntFormats = lmntModel.supportedFormats

            #expect(lmntFormats.contains(.wav))
            #expect(lmntFormats.contains(.mp3))
            // LMNT may have more limited format support than OpenAI
        }

        @Test("Audio formats have proper properties")
        func audioFormatsHaveProperProperties() {
            // Test that audio formats are properly categorized
            let losslessFormats = AudioFormat.allCases.filter(\.isLossless)
            let lossyFormats = AudioFormat.allCases.filter { !$0.isLossless }

            #expect(losslessFormats.contains(.wav))
            #expect(losslessFormats.contains(.flac))
            #expect(losslessFormats.contains(.pcm))

            #expect(lossyFormats.contains(.mp3))
            #expect(lossyFormats.contains(.opus))
            #expect(lossyFormats.contains(.aac))
            #expect(lossyFormats.contains(.ogg))

            // Test MIME types are correct
            #expect(AudioFormat.wav.mimeType == "audio/wav")
            #expect(AudioFormat.mp3.mimeType == "audio/mpeg")
            #expect(AudioFormat.flac.mimeType == "audio/flac")
        }
    }

    // MARK: - Voice Options Tests

    @Suite("Voice Options Tests")
    struct VoiceOptionsTests {
        @Test("Voice options are properly categorized")
        func voiceOptionsAreProperlyCategories() {
            // Test voice categorization
            let femaleVoices = VoiceOption.female
            let maleVoices = VoiceOption.male

            #expect(femaleVoices.contains(.alloy))
            #expect(femaleVoices.contains(.nova))
            #expect(femaleVoices.contains(.shimmer))

            #expect(maleVoices.contains(.echo))
            #expect(maleVoices.contains(.fable))
            #expect(maleVoices.contains(.onyx))

            // Test that there's no overlap
            let overlap = Set(femaleVoices).intersection(Set(maleVoices))
            #expect(overlap.isEmpty)
        }

        @Test("Voice options have proper string values")
        func voiceOptionsHaveProperStringValues() {
            // Test that string values match expected API values
            #expect(VoiceOption.alloy.stringValue == "alloy")
            #expect(VoiceOption.echo.stringValue == "echo")
            #expect(VoiceOption.fable.stringValue == "fable")
            #expect(VoiceOption.onyx.stringValue == "onyx")
            #expect(VoiceOption.nova.stringValue == "nova")
            #expect(VoiceOption.shimmer.stringValue == "shimmer")

            // Test custom voice
            let custom = VoiceOption.custom("my-custom-voice")
            #expect(custom.stringValue == "my-custom-voice")
        }

        @Test("Default voice is reasonable")
        func defaultVoiceIsReasonable() {
            // Test that the default voice is a good choice
            #expect(VoiceOption.default == .alloy)
            #expect(VoiceOption.female.contains(.alloy))
        }
    }
}
