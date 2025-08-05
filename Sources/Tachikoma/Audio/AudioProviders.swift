import Foundation

// MARK: - Provider Protocols

/// Protocol for transcription providers
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public protocol TranscriptionProvider: Sendable {
    var modelId: String { get }
    var capabilities: TranscriptionCapabilities { get }

    func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult
}

/// Protocol for speech synthesis providers
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public protocol SpeechProvider: Sendable {
    var modelId: String { get }
    var capabilities: SpeechCapabilities { get }

    func generateSpeech(request: SpeechRequest) async throws -> SpeechResult
}

// MARK: - Capability Types

/// Capabilities of a transcription provider
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct TranscriptionCapabilities: Sendable {
    public let supportedFormats: [AudioFormat]
    public let supportsTimestamps: Bool
    public let supportsLanguageDetection: Bool
    public let supportsSpeakerDiarization: Bool
    public let supportsSummarization: Bool
    public let supportsWordTimestamps: Bool
    public let maxFileSize: Int? // in bytes
    public let maxDuration: TimeInterval? // in seconds
    public let supportedLanguages: [String]? // ISO 639-1 codes

    public init(
        supportedFormats: [AudioFormat] = AudioFormat.allCases,
        supportsTimestamps: Bool = false,
        supportsLanguageDetection: Bool = false,
        supportsSpeakerDiarization: Bool = false,
        supportsSummarization: Bool = false,
        supportsWordTimestamps: Bool = false,
        maxFileSize: Int? = nil,
        maxDuration: TimeInterval? = nil,
        supportedLanguages: [String]? = nil
    ) {
        self.supportedFormats = supportedFormats
        self.supportsTimestamps = supportsTimestamps
        self.supportsLanguageDetection = supportsLanguageDetection
        self.supportsSpeakerDiarization = supportsSpeakerDiarization
        self.supportsSummarization = supportsSummarization
        self.supportsWordTimestamps = supportsWordTimestamps
        self.maxFileSize = maxFileSize
        self.maxDuration = maxDuration
        self.supportedLanguages = supportedLanguages
    }
}

/// Capabilities of a speech synthesis provider
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct SpeechCapabilities: Sendable {
    public let supportedFormats: [AudioFormat]
    public let supportedVoices: [VoiceOption]
    public let supportsVoiceInstructions: Bool
    public let supportsSpeedControl: Bool
    public let supportsLanguageSelection: Bool
    public let supportsEmotionalControl: Bool
    public let maxTextLength: Int? // in characters
    public let supportedLanguages: [String]? // ISO 639-1 codes

    public init(
        supportedFormats: [AudioFormat] = [.mp3, .wav],
        supportedVoices: [VoiceOption] = [.alloy, .echo, .fable, .onyx, .nova, .shimmer],
        supportsVoiceInstructions: Bool = false,
        supportsSpeedControl: Bool = true,
        supportsLanguageSelection: Bool = false,
        supportsEmotionalControl: Bool = false,
        maxTextLength: Int? = nil,
        supportedLanguages: [String]? = nil
    ) {
        self.supportedFormats = supportedFormats
        self.supportedVoices = supportedVoices
        self.supportsVoiceInstructions = supportsVoiceInstructions
        self.supportsSpeedControl = supportsSpeedControl
        self.supportsLanguageSelection = supportsLanguageSelection
        self.supportsEmotionalControl = supportsEmotionalControl
        self.maxTextLength = maxTextLength
        self.supportedLanguages = supportedLanguages
    }
}

// MARK: - Provider Factories

