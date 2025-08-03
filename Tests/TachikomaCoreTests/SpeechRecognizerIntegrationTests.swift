import Foundation
import Testing
@testable import TachikomaCore

@Suite("Audio System Integration Tests")
struct AudioSystemIntegrationTests {
    
    // MARK: - Basic Audio Function Tests
    
    @Suite("Basic Audio Function Tests")
    struct BasicAudioFunctionTests {
        
        @Test("Audio transcription functions are available")
        func audioTranscriptionFunctionsAvailable() async throws {
            // Test that core audio transcription functions exist and work
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let audioData = AudioData(data: Data([0x01, 0x02, 0x03, 0x04]), format: .wav)
                
                // Test basic transcription function exists
                let result = try await transcribe(audioData, using: .openai(.whisper1))
                
                #expect(!result.text.isEmpty)
                #expect(result.usage != nil)
            }
        }
        
        @Test("Audio speech generation functions are available")
        func audioSpeechGenerationFunctionsAvailable() async throws {
            // Test that core speech generation functions exist and work
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                // Test basic speech generation function exists
                let result = try await generateSpeech("Hello, world!", using: .openai(.tts1))
                
                #expect(!result.audioData.data.isEmpty)
                #expect(result.audioData.format == .mp3) // Default format
                #expect(result.usage != nil)
            }
        }
        
        @Test("Audio model types work correctly")
        func audioModelTypesWork() {
            // Test that audio model enums work as expected
            let transcriptionModel = TranscriptionModel.openai(.whisper1)
            #expect(transcriptionModel.modelId == "whisper-1")
            #expect(transcriptionModel.providerName == "OpenAI")
            #expect(transcriptionModel.supportsTimestamps == true)
            
            let speechModel = SpeechModel.openai(.tts1)
            #expect(speechModel.modelId == "tts-1")
            #expect(speechModel.providerName == "OpenAI")
            #expect(speechModel.supportedFormats.contains(.mp3))
        }
        
        @Test("Audio data types work correctly")
        func audioDataTypesWork() throws {
            // Test that audio data types work as expected
            let testData = Data([0x01, 0x02, 0x03, 0x04])
            let audioData = AudioData(data: testData, format: .wav, sampleRate: 44100, channels: 2, duration: 5.0)
            
            #expect(audioData.data == testData)
            #expect(audioData.format == .wav)
            #expect(audioData.sampleRate == 44100)
            #expect(audioData.channels == 2)
            #expect(audioData.duration == 5.0)
            #expect(audioData.size == 4)
            
            // Test audio format properties
            #expect(AudioFormat.wav.mimeType == "audio/wav")
            #expect(AudioFormat.wav.isLossless == true)
            #expect(AudioFormat.mp3.isLossless == false)
            
            // Test voice options
            #expect(VoiceOption.alloy.stringValue == "alloy")
            #expect(VoiceOption.default == .alloy)
        }
        
        @Test("AbortSignal functionality works")
        func abortSignalFunctionality() async throws {
            let signal = AbortSignal()
            
            #expect(signal.cancelled == false)
            
            signal.cancel()
            #expect(signal.cancelled == true)
            
            // Test that cancelled signal throws
            #expect(throws: TachikomaError.self) {
                try signal.throwIfCancelled()
            }
            
            // Test timeout signal
            let timeoutSignal = AbortSignal.timeout(0.1) // 100ms
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            #expect(timeoutSignal.cancelled == true)
        }
    }
    
    // MARK: - Provider Integration Tests
    
    @Suite("Provider Integration Tests")
    struct ProviderIntegrationTests {
        
        @Test("Transcription provider factory works")
        func transcriptionProviderFactoryWorks() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let provider = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))
                
                #expect(provider.modelId == "whisper-1")
                #expect(provider.capabilities.supportsTimestamps == true)
                #expect(provider.capabilities.supportedFormats.contains(.wav))
            }
        }
        
        @Test("Speech provider factory works")
        func speechProviderFactoryWorks() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let provider = try SpeechProviderFactory.createProvider(for: .openai(.tts1))
                
                #expect(provider.modelId == "tts-1")
                #expect(provider.capabilities.supportsSpeedControl == true)
                #expect(provider.capabilities.supportedFormats.contains(.mp3))
            }
        }
        
        @Test("Provider factory fails without API key")
        func providerFactoryFailsWithoutAPIKey() async throws {
            try await TestHelpers.withNoAPIKeys {
                #expect(throws: TachikomaError.self) {
                    _ = try TranscriptionProviderFactory.createProvider(for: .openai(.whisper1))
                }
                
                #expect(throws: TachikomaError.self) {
                    _ = try SpeechProviderFactory.createProvider(for: .openai(.tts1))
                }
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Suite("Error Handling Tests")
    struct ErrorHandlingTests {
        
        @Test("Audio error types are defined")
        func audioErrorTypesAreDefined() {
            let operationCancelled = TachikomaError.operationCancelled
            let noAudioData = TachikomaError.noAudioData
            let unsupportedFormat = TachikomaError.unsupportedAudioFormat
            let transcriptionFailed = TachikomaError.transcriptionFailed
            let speechFailed = TachikomaError.speechGenerationFailed
            
            // Test that these errors have meaningful descriptions
            #expect(operationCancelled.localizedDescription.contains("cancelled"))
            #expect(noAudioData.localizedDescription.contains("audio data"))
            #expect(unsupportedFormat.localizedDescription.contains("format"))
            #expect(transcriptionFailed.localizedDescription.contains("Transcription"))
            #expect(speechFailed.localizedDescription.contains("Speech"))
        }
        
        @Test("Empty audio data is handled")
        func emptyAudioDataIsHandled() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let emptyAudioData = AudioData(data: Data(), format: .wav)
                
                await #expect(throws: TachikomaError.self) {
                    _ = try await transcribe(emptyAudioData, using: .openai(.whisper1))
                }
            }
        }
        
        @Test("Empty text for speech generation is handled")
        func emptyTextForSpeechGenerationIsHandled() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                await #expect(throws: TachikomaError.self) {
                    _ = try await generateSpeech("", using: .openai(.tts1))
                }
            }
        }
    }
    
    // MARK: - File I/O Tests
    
    @Suite("File I/O Tests")
    struct FileIOTests {
        
        @Test("AudioData file operations work")
        func audioDataFileOperationsWork() throws {
            // Test creating AudioData from file
            let tempDir = FileManager.default.temporaryDirectory
            let testFile = tempDir.appendingPathComponent("test_audio.wav")
            let testData = Data([0x01, 0x02, 0x03, 0x04])
            try testData.write(to: testFile)
            
            let audioData = try AudioData(contentsOf: testFile)
            #expect(audioData.data == testData)
            #expect(audioData.format == .wav) // Inferred from extension
            #expect(audioData.size == 4)
            
            // Test writing AudioData to file
            let outputFile = tempDir.appendingPathComponent("output_audio.wav")
            try audioData.write(to: outputFile)
            
            let writtenData = try Data(contentsOf: outputFile)
            #expect(writtenData == testData)
            
            // Clean up
            try? FileManager.default.removeItem(at: testFile)
            try? FileManager.default.removeItem(at: outputFile)
        }
        
        @Test("AudioData handles unknown file extensions")
        func audioDataHandlesUnknownExtensions() throws {
            let tempDir = FileManager.default.temporaryDirectory
            let testFile = tempDir.appendingPathComponent("test_audio.unknown")
            let testData = Data([0x01, 0x02])
            try testData.write(to: testFile)
            
            let audioData = try AudioData(contentsOf: testFile)
            #expect(audioData.format == .wav) // Default fallback
            
            // Clean up
            try? FileManager.default.removeItem(at: testFile)
        }
    }
}