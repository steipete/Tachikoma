import Foundation
import Testing
@testable import TachikomaCore

@Suite("Audio Models Tests")
struct AudioModelsTests {
    
    // MARK: - TranscriptionModel Tests
    
    @Suite("TranscriptionModel Tests")
    struct TranscriptionModelTests {
        
        @Test("TranscriptionModel OpenAI enum properties")
        func openAIModelProperties() {
            let whisper = TranscriptionModel.OpenAI.whisper1
            let gpt4oTranscribe = TranscriptionModel.OpenAI.gpt4oTranscribe
            let gpt4oMiniTranscribe = TranscriptionModel.OpenAI.gpt4oMiniTranscribe
            
            // Test model IDs
            #expect(whisper.rawValue == "whisper-1")
            #expect(gpt4oTranscribe.rawValue == "gpt-4o-transcribe")
            #expect(gpt4oMiniTranscribe.rawValue == "gpt-4o-mini-transcribe")
            
            // Test capabilities
            #expect(whisper.supportsTimestamps == true)
            #expect(gpt4oTranscribe.supportsTimestamps == false)
            #expect(gpt4oMiniTranscribe.supportsTimestamps == false)
            
            #expect(whisper.supportsLanguageDetection == true)
            #expect(gpt4oTranscribe.supportsLanguageDetection == false)
            #expect(gpt4oMiniTranscribe.supportsLanguageDetection == false)
        }
        
        @Test("TranscriptionModel Groq enum properties")
        func groqModelProperties() {
            let whisperLargeV3 = TranscriptionModel.Groq.whisperLargeV3
            let whisperLargeV3Turbo = TranscriptionModel.Groq.whisperLargeV3Turbo
            let distilWhisperLargeV3En = TranscriptionModel.Groq.distilWhisperLargeV3En
            
            // Test model IDs
            #expect(whisperLargeV3.rawValue == "whisper-large-v3")
            #expect(whisperLargeV3Turbo.rawValue == "whisper-large-v3-turbo")
            #expect(distilWhisperLargeV3En.rawValue == "distil-whisper-large-v3-en")
            
            // Test capabilities (all Groq models support these)
            #expect(whisperLargeV3.supportsTimestamps == true)
            #expect(whisperLargeV3Turbo.supportsLanguageDetection == true)
            #expect(distilWhisperLargeV3En.supportsTimestamps == true)
        }
        
        @Test("TranscriptionModel main enum properties")
        func transcriptionModelProperties() {
            let openaiModel = TranscriptionModel.openai(.whisper1)
            let groqModel = TranscriptionModel.groq(.whisperLargeV3Turbo)
            let deepgramModel = TranscriptionModel.deepgram(.nova3)
            
            // Test descriptions
            #expect(openaiModel.description == "OpenAI/whisper-1")
            #expect(groqModel.description == "Groq/whisper-large-v3-turbo")
            #expect(deepgramModel.description == "Deepgram/nova-3")
            
            // Test model IDs
            #expect(openaiModel.modelId == "whisper-1")
            #expect(groqModel.modelId == "whisper-large-v3-turbo")
            #expect(deepgramModel.modelId == "nova-3")
            
            // Test provider names
            #expect(openaiModel.providerName == "OpenAI")
            #expect(groqModel.providerName == "Groq")
            #expect(deepgramModel.providerName == "Deepgram")
        }
        
        @Test("TranscriptionModel default models")
        func defaultTranscriptionModels() {
            #expect(TranscriptionModel.default.description == "OpenAI/whisper-1")
            #expect(TranscriptionModel.whisper.description == "OpenAI/whisper-1")
            #expect(TranscriptionModel.fast.description == "Groq/whisper-large-v3-turbo")
            #expect(TranscriptionModel.accurate.description == "Deepgram/nova-3")
        }
        
        @Test("TranscriptionModel capabilities forwarding")
        func capabilitiesForwarding() {
            let openaiWhisper = TranscriptionModel.openai(.whisper1)
            let groqTurbo = TranscriptionModel.groq(.whisperLargeV3Turbo)
            
            // Test that main enum forwards capabilities correctly
            #expect(openaiWhisper.supportsTimestamps == true)
            #expect(openaiWhisper.supportsLanguageDetection == true)
            
            #expect(groqTurbo.supportsTimestamps == true)
            #expect(groqTurbo.supportsLanguageDetection == true)
        }
    }
    
    // MARK: - SpeechModel Tests
    
    @Suite("SpeechModel Tests")
    struct SpeechModelTests {
        
        @Test("SpeechModel OpenAI enum properties")
        func openAIModelProperties() {
            let tts1 = SpeechModel.OpenAI.tts1
            let tts1HD = SpeechModel.OpenAI.tts1HD
            let gpt4oMiniTTS = SpeechModel.OpenAI.gpt4oMiniTTS
            
            // Test model IDs
            #expect(tts1.rawValue == "tts-1")
            #expect(tts1HD.rawValue == "tts-1-hd")
            #expect(gpt4oMiniTTS.rawValue == "gpt-4o-mini-tts")
            
            // Test voice instructions support
            #expect(tts1.supportsVoiceInstructions == false)
            #expect(tts1HD.supportsVoiceInstructions == false)
            #expect(gpt4oMiniTTS.supportsVoiceInstructions == true)
            
            // Test supported formats (all should support the same formats)
            let expectedFormats: [AudioFormat] = [.mp3, .opus, .aac, .flac, .wav, .pcm]
            #expect(tts1.supportedFormats == expectedFormats)
            #expect(tts1HD.supportedFormats == expectedFormats)
            #expect(gpt4oMiniTTS.supportedFormats == expectedFormats)
            
            // Test supported voices (all should support the same voices)
            let expectedVoices: [VoiceOption] = [.alloy, .echo, .fable, .onyx, .nova, .shimmer]
            #expect(tts1.supportedVoices == expectedVoices)
            #expect(tts1HD.supportedVoices == expectedVoices)
            #expect(gpt4oMiniTTS.supportedVoices == expectedVoices)
        }
        
