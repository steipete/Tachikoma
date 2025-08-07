//
//  AudioProviderTests.swift
//  Tachikoma
//

import Testing
import Foundation
@testable import Tachikoma

@Suite("Audio Provider Tests")
struct AudioProviderTests {
    
    // MARK: - Groq Tests
    
    @Test("Groq provider initialization")
    func testGroqProviderInitialization() async throws {
        // Set test mode to use mock provider
        setenv("TACHIKOMA_TEST_MODE", "mock", 1)
        setenv("GROQ_API_KEY", "test-key", 1)
        
        let provider = try TranscriptionProviderFactory.createProvider(
            for: .groq(.whisperLargeV3),
            configuration: TachikomaConfiguration()
        )
        
        #expect(provider.modelId == "whisper-large-v3")
        #expect(provider.capabilities.supportsTimestamps == true)
        #expect(provider.capabilities.supportsLanguageDetection == true)
        
        unsetenv("TACHIKOMA_TEST_MODE")
        unsetenv("GROQ_API_KEY")
    }
    
    @Test("Groq transcription with mock")
    func testGroqTranscriptionMock() async throws {
        // Set test mode
        setenv("TACHIKOMA_TEST_MODE", "mock", 1)
        setenv("GROQ_API_KEY", "test-key", 1)
        
        let provider = try TranscriptionProviderFactory.createProvider(
            for: .groq(.whisperLargeV3),
            configuration: TachikomaConfiguration()
        )
        
        // Create test audio data
        let audioData = AudioData(data: Data([0x00, 0x01, 0x02]), format: .mp3)
        let request = TranscriptionRequest(
            audio: audioData,
            language: "en",
            includeTimestamps: true
        )
        
        let result = try await provider.transcribe(request: request)
        
        #expect(result.text == "Mock transcription result for audio file.")
        #expect(result.language == "en")
        #expect(result.segments != nil)
        
        unsetenv("TACHIKOMA_TEST_MODE")
        unsetenv("GROQ_API_KEY")
    }
    