/// Factory for creating transcription providers
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct TranscriptionProviderFactory {
    /// Create a transcription provider for the specified model
    public static func createProvider(for model: TranscriptionModel, configuration: TachikomaConfiguration = TachikomaConfiguration()) throws -> any TranscriptionProvider {
        // Check if API tests are disabled
        if ProcessInfo.processInfo.environment["TACHIKOMA_DISABLE_API_TESTS"] == "true" ||
           ProcessInfo.processInfo.environment["TACHIKOMA_TEST_MODE"] == "mock" {
            
            // Even in mock mode, validate API keys if explicitly testing missing key scenarios
            let providerName = model.providerName.lowercased()
            if !configuration.hasAPIKey(for: providerName) {
                throw TachikomaError.authenticationFailed("\(providerName.uppercased())_API_KEY not found")
            }
            
            return MockTranscriptionProvider(model: model)
        }

        switch model {
        case let .openai(openaiModel):
            return try OpenAITranscriptionProvider(model: openaiModel, configuration: configuration)
        case let .groq(groqModel):
            return try GroqTranscriptionProvider(model: groqModel, configuration: configuration)
        case let .deepgram(deepgramModel):
            return try DeepgramTranscriptionProvider(model: deepgramModel, configuration: configuration)
        case let .assemblyai(assemblyaiModel):
            return try AssemblyAITranscriptionProvider(model: assemblyaiModel, configuration: configuration)
        case let .elevenlabs(elevenlabsModel):
            return try ElevenLabsTranscriptionProvider(model: elevenlabsModel, configuration: configuration)
        case let .revai(revaiModel):
            return try RevAITranscriptionProvider(model: revaiModel, configuration: configuration)
        case let .azure(azureModel):
            return try AzureTranscriptionProvider(model: azureModel, configuration: configuration)
        }
    }
}

/// Factory for creating speech synthesis providers
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct SpeechProviderFactory {
    /// Create a speech provider for the specified model
    public static func createProvider(for model: SpeechModel, configuration: TachikomaConfiguration = TachikomaConfiguration()) throws -> any SpeechProvider {
        // Check if API tests are disabled
        if ProcessInfo.processInfo.environment["TACHIKOMA_DISABLE_API_TESTS"] == "true" ||
           ProcessInfo.processInfo.environment["TACHIKOMA_TEST_MODE"] == "mock" {
            
            // Even in mock mode, validate API keys if explicitly testing missing key scenarios
            let providerName = model.providerName.lowercased()
            if !configuration.hasAPIKey(for: providerName) {
                throw TachikomaError.authenticationFailed("\(providerName.uppercased())_API_KEY not found")
            }
            
            return MockSpeechProvider(model: model)
        }

        switch model {
        case let .openai(openaiModel):
            return try OpenAISpeechProvider(model: openaiModel, configuration: configuration)
        case let .lmnt(lmntModel):
            return try LMNTSpeechProvider(model: lmntModel, configuration: configuration)
        case let .hume(humeModel):
            return try HumeSpeechProvider(model: humeModel, configuration: configuration)
        case let .elevenlabs(elevenlabsModel):
            return try ElevenLabsSpeechProvider(model: elevenlabsModel, configuration: configuration)
        }
    }
}

// MARK: - Configuration Helper

/// Configuration helper for audio providers
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AudioConfiguration {
    /// Get API key for a specific provider
    public static func getAPIKey(for provider: String, configuration: TachikomaConfiguration? = nil) -> String? {
        let config = configuration ?? TachikomaConfiguration()
        
        // First check TachikomaConfiguration
        if let key = config.getAPIKey(for: provider) {
            return key
        }

        // Then check environment variables with common patterns
        let envKeys = self.environmentKeys(for: provider)
        for key in envKeys {
            if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
                return value
            }
        }

        return nil
    }

    /// Get common environment variable names for a provider
    private static func environmentKeys(for provider: String) -> [String] {
        let upperProvider = provider.uppercased()

        switch provider.lowercased() {
        case "openai":
            return ["OPENAI_API_KEY"]
        case "groq":
            return ["GROQ_API_KEY"]
        case "deepgram":
            return ["DEEPGRAM_API_KEY", "DEEPGRAM_TOKEN"]
        case "assemblyai":
            return ["ASSEMBLYAI_API_KEY", "ASSEMBLY_AI_API_KEY"]
        case "elevenlabs":
            return ["ELEVENLABS_API_KEY", "ELEVEN_LABS_API_KEY"]
        case "revai":
            return ["REVAI_API_KEY", "REV_AI_API_KEY"]
        case "azure":
            return ["AZURE_OPENAI_API_KEY", "AZURE_API_KEY"]
        case "lmnt":
            return ["LMNT_API_KEY"]
        case "hume":
            return ["HUME_API_KEY"]
        default:
            return ["\(upperProvider)_API_KEY", "\(upperProvider)_TOKEN"]
        }
    }
}

