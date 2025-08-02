import Foundation

// Note: AudioContent is defined in Core/MessageTypes.swift to avoid duplication

// MARK: - Audio Input Service Protocol

/// Protocol defining audio input capabilities for AI systems
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@MainActor
public protocol AudioInputServiceProtocol: AnyObject, Sendable {
    /// Start recording audio from the default input device
    func startRecording() async throws
    
    /// Stop recording and return the transcribed text
    func stopRecording() async throws -> String
    
    /// Transcribe an audio file and return the text
    func transcribeAudioFile(_ url: URL) async throws -> String
    
    /// Check if currently recording
    var isRecording: Bool { get }
    
    /// Check if audio input is available
    var isAvailable: Bool { get }
}

// MARK: - Audio Input Errors

/// Errors that can occur during audio input operations
public enum AudioInputError: LocalizedError, Equatable {
    case alreadyRecording
    case notRecording
    case invalidURL
    case fileNotFound(URL)
    case unsupportedFileType(String)
    case fileTooLarge(Int64, Int64)
    case noTranscriptionService
    case transcriptionFailed(String)
    case microphonePermissionDenied
    case platformNotSupported
    
    public var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            "Audio recording is already in progress"
        case .notRecording:
            "No audio recording is in progress"
        case .invalidURL:
            "Invalid recording URL"
        case let .fileNotFound(url):
            "Audio file not found: \(url.path)"
        case let .unsupportedFileType(type):
            "Unsupported audio file type: \(type)"
        case let .fileTooLarge(size, maxSize):
            "Audio file too large: \(size) bytes (max: \(maxSize) bytes)"
        case .noTranscriptionService:
            "No transcription service configured. Please set OpenAI API key."
        case let .transcriptionFailed(reason):
            "Transcription failed: \(reason)"
        case .microphonePermissionDenied:
            "Microphone permission denied"
        case .platformNotSupported:
            "Audio input not supported on this platform"
        }
    }
}

// MARK: - Audio Configuration

/// Configuration for audio recording and transcription
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AudioConfiguration: Sendable {
    /// Sample rate for recording (defaults to 16kHz for optimal speech recognition)
    public let sampleRate: Double
    
    /// Number of audio channels (defaults to 1 for mono)
    public let channels: Int
    
    /// Audio quality setting
    public let quality: AudioQuality
    
    /// Maximum file size in bytes (defaults to 25MB)
    public let maxFileSize: Int64
    
    /// Supported file extensions for transcription
    public let supportedExtensions: [String]
    
    public enum AudioQuality: Int, Sendable {
        case low = 0
        case medium = 1
        case high = 2
    }
    
    public init(
        sampleRate: Double = 16000.0,
        channels: Int = 1,
        quality: AudioQuality = .high,
        maxFileSize: Int64 = 25 * 1024 * 1024,
        supportedExtensions: [String] = ["wav", "mp3", "m4a", "aiff", "aac", "flac"]
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.quality = quality
        self.maxFileSize = maxFileSize
        self.supportedExtensions = supportedExtensions
    }
    
    /// Default configuration optimized for speech recognition
    public static let speechRecognition = AudioConfiguration()
}