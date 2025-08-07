//
//  AudioRecorder.swift
//  TachikomaAudio
//

import Foundation
import AVFoundation
import os.log
import Tachikoma  // For TachikomaError

/// Protocol for audio recording functionality
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@MainActor
public protocol AudioRecorderProtocol: Sendable {
    var isRecording: Bool { get }
    var isAvailable: Bool { get }
    var recordingDuration: TimeInterval { get }

    func startRecording() async throws
    func stopRecording() async throws -> AudioData
    func cancelRecording() async
    func pauseRecording() async
    func resumeRecording() async
}

private let logger = Logger(subsystem: "com.tachikoma.audio", category: "AudioRecorder")

/// Main audio recorder implementation using AVFoundation
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@MainActor
public final class AudioRecorder: ObservableObject, AudioRecorderProtocol {

    // MARK: - Properties

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?

    @Published public private(set) var isRecording = false
    @Published public private(set) var recordingDuration: TimeInterval = 0
    @Published public private(set) var isPaused = false

    private var recordingStartTime: Date?
    private var recordingTimer: Timer?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?

    // Audio format settings
    private let sampleRate: Double = 44100
    private let channels: AVAudioChannelCount = 1
    private let bitDepth: Int = 16

    // Maximum recording duration (5 minutes by default)
    public var maxRecordingDuration: TimeInterval = 300

    // MARK: - Initialization

    public init() {
        // Initialize with default settings
    }

    // MARK: - Public Properties

    /// Check if audio recording is available
    public var isAvailable: Bool {
        #if os(macOS)
        return AVCaptureDevice.authorizationStatus(for: .audio) != .denied
        #elseif os(iOS) || os(tvOS) || os(watchOS)
        return AVAudioSession.sharedInstance().recordPermission != .denied
        #else
        return true
        #endif
    }

    // MARK: - Recording Methods

    /// Start recording audio from the microphone
    public func startRecording() async throws {
        guard !isRecording else {
            throw AudioRecordingError.alreadyRecording
        }

        // Check microphone permission
        let authorized = await checkMicrophonePermission()
        guard authorized else {
            throw AudioRecordingError.microphonePermissionDenied
        }

        // Configure audio session only after permission is granted
        configureAudioSession()

        // Create temporary file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_\(Date().timeIntervalSince1970).wav"
        recordingURL = tempDir.appendingPathComponent(fileName)

        guard let url = recordingURL else {
            throw AudioRecordingError.failedToCreateFile
        }

        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioRecordingError.audioEngineError("Failed to create audio engine")
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Create audio file
        audioFile = try AVAudioFile(forWriting: url, settings: recordingFormat.settings)

        // Install tap on a background queue to avoid inheriting any actor/queue context
        guard let audioFile = audioFile else {
            throw AudioRecordingError.failedToCreateFile
        }

        DispatchQueue.global(qos: .userInitiated).sync {
            installInputTapNonisolated(inputNode: inputNode, format: recordingFormat, audioFile: audioFile)
        }

        // Start the audio engine
        try audioEngine.start()

        // Update state
        isRecording = true
        isPaused = false
        recordingStartTime = Date()
        pausedDuration = 0

        // Start duration timer
        startDurationTimer()

        logger.info("Started audio recording")
    }

    /// Stop recording and return the recorded audio
    public func stopRecording() async throws -> AudioData {
        guard isRecording else {
            throw AudioRecordingError.notRecording
        }

        // Stop the audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        // Close the audio file
        audioFile = nil

        // Stop the timer
        stopDurationTimer()

        // Update state
        isRecording = false
        isPaused = false
        recordingDuration = 0
        recordingStartTime = nil
        pausedDuration = 0

        logger.info("Stopped audio recording")

        // Read the recorded audio
        guard let url = recordingURL else {
            throw AudioRecordingError.noRecordingAvailable
        }

        defer {
            // Clean up the temporary file
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }

        let audioData = try AudioData(contentsOf: url)
        return audioData
    }

    /// Cancel recording without returning data
    public func cancelRecording() async {
        guard isRecording else { return }

        // Stop the audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        // Close the audio file
        audioFile = nil

        // Stop the timer
        stopDurationTimer()

        // Update state
        isRecording = false
        isPaused = false
        recordingDuration = 0
        recordingStartTime = nil
        pausedDuration = 0

        // Clean up the temporary file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }

        logger.info("Cancelled audio recording")
    }

    /// Pause the current recording
    public func pauseRecording() async {
        guard isRecording && !isPaused else { return }

        audioEngine?.pause()
        isPaused = true
        pauseStartTime = Date()

        logger.info("Paused audio recording")
    }

    /// Resume a paused recording
    public func resumeRecording() async {
        guard isRecording && isPaused else { return }

        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }

        do {
            try audioEngine?.start()
            isPaused = false
            pauseStartTime = nil

            logger.info("Resumed audio recording")
        } catch {
            logger.error("Failed to resume recording: \(error)")
        }
    }

    // MARK: - Private Methods

    private func checkMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            #if os(macOS)
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                continuation.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            case .denied, .restricted:
                continuation.resume(returning: false)
            @unknown default:
                continuation.resume(returning: false)
            }
            #elseif os(iOS) || os(tvOS) || os(watchOS)
            let session = AVAudioSession.sharedInstance()
            switch session.recordPermission {
            case .granted:
                continuation.resume(returning: true)
            case .denied:
                continuation.resume(returning: false)
            case .undetermined:
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            @unknown default:
                continuation.resume(returning: false)
            }
            #else
            continuation.resume(returning: true)
            #endif
        }
    }

    private func startDurationTimer() {
        stopDurationTimer()

        let startTime = recordingStartTime
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = startTime else { return }

            Task { @MainActor in
                let elapsed = Date().timeIntervalSince(startTime) - self.pausedDuration
                self.recordingDuration = elapsed

                // Check max duration
                if elapsed >= self.maxRecordingDuration {
                    logger.warning("Max recording duration reached")
                    _ = try? await self.stopRecording()
                }
            }
        }
    }

    private func stopDurationTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

// MARK: - Realtime helper (free function, not MainActor-isolated)

private func installInputTapNonisolated(inputNode: AVAudioInputNode,
                                       format: AVAudioFormat,
                                       audioFile: AVAudioFile) {
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        do {
            try audioFile.write(from: buffer)
        } catch {
            logger.error("Failed to write audio buffer: \(error)")        }
    }
}

// MARK: - Recording Errors

/// Error types for audio recording operations
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum AudioRecordingError: LocalizedError {
    case alreadyRecording
    case notRecording
    case microphonePermissionDenied
    case audioEngineError(String)
    case failedToCreateFile
    case noRecordingAvailable
    case recordingTooShort
    case recordingTooLong

    public var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Already recording audio"
        case .notRecording:
            return "Not currently recording"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        case .audioEngineError(let message):
            return "Audio engine error: \(message)"
        case .failedToCreateFile:
            return "Failed to create recording file"
        case .noRecordingAvailable:
            return "No recording available"
        case .recordingTooShort:
            return "Recording is too short"
        case .recordingTooLong:
            return "Recording exceeded maximum duration"
        }
    }
}

// MARK: - Platform-Specific Extensions

#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit

@available(iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension AudioRecorder {
    /// Configure audio session for iOS/watchOS/tvOS
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}
#endif

#if os(macOS)
@available(macOS 13.0, *)
extension AudioRecorder {
    /// No-op on macOS where `AVAudioSession` is not used
    private func configureAudioSession() { }
}
#endif
