#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import Foundation
import Tachikoma

// MARK: - Audio Stream Pipeline

/// Pipeline for processing audio streams in real-time
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@MainActor
public final class AudioStreamPipeline {
    // MARK: - Properties

    /// Audio manager for capture and playback
    private let audioManager: RealtimeAudioManager

    /// Audio processor for format conversion
    private let processor: RealtimeAudioProcessor

    /// Voice activity detector
    private let voiceDetector: VoiceActivityDetector

    /// Stream buffer for input
    private let inputBuffer: AudioStreamBuffer

    /// Stream buffer for output
    private let outputBuffer: AudioStreamBuffer

    /// Current pipeline state
    public private(set) var isActive = false

    /// Pipeline configuration
    public let configuration: PipelineConfiguration

    /// Delegate for pipeline events
    public weak var delegate: AudioStreamPipelineDelegate?

    // Processing tasks
    private var inputProcessingTask: Task<Void, Never>?
    private var outputProcessingTask: Task<Void, Never>?

    // MARK: - Configuration

    public struct PipelineConfiguration {
        public var inputChunkSize: Int = 4096
        public var outputChunkSize: Int = 4096
        public var maxBufferSize: Int = 65536
        public var voiceThreshold: Float = 0.01
        public var silenceDuration: TimeInterval = 0.5
        public var enableVAD: Bool = true
        public var enableEchoCancellation: Bool = true
        public var enableNoiseSupression: Bool = true

        public init() {}
    }

    // MARK: - Initialization

    public init(configuration: PipelineConfiguration = PipelineConfiguration()) throws {
        self.configuration = configuration
        self.audioManager = RealtimeAudioManager()
        self.processor = try RealtimeAudioProcessor()
        self.voiceDetector = VoiceActivityDetector(
            energyThreshold: configuration.voiceThreshold,
            silenceDuration: configuration.silenceDuration,
        )
        self.inputBuffer = AudioStreamBuffer(
            chunkSize: configuration.inputChunkSize,
            maxBufferSize: configuration.maxBufferSize,
        )
        self.outputBuffer = AudioStreamBuffer(
            chunkSize: configuration.outputChunkSize,
            maxBufferSize: configuration.maxBufferSize,
        )

        self.setupAudioManager()
    }

    // MARK: - Setup

    private func setupAudioManager() {
        // Configure for voice chat
        self.audioManager.configureForVoiceChat()

        // Enable processing features
        if self.configuration.enableEchoCancellation {
            self.audioManager.setEchoCancellation(true)
        }

        if self.configuration.enableNoiseSupression {
            self.audioManager.setVoiceProcessing(true)
        }

        // Set up callbacks
        self.audioManager.onAudioCaptured = { [weak self] data in
            await self?.handleCapturedAudio(data)
        }

        self.audioManager.onAudioLevelUpdate = { [weak self] level in
            self?.delegate?.audioStreamPipeline(didUpdateInputLevel: level)
        }
    }

    // MARK: - Lifecycle

    /// Start the audio pipeline
    public func start() async throws {
        // Start the audio pipeline
        guard !self.isActive else { return }

        // Start audio capture
        try await self.audioManager.startRecording()

        // Start processing tasks
        self.startInputProcessing()
        self.startOutputProcessing()

        self.isActive = true
        await self.delegate?.audioStreamPipelineDidStart()
    }

    /// Stop the audio pipeline
    public func stop() async {
        // Stop the audio pipeline
        guard self.isActive else { return }

        // Cancel processing tasks
        self.inputProcessingTask?.cancel()
        self.outputProcessingTask?.cancel()

        // Stop audio
        self.audioManager.stopRecording()
        self.audioManager.stopPlayback()

        // Clear buffers
        self.inputBuffer.clear()
        self.outputBuffer.clear()

        self.isActive = false
        await self.delegate?.audioStreamPipelineDidStop()
    }

    // MARK: - Audio Input

    /// Send audio data to the pipeline
    public func sendAudio(_ data: Data) {
        // Send audio data to the pipeline
        self.outputBuffer.append(data)
    }

    /// Get processed audio data
    public func getProcessedAudio() -> Data? {
        // Get processed audio data
        self.inputBuffer.nextChunk()
    }

    // MARK: - Processing

    private func handleCapturedAudio(_ data: Data) async {
        // Voice activity detection
        if self.configuration.enableVAD {
            let (hasVoice, isSpeaking) = self.voiceDetector.processAudio(data)

            if hasVoice {
                await self.delegate?.audioStreamPipeline(didDetectVoice: true)
            } else if !isSpeaking {
                await self.delegate?.audioStreamPipeline(didDetectVoice: false)
            }

            // Only process if voice detected or still speaking
            guard hasVoice || isSpeaking else { return }
        }

        // Add to input buffer
        self.inputBuffer.append(data)

        // Notify delegate
        await self.delegate?.audioStreamPipeline(didCaptureAudio: data)
    }