// MARK: - Provider Base Classes (Stubs)

// These are placeholder implementations that need to be filled in with actual API calls

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class OpenAITranscriptionProvider: TranscriptionProvider {
    public let modelId: String
    public let capabilities: TranscriptionCapabilities

    private let model: TranscriptionModel.OpenAI
    let apiKey: String

    public init(model: TranscriptionModel.OpenAI, configuration: TachikomaConfiguration) throws {
        self.model = model
        self.modelId = model.rawValue

        guard let key = AudioConfiguration.getAPIKey(for: "openai", configuration: configuration) else {
            throw TachikomaError.authenticationFailed("OPENAI_API_KEY not found")
        }
        self.apiKey = key

        self.capabilities = TranscriptionCapabilities(
            supportedFormats: [.mp3, .wav, .flac, .m4a, .opus, .pcm],
            supportsTimestamps: model.supportsTimestamps,
            supportsLanguageDetection: model.supportsLanguageDetection,
            supportsSpeakerDiarization: false,
            supportsSummarization: false,
            supportsWordTimestamps: model.supportsTimestamps,
            maxFileSize: 25 * 1024 * 1024, // 25MB
            maxDuration: nil
        )
    }

    // Implementation is in OpenAIAudioProvider.swift extension
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class OpenAISpeechProvider: SpeechProvider {
    public let modelId: String
    public let capabilities: SpeechCapabilities

    private let model: SpeechModel.OpenAI
    let apiKey: String

    public init(model: SpeechModel.OpenAI, configuration: TachikomaConfiguration) throws {
        self.model = model
        self.modelId = model.rawValue

        guard let key = AudioConfiguration.getAPIKey(for: "openai", configuration: configuration) else {
            throw TachikomaError.authenticationFailed("OPENAI_API_KEY not found")
        }
        self.apiKey = key

        self.capabilities = SpeechCapabilities(
            supportedFormats: model.supportedFormats,
            supportedVoices: model.supportedVoices,
            supportsVoiceInstructions: model.supportsVoiceInstructions,
            supportsSpeedControl: true,
            supportsLanguageSelection: false,
            supportsEmotionalControl: false,
            maxTextLength: 4096
        )
    }

    // Implementation is in OpenAIAudioProvider.swift extension
}

// MARK: - Other Provider Stubs

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class GroqTranscriptionProvider: TranscriptionProvider {
    public let modelId: String
    public let capabilities: TranscriptionCapabilities

    public init(model: TranscriptionModel.Groq, configuration: TachikomaConfiguration) throws {
        self.modelId = model.rawValue
        self.capabilities = TranscriptionCapabilities(
            supportsTimestamps: model.supportsTimestamps,
            supportsLanguageDetection: model.supportsLanguageDetection
        )
    }

    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        throw TachikomaError.unsupportedOperation("Groq transcription not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class DeepgramTranscriptionProvider: TranscriptionProvider {
    public let modelId: String
    public let capabilities: TranscriptionCapabilities

    public init(model: TranscriptionModel.Deepgram, configuration: TachikomaConfiguration) throws {
        self.modelId = model.rawValue
        self.capabilities = TranscriptionCapabilities(
            supportsTimestamps: model.supportsTimestamps,
            supportsLanguageDetection: model.supportsLanguageDetection,
            supportsSummarization: model.supportsSummarization
        )
    }

    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        throw TachikomaError.unsupportedOperation("Deepgram transcription not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class AssemblyAITranscriptionProvider: TranscriptionProvider {
    public let modelId: String
    public let capabilities: TranscriptionCapabilities

    public init(model: TranscriptionModel.AssemblyAI, configuration: TachikomaConfiguration) throws {
        self.modelId = model.rawValue
        self.capabilities = TranscriptionCapabilities(
            supportsTimestamps: model.supportsTimestamps,
            supportsLanguageDetection: model.supportsLanguageDetection,
            supportsSpeakerDiarization: model.supportsSpeakerDiarization
        )
    }

    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        throw TachikomaError.unsupportedOperation("AssemblyAI transcription not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class ElevenLabsTranscriptionProvider: TranscriptionProvider {
    public let modelId: String
    public let capabilities: TranscriptionCapabilities

    public init(model: TranscriptionModel.ElevenLabs, configuration: TachikomaConfiguration) throws {
        self.modelId = model.rawValue
        self.capabilities = TranscriptionCapabilities(
            supportsTimestamps: model.supportsTimestamps,
            supportsLanguageDetection: model.supportsLanguageDetection
        )
    }

    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        throw TachikomaError.unsupportedOperation("ElevenLabs transcription not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class RevAITranscriptionProvider: TranscriptionProvider {
    public let modelId: String
    public let capabilities: TranscriptionCapabilities

    public init(model: TranscriptionModel.RevAI, configuration: TachikomaConfiguration) throws {
        self.modelId = model.rawValue
        self.capabilities = TranscriptionCapabilities(
            supportsTimestamps: model.supportsTimestamps,
            supportsLanguageDetection: model.supportsLanguageDetection
        )
    }

    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        throw TachikomaError.unsupportedOperation("RevAI transcription not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class AzureTranscriptionProvider: TranscriptionProvider {
    public let modelId: String
    public let capabilities: TranscriptionCapabilities

    public init(model: TranscriptionModel.Azure, configuration: TachikomaConfiguration) throws {
        self.modelId = model.rawValue
        self.capabilities = TranscriptionCapabilities(
            supportsTimestamps: model.supportsTimestamps
        )
    }

    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        throw TachikomaError.unsupportedOperation("Azure transcription not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class LMNTSpeechProvider: SpeechProvider {
    public let modelId: String
    public let capabilities: SpeechCapabilities

    public init(model: SpeechModel.LMNT, configuration: TachikomaConfiguration) throws {
        self.modelId = model.rawValue
        self.capabilities = SpeechCapabilities(
            supportedFormats: model.supportedFormats,
            supportsLanguageSelection: model.supportsLanguages
        )
    }

    public func generateSpeech(request: SpeechRequest) async throws -> SpeechResult {
        throw TachikomaError.unsupportedOperation("LMNT speech generation not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class HumeSpeechProvider: SpeechProvider {
    public let modelId: String
    public let capabilities: SpeechCapabilities

    public init(model: SpeechModel.Hume, configuration: TachikomaConfiguration) throws {
        self.modelId = model.rawValue
        self.capabilities = SpeechCapabilities(
            supportedFormats: model.supportedFormats,
            supportsEmotionalControl: model.supportsEmotionalControl
        )
    }

    public func generateSpeech(request: SpeechRequest) async throws -> SpeechResult {
        throw TachikomaError.unsupportedOperation("Hume speech generation not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class ElevenLabsSpeechProvider: SpeechProvider {
    public let modelId: String
    public let capabilities: SpeechCapabilities

    public init(model: SpeechModel.ElevenLabs, configuration: TachikomaConfiguration) throws {
        self.modelId = model.rawValue
        self.capabilities = SpeechCapabilities(
            supportedFormats: model.supportedFormats,
            supportsVoiceInstructions: model.supportsVoiceCloning
        )
    }

    public func generateSpeech(request: SpeechRequest) async throws -> SpeechResult {
        throw TachikomaError.unsupportedOperation("ElevenLabs speech generation not yet implemented")
    }
}

// MARK: - Mock Providers for Testing

/// Mock transcription provider for testing
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class MockTranscriptionProvider: TranscriptionProvider {
    public let modelId: String
    public let capabilities: TranscriptionCapabilities

    private let model: TranscriptionModel

    public init(model: TranscriptionModel) {
        self.model = model
        self.modelId = model.modelId
        
        // Set capabilities based on the model
        switch model {
        case .openai(let openaiModel):
            self.capabilities = TranscriptionCapabilities(
                supportedFormats: [.flac, .m4a, .mp3, .opus, .aac, .ogg, .wav, .pcm],
                supportsTimestamps: openaiModel.supportsTimestamps,
                supportsLanguageDetection: openaiModel.supportsLanguageDetection,
                supportsWordTimestamps: openaiModel.supportsTimestamps,
                maxFileSize: 25 * 1024 * 1024 // 25MB
            )
        default:
            self.capabilities = TranscriptionCapabilities(
                supportedFormats: AudioFormat.allCases,
                supportsTimestamps: true,
                supportsLanguageDetection: true,
                supportsWordTimestamps: true
            )
        }
    }

    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        // Check for abort signal
        try request.abortSignal?.throwIfCancelled()
        
        // Validate audio data
        if request.audio.data.isEmpty {
            throw TachikomaError.invalidInput("Audio data is empty")
        }
        
        // Check file size limits
        if let maxSize = capabilities.maxFileSize, request.audio.data.count > maxSize {
            throw TachikomaError.invalidInput("Audio file too large: \(request.audio.data.count) bytes (max: \(maxSize))")
        }
        
        // Simulate network delay
        try await Task.sleep(for: .milliseconds(100))
        
        // Check for abort signal again after delay
        try request.abortSignal?.throwIfCancelled()
        
        let mockText = "Mock transcription result for audio file."
        let mockDuration = request.audio.duration ?? 2.0
        
        // Create segments if timestamps are requested
        var segments: [TranscriptionSegment]? = nil
        if request.timestampGranularities.contains(.segment) || request.responseFormat == .verbose {
            segments = [
                TranscriptionSegment(
                    text: mockText,
                    start: 0.0,
                    end: mockDuration,
                    words: request.timestampGranularities.contains(.word) ? [
                        TranscriptionWord(word: "Mock", start: 0.0, end: 0.5),
                        TranscriptionWord(word: "transcription", start: 0.5, end: 1.5),
                        TranscriptionWord(word: "result", start: 1.5, end: mockDuration)
                    ] : nil
                )
            ]
        }
        
        return TranscriptionResult(
            text: mockText,
            language: request.language ?? "en",
            duration: mockDuration,
            segments: segments,
            usage: TranscriptionUsage(durationSeconds: mockDuration)
        )
    }
}

/// Mock speech provider for testing
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class MockSpeechProvider: SpeechProvider {
    public let modelId: String
    public let capabilities: SpeechCapabilities

    private let model: SpeechModel

    public init(model: SpeechModel) {
        self.model = model
        self.modelId = model.modelId
        
        // Set capabilities based on the model
        switch model {
        case .openai(let openaiModel):
            self.capabilities = SpeechCapabilities(
                supportedFormats: openaiModel.supportedFormats,
                supportedVoices: openaiModel.supportedVoices,
                supportsVoiceInstructions: openaiModel.supportsVoiceInstructions,
                supportsSpeedControl: true,
                maxTextLength: 4096
            )
        default:
            self.capabilities = SpeechCapabilities(
                supportedFormats: [.mp3, .wav],
                supportedVoices: [.alloy, .echo, .fable, .onyx, .nova, .shimmer],
                supportsSpeedControl: true
            )
        }
    }

    public func generateSpeech(request: SpeechRequest) async throws -> SpeechResult {
        // Check for abort signal
        try request.abortSignal?.throwIfCancelled()
        
        // Validate text
        if request.text.isEmpty {
            throw TachikomaError.invalidInput("Text is empty")
        }
        
        // Check text length limits
        if let maxLength = capabilities.maxTextLength, request.text.count > maxLength {
            throw TachikomaError.invalidInput("Text too long: \(request.text.count) characters (max: \(maxLength))")
        }
        
        // Validate voice
        if !capabilities.supportedVoices.contains(request.voice) {
            throw TachikomaError.invalidInput("Unsupported voice: \(request.voice.stringValue)")
        }
        
        // Validate format
        if !capabilities.supportedFormats.contains(request.format) {
            throw TachikomaError.invalidInput("Unsupported format: \(request.format.rawValue)")
        }
        
        // Validate speed
        if request.speed < 0.25 || request.speed > 4.0 {
            throw TachikomaError.invalidInput("Speed must be between 0.25 and 4.0")
        }
        
        // Simulate network delay
        try await Task.sleep(for: .milliseconds(100))
        
        // Check for abort signal again after delay
        try request.abortSignal?.throwIfCancelled()
        
        // Generate minimal audio data (4 bytes)
        let mockAudioData = Data([0x00, 0x01, 0x02, 0x03])

        return SpeechResult(
            audioData: AudioData(data: mockAudioData, format: request.format),
            usage: SpeechUsage(charactersProcessed: request.text.count)
        )
    }
}
