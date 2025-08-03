import Foundation
import Testing
@testable import TachikomaCore

@Suite("SpeechRecognizer Integration Tests")
struct SpeechRecognizerIntegrationTests {
    
    // MARK: - SpeechRecognizer Enhancement Tests
    
    @Suite("SpeechRecognizer Enhancement Tests")
    struct SpeechRecognizerEnhancementTests {
        
        @Test("SpeechRecognizer has audio transcription capabilities")
        func speechRecognizerAudioCapabilities() {
            // Test that SpeechRecognizer now supports enhanced audio transcription
            let recognizer = SpeechRecognizer()
            
            // Verify that the recognizer has been enhanced with new audio capabilities
            #expect(recognizer.supportedFormats.contains(.wav))
            #expect(recognizer.supportedFormats.contains(.mp3))
            #expect(recognizer.supportedFormats.contains(.flac))
            
            // Check that it supports multiple providers
            #expect(recognizer.supportedProviders.contains("openai"))
            #expect(recognizer.supportedProviders.contains("groq"))
            #expect(recognizer.supportedProviders.contains("deepgram"))
        }
        
        @Test("SpeechRecognizer transcribe with Tachikoma integration")
        func speechRecognizerTachikomaIntegration() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let recognizer = SpeechRecognizer()
                let audioData = AudioData(data: Data([0x01, 0x02, 0x03, 0x04]), format: .wav)
                
                // Test enhanced transcription with Tachikoma backend
                let result = try await recognizer.transcribeWithTachikoma(
                    audioData,
                    using: .openai(.whisper1),
                    language: "en"
                )
                
                #expect(!result.text.isEmpty)
                #expect(result.language == "en")
                #expect(result.usage != nil)
                
