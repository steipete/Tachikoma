import Foundation
import Testing
@testable import TachikomaCore

@Suite("Model Capabilities Audio Tests")
struct ModelCapabilitiesAudioTests {
    
    // MARK: - Model Audio Support Detection Tests
    
    @Suite("Model Audio Support Detection Tests")
    struct ModelAudioSupportDetectionTests {
        
        @Test("Model supports audio input detection")
        func modelSupportsAudioInput() {
            // Test detection of models that support audio input (transcription)
            #expect(Model.openai(.gpt4o).supportsAudioInput == false) // Vision model, not audio
            #expect(Model.openai(.whisper1).supportsAudioInput == true) // Audio transcription model
            #expect(Model.anthropic(.opus4).supportsAudioInput == false) // Text model
            #expect(Model.groq(.whisperLargeV3Turbo).supportsAudioInput == true) // Audio model
            
            // Test Deepgram models
            #expect(Model.deepgram(.nova3).supportsAudioInput == true)
            #expect(Model.deepgram(.whisperLargeV3).supportsAudioInput == true)
            
            // Test AssemblyAI models
            #expect(Model.assemblyai(.best).supportsAudioInput == true)
            #expect(Model.assemblyai(.nano).supportsAudioInput == true)
        }
        
        @Test("Model supports audio output detection")
        func modelSupportsAudioOutput() {
            // Test detection of models that support audio output (speech synthesis)
            #expect(Model.openai(.gpt4o).supportsAudioOutput == false) // Vision model, not TTS
            #expect(Model.openai(.tts1).supportsAudioOutput == true) // TTS model
            #expect(Model.openai(.tts1HD).supportsAudioOutput == true) // HD TTS model
            #expect(Model.openai(.gpt4oMiniTTS).supportsAudioOutput == true) // GPT-4o Mini TTS
            
            // Test other TTS providers
            #expect(Model.lmnt(.aurora).supportsAudioOutput == true)
            #expect(Model.elevenlabs(.multilingualV1).supportsAudioOutput == true)
            #expect(Model.hume(.default).supportsAudioOutput == true)
            
            // Test non-TTS models
            #expect(Model.anthropic(.opus4).supportsAudioOutput == false)
            #expect(Model.groq(.mixtral8x7b).supportsAudioOutput == false)
        }
        
        @Test("Model audio capabilities detection")
        func modelAudioCapabilities() {
            // Test comprehensive audio capability detection
            let whisperModel = Model.openai(.whisper1)
            let audioCapabilities = whisperModel.audioCapabilities
            
            #expect(audioCapabilities != nil)
            #expect(audioCapabilities?.supportsTranscription == true)
            #expect(audioCapabilities?.supportsSpeechSynthesis == false)
            #expect(audioCapabilities?.supportsTimestamps == true)
            #expect(audioCapabilities?.supportsLanguageDetection == true)
            
            let ttsModel = Model.openai(.tts1)
            let ttsCapabilities = ttsModel.audioCapabilities
            
            #expect(ttsCapabilities != nil)
            #expect(ttsCapabilities?.supportsTranscription == false)
            #expect(ttsCapabilities?.supportsSpeechSynthesis == true)
            #expect(ttsCapabilities?.supportsVoiceSelection == true)
            #expect(ttsCapabilities?.supportsSpeedControl == true)
            
            // Non-audio model should have no audio capabilities
            let textModel = Model.anthropic(.opus4)
            #expect(textModel.audioCapabilities == nil)
        }
        
        @Test("Model multimodal audio support")
        func modelMultimodalAudioSupport() {
            // Test models that support both text and audio
            let gpt4oMiniTTS = Model.openai(.gpt4oMiniTTS)
            
            #expect(gpt4oMiniTTS.supportsText == true)
            #expect(gpt4oMiniTTS.supportsAudioOutput == true)
            #expect(gpt4oMiniTTS.supportsVision == false) // TTS variant doesn't do vision
            
            // Test that multimodal capabilities are properly detected
            let capabilities = gpt4oMiniTTS.capabilities
            #expect(capabilities.inputTypes.contains(.text) == true)
            #expect(capabilities.outputTypes.contains(.audio) == true)
            #expect(capabilities.isMultimodal == true)
        }
    }
    