        @Test("SpeechModel LMNT enum properties")
        func lmntModelProperties() {
            let aurora = SpeechModel.LMNT.aurora
            let blizzard = SpeechModel.LMNT.blizzard
            
            // Test model IDs
            #expect(aurora.rawValue == "aurora")
            #expect(blizzard.rawValue == "blizzard")
            
            // Test capabilities
            #expect(aurora.supportsLanguages == true)
            #expect(blizzard.supportsLanguages == true)
            
            let expectedFormats: [AudioFormat] = [.wav, .mp3]
            #expect(aurora.supportedFormats == expectedFormats)
            #expect(blizzard.supportedFormats == expectedFormats)
        }
        
        @Test("SpeechModel main enum properties")
        func speechModelProperties() {
            let openaiModel = SpeechModel.openai(.tts1)
            let lmntModel = SpeechModel.lmnt(.aurora)
            let humeModel = SpeechModel.hume(.default)
            let elevenlabsModel = SpeechModel.elevenlabs(.multilingualV1)
            
            // Test descriptions
            #expect(openaiModel.description == "OpenAI/tts-1")
            #expect(lmntModel.description == "LMNT/aurora")
            #expect(humeModel.description == "Hume/default")
            #expect(elevenlabsModel.description == "ElevenLabs/eleven_multilingual_v1")
            
            // Test model IDs
            #expect(openaiModel.modelId == "tts-1")
            #expect(lmntModel.modelId == "aurora")
            #expect(humeModel.modelId == "default")
            #expect(elevenlabsModel.modelId == "eleven_multilingual_v1")
            
            // Test provider names
            #expect(openaiModel.providerName == "OpenAI")
            #expect(lmntModel.providerName == "LMNT")
            #expect(humeModel.providerName == "Hume")
            #expect(elevenlabsModel.providerName == "ElevenLabs")
        }
        
        @Test("SpeechModel default models")
        func defaultSpeechModels() {
            #expect(SpeechModel.default.description == "OpenAI/tts-1")
            #expect(SpeechModel.highQuality.description == "OpenAI/tts-1-hd")
            #expect(SpeechModel.fast.description == "OpenAI/tts-1")
            #expect(SpeechModel.expressive.description == "OpenAI/gpt-4o-mini-tts")
        }
        
        @Test("SpeechModel supported formats forwarding")
        func supportedFormatsForwarding() {
            let openaiModel = SpeechModel.openai(.tts1)
            let lmntModel = SpeechModel.lmnt(.aurora)
            let humeModel = SpeechModel.hume(.default)
            
            // Test that main enum forwards supported formats correctly
            let expectedOpenAIFormats: [AudioFormat] = [.mp3, .opus, .aac, .flac, .wav, .pcm]
            #expect(openaiModel.supportedFormats == expectedOpenAIFormats)
            
            let expectedLMNTFormats: [AudioFormat] = [.wav, .mp3]
            #expect(lmntModel.supportedFormats == expectedLMNTFormats)
            
            let expectedHumeFormats: [AudioFormat] = [.wav]
            #expect(humeModel.supportedFormats == expectedHumeFormats)
        }
    }
    
    // MARK: - All Cases Tests
    
    @Test("TranscriptionModel all cases completeness")
    func transcriptionModelAllCases() {
        // Test that allCases includes all expected models
        let openaiCases = TranscriptionModel.OpenAI.allCases
        #expect(openaiCases.contains(.whisper1))
        #expect(openaiCases.contains(.gpt4oTranscribe))
        #expect(openaiCases.contains(.gpt4oMiniTranscribe))
        #expect(openaiCases.count == 3)
        
        let groqCases = TranscriptionModel.Groq.allCases
        #expect(groqCases.contains(.whisperLargeV3))
        #expect(groqCases.contains(.whisperLargeV3Turbo))
        #expect(groqCases.contains(.distilWhisperLargeV3En))
        #expect(groqCases.count == 3)
    }
    
    @Test("SpeechModel all cases completeness")
    func speechModelAllCases() {
        // Test that allCases includes all expected models
        let openaiCases = SpeechModel.OpenAI.allCases
        #expect(openaiCases.contains(.tts1))
        #expect(openaiCases.contains(.tts1HD))
        #expect(openaiCases.contains(.gpt4oMiniTTS))
        #expect(openaiCases.count == 3)
        
        let lmntCases = SpeechModel.LMNT.allCases
        #expect(lmntCases.contains(.aurora))
        #expect(lmntCases.contains(.blizzard))
        #expect(lmntCases.count == 2)
    }
}