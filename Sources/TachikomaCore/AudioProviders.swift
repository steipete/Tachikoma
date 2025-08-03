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
        supportedLanguages: [String]? = nil)
    {
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
        supportedLanguages: [String]? = nil)
    {
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
    public static func createProvider(for model: TranscriptionModel) throws -> any TranscriptionProvider {
        switch model {
        case let .openai(openaiModel):
            try OpenAITranscriptionProvider(model: openaiModel)
        case let .groq(groqModel):
            try GroqTranscriptionProvider(model: groqModel)
        case let .deepgram(deepgramModel):
            try DeepgramTranscriptionProvider(model: deepgramModel)
        case let .assemblyai(assemblyaiModel):
            try AssemblyAITranscriptionProvider(model: assemblyaiModel)
        case let .elevenlabs(elevenlabsModel):
            try ElevenLabsTranscriptionProvider(model: elevenlabsModel)
        case let .revai(revaiModel):
            try RevAITranscriptionProvider(model: revaiModel)
        case let .azure(azureModel):
            try AzureTranscriptionProvider(model: azureModel)
        }
    }
}

/// Factory for creating speech synthesis providers
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct SpeechProviderFactory {
    /// Create a speech provider for the specified model
    public static func createProvider(for model: SpeechModel) throws -> any SpeechProvider {
        switch model {
        case let .openai(openaiModel):
            try OpenAISpeechProvider(model: openaiModel)
        case let .lmnt(lmntModel):
            try LMNTSpeechProvider(model: lmntModel)
        case let .hume(humeModel):
            try HumeSpeechProvider(model: humeModel)
        case let .elevenlabs(elevenlabsModel):
            try ElevenLabsSpeechProvider(model: elevenlabsModel)
        }
    }
}

// MARK: - Configuration Helper