    // MARK: - Audio Model Routing Tests
    
    @Suite("Audio Model Routing Tests")
    struct AudioModelRoutingTests {
        
        @Test("Automatic transcription model selection")
        func automaticTranscriptionModelSelection() {
            // Test automatic selection of appropriate transcription models
            let fastTranscription = Model.selectOptimalFor(task: .transcription, priority: .speed)
            #expect(fastTranscription.supportsAudioInput == true)
            #expect(fastTranscription.description.contains("turbo") || 
                   fastTranscription.description.contains("Groq"))
            
            let accurateTranscription = Model.selectOptimalFor(task: .transcription, priority: .accuracy)
            #expect(accurateTranscription.supportsAudioInput == true)
            #expect(accurateTranscription.description.contains("nova") || 
                   accurateTranscription.description.contains("best"))
            
            let balancedTranscription = Model.selectOptimalFor(task: .transcription, priority: .balanced)
            #expect(balancedTranscription.supportsAudioInput == true)
            #expect(balancedTranscription.description.contains("whisper"))
        }
        
        @Test("Automatic speech synthesis model selection")
        func automaticSpeechSynthesisModelSelection() {
            // Test automatic selection of appropriate TTS models
            let fastTTS = Model.selectOptimalFor(task: .speechSynthesis, priority: .speed)
            #expect(fastTTS.supportsAudioOutput == true)
            #expect(fastTTS.description.contains("tts-1") || 
                   fastTTS.description.contains("LMNT"))
            
            let qualityTTS = Model.selectOptimalFor(task: .speechSynthesis, priority: .quality)
            #expect(qualityTTS.supportsAudioOutput == true)
            #expect(qualityTTS.description.contains("HD") || 
                   qualityTTS.description.contains("multilingual"))
            
            let expressiveTTS = Model.selectOptimalFor(task: .speechSynthesis, priority: .expressiveness)
            #expect(expressiveTTS.supportsAudioOutput == true)
            #expect(expressiveTTS.description.contains("gpt-4o") || 
                   expressiveTTS.description.contains("ElevenLabs"))
        }
        
        @Test("Model compatibility checking")
        func modelCompatibilityChecking() {
            // Test compatibility between models and tasks
            let whisperModel = Model.openai(.whisper1)
            #expect(whisperModel.isCompatibleWith(task: .transcription) == true)
            #expect(whisperModel.isCompatibleWith(task: .speechSynthesis) == false)
            #expect(whisperModel.isCompatibleWith(task: .textGeneration) == false)
            
            let ttsModel = Model.openai(.tts1)
            #expect(ttsModel.isCompatibleWith(task: .transcription) == false)
            #expect(ttsModel.isCompatibleWith(task: .speechSynthesis) == true)
            #expect(ttsModel.isCompatibleWith(task: .textGeneration) == false)
            
            let textModel = Model.anthropic(.opus4)
            #expect(textModel.isCompatibleWith(task: .transcription) == false)
            #expect(textModel.isCompatibleWith(task: .speechSynthesis) == false)
            #expect(textModel.isCompatibleWith(task: .textGeneration) == true)
        }
        
        @Test("Model fallback strategies")
        func modelFallbackStrategies() {
            // Test fallback model selection when preferred models are unavailable
            let fallbackChain = Model.createFallbackChain(
                primaryTask: .transcription,
                preferredProviders: ["openai", "groq", "deepgram"],
                requirements: [.supportsTimestamps, .supportsLanguageDetection]
            )
            
            #expect(fallbackChain.count >= 2) // Should have multiple fallback options
            #expect(fallbackChain.allSatisfy { $0.supportsAudioInput })
            
            // Test that fallback maintains capability requirements
            for model in fallbackChain {
                let capabilities = model.audioCapabilities
                #expect(capabilities?.supportsTimestamps == true)
                #expect(capabilities?.supportsLanguageDetection == true)
            }
        }
    }
    
    // MARK: - Audio Format Compatibility Tests
    
    @Suite("Audio Format Compatibility Tests")
    struct AudioFormatCompatibilityTests {
        
        @Test("Model audio format support")
        func modelAudioFormatSupport() {
            // Test which audio formats each model supports
            let whisperModel = Model.openai(.whisper1)
            let supportedFormats = whisperModel.supportedAudioFormats
            
            #expect(supportedFormats.contains(.wav) == true)
            #expect(supportedFormats.contains(.mp3) == true)
            #expect(supportedFormats.contains(.flac) == true)
            #expect(supportedFormats.contains(.m4a) == true)
            
            // Test TTS model format support
            let ttsModel = Model.openai(.tts1)
            let ttsFormats = ttsModel.supportedAudioFormats
            
            #expect(ttsFormats.contains(.mp3) == true)
            #expect(ttsFormats.contains(.wav) == true)
            #expect(ttsFormats.contains(.opus) == true)
            #expect(ttsFormats.contains(.aac) == true)
            
            // Test Groq model format support
            let groqModel = Model.groq(.whisperLargeV3Turbo)
            let groqFormats = groqModel.supportedAudioFormats
            
            #expect(groqFormats.contains(.wav) == true)
            #expect(groqFormats.contains(.mp3) == true)
        }
        
        @Test("Optimal format recommendation")
        func optimalFormatRecommendation() {
            // Test format recommendations based on model capabilities
            let whisperModel = Model.openai(.whisper1)
            let optimalFormat = whisperModel.recommendedAudioFormat(for: .accuracy)
            #expect(optimalFormat.isLossless == true) // Should recommend lossless for accuracy
            
            let speedFormat = whisperModel.recommendedAudioFormat(for: .speed)
            #expect([AudioFormat.wav, .mp3].contains(speedFormat)) // Common, fast formats
            
            let ttsModel = Model.openai(.tts1)
            let ttsFormat = ttsModel.recommendedAudioFormat(for: .quality)
            #expect([AudioFormat.wav, .flac].contains(ttsFormat)) // High quality output
        }
        
        @Test("Format conversion requirements")
        func formatConversionRequirements() {
            // Test when format conversion is needed
            let whisperModel = Model.openai(.whisper1)
            
            #expect(whisperModel.requiresConversion(from: .wav) == false) // Native support
            #expect(whisperModel.requiresConversion(from: .mp3) == false) // Native support
            #expect(whisperModel.requiresConversion(from: .flac) == false) // Native support
            
            // Test conversion recommendations
            let conversion = whisperModel.conversionRecommendation(from: .ogg)
            if whisperModel.supportedAudioFormats.contains(.ogg) {
                #expect(conversion == nil) // No conversion needed
            } else {
                #expect(conversion != nil)
                #expect(conversion?.isLossless == true) // Should preserve quality
            }
        }
        
        @Test("Audio quality requirements")
        func audioQualityRequirements() {
            // Test quality requirements for different models
            let whisperModel = Model.openai(.whisper1)
            let qualityReqs = whisperModel.audioQualityRequirements
            
            #expect(qualityReqs.minimumSampleRate != nil)
            #expect(qualityReqs.minimumSampleRate! >= 16000) // CD quality or better
            #expect(qualityReqs.preferredChannels == 1) // Mono for speech
            #expect(qualityReqs.maximumFileSize != nil)
            
            // Test TTS quality requirements
            let ttsModel = Model.openai(.tts1)
            let ttsQualityReqs = ttsModel.audioQualityRequirements
            
            #expect(ttsQualityReqs.outputSampleRate != nil)
            #expect(ttsQualityReqs.outputSampleRate! >= 22050) // Good quality output
        }
    }
    
    // MARK: - Model Performance Characteristics Tests
    
    @Suite("Model Performance Characteristics Tests")
    struct ModelPerformanceCharacteristicsTests {
        
        @Test("Transcription model performance profiles")
        func transcriptionModelPerformanceProfiles() {
            // Test performance characteristics of transcription models
            let whisperModel = Model.openai(.whisper1)
            let whisperProfile = whisperModel.performanceProfile
            
            #expect(whisperProfile.averageProcessingSpeed != nil)
            #expect(whisperProfile.accuracyRating >= 0.0)
            #expect(whisperProfile.accuracyRating <= 1.0)
            #expect(whisperProfile.costPerMinute != nil)
            
            let groqTurboModel = Model.groq(.whisperLargeV3Turbo)
            let groqProfile = groqTurboModel.performanceProfile
            
            #expect(groqProfile.averageProcessingSpeed != nil)
            // Turbo models should be faster
            if let whisperSpeed = whisperProfile.averageProcessingSpeed,
               let groqSpeed = groqProfile.averageProcessingSpeed {
                #expect(groqSpeed > whisperSpeed)
            }
            
            let deepgramModel = Model.deepgram(.nova3)
            let deepgramProfile = deepgramModel.performanceProfile
            
            #expect(deepgramProfile.accuracyRating >= 0.0)
            #expect(deepgramProfile.accuracyRating <= 1.0)
            #expect(deepgramProfile.supportsConcurrentRequests == true)
        }
        
        @Test("Speech synthesis model performance profiles")
        func speechSynthesisModelPerformanceProfiles() {
            // Test performance characteristics of TTS models
            let ttsModel = Model.openai(.tts1)
            let ttsProfile = ttsModel.performanceProfile
            
            #expect(ttsProfile.averageGenerationSpeed != nil) // Characters per second
            #expect(ttsProfile.voiceQualityRating >= 0.0)
            #expect(ttsProfile.voiceQualityRating <= 1.0)
            #expect(ttsProfile.latency != nil)
            
            let hdModel = Model.openai(.tts1HD)
            let hdProfile = hdModel.performanceProfile
            
            // HD model should have better quality but possibly higher latency
            #expect(hdProfile.voiceQualityRating >= ttsProfile.voiceQualityRating)
            
            let elevenlabsModel = Model.elevenlabs(.multilingualV1)
            let elevenlabsProfile = elevenlabsModel.performanceProfile
            
            #expect(elevenlabsProfile.supportsCustomVoices == true)
            #expect(elevenlabsProfile.emotionalExpressionSupport == true)
        }
        
        @Test("Model resource requirements")
        func modelResourceRequirements() {
            // Test resource requirements for different models
            let whisperModel = Model.openai(.whisper1)
            let whisperResources = whisperModel.resourceRequirements
            
            #expect(whisperResources.memoryUsage != nil)
            #expect(whisperResources.processingPower != nil)
            #expect(whisperResources.networkBandwidth != nil)
            #expect(whisperResources.isCloudBased == true)
            
            // Local models would have different resource profiles
            if let localModel = Model.createLocalModel(type: .whisper, variant: .small) {
                let localResources = localModel.resourceRequirements
                #expect(localResources.isCloudBased == false)
                #expect(localResources.localStorageRequired != nil)
            }
        }
        
        @Test("Model scalability characteristics")
        func modelScalabilityCharacteristics() {
            // Test how models handle different scales of operation
            let whisperModel = Model.openai(.whisper1)
            let scalability = whisperModel.scalabilityProfile
            
            #expect(scalability.maxConcurrentRequests != nil)
            #expect(scalability.rateLimits.requestsPerMinute != nil)
            #expect(scalability.rateLimits.tokensPerMinute != nil)
            #expect(scalability.supportsBatchProcessing == true)
            
            let groqModel = Model.groq(.whisperLargeV3Turbo)
            let groqScalability = groqModel.scalabilityProfile
            
            // Groq typically has higher throughput
            if let whisperConcurrent = scalability.maxConcurrentRequests,
               let groqConcurrent = groqScalability.maxConcurrentRequests {
                #expect(groqConcurrent >= whisperConcurrent)
            }
        }
    }
    
    // MARK: - Model Feature Matrix Tests
    
    @Suite("Model Feature Matrix Tests")
    struct ModelFeatureMatrixTests {
        
        @Test("Comprehensive feature matrix")
        func comprehensiveFeatureMatrix() {
            // Test comprehensive feature support across all audio models
            let audioModels = [
                Model.openai(.whisper1),
                Model.groq(.whisperLargeV3Turbo),
                Model.deepgram(.nova3),
                Model.assemblyai(.best),
                Model.openai(.tts1),
                Model.elevenlabs(.multilingualV1)
            ]
            
            for model in audioModels {
                let features = model.featureMatrix
                
                // All audio models should have basic audio support
                #expect(features.supportsAudio == true)
                
                // Check specific features based on model type
                if model.supportsAudioInput {
                    #expect(features.transcription != nil)
                    #expect(features.transcription?.supportsLanguages != nil)
                }
                
                if model.supportsAudioOutput {
                    #expect(features.speechSynthesis != nil)
                    #expect(features.speechSynthesis?.supportedVoices != nil)
                }
            }
        }
        
        @Test("Feature compatibility matrix")
        func featureCompatibilityMatrix() {
            // Test compatibility between different features
            let whisperModel = Model.openai(.whisper1)
            let compatibility = whisperModel.featureCompatibilityMatrix
            
            #expect(compatibility.timestampsWithLanguageDetection == true)
            #expect(compatibility.wordTimestampsWithSegmentTimestamps == true)
            #expect(compatibility.multipleLanguagesSimultaneous == false) // Usually not supported
            
            let ttsModel = Model.openai(.tts1)
            let ttsCompatibility = ttsModel.featureCompatibilityMatrix
            
            #expect(ttsCompatibility.voiceWithSpeedControl == true)
            #expect(ttsCompatibility.multipleFormatsSimultaneous == false)
        }
        
        @Test("Feature availability by region")
        func featureAvailabilityByRegion() {
            // Test regional availability of features
            let whisperModel = Model.openai(.whisper1)
            let regionalAvailability = whisperModel.regionalAvailability
            
            #expect(regionalAvailability.supportedRegions.contains("us") == true)
            #expect(regionalAvailability.supportedRegions.contains("eu") == true)
            
            // Check feature availability in different regions
            let usFeatures = regionalAvailability.featuresInRegion("us")
            let euFeatures = regionalAvailability.featuresInRegion("eu")
            
            #expect(usFeatures.contains("transcription") == true)
            #expect(euFeatures.contains("transcription") == true)
            
            // Some features might be region-specific
            let elevenlabsModel = Model.elevenlabs(.multilingualV1)
            let elevenlabsRegions = elevenlabsModel.regionalAvailability
            
            #expect(!elevenlabsRegions.supportedRegions.isEmpty)
        }
        
        @Test("Model deprecation and lifecycle")
        func modelDeprecationAndLifecycle() {
            // Test model lifecycle information
            let whisperModel = Model.openai(.whisper1)
            let lifecycle = whisperModel.lifecycleInfo
            
            #expect(lifecycle.isDeprecated == false)
            #expect(lifecycle.releaseDate != nil)
            #expect(lifecycle.deprecationDate == nil) // Should be nil for active models
            
            // Test that we can detect deprecated models
            if let deprecatedModel = Model.findDeprecatedModel(provider: "openai", modelType: "transcription") {
                let deprecatedLifecycle = deprecatedModel.lifecycleInfo
                #expect(deprecatedLifecycle.isDeprecated == true)
                #expect(deprecatedLifecycle.deprecationDate != nil)
                #expect(deprecatedLifecycle.replacementModel != nil)
            }
        }
    }
    
    // MARK: - Integration with Generation Models Tests
    
    @Suite("Integration with Generation Models Tests")
    struct IntegrationWithGenerationModelsTests {
        
        @Test("Text generation model audio awareness")
        func textGenerationModelAudioAwareness() {
            // Test that text generation models are aware of audio capabilities
            let gpt4oModel = Model.openai(.gpt4o)
            
            #expect(gpt4oModel.canProcessAudioInput == false) // Vision model, not audio
            #expect(gpt4oModel.canGenerateAudioOutput == false)
            #expect(gpt4oModel.canReasonAboutAudio == true) // Can discuss audio concepts
            
            // Test audio-aware text models
            let gpt4oMiniTTS = Model.openai(.gpt4oMiniTTS)
            
            #expect(gpt4oMiniTTS.canProcessAudioInput == false) // TTS only, not STT
            #expect(gpt4oMiniTTS.canGenerateAudioOutput == true)
            #expect(gpt4oMiniTTS.canReasonAboutAudio == true)
            #expect(gpt4oMiniTTS.audioOutputQuality == .high)
        }
        
        @Test("Multimodal model audio integration")
        func multimodalModelAudioIntegration() {
            // Test integration between text, vision, and audio modalities
            let gpt4oModel = Model.openai(.gpt4o)
            let modalities = gpt4oModel.supportedModalities
            
            #expect(modalities.contains(.text) == true)
            #expect(modalities.contains(.vision) == true)
            #expect(modalities.contains(.audio) == false) // GPT-4o doesn't do audio directly
            
            // Test that we can create pipelines between modalities
            let pipeline = Model.createMultimodalPipeline([
                .transcription(Model.openai(.whisper1)),
                .textGeneration(Model.openai(.gpt4o)),
                .speechSynthesis(Model.openai(.tts1))
            ])
            
            #expect(pipeline.inputModalities.contains(.audio) == true)
            #expect(pipeline.outputModalities.contains(.audio) == true)
            #expect(pipeline.intermediateModalities.contains(.text) == true)
        }
        
        @Test("Model recommendation for audio workflows")
        func modelRecommendationForAudioWorkflows() {
            // Test recommendations for complete audio workflows
            let transcriptionWorkflow = Model.recommendForWorkflow(.audioTranscription)
            #expect(transcriptionWorkflow.primary.supportsAudioInput == true)
            #expect(transcriptionWorkflow.fallbacks.allSatisfy { $0.supportsAudioInput })
            
            let ttsWorkflow = Model.recommendForWorkflow(.textToSpeech)
            #expect(ttsWorkflow.primary.supportsAudioOutput == true)
            #expect(ttsWorkflow.fallbacks.allSatisfy { $0.supportsAudioOutput })
            
            let audioConversationWorkflow = Model.recommendForWorkflow(.audioConversation)
            #expect(audioConversationWorkflow.transcriptionModel.supportsAudioInput == true)
            #expect(audioConversationWorkflow.generationModel.supportsText == true)
            #expect(audioConversationWorkflow.synthesisModel.supportsAudioOutput == true)
        }
        
        @Test("Model cost optimization for audio tasks")
        func modelCostOptimizationForAudioTasks() {
            // Test cost-optimized model selection for audio tasks
            let costOptimized = Model.selectCostOptimal(for: .transcription, budget: 0.01) // $0.01 per minute
            #expect(costOptimized.supportsAudioInput == true)
            #expect(costOptimized.costPerMinute <= 0.01)
            
            let qualityOptimized = Model.selectQualityOptimal(for: .transcription, minQuality: 0.95)
            #expect(qualityOptimized.supportsAudioInput == true)
            #expect(qualityOptimized.performanceProfile.accuracyRating >= 0.95)
            
            // Test cost vs quality tradeoffs
            let balanced = Model.selectBalanced(for: .transcription, 
                                              costWeight: 0.3, 
                                              qualityWeight: 0.7)
            #expect(balanced.supportsAudioInput == true)
            
            let balancedScore = balanced.balancedScore(costWeight: 0.3, qualityWeight: 0.7)
            #expect(balancedScore > 0.0)
            #expect(balancedScore <= 1.0)
        }
    }
}