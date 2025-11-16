import Foundation
import Tachikoma // For TachikomaError

// MARK: - Audio Data Types

/// Audio data container with format and metadata information
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AudioData: Sendable {
    public let data: Data
    public let format: AudioFormat
    public let sampleRate: Int?
    public let channels: Int?
    public let duration: TimeInterval?

    public init(
        data: Data,
        format: AudioFormat = .wav,
        sampleRate: Int? = nil,
        channels: Int? = nil,
        duration: TimeInterval? = nil,
    ) {
        self.data = data
        self.format = format
        self.sampleRate = sampleRate
        self.channels = channels
        self.duration = duration
    }

    /// Create AudioData from a file URL
    public init(contentsOf url: URL) throws {
        self.data = try Data(contentsOf: url)

        // Infer format from file extension
        let pathExtension = url.pathExtension.lowercased()
        self.format = AudioFormat(rawValue: pathExtension) ?? .wav

        // TODO: Extract metadata from audio file headers
        self.sampleRate = nil
        self.channels = nil
        self.duration = nil
    }

    /// Size in bytes
    public var size: Int {
        self.data.count
    }

    /// Write audio data to a file URL
    public func write(to url: URL) throws {
        // Write audio data to a file URL
        try self.data.write(to: url)
    }
}

/// Supported audio formats
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum AudioFormat: String, CaseIterable, Sendable {
    case wav
    case mp3
    case flac
    case opus
    case m4a
    case aac
    case pcm
    case ogg

    /// MIME type for the audio format
    public var mimeType: String {
        switch self {
        case .wav: "audio/wav"
        case .mp3: "audio/mpeg"
        case .flac: "audio/flac"
        case .opus: "audio/opus"
        case .m4a: "audio/mp4"
        case .aac: "audio/aac"
        case .pcm: "audio/pcm"
        case .ogg: "audio/ogg"
        }
    }

    /// Whether the format supports lossless compression
    public var isLossless: Bool {
        switch self {
        case .wav, .flac, .pcm: true
        case .mp3, .opus, .m4a, .aac, .ogg: false
        }
    }
}

/// Voice options for speech synthesis
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum VoiceOption: Sendable, Hashable {
    // OpenAI voices
    case alloy
    case echo
    case fable
    case onyx
    case nova
    case shimmer

    // Custom voice (provider-specific)
    case custom(String)

    public var stringValue: String {
        switch self {
        case .alloy: "alloy"
        case .echo: "echo"
        case .fable: "fable"
        case .onyx: "onyx"
        case .nova: "nova"
        case .shimmer: "shimmer"
        case let .custom(voice): voice
        }
    }

    /// Default female voice
    public static let `default`: VoiceOption = .alloy

    /// Recommended voices by gender
    public static let female: [VoiceOption] = [.alloy, .nova, .shimmer]
    public static let male: [VoiceOption] = [.echo, .fable, .onyx]
}

/// Timestamp granularity for transcription
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum TimestampGranularity: String, CaseIterable, Sendable {
    case word
    case segment
}

/// Response format for transcription
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum TranscriptionResponseFormat: String, CaseIterable, Sendable {
    case json
    case text
    case srt
    case verbose = "verbose_json"
    case vtt
}

// MARK: - Transcription Results

/// Result of audio transcription
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct TranscriptionResult: Sendable {
    public let text: String
    public let language: String?
    public let duration: TimeInterval?
    public let segments: [TranscriptionSegment]?
    public let usage: TranscriptionUsage?
    public let warnings: [String]?

    public init(
        text: String,
        language: String? = nil,
        duration: TimeInterval? = nil,
        segments: [TranscriptionSegment]? = nil,
        usage: TranscriptionUsage? = nil,
        warnings: [String]? = nil,
    ) {
        self.text = text
        self.language = language
        self.duration = duration
        self.segments = segments
        self.usage = usage
        self.warnings = warnings
    }
}

/// Individual segment in a transcription with timing information
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct TranscriptionSegment: Sendable {
    public let text: String
    public let start: TimeInterval
    public let end: TimeInterval
    public let confidence: Double?
    public let words: [TranscriptionWord]?

    public init(
        text: String,
        start: TimeInterval,
        end: TimeInterval,
        confidence: Double? = nil,
        words: [TranscriptionWord]? = nil,
    ) {
        self.text = text
        self.start = start
        self.end = end
        self.confidence = confidence
        self.words = words
    }

    /// Duration of this segment
    public var duration: TimeInterval {
        self.end - self.start
    }
}

/// Individual word in a transcription with precise timing
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct TranscriptionWord: Sendable {
    public let word: String
    public let start: TimeInterval
    public let end: TimeInterval
    public let confidence: Double?

    public init(
        word: String,
        start: TimeInterval,
        end: TimeInterval,
        confidence: Double? = nil,
    ) {
        self.word = word
        self.start = start
        self.end = end
        self.confidence = confidence
    }
}

/// Usage information for transcription
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct TranscriptionUsage: Sendable {
    public let durationSeconds: TimeInterval
    public let cost: Double?

    public init(
        durationSeconds: TimeInterval,
        cost: Double? = nil,
    ) {
        self.durationSeconds = durationSeconds
        self.cost = cost
    }
}

// MARK: - Speech Results

/// Result of speech synthesis
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct SpeechResult: Sendable {
    public let audioData: AudioData
    public let usage: SpeechUsage?
    public let warnings: [String]?

    public init(
        audioData: AudioData,
        usage: SpeechUsage? = nil,
        warnings: [String]? = nil,
    ) {
        self.audioData = audioData
        self.usage = usage
        self.warnings = warnings
    }
}

/// Usage information for speech synthesis
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct SpeechUsage: Sendable {
    public let charactersProcessed: Int
    public let cost: Double?

    public init(
        charactersProcessed: Int,
        cost: Double? = nil,
    ) {
        self.charactersProcessed = charactersProcessed
        self.cost = cost
    }
}

// MARK: - Request Types

/// Request for audio transcription
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct TranscriptionRequest: Sendable {
    public let audio: AudioData
    public let language: String?
    public let prompt: String?
    public let timestampGranularities: [TimestampGranularity]
    public let responseFormat: TranscriptionResponseFormat
    public let abortSignal: AbortSignal?
    public let headers: [String: String]

    public init(
        audio: AudioData,
        language: String? = nil,
        prompt: String? = nil,
        timestampGranularities: [TimestampGranularity] = [],
        responseFormat: TranscriptionResponseFormat = .verbose,
        abortSignal: AbortSignal? = nil,
        headers: [String: String] = [:],
    ) {
        self.audio = audio
        self.language = language
        self.prompt = prompt
        self.timestampGranularities = timestampGranularities
        self.responseFormat = responseFormat
        self.abortSignal = abortSignal
        self.headers = headers
    }
}

/// Request for speech synthesis
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct SpeechRequest: Sendable {
    public let text: String
    public let voice: VoiceOption
    public let language: String?
    public let speed: Double
    public let format: AudioFormat
    public let instructions: String?
    public let abortSignal: AbortSignal?
    public let headers: [String: String]

    public init(
        text: String,
        voice: VoiceOption = .alloy,
        language: String? = nil,
        speed: Double = 1.0,
        format: AudioFormat = .mp3,
        instructions: String? = nil,
        abortSignal: AbortSignal? = nil,
        headers: [String: String] = [:],
    ) {
        self.text = text
        self.voice = voice
        self.language = language
        self.speed = speed
        self.format = format
        self.instructions = instructions
        self.abortSignal = abortSignal
        self.headers = headers
    }
}

// MARK: - AbortSignal Support

/// Simple abort signal implementation for cancelling audio operations
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class AbortSignal: @unchecked Sendable {
    private var _cancelled = false
    private let lock = NSLock()

    public var cancelled: Bool {
        self.lock.lock()
        defer { lock.unlock() }
        return self._cancelled
    }

    public func cancel() {
        self.lock.lock()
        defer { lock.unlock() }
        self._cancelled = true
    }

    /// Initialize a new abort signal
    public init() {
        // Empty initializer - all properties have default values
    }

    /// Create an abort signal that cancels after a timeout
    public static func timeout(_ timeInterval: TimeInterval) -> AbortSignal {
        // Create an abort signal that cancels after a timeout
        let signal = AbortSignal()

        Task {
            try await Task.sleep(nanoseconds: UInt64(timeInterval * 1_000_000_000))
            signal.cancel()
        }

        return signal
    }

    /// Check if the signal is cancelled and throw if so
    public func throwIfCancelled() throws {
        // Check if the signal is cancelled and throw if so
        if self.cancelled {
            throw TachikomaError.operationCancelled
        }
    }
}

// MARK: - Audio Errors

extension TachikomaError {
    public static let operationCancelled = TachikomaError.invalidInput("Operation was cancelled")
    public static let noAudioData = TachikomaError.invalidInput("No audio data provided")
    public static let unsupportedAudioFormat = TachikomaError.invalidInput("Unsupported audio format")
    public static let transcriptionFailed = TachikomaError.apiError("Transcription failed")
    public static let speechGenerationFailed = TachikomaError.apiError("Speech generation failed")
}
