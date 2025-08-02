import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

#if os(iOS) || os(watchOS) || os(tvOS)
import AVFAudio
#endif

// AudioContent is available from MessageTypes.swift

// MARK: - Audio Input Service Implementation

/// Cross-platform audio input service implementation
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@MainActor
public final class AudioInputService: AudioInputServiceProtocol, @unchecked Sendable {
    private let configuration: AudioConfiguration
    private let apiKeyProvider: () -> String?
    
    #if canImport(AVFoundation)
    private var audioRecorder: AVAudioRecorder?
    #endif
    
    private var recordingURL: URL?
    
    public private(set) var isRecording = false
    
    public var isAvailable: Bool {
        #if canImport(AVFoundation)
        #if os(macOS)
        return true // Simplified for now - could check AVCaptureDevice
        #else
        guard let availableInputs = AVAudioSession.sharedInstance().availableInputs else {
            return false
        }
        return !availableInputs.isEmpty
        #endif
        #else
        return false
        #endif
    }
    
    /// Initialize audio input service
    /// - Parameters:
    ///   - configuration: Audio configuration settings
    ///   - apiKeyProvider: Closure that provides OpenAI API key for transcription
    public init(
        configuration: AudioConfiguration = .speechRecognition,
        apiKeyProvider: @escaping () -> String?
    ) {
        self.configuration = configuration
        self.apiKeyProvider = apiKeyProvider
    }
    
    public func startRecording() async throws {
        #if !canImport(AVFoundation)
        throw AudioInputError.platformNotSupported
        #else
        
        guard !self.isRecording else {
            throw AudioInputError.alreadyRecording
        }
        
        // Configure audio session (iOS/watchOS/tvOS only)
        #if os(iOS) || os(watchOS) || os(tvOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default)
        try audioSession.setActive(true)
        #endif
        
        // Create temporary file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "tachikoma_recording_\(UUID().uuidString).wav"
        recordingURL = tempDir.appendingPathComponent(fileName)
        
        guard let recordingURL else {
            throw AudioInputError.invalidURL
        }
        
        // Configure audio settings optimized for speech recognition
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: configuration.sampleRate,
            AVNumberOfChannelsKey: configuration.channels,
            AVEncoderAudioQualityKey: configuration.quality.rawValue,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
        ]
        
        // Create and start recorder
        self.audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
        self.audioRecorder?.prepareToRecord()
        self.audioRecorder?.record()
        self.isRecording = true
        
        #endif
    }
    
    public func stopRecording() async throws -> String {
        #if !canImport(AVFoundation)
        throw AudioInputError.platformNotSupported
        #else
        
        guard self.isRecording else {
            throw AudioInputError.notRecording
        }
        
        // Stop recording
        self.audioRecorder?.stop()
        self.isRecording = false
        
        // Deactivate audio session (iOS/watchOS/tvOS only)
        #if os(iOS) || os(watchOS) || os(tvOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setActive(false)
        #endif
        
        guard let recordingURL else {
            throw AudioInputError.invalidURL
        }
        
        // Transcribe the recorded audio
        let transcript = try await transcribeAudioFile(recordingURL)
        
        // Clean up temporary file
        try? FileManager.default.removeItem(at: recordingURL)
        self.recordingURL = nil
        
        return transcript
        
        #endif
    }
    
    public func transcribeAudioFile(_ url: URL) async throws -> String {
        // Validate file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioInputError.fileNotFound(url)
        }
        
        // Validate file type
        guard configuration.supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw AudioInputError.unsupportedFileType(url.pathExtension)
        }
        
        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        guard fileSize <= configuration.maxFileSize else {
            throw AudioInputError.fileTooLarge(fileSize, configuration.maxFileSize)
        }
        
        // Use OpenAI Whisper API for transcription
        let transcript = try await transcribeWithWhisper(url)
        
        return transcript
    }
    
    // MARK: - Private Methods
    
    private func transcribeWithWhisper(_ url: URL) async throws -> String {
        // Check if we have OpenAI API key
        guard let openAIKey = apiKeyProvider(), !openAIKey.isEmpty else {
            throw AudioInputError.noTranscriptionService
        }
        
        // Create multipart form data request
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart body
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Add file data
        let audioData = try Data(contentsOf: url)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(url.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add response format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw AudioInputError.transcriptionFailed("Invalid response from Whisper API")
        }
        
        // Parse response
        struct WhisperResponse: Codable {
            let text: String
        }
        
        let decoder = JSONDecoder()
        let whisperResponse = try decoder.decode(WhisperResponse.self, from: data)
        
        return whisperResponse.text
    }
}

// MARK: - Convenience Extensions

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension AudioInputService {
    /// Create an audio input service that gets API key from environment
    public static func withEnvironmentAPIKey(
        configuration: AudioConfiguration = .speechRecognition
    ) -> AudioInputService {
        return AudioInputService(configuration: configuration) {
            ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        }
    }
    
    /// Create an audio input service with a static API key
    public static func withAPIKey(
        _ apiKey: String,
        configuration: AudioConfiguration = .speechRecognition
    ) -> AudioInputService {
        return AudioInputService(configuration: configuration) {
            apiKey
        }
    }
}