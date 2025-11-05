import Foundation
import Tachikoma // For model types

// MARK: - Audio Model Types

/// Transcription models for speech-to-text processing
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum TranscriptionModel: Sendable, CustomStringConvertible {
    // Provider-specific transcription models
    case openai(OpenAI)
    case groq(Groq)
    case deepgram(Deepgram)
    case elevenlabs(ElevenLabs)

    // MARK: - Provider Sub-Enums

    public enum OpenAI: String, CaseIterable, Sendable {
        case whisper1 = "whisper-1"
        case gpt4oTranscribe = "gpt-4o-transcribe"
        case gpt4oMiniTranscribe = "gpt-4o-mini-transcribe"

        public var supportsTimestamps: Bool {
            switch self {
            case .whisper1: true
            case .gpt4oTranscribe, .gpt4oMiniTranscribe: false
            }
        }

        public var supportsLanguageDetection: Bool {
            switch self {
            case .whisper1: true
            case .gpt4oTranscribe, .gpt4oMiniTranscribe: false
            }
        }
    }

    public enum Groq: String, CaseIterable, Sendable {
        case whisperLargeV3 = "whisper-large-v3"
        case whisperLargeV3Turbo = "whisper-large-v3-turbo"
        case distilWhisperLargeV3En = "distil-whisper-large-v3-en"

        public var supportsTimestamps: Bool { true }
        public var supportsLanguageDetection: Bool { true }
    }

    public enum Deepgram: String, CaseIterable, Sendable {
        case nova3 = "nova-3"
        case nova2 = "nova-2"
        case enhanced
        case base

        public var supportsTimestamps: Bool { true }
        public var supportsLanguageDetection: Bool { true }
        public var supportsSummarization: Bool { true }
    }

    public enum ElevenLabs: String, CaseIterable, Sendable {
        case scribeV1 = "scribe_v1"
        case scribeV1Experimental = "scribe_v1_experimental"

        public var supportsTimestamps: Bool { false }
        public var supportsLanguageDetection: Bool { true }
    }

    // MARK: - Model Properties

    public var description: String {
        switch self {
        case let .openai(model):
            "OpenAI/\(model.rawValue)"
        case let .groq(model):
            "Groq/\(model.rawValue)"
        case let .deepgram(model):
            "Deepgram/\(model.rawValue)"
        case let .elevenlabs(model):
            "ElevenLabs/\(model.rawValue)"
        }
    }

    public var modelId: String {
        switch self {
        case let .openai(model):
            model.rawValue
        case let .groq(model):
            model.rawValue
        case let .deepgram(model):
            model.rawValue
        case let .elevenlabs(model):
            model.rawValue
        }
    }

    public var providerName: String {
        switch self {
        case .openai: "OpenAI"
        case .groq: "Groq"
        case .deepgram: "Deepgram"
        case .elevenlabs: "ElevenLabs"
        }
    }

    public var supportsTimestamps: Bool {
        switch self {
        case let .openai(model): model.supportsTimestamps
        case let .groq(model): model.supportsTimestamps
        case let .deepgram(model): model.supportsTimestamps
        case let .elevenlabs(model): model.supportsTimestamps
        }
    }

    public var supportsLanguageDetection: Bool {
        switch self {
        case let .openai(model): model.supportsLanguageDetection
        case let .groq(model): model.supportsLanguageDetection
        case let .deepgram(model): model.supportsLanguageDetection
        case let .elevenlabs(model): model.supportsLanguageDetection
        }
    }

    // MARK: - Default Models

    public static let `default`: TranscriptionModel = .openai(.whisper1)
    public static let whisper: TranscriptionModel = .openai(.whisper1)
    public static let fast: TranscriptionModel = .groq(.whisperLargeV3Turbo)
    public static let accurate: TranscriptionModel = .deepgram(.nova3)
}

/// Speech synthesis models for text-to-speech processing
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum SpeechModel: Sendable, CustomStringConvertible {
    // Provider-specific speech models
    case openai(OpenAI)
    case elevenlabs(ElevenLabs)

    // MARK: - Provider Sub-Enums

    public enum OpenAI: String, CaseIterable, Sendable {
        case tts1 = "tts-1"
        case tts1HD = "tts-1-hd"
        case gpt4oMiniTTS = "gpt-4o-mini-tts"

        public var supportsVoiceInstructions: Bool {
            switch self {
            case .tts1, .tts1HD: false
            case .gpt4oMiniTTS: true
            }
        }

        public var supportedFormats: [AudioFormat] {
            [.mp3, .opus, .aac, .flac, .wav, .pcm]
        }

        public var supportedVoices: [VoiceOption] {
            [.alloy, .echo, .fable, .onyx, .nova, .shimmer]
        }
    }

    public enum ElevenLabs: String, CaseIterable, Sendable {
        case multilingualV1 = "eleven_multilingual_v1"
        case multilingualV2 = "eleven_multilingual_v2"
        case englishV1 = "eleven_english_v1"

        public var supportsVoiceCloning: Bool { true }
        public var supportedFormats: [AudioFormat] { [.mp3, .wav, .pcm] }
    }

    // MARK: - Model Properties

    public var description: String {
        switch self {
        case let .openai(model):
            "OpenAI/\(model.rawValue)"
        case let .elevenlabs(model):
            "ElevenLabs/\(model.rawValue)"
        }
    }

    public var modelId: String {
        switch self {
        case let .openai(model):
            model.rawValue
        case let .elevenlabs(model):
            model.rawValue
        }
    }

    public var providerName: String {
        switch self {
        case .openai: "OpenAI"
        case .elevenlabs: "ElevenLabs"
        }
    }

    public var supportedFormats: [AudioFormat] {
        switch self {
        case let .openai(model): model.supportedFormats
        case let .elevenlabs(model): model.supportedFormats
        }
    }

    // MARK: - Default Models

    public static let `default`: SpeechModel = .openai(.tts1)
    public static let highQuality: SpeechModel = .openai(.tts1HD)
    public static let fast: SpeechModel = .openai(.tts1)
    public static let expressive: SpeechModel = .openai(.gpt4oMiniTTS)
}