/// Configuration helper for audio providers
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AudioConfiguration {
    /// Get API key for a specific provider
    public static func getAPIKey(for provider: String) -> String? {
        // First check TachikomaConfiguration
        if let key = TachikomaConfiguration.shared.getAPIKey(for: provider) {
            return key
        }

        // Then check environment variables with common patterns
        let envKeys = self.environmentKeys(for: provider)
        for key in envKeys {
            if let value = ProcessInfo.processInfo.environment[key] {
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

    public init(model: TranscriptionModel.OpenAI) throws {
        self.model = model
        self.modelId = model.rawValue

        guard let key = AudioConfiguration.getAPIKey(for: "openai") else {
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
            maxDuration: nil)
    }

    // Implementation is in OpenAIAudioProvider.swift extension
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class OpenAISpeechProvider: SpeechProvider {
    public let modelId: String
    public let capabilities: SpeechCapabilities

    private let model: SpeechModel.OpenAI
    let apiKey: String

    public init(model: SpeechModel.OpenAI) throws {
        self.model = model
        self.modelId = model.rawValue

        guard let key = AudioConfiguration.getAPIKey(for: "openai") else {
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
            maxTextLength: 4096)
    }

    // Implementation is in OpenAIAudioProvider.swift extension
}

// MARK: - Other Provider Stubs

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class GroqTranscriptionProvider: TranscriptionProvider {
    public let modelId: String
    public let capabilities: TranscriptionCapabilities

    public init(model: TranscriptionModel.Groq) throws {
        self.modelId = model.rawValue
        self.capabilities = TranscriptionCapabilities(
            supportsTimestamps: model.supportsTimestamps,
            supportsLanguageDetection: model.supportsLanguageDetection)
    }

    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        throw TachikomaError.unsupportedOperation("Groq transcription not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class DeepgramTranscriptionProvider: TranscriptionProvider {
    public let modelId: String
    public let capabilities: TranscriptionCapabilities

    public init(model: TranscriptionModel.Deepgram) throws {
        self.modelId = model.rawValue
        self.capabilities = TranscriptionCapabilities(
            supportsTimestamps: model.supportsTimestamps,
            supportsLanguageDetection: model.supportsLanguageDetection,
            supportsSummarization: model.supportsSummarization)
    }

    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        throw TachikomaError.unsupportedOperation("Deepgram transcription not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class AssemblyAITranscriptionProvider: TranscriptionProvider {
    public let modelId: String
    public let capabilities: TranscriptionCapabilities

    public init(model: TranscriptionModel.AssemblyAI) throws {
        self.modelId = model.rawValue
        self.capabilities = TranscriptionCapabilities(
            supportsTimestamps: model.supportsTimestamps,
            supportsLanguageDetection: model.supportsLanguageDetection,
            supportsSpeakerDiarization: model.supportsSpeakerDiarization)
    }

    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        throw TachikomaError.unsupportedOperation("AssemblyAI transcription not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class ElevenLabsTranscriptionProvider: TranscriptionProvider {
    public let modelId: String
    public let capabilities: TranscriptionCapabilities

    public init(model: TranscriptionModel.ElevenLabs) throws {
        self.modelId = model.rawValue
        self.capabilities = TranscriptionCapabilities(
            supportsTimestamps: model.supportsTimestamps,
            supportsLanguageDetection: model.supportsLanguageDetection)
    }

    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        throw TachikomaError.unsupportedOperation("ElevenLabs transcription not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class RevAITranscriptionProvider: TranscriptionProvider {
    public let modelId: String
    public let capabilities: TranscriptionCapabilities

    public init(model: TranscriptionModel.RevAI) throws {
        self.modelId = model.rawValue
        self.capabilities = TranscriptionCapabilities(
            supportsTimestamps: model.supportsTimestamps,
            supportsLanguageDetection: model.supportsLanguageDetection)
    }

    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        throw TachikomaError.unsupportedOperation("RevAI transcription not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class AzureTranscriptionProvider: TranscriptionProvider {
    public let modelId: String
    public let capabilities: TranscriptionCapabilities

    public init(model: TranscriptionModel.Azure) throws {
        self.modelId = model.rawValue
        self.capabilities = TranscriptionCapabilities(
            supportsTimestamps: model.supportsTimestamps)
    }

    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        throw TachikomaError.unsupportedOperation("Azure transcription not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class LMNTSpeechProvider: SpeechProvider {
    public let modelId: String
    public let capabilities: SpeechCapabilities

    public init(model: SpeechModel.LMNT) throws {
        self.modelId = model.rawValue
        self.capabilities = SpeechCapabilities(
            supportedFormats: model.supportedFormats,
            supportsLanguageSelection: model.supportsLanguages)
    }

    public func generateSpeech(request: SpeechRequest) async throws -> SpeechResult {
        throw TachikomaError.unsupportedOperation("LMNT speech generation not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class HumeSpeechProvider: SpeechProvider {
    public let modelId: String
    public let capabilities: SpeechCapabilities

    public init(model: SpeechModel.Hume) throws {
        self.modelId = model.rawValue
        self.capabilities = SpeechCapabilities(
            supportedFormats: model.supportedFormats,
            supportsEmotionalControl: model.supportsEmotionalControl)
    }

    public func generateSpeech(request: SpeechRequest) async throws -> SpeechResult {
        throw TachikomaError.unsupportedOperation("Hume speech generation not yet implemented")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class ElevenLabsSpeechProvider: SpeechProvider {
    public let modelId: String
    public let capabilities: SpeechCapabilities

    public init(model: SpeechModel.ElevenLabs) throws {
        self.modelId = model.rawValue
        self.capabilities = SpeechCapabilities(
            supportedFormats: model.supportedFormats,
            supportsVoiceInstructions: model.supportsVoiceCloning)
    }

    public func generateSpeech(request: SpeechRequest) async throws -> SpeechResult {
        throw TachikomaError.unsupportedOperation("ElevenLabs speech generation not yet implemented")
    }
}