    private func startInputProcessing() {
        self.inputProcessingTask = Task {
            while !Task.isCancelled {
                // Process input chunks
                if let chunk = inputBuffer.nextChunk() {
                    await self.processInputChunk(chunk)
                }

                // Small delay to prevent busy waiting
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }

    private func startOutputProcessing() {
        self.outputProcessingTask = Task {
            while !Task.isCancelled {
                // Process output chunks
                if let chunk = outputBuffer.nextChunk() {
                    await self.processOutputChunk(chunk)
                }

                // Small delay to prevent busy waiting
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }

    private func processInputChunk(_ chunk: Data) async {
        // Additional processing if needed
        // For now, just notify delegate
        await self.delegate?.audioStreamPipeline(didProcessInput: chunk)
    }

    private func processOutputChunk(_ chunk: Data) async {
        // Play the audio
        do {
            try await self.audioManager.playAudio(chunk)
            await self.delegate?.audioStreamPipeline(didProcessOutput: chunk)
        } catch {
            await self.delegate?.audioStreamPipeline(didEncounterError: error)
        }
    }

    // MARK: - Utilities

    /// Reset voice activity detection
    public func resetVAD() {
        // Reset voice activity detection
        self.voiceDetector.reset()
    }

    /// Flush all buffers
    public func flush() -> (input: Data, output: Data) {
        // Flush all buffers
        let inputData = self.inputBuffer.flush()
        let outputData = self.outputBuffer.flush()
        return (inputData, outputData)
    }

    /// Get current buffer sizes
    public var bufferSizes: (input: Int, output: Int) {
        (self.inputBuffer.count, self.outputBuffer.count)
    }
}

// MARK: - Pipeline Delegate

/// Delegate protocol for audio stream pipeline events
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@MainActor
public protocol AudioStreamPipelineDelegate: AnyObject {
    /// Pipeline started
    func audioStreamPipelineDidStart() async

    /// Pipeline stopped
    func audioStreamPipelineDidStop() async

    /// Audio captured
    func audioStreamPipeline(didCaptureAudio data: Data) async

    /// Input processed
    func audioStreamPipeline(didProcessInput data: Data) async

    /// Output processed
    func audioStreamPipeline(didProcessOutput data: Data) async

    /// Voice activity detected
    func audioStreamPipeline(didDetectVoice: Bool) async

    /// Input level updated
    func audioStreamPipeline(didUpdateInputLevel level: Float)

    /// Error occurred
    func audioStreamPipeline(didEncounterError error: Error) async
}

// Default implementation for optional methods
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension AudioStreamPipelineDelegate {
    // Pipeline started
    public func audioStreamPipelineDidStart() async {}
    public func audioStreamPipelineDidStop() async {}
    public func audioStreamPipeline(didCaptureAudio _: Data) async {}
    public func audioStreamPipeline(didProcessInput _: Data) async {}
    public func audioStreamPipeline(didProcessOutput _: Data) async {}
    public func audioStreamPipeline(didDetectVoice _: Bool) async {}
    public func audioStreamPipeline(didUpdateInputLevel _: Float) {}
    public func audioStreamPipeline(didEncounterError _: Error) async {}
}

// MARK: - Integration with Realtime Conversation

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension RealtimeConversation {
    /// Create and configure audio pipeline
    public func setupAudioPipeline() async throws -> AudioStreamPipeline {
        // Create and configure audio pipeline
        let pipeline = try AudioStreamPipeline()

        // Create delegate adapter
        let adapter = AudioPipelineAdapter(conversation: self)
        pipeline.delegate = adapter

        // Start pipeline
        try await pipeline.start()

        return pipeline
    }
}

/// Adapter to connect pipeline to conversation
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@MainActor
private final class AudioPipelineAdapter: AudioStreamPipelineDelegate {
    weak var conversation: RealtimeConversation?

    init(conversation: RealtimeConversation) {
        self.conversation = conversation
    }

    func audioStreamPipeline(didCaptureAudio data: Data) async {
        // Send audio to conversation
        try? await self.conversation?.sendAudio(data)
    }

    func audioStreamPipeline(didDetectVoice hasVoice: Bool) async {
        // Handle voice detection
        if hasVoice {
            try? await self.conversation?.startListening()
        } else {
            await self.conversation?.stopListening()
        }
    }

    func audioStreamPipeline(didUpdateInputLevel _: Float) {
        // Forward to conversation's audio level updates
        // This would be connected to the audioLevelContinuation
    }
}

#endif // canImport(AVFoundation)