    @Test("Groq missing API key")
    func testGroqMissingAPIKey() async throws {
        // Ensure no API key is set
        unsetenv("GROQ_API_KEY")
        unsetenv("TACHIKOMA_TEST_MODE")
        
        do {
            _ = try TranscriptionProviderFactory.createProvider(
                for: .groq(.whisperLargeV3),
                configuration: TachikomaConfiguration()
            )
            Issue.record("Should have thrown error for missing API key")
        } catch {
            #expect(error is TachikomaError)
            if case let TachikomaError.authenticationFailed(message) = error {
                #expect(message.contains("GROQ_API_KEY"))
            } else {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Deepgram Tests
    
    @Test("Deepgram provider initialization")
    func testDeepgramProviderInitialization() async throws {
        // Set test mode
        setenv("TACHIKOMA_TEST_MODE", "mock", 1)
        setenv("DEEPGRAM_API_KEY", "test-key", 1)
        
        let provider = try TranscriptionProviderFactory.createProvider(
            for: .deepgram(.nova2),
            configuration: TachikomaConfiguration()
        )
        
        #expect(provider.modelId == "nova-2")
        #expect(provider.capabilities.supportsTimestamps == true)
        #expect(provider.capabilities.supportsLanguageDetection == true)
        #expect(provider.capabilities.supportsSummarization == true)
        
        unsetenv("TACHIKOMA_TEST_MODE")
        unsetenv("DEEPGRAM_API_KEY")
    }
    
    @Test("Deepgram transcription with mock")
    func testDeepgramTranscriptionMock() async throws {
        // Set test mode
        setenv("TACHIKOMA_TEST_MODE", "mock", 1)
        setenv("DEEPGRAM_API_KEY", "test-key", 1)
        
        let provider = try TranscriptionProviderFactory.createProvider(
            for: .deepgram(.nova2),
            configuration: TachikomaConfiguration()
        )
        
        // Create test audio data
        let audioData = AudioData(data: Data([0x00, 0x01, 0x02]), format: .wav)
        let request = TranscriptionRequest(
            audio: audioData,
            language: "en",
            includeTimestamps: true,
            speakerDiarization: true,
            summarize: true
        )
        
        let result = try await provider.transcribe(request: request)
        
        #expect(result.text == "Mock transcription result for audio file.")
        #expect(result.language == "en")
        #expect(result.segments != nil)
        
        unsetenv("TACHIKOMA_TEST_MODE")
        unsetenv("DEEPGRAM_API_KEY")
    }
    
    // MARK: - ElevenLabs Tests
    
    @Test("ElevenLabs speech provider initialization")
    func testElevenLabsSpeechProviderInitialization() async throws {
        // Set test mode
        setenv("TACHIKOMA_TEST_MODE", "mock", 1)
        setenv("ELEVENLABS_API_KEY", "test-key", 1)
        
        let provider = try SpeechProviderFactory.createProvider(
            for: .elevenlabs(.multilingual_v2),
            configuration: TachikomaConfiguration()
        )
        
        #expect(provider.modelId == "eleven_multilingual_v2")
        #expect(provider.capabilities.supportedFormats.contains(.mp3))
        #expect(provider.capabilities.supportsVoiceInstructions == true) // Voice cloning
        
        unsetenv("TACHIKOMA_TEST_MODE")
        unsetenv("ELEVENLABS_API_KEY")
    }
    
    @Test("ElevenLabs speech generation with mock")
    func testElevenLabsSpeechGenerationMock() async throws {
        // Set test mode
        setenv("TACHIKOMA_TEST_MODE", "mock", 1)
        setenv("ELEVENLABS_API_KEY", "test-key", 1)
        
        let provider = try SpeechProviderFactory.createProvider(
            for: .elevenlabs(.multilingual_v2),
            configuration: TachikomaConfiguration()
        )
        
        let request = SpeechRequest(
            text: "Hello, world!",
            voice: .custom("rachel"),
            format: .mp3,
            speed: 1.0
        )
        
        let result = try await provider.generateSpeech(request: request)
        
        #expect(result.audioData.data.count == 4) // Mock returns 4 bytes
        #expect(result.audioData.format == .mp3)
        #expect(result.usage?.charactersProcessed == request.text.count)
        
        unsetenv("TACHIKOMA_TEST_MODE")
        unsetenv("ELEVENLABS_API_KEY")
    }
    
    @Test("ElevenLabs transcription not supported")
    func testElevenLabsTranscriptionNotSupported() async throws {
        // Set test mode
        setenv("TACHIKOMA_TEST_MODE", "mock", 1)
        setenv("ELEVENLABS_API_KEY", "test-key", 1)
        
        // Note: ElevenLabs doesn't actually have a transcription model in the current implementation
        // This test verifies that trying to use it for transcription fails appropriately
        
        // If ElevenLabs transcription provider is implemented but throws unsupported:
        do {
            let provider = try TranscriptionProviderFactory.createProvider(
                for: .elevenlabs(.multilingual_v2),
                configuration: TachikomaConfiguration()
            )
            
            let audioData = AudioData(data: Data([0x00, 0x01]), format: .mp3)
            let request = TranscriptionRequest(audio: audioData)
            
            _ = try await provider.transcribe(request: request)
            Issue.record("Should have thrown unsupported operation error")
        } catch {
            // Expected to fail
            #expect(error is TachikomaError)
        }
        
        unsetenv("TACHIKOMA_TEST_MODE")
        unsetenv("ELEVENLABS_API_KEY")
    }
    
    // MARK: - Factory Tests
    
    @Test("TranscriptionProviderFactory creates correct providers")
    func testTranscriptionProviderFactory() async throws {
        // Set test mode
        setenv("TACHIKOMA_TEST_MODE", "mock", 1)
        
        // Test OpenAI
        setenv("OPENAI_API_KEY", "test-key", 1)
        let openaiProvider = try TranscriptionProviderFactory.createProvider(
            for: .openai(.whisperLarge),
            configuration: TachikomaConfiguration()
        )
        #expect(openaiProvider.modelId == "whisper-large")
        unsetenv("OPENAI_API_KEY")
        
        // Test Groq
        setenv("GROQ_API_KEY", "test-key", 1)
        let groqProvider = try TranscriptionProviderFactory.createProvider(
            for: .groq(.whisperLargeV3),
            configuration: TachikomaConfiguration()
        )
        #expect(groqProvider.modelId == "whisper-large-v3")
        unsetenv("GROQ_API_KEY")
        
        // Test Deepgram
        setenv("DEEPGRAM_API_KEY", "test-key", 1)
        let deepgramProvider = try TranscriptionProviderFactory.createProvider(
            for: .deepgram(.nova2),
            configuration: TachikomaConfiguration()
        )
        #expect(deepgramProvider.modelId == "nova-2")
        unsetenv("DEEPGRAM_API_KEY")
        
        unsetenv("TACHIKOMA_TEST_MODE")
    }
    
    @Test("SpeechProviderFactory creates correct providers")
    func testSpeechProviderFactory() async throws {
        // Set test mode
        setenv("TACHIKOMA_TEST_MODE", "mock", 1)
        
        // Test OpenAI
        setenv("OPENAI_API_KEY", "test-key", 1)
        let openaiProvider = try SpeechProviderFactory.createProvider(
            for: .openai(.tts1HD),
            configuration: TachikomaConfiguration()
        )
        #expect(openaiProvider.modelId == "tts-1-hd")
        unsetenv("OPENAI_API_KEY")
        
        // Test ElevenLabs
        setenv("ELEVENLABS_API_KEY", "test-key", 1)
        let elevenLabsProvider = try SpeechProviderFactory.createProvider(
            for: .elevenlabs(.multilingual_v2),
            configuration: TachikomaConfiguration()
        )
        #expect(elevenLabsProvider.modelId == "eleven_multilingual_v2")
        unsetenv("ELEVENLABS_API_KEY")
        
        unsetenv("TACHIKOMA_TEST_MODE")
    }
    
    @Test("Unsupported providers throw errors")
    func testUnsupportedProviders() async throws {
        // Don't set test mode to trigger actual implementation
        unsetenv("TACHIKOMA_TEST_MODE")
        
        // Test AssemblyAI (removed)
        do {
            _ = try TranscriptionProviderFactory.createProvider(
                for: .assemblyai(.best),
                configuration: TachikomaConfiguration()
            )
            Issue.record("AssemblyAI should not be implemented")
        } catch {
            #expect(error is TachikomaError)
            if case let TachikomaError.unsupportedOperation(message) = error {
                #expect(message.contains("AssemblyAI"))
            }
        }
        
        // Test RevAI (removed)
        do {
            _ = try TranscriptionProviderFactory.createProvider(
                for: .revai(.english),
                configuration: TachikomaConfiguration()
            )
            Issue.record("RevAI should not be implemented")
        } catch {
            #expect(error is TachikomaError)
            if case let TachikomaError.unsupportedOperation(message) = error {
                #expect(message.contains("RevAI"))
            }
        }
        
        // Test Azure (removed)
        do {
            _ = try TranscriptionProviderFactory.createProvider(
                for: .azure(.speechToTextV2),
                configuration: TachikomaConfiguration()
            )
            Issue.record("Azure should not be implemented")
        } catch {
            #expect(error is TachikomaError)
            if case let TachikomaError.unsupportedOperation(message) = error {
                #expect(message.contains("Azure"))
            }
        }
    }
    
    // MARK: - Audio Configuration Tests
    
    @Test("AudioConfiguration gets API keys")
    func testAudioConfigurationAPIKeys() async throws {
        // Test environment variable lookup
        setenv("GROQ_API_KEY", "groq-test-key", 1)
        setenv("DEEPGRAM_API_KEY", "deepgram-test-key", 1)
        setenv("ELEVENLABS_API_KEY", "elevenlabs-test-key", 1)
        
        let groqKey = AudioConfiguration.getAPIKey(for: "groq")
        #expect(groqKey == "groq-test-key")
        
        let deepgramKey = AudioConfiguration.getAPIKey(for: "deepgram")
        #expect(deepgramKey == "deepgram-test-key")
        
        let elevenLabsKey = AudioConfiguration.getAPIKey(for: "elevenlabs")
        #expect(elevenLabsKey == "elevenlabs-test-key")
        
        // Test alternative names
        setenv("DEEPGRAM_TOKEN", "deepgram-token", 1)
        unsetenv("DEEPGRAM_API_KEY")
        let deepgramToken = AudioConfiguration.getAPIKey(for: "deepgram")
        #expect(deepgramToken == "deepgram-token")
        
        // Clean up
        unsetenv("GROQ_API_KEY")
        unsetenv("DEEPGRAM_API_KEY")
        unsetenv("DEEPGRAM_TOKEN")
        unsetenv("ELEVENLABS_API_KEY")
    }
}