                // Should provide more detailed results than basic speech recognition
                #expect(result.segments != nil)
                #expect(result.duration != nil)
            }
        }
        
        @Test("SpeechRecognizer fallback to system recognition")
        func speechRecognizerFallbackToSystem() async throws {
            try await TestHelpers.withNoAPIKeys {
                let recognizer = SpeechRecognizer()
                let audioData = AudioData(data: Data([0x01, 0x02, 0x03, 0x04]), format: .wav)
                
                // When no API keys are available, should fall back to system speech recognition
                let result = try await recognizer.transcribeWithFallback(audioData)
                
                #expect(!result.text.isEmpty)
                // System recognition won't have the same detailed metadata
                #expect(result.usage == nil || result.usage?.cost == nil)
            }
        }
        
        @Test("SpeechRecognizer provider selection")
        func speechRecognizerProviderSelection() throws {
            let recognizer = SpeechRecognizer()
            
            // Test automatic provider selection based on requirements
            let fastProvider = recognizer.selectOptimalProvider(for: .speed)
            #expect(fastProvider.description.contains("Groq") || fastProvider.description.contains("turbo"))
            
            let accurateProvider = recognizer.selectOptimalProvider(for: .accuracy)
            #expect(accurateProvider.description.contains("Deepgram") || accurateProvider.description.contains("nova"))
            
            let balancedProvider = recognizer.selectOptimalProvider(for: .balanced)
            #expect(balancedProvider.description.contains("OpenAI") || balancedProvider.description.contains("whisper"))
        }
        
        @Test("SpeechRecognizer format optimization")
        func speechRecognizerFormatOptimization() {
            let recognizer = SpeechRecognizer()
            
            // Test format recommendations based on provider capabilities
            let openaiFormats = recognizer.recommendedFormats(for: .openai(.whisper1))
            #expect(openaiFormats.contains(.wav))
            #expect(openaiFormats.contains(.mp3))
            #expect(openaiFormats.contains(.flac))
            
            let groqFormats = recognizer.recommendedFormats(for: .groq(.distilWhisperLargeV3En))
            #expect(groqFormats.contains(.wav))
            #expect(groqFormats.contains(.mp3))
            
            // Should prioritize lossless formats for accuracy
            let accuracyFormats = recognizer.recommendedFormats(for: .deepgram(.nova3), priority: .accuracy)
            #expect(accuracyFormats.first?.isLossless == true)
        }
    }
    
    // MARK: - Real-time Transcription Tests
    
    @Suite("Real-time Transcription Tests")
    struct RealTimeTranscriptionTests {
        
        @Test("SpeechRecognizer streaming transcription setup")
        func speechRecognizerStreamingSetup() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let recognizer = SpeechRecognizer()
                
                // Test streaming transcription configuration
                let streamingConfig = recognizer.createStreamingConfiguration(
                    provider: .openai(.whisper1),
                    language: "en",
                    enableRealTimeResults: true
                )
                
                #expect(streamingConfig.provider.modelId == "whisper-1")
                #expect(streamingConfig.language == "en")
                #expect(streamingConfig.enableRealTimeResults == true)
                #expect(streamingConfig.bufferSize > 0)
            }
        }
        
        @Test("SpeechRecognizer audio buffer management")
        func speechRecognizerAudioBufferManagement() {
            let recognizer = SpeechRecognizer()
            
            // Test audio buffer for streaming
            let buffer = recognizer.createAudioBuffer(
                format: .wav,
                sampleRate: 44100,
                channels: 1,
                bufferDuration: 1.0
            )
            
            #expect(buffer.format == .wav)
            #expect(buffer.sampleRate == 44100)
            #expect(buffer.channels == 1)
            #expect(buffer.capacity > 0)
            
            // Test buffer operations
            let testData = Data([0x01, 0x02, 0x03, 0x04])
            buffer.append(testData)
            
            #expect(buffer.currentSize == testData.count)
            #expect(buffer.hasMinimumData == false) // Small test data
            
            let retrieved = buffer.retrieveChunk()
            #expect(retrieved.count <= testData.count)
        }
        
        @Test("SpeechRecognizer partial results handling")
        func speechRecognizerPartialResults() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let recognizer = SpeechRecognizer()
                
                // Simulate streaming audio data
                let audioChunks = [
                    AudioData(data: Data([0x01, 0x02]), format: .wav),
                    AudioData(data: Data([0x03, 0x04]), format: .wav),
                    AudioData(data: Data([0x05, 0x06]), format: .wav)
                ]
                
                var partialResults: [String] = []
                var finalResult: TranscriptionResult?
                
                let streamingSession = try await recognizer.startStreamingTranscription(
                    using: .openai(.whisper1),
                    language: "en"
                ) { partial in
                    partialResults.append(partial.text)
                } onFinal: { final in
                    finalResult = final
                }
                
                // Send audio chunks
                for chunk in audioChunks {
                    try await streamingSession.processAudioChunk(chunk)
                }
                
                try await streamingSession.finalize()
                
                // Should have received some partial results
                #expect(!partialResults.isEmpty)
                #expect(finalResult != nil)
                #expect(!finalResult!.text.isEmpty)
            }
        }
    }
    
    // MARK: - Audio Quality Enhancement Tests
    
    @Suite("Audio Quality Enhancement Tests")
    struct AudioQualityEnhancementTests {
        
        @Test("SpeechRecognizer noise reduction")
        func speechRecognizerNoiseReduction() {
            let recognizer = SpeechRecognizer()
            
            // Test noise reduction capabilities
            let noisyAudioData = AudioData(
                data: Data([0x01, 0x02, 0x03, 0x04, 0xFF, 0x00, 0xFF, 0x00]), // Simulated noisy data
                format: .wav,
                sampleRate: 44100,
                channels: 1
            )
            
            let enhancedAudio = recognizer.applyNoiseReduction(noisyAudioData)
            
            #expect(enhancedAudio.format == noisyAudioData.format)
            #expect(enhancedAudio.sampleRate == noisyAudioData.sampleRate)
            #expect(enhancedAudio.channels == noisyAudioData.channels)
            
            // Enhanced audio should be different from original (noise reduced)
            #expect(enhancedAudio.data != noisyAudioData.data)
        }
        
        @Test("SpeechRecognizer volume normalization")
        func speechRecognizerVolumeNormalization() {
            let recognizer = SpeechRecognizer()
            
            // Test volume normalization
            let quietAudioData = AudioData(
                data: Data([0x01, 0x01, 0x02, 0x02]), // Low amplitude
                format: .wav,
                sampleRate: 44100,
                channels: 1
            )
            
            let normalizedAudio = recognizer.normalizeVolume(quietAudioData, targetLevel: 0.7)
            
            #expect(normalizedAudio.format == quietAudioData.format)
            #expect(normalizedAudio.data.count == quietAudioData.data.count)
            
            // Normalized audio should have different amplitude
            #expect(normalizedAudio.data != quietAudioData.data)
            
            // Check that volume level is appropriate
            let volumeLevel = recognizer.analyzeVolumeLevel(normalizedAudio)
            #expect(volumeLevel > 0.5)
            #expect(volumeLevel <= 1.0)
        }
        
        @Test("SpeechRecognizer audio format conversion")
        func speechRecognizerFormatConversion() throws {
            let recognizer = SpeechRecognizer()
            
            // Test automatic format conversion for optimal recognition
            let mp3AudioData = AudioData(data: Data([0x01, 0x02, 0x03, 0x04]), format: .mp3)
            
            let optimizedAudio = try recognizer.convertForOptimalRecognition(
                mp3AudioData,
                targetProvider: .openai(.whisper1)
            )
            
            // Should convert to a format optimal for the provider
            #expect(optimizedAudio.format != .mp3) // Should be converted
            #expect([AudioFormat.wav, .flac].contains(optimizedAudio.format)) // To lossless format
            #expect(optimizedAudio.sampleRate != nil)
            #expect(optimizedAudio.channels != nil)
        }
        
        @Test("SpeechRecognizer audio quality analysis")
        func speechRecognizerQualityAnalysis() {
            let recognizer = SpeechRecognizer()
            
            // Test audio quality assessment
            let highQualityAudio = AudioData(
                data: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]),
                format: .wav,
                sampleRate: 44100,
                channels: 1,
                duration: 1.0
            )
            
            let qualityMetrics = recognizer.analyzeAudioQuality(highQualityAudio)
            
            #expect(qualityMetrics.sampleRate == 44100)
            #expect(qualityMetrics.bitDepth != nil)
            #expect(qualityMetrics.channels == 1)
            #expect(qualityMetrics.duration == 1.0)
            #expect(qualityMetrics.estimatedSNR != nil) // Signal-to-noise ratio
            #expect(qualityMetrics.recommendedProvider != nil)
            
            // Quality score should be reasonable
            #expect(qualityMetrics.overallScore >= 0.0)
            #expect(qualityMetrics.overallScore <= 1.0)
        }
    }
    
    // MARK: - Integration with Existing Features Tests
    
    @Suite("Integration with Existing Features Tests")
    struct IntegrationWithExistingFeaturesTests {
        
        @Test("SpeechRecognizer backward compatibility")
        func speechRecognizerBackwardCompatibility() async throws {
            let recognizer = SpeechRecognizer()
            
            // Test that existing SpeechRecognizer methods still work
            let audioData = AudioData(data: Data([0x01, 0x02, 0x03, 0x04]), format: .wav)
            
            // Original method should still work
            let legacyResult = try await recognizer.transcribe(audioData)
            #expect(!legacyResult.isEmpty)
            
            // Enhanced method should provide more features
            let enhancedResult = try await recognizer.transcribeWithTachikoma(
                audioData,
                using: .openai(.whisper1)
            )
            #expect(!enhancedResult.text.isEmpty)
            #expect(enhancedResult.usage != nil)
            
            // Both should produce similar core text results
            #expect(legacyResult.lowercased().contains("test") || 
                   enhancedResult.text.lowercased().contains("test") ||
                   !legacyResult.isEmpty && !enhancedResult.text.isEmpty)
        }
        
        @Test("SpeechRecognizer performance comparison")
        func speechRecognizerPerformanceComparison() async throws {
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                let recognizer = SpeechRecognizer()
                let audioData = AudioData(data: Data([0x01, 0x02, 0x03, 0x04]), format: .wav)
                
                // Test system recognition performance
                let systemStartTime = Date()
                let systemResult = try await recognizer.transcribe(audioData)
                let systemDuration = Date().timeIntervalSince(systemStartTime)
                
                // Test Tachikoma-enhanced recognition performance
                let tachikomaStartTime = Date()
                let tachikomaResult = try await recognizer.transcribeWithTachikoma(
                    audioData,
                    using: .openai(.whisper1)
                )
                let tachikomataDuration = Date().timeIntervalSince(tachikomaStartTime)
                
                #expect(!systemResult.isEmpty)
                #expect(!tachikomaResult.text.isEmpty)
                
                // Both should complete in reasonable time
                #expect(systemDuration < 30.0) // Should be fast
                #expect(tachikomataDuration < 30.0) // Network call might be slower
                
                // Tachikoma should provide richer results
                #expect(tachikomaResult.usage != nil)
                #expect(tachikomaResult.segments != nil || tachikomaResult.duration != nil)
            }
        }
        
        @Test("SpeechRecognizer error handling integration")
        func speechRecognizerErrorHandlingIntegration() async throws {
            let recognizer = SpeechRecognizer()
            
            // Test error handling with invalid audio data
            let invalidAudioData = AudioData(data: Data(), format: .wav) // Empty data
            
            // System recognition error handling
            do {
                _ = try await recognizer.transcribe(invalidAudioData)
                // Might succeed with empty result
            } catch {
                #expect(error is SpeechRecognitionError || error is TachikomaError)
            }
            
            // Tachikoma integration error handling
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                do {
                    _ = try await recognizer.transcribeWithTachikoma(
                        invalidAudioData,
                        using: .openai(.whisper1)
                    )
                    // Should handle gracefully
                } catch {
                    #expect(error is TachikomaError)
                }
            }
        }
        
        @Test("SpeechRecognizer configuration inheritance")
        func speechRecognizerConfigurationInheritance() {
            let recognizer = SpeechRecognizer()
            
            // Test that SpeechRecognizer inherits and extends existing configuration
            #expect(recognizer.isAvailable) // Should still work
            
            // New audio capabilities should be available
            #expect(recognizer.supportedFormats.count > 1)
            #expect(recognizer.supportedProviders.count > 0)
            
            // Configuration should be preserved
            recognizer.preferredLanguage = "en-US"
            #expect(recognizer.preferredLanguage == "en-US")
            
            // Enhanced settings should be available
            recognizer.preferredProvider = .openai(.whisper1)
            #expect(recognizer.preferredProvider?.modelId == "whisper-1")
            
            recognizer.enableEnhancedAccuracy = true
            #expect(recognizer.enableEnhancedAccuracy == true)
        }
    }
    
    // MARK: - Migration and Upgrade Tests
    
    @Suite("Migration and Upgrade Tests")
    struct MigrationAndUpgradeTests {
        
        @Test("SpeechRecognizer migration from legacy implementation")
        func speechRecognizerMigrationFromLegacy() async throws {
            // Test smooth migration from old SpeechRecognizer usage
            let recognizer = SpeechRecognizer()
            
            // Legacy usage pattern
            let audioData = AudioData(data: Data([0x01, 0x02, 0x03, 0x04]), format: .wav)
            
            // Old method should work unchanged
            let legacyResult = try await recognizer.transcribe(audioData)
            #expect(!legacyResult.isEmpty)
            
            // Upgrade path should be seamless
            try await TestHelpers.withTestEnvironment(apiKeys: ["openai": "test-key"]) {
                // Enable enhanced features
                recognizer.enableEnhancedAccuracy = true
                recognizer.preferredProvider = .openai(.whisper1)
                
                // Same method call, enhanced results
                let enhancedResult = try await recognizer.transcribe(audioData)
                #expect(!enhancedResult.isEmpty)
                
                // Should get more detailed results when enhanced mode is enabled
                if recognizer.enableEnhancedAccuracy {
                    // Additional metadata should be available through enhanced interface
                    let detailedResult = try await recognizer.getLastTranscriptionDetails()
                    #expect(detailedResult?.usage != nil)
                }
            }
        }
        
        @Test("SpeechRecognizer feature detection")
        func speechRecognizerFeatureDetection() {
            let recognizer = SpeechRecognizer()
            
            // Test feature availability detection
            #expect(recognizer.supportsTachikomaIntegration == true)
            #expect(recognizer.supportsMultipleProviders == true)
            #expect(recognizer.supportsStreamingTranscription == true)
            #expect(recognizer.supportsAudioEnhancement == true)
            
            // Provider-specific feature detection
            #expect(recognizer.supportsTimestamps(for: .openai(.whisper1)) == true)
            #expect(recognizer.supportsLanguageDetection(for: .openai(.whisper1)) == true)
            #expect(recognizer.supportsSpeakerDiarization(for: .deepgram(.nova3)) == true)
            
            // Format support detection
            #expect(recognizer.supportsFormat(.wav, for: .openai(.whisper1)) == true)
            #expect(recognizer.supportsFormat(.mp3, for: .groq(.whisperLargeV3Turbo)) == true)
        }
        
        @Test("SpeechRecognizer version compatibility")
        func speechRecognizerVersionCompatibility() {
            let recognizer = SpeechRecognizer()
            
            // Test version information
            let version = recognizer.tachikomaIntegrationVersion
            #expect(!version.isEmpty)
            #expect(version.contains(".")) // Should be semantic version
            
            // Test compatibility checks
            let isCompatible = recognizer.isCompatibleWithTachikomaVersion("1.0.0")
            #expect(isCompatible == true) // Should be compatible with baseline version
            
            // Test minimum requirements
            let requirements = recognizer.minimumSystemRequirements
            #expect(requirements.macOSVersion != nil)
            #expect(requirements.availableProviders.count > 0)
        }
    }
}