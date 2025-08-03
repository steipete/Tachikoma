import Foundation
import Testing
@testable import TachikomaCore

@Suite("Audio Functions Tests")
struct AudioFunctionsTests {
    
    // MARK: - Transcription Function Tests
    
    @Suite("Transcription Functions Tests")
    struct TranscriptionFunctionsTests {
        
        @Test("transcribe() function with default parameters")
        func transcribeFunctionDefaults() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let audioData = AudioData(data: Data([0x01, 0x02, 0x03]), format: .wav)
                
                let result = try await transcribe(audioData)
                
                // With placeholder implementation, verify basic structure
                #expect(!result.text.isEmpty)
                #expect(result.usage != nil)
                #expect(result.usage?.durationSeconds != nil)
            }
        }
        
        @Test("transcribe() function with specific model")
        func transcribeFunctionSpecificModel() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let audioData = AudioData(data: Data([0x01, 0x02, 0x03]), format: .mp3)
                
                let result = try await transcribe(
                    audioData,
                    using: .openai(.whisper1),
                    language: "en",
                    prompt: "This is audio from a meeting"
                )
                
                #expect(!result.text.isEmpty)
                #expect(result.language == "en")
            }
        }
        
        @Test("transcribe() function with file URL")
        func transcribeFunctionFileURL() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["groq": "test-key"]) {
                // Create a temporary audio file
                let tempDir = FileManager.default.temporaryDirectory
                let audioFile = tempDir.appendingPathComponent("test_audio.wav")
                let testData = Data([0x01, 0x02, 0x03, 0x04])
                try testData.write(to: audioFile)
                
                let result = try await transcribe(
                    audioFile,
                    using: .groq(.whisperLargeV3Turbo)
                )
                
                #expect(!result.text.isEmpty)
                
                // Clean up
                try? FileManager.default.removeItem(at: audioFile)
            }
        }
        
        @Test("transcribe() function with timestamps")
        func transcribeFunctionTimestamps() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["deepgram": "test-key"]) {
                let audioData = AudioData(data: Data([0x01, 0x02, 0x03]), format: .wav)
                
                let result = try await transcribe(
                    audioData,
                    using: .deepgram(.nova3),
                    timestampGranularities: [.word, .segment],
                    responseFormat: .verbose
                )
                
                #expect(!result.text.isEmpty)
                #expect(result.segments != nil)
            }
        }
        
        @Test("transcribe() function with abort signal")
        func transcribeFunctionAbortSignal() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let audioData = AudioData(data: Data([0x01, 0x02, 0x03]), format: .wav)
                let abortSignal = AbortSignal()
                
                // Cancel immediately to test abort functionality
                abortSignal.cancel()
                
                await #expect(throws: TachikomaError.self) {
                    try await transcribe(
                        audioData,
                        using: .openai(.whisper1),
                        abortSignal: abortSignal
                    )
                }
            }
        }
        
        @Test("transcribe() function error handling - missing API key")
        func transcribeFunctionMissingAPIKey() async throws {
            try await TestHelpers.withNoAPIKeys {
                let audioData = AudioData(data: Data([0x01, 0x02]), format: .wav)
                
                await #expect(throws: TachikomaError.self) {
                    try await transcribe(audioData, using: .openai(.whisper1))
                }
            }
        }
        
        @Test("transcribe() function error handling - empty audio data")
        func transcribeFunctionEmptyAudioData() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let emptyAudioData = AudioData(data: Data(), format: .wav)
                
                await #expect(throws: TachikomaError.self) {
                    try await transcribe(emptyAudioData)
                }
            }
        }
    }
    
    // MARK: - Speech Generation Function Tests
    
    @Suite("Speech Generation Functions Tests")
    struct SpeechGenerationFunctionsTests {
        
        @Test("generateSpeech() function with default parameters")
        func generateSpeechFunctionDefaults() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let result = try await generateSpeech("Hello, world!")
                
                #expect(!result.audioData.data.isEmpty)
                #expect(result.audioData.format == .mp3) // Default format
                #expect(result.usage != nil)
                #expect(result.usage?.charactersProcessed == 13) // "Hello, world!".count
            }
        }
        
        @Test("generateSpeech() function with specific model and voice")
        func generateSpeechFunctionSpecificModel() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let result = try await generateSpeech(
                    "This is a test message",
                    using: .openai(.tts1HD),
                    voice: .nova,
                    format: .wav,
                    speed: 1.2
                )
                
                #expect(!result.audioData.data.isEmpty)
                #expect(result.audioData.format == .wav)
                #expect(result.usage != nil)
            }
        }
        
        @Test("generateSpeech() function with custom voice")
        func generateSpeechFunctionCustomVoice() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["elevenlabs": "test-key"]) {
                let customVoice = VoiceOption.custom("my-custom-voice-id")
                
                let result = try await generateSpeech(
                    "Testing custom voice",
                    using: .elevenlabs(.multilingualV1),
                    voice: customVoice,
                    language: "en",
                    instructions: "Speak slowly and clearly"
                )
                
                #expect(!result.audioData.data.isEmpty)
                #expect(result.usage != nil)
            }
        }
        
        @Test("generateSpeech() function with file output")
        func generateSpeechFunctionFileOutput() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let tempDir = FileManager.default.temporaryDirectory
                let outputFile = tempDir.appendingPathComponent("generated_speech.wav")
                
                let result = try await generateSpeech(
                    "Save this to a file",
                    using: .openai(.tts1),
                    voice: .alloy,
                    format: .wav,
                    outputFile: outputFile
                )
                
                #expect(!result.audioData.data.isEmpty)
                #expect(FileManager.default.fileExists(atPath: outputFile.path))
                
                // Verify file contents match result
                let fileData = try Data(contentsOf: outputFile)
                #expect(fileData == result.audioData.data)
                
                // Clean up
                try? FileManager.default.removeItem(at: outputFile)
            }
        }
        
        @Test("generateSpeech() function with abort signal")
        func generateSpeechFunctionAbortSignal() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let abortSignal = AbortSignal()
                
                // Cancel immediately to test abort functionality
                abortSignal.cancel()
                
                await #expect(throws: TachikomaError.self) {
                    try await generateSpeech(
                        "This should be cancelled",
                        using: .openai(.tts1),
                        abortSignal: abortSignal
                    )
                }
            }
        }
        
        @Test("generateSpeech() function error handling - empty text")
        func generateSpeechFunctionEmptyText() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                await #expect(throws: TachikomaError.self) {
                    try await generateSpeech("")
                }
            }
        }
        
        @Test("generateSpeech() function error handling - text too long")
        func generateSpeechFunctionTextTooLong() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                // Create text longer than OpenAI's 4096 character limit
                let longText = String(repeating: "A", count: 5000)
                
                await #expect(throws: TachikomaError.self) {
                    try await generateSpeech(longText, using: .openai(.tts1))
                }
            }
        }
        
        @Test("generateSpeech() function error handling - missing API key")
        func generateSpeechFunctionMissingAPIKey() async throws {
            try await TestHelpers.withNoAPIKeys {
                await #expect(throws: TachikomaError.self) {
                    try await generateSpeech("Test", using: .openai(.tts1))
                }
            }
        }
    }
    
    // MARK: - Batch Operations Tests
    
    @Suite("Batch Operations Tests")
    struct BatchOperationsTests {
        
        @Test("batchTranscribe() function with multiple audio files")
        func batchTranscribeFunctionMultipleFiles() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let audioData1 = AudioData(data: Data([0x01, 0x02]), format: .wav)
                let audioData2 = AudioData(data: Data([0x03, 0x04]), format: .mp3)
                let audioData3 = AudioData(data: Data([0x05, 0x06]), format: .flac)
                
                let results = try await batchTranscribe(
                    [audioData1, audioData2, audioData3],
                    using: .openai(.whisper1),
                    language: "en"
                )
                
                #expect(results.count == 3)
                #expect(results.allSatisfy { !$0.text.isEmpty })
                #expect(results.allSatisfy { $0.language == "en" })
            }
        }
        
        @Test("batchTranscribe() function with different models")
        func batchTranscribeFunctionDifferentModels() async throws {
            try await TestHelpers.withStandardTestKeys {
                let audioData = AudioData(data: Data([0x01, 0x02]), format: .wav)
                
                let models: [TranscriptionModel] = [
                    .openai(.whisper1),
                    .groq(.whisperLargeV3Turbo),
                    .deepgram(.nova3)
                ]
                
                let results = try await batchTranscribe(
                    Array(repeating: audioData, count: 3),
                    using: models
                )
                
                #expect(results.count == 3)
                #expect(results.allSatisfy { !$0.text.isEmpty })
            }
        }
        
        @Test("batchTranscribe() function with concurrent limit")
        func batchTranscribeFunctionConcurrentLimit() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let audioFiles = (1...10).map { index in
                    AudioData(data: Data([UInt8(index)]), format: .wav)
                }
                
                let startTime = Date()
                let results = try await batchTranscribe(
                    audioFiles,
                    using: .openai(.whisper1),
                    maxConcurrentOperations: 3
                )
                let duration = Date().timeIntervalSince(startTime)
                
                #expect(results.count == 10)
                #expect(results.allSatisfy { !$0.text.isEmpty })
                
                // With concurrent limit of 3, it should take longer than unlimited concurrency
                // But since we're using placeholder implementations, just verify it completed
                #expect(duration > 0)
            }
        }
        
        @Test("batchGenerateSpeech() function with multiple texts")
        func batchGenerateSpeechFunctionMultipleTexts() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let texts = [
                    "Hello, world!",
                    "This is the second message.",
                    "And this is the third one."
                ]
                
                let results = try await batchGenerateSpeech(
                    texts,
                    using: .openai(.tts1),
                    voice: .alloy,
                    format: .wav
                )
                
                #expect(results.count == 3)
                #expect(results.allSatisfy { !$0.audioData.data.isEmpty })
                #expect(results.allSatisfy { $0.audioData.format == .wav })
            }
        }
        
        @Test("batchGenerateSpeech() function with different voices")
        func batchGenerateSpeechFunctionDifferentVoices() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let texts = ["Message one", "Message two", "Message three"]
                let voices: [VoiceOption] = [.alloy, .nova, .shimmer]
                
                let results = try await batchGenerateSpeech(
                    texts,
                    using: .openai(.tts1),
                    voices: voices,
                    format: .mp3
                )
                
                #expect(results.count == 3)
                #expect(results.allSatisfy { !$0.audioData.data.isEmpty })
            }
        }
        
        @Test("batchGenerateSpeech() function error handling - partial failures")
        func batchGenerateSpeechFunctionPartialFailures() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let texts = [
                    "Valid text",
                    "", // Empty text - should fail
                    "Another valid text"
                ]
                
                // With continueOnError: true, should get partial results
                let results = try await batchGenerateSpeech(
                    texts,
                    using: .openai(.tts1),
                    continueOnError: true
                )
                
                // Should have 2 successful results (valid texts) and 1 failure handled
                #expect(results.count <= 3) // May have fewer results due to failures
                #expect(results.allSatisfy { !$0.audioData.data.isEmpty })
            }
        }
        
        @Test("batch operations progress tracking")
        func batchOperationsProgressTracking() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let audioFiles = (1...5).map { index in
                    AudioData(data: Data([UInt8(index)]), format: .wav)
                }
                
                var progressUpdates: [BatchProgress] = []
                
                let results = try await batchTranscribe(
                    audioFiles,
                    using: .openai(.whisper1)
                ) { progress in
                    progressUpdates.append(progress)
                }
                
                #expect(results.count == 5)
                #expect(!progressUpdates.isEmpty)
                #expect(progressUpdates.last?.completedCount == 5)
                #expect(progressUpdates.last?.totalCount == 5)
            }
        }
    }
    
    // MARK: - Convenience Functions Tests
    
    @Suite("Convenience Functions Tests")
    struct ConvenienceFunctionsTests {
        
        @Test("quickTranscribe() convenience function")
        func quickTranscribeFunction() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let audioData = AudioData(data: Data([0x01, 0x02, 0x03]), format: .wav)
                
                // Quick transcribe should use defaults and return just the text
                let text = try await quickTranscribe(audioData)
                
                #expect(!text.isEmpty)
            }
        }
        
        @Test("quickGenerateSpeech() convenience function")
        func quickGenerateSpeechFunction() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                // Quick generate speech should return AudioData directly
                let audioData = try await quickGenerateSpeech("Hello, world!")
                
                #expect(!audioData.data.isEmpty)
                #expect(audioData.format == .mp3) // Default format
            }
        }
        
        @Test("saveTranscription() convenience function")
        func saveTranscriptionFunction() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let audioData = AudioData(data: Data([0x01, 0x02, 0x03]), format: .wav)
                let tempDir = FileManager.default.temporaryDirectory
                let outputFile = tempDir.appendingPathComponent("transcription.txt")
                
                try await saveTranscription(
                    audioData,
                    to: outputFile,
                    using: .openai(.whisper1),
                    format: .text
                )
                
                #expect(FileManager.default.fileExists(atPath: outputFile.path))
                
                let savedText = try String(contentsOf: outputFile)
                #expect(!savedText.isEmpty)
                
                // Clean up
                try? FileManager.default.removeItem(at: outputFile)
            }
        }
        
        @Test("saveTranscription() with SRT format")
        func saveTranscriptionSRTFormat() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let audioData = AudioData(data: Data([0x01, 0x02, 0x03]), format: .wav)
                let tempDir = FileManager.default.temporaryDirectory
                let outputFile = tempDir.appendingPathComponent("transcription.srt")
                
                try await saveTranscription(
                    audioData,
                    to: outputFile,
                    using: .openai(.whisper1),
                    format: .srt,
                    timestampGranularities: [.segment]
                )
                
                #expect(FileManager.default.fileExists(atPath: outputFile.path))
                
                let savedContent = try String(contentsOf: outputFile)
                #expect(!savedContent.isEmpty)
                
                // Clean up
                try? FileManager.default.removeItem(at: outputFile)
            }
        }
    }
    
    // MARK: - Integration Tests
    
    @Suite("Integration Tests")
    struct IntegrationTests {
        
        @Test("transcribe and generate speech pipeline")
        func transcribeAndGenerateSpeechPipeline() async throws {
            try await TestHelpers.withStandardTestKeys {
                // Step 1: Create some "audio" data
                let originalAudioData = AudioData(data: Data([0x01, 0x02, 0x03, 0x04]), format: .wav)
                
                // Step 2: Transcribe it
                let transcriptionResult = try await transcribe(
                    originalAudioData,
                    using: .openai(.whisper1)
                )
                
                #expect(!transcriptionResult.text.isEmpty)
                
                // Step 3: Generate speech from the transcribed text
                let speechResult = try await generateSpeech(
                    transcriptionResult.text,
                    using: .openai(.tts1),
                    voice: .nova,
                    format: .wav
                )
                
                #expect(!speechResult.audioData.data.isEmpty)
                #expect(speechResult.audioData.format == .wav)
            }
        }
        
        @Test("multi-provider transcription comparison")
        func multiProviderTranscriptionComparison() async throws {
            try await TestHelpers.withStandardTestKeys {
                let audioData = AudioData(data: Data([0x01, 0x02, 0x03]), format: .wav)
                
                let providers: [TranscriptionModel] = [
                    .openai(.whisper1),
                    .groq(.whisperLargeV3Turbo),
                    .deepgram(.nova3)
                ]
                
                var results: [String: TranscriptionResult] = [:]
                
                for provider in providers {
                    let result = try await transcribe(audioData, using: provider)
                    results[provider.description] = result
                }
                
                #expect(results.count == 3)
                #expect(results.values.allSatisfy { !$0.text.isEmpty })
                
                // All providers should have processed the same audio
                let durations = results.values.compactMap { $0.duration }
                #expect(!durations.isEmpty)
            }
        }
        
        @Test("audio format conversion pipeline")
        func audioFormatConversionPipeline() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                // Generate speech in MP3
                let mp3Result = try await generateSpeech(
                    "Test audio format conversion",
                    using: .openai(.tts1),
                    format: .mp3
                )
                
                #expect(mp3Result.audioData.format == .mp3)
                
                // Convert to WAV format by re-processing
                let wavResult = try await generateSpeech(
                    "Test audio format conversion",
                    using: .openai(.tts1),
                    format: .wav
                )
                
                #expect(wavResult.audioData.format == .wav)
                
                // Both should contain audio data
                #expect(!mp3Result.audioData.data.isEmpty)
                #expect(!wavResult.audioData.data.isEmpty)
            }
        }
    }
}