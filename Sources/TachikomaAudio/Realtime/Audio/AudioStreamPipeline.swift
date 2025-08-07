//
//  AudioStreamPipeline.swift
//  Tachikoma
//

#if canImport(AVFoundation)
import Foundation
import Tachikoma
@preconcurrency import AVFoundation

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
            silenceDuration: configuration.silenceDuration
        )
        self.inputBuffer = AudioStreamBuffer(
            chunkSize: configuration.inputChunkSize,
            maxBufferSize: configuration.maxBufferSize
        )
        self.outputBuffer = AudioStreamBuffer(
            chunkSize: configuration.outputChunkSize,
            maxBufferSize: configuration.maxBufferSize
        )
        
        setupAudioManager()
    }
    
    // MARK: - Setup
    
    private func setupAudioManager() {
        // Configure for voice chat
        audioManager.configureForVoiceChat()
        
        // Enable processing features
        if configuration.enableEchoCancellation {
            audioManager.setEchoCancellation(true)
        }
        
        if configuration.enableNoiseSupression {
            audioManager.setVoiceProcessing(true)
        }
        
        // Set up callbacks
        audioManager.onAudioCaptured = { [weak self] data in
            await self?.handleCapturedAudio(data)
        }
        
        audioManager.onAudioLevelUpdate = { [weak self] level in
            self?.delegate?.audioStreamPipeline(didUpdateInputLevel: level)
        }
    }
    
    // MARK: - Lifecycle
    
    /// Start the audio pipeline
    public func start() async throws {
        guard !isActive else { return }
        
        // Start audio capture
        try await audioManager.startRecording()
        
        // Start processing tasks
        startInputProcessing()
        startOutputProcessing()
        
        isActive = true
        await delegate?.audioStreamPipelineDidStart()
    }
    
    /// Stop the audio pipeline
    public func stop() async {
        guard isActive else { return }
        
        // Cancel processing tasks
        inputProcessingTask?.cancel()
        outputProcessingTask?.cancel()
        
        // Stop audio
        audioManager.stopRecording()
        audioManager.stopPlayback()
        
        // Clear buffers
        inputBuffer.clear()
        outputBuffer.clear()
        
        isActive = false
        await delegate?.audioStreamPipelineDidStop()
    }
    
    // MARK: - Audio Input
    
    /// Send audio data to the pipeline
    public func sendAudio(_ data: Data) {
        outputBuffer.append(data)
    }
    
    /// Get processed audio data
    public func getProcessedAudio() -> Data? {
        inputBuffer.nextChunk()
    }
    
    // MARK: - Processing
    
    private func handleCapturedAudio(_ data: Data) async {
        // Voice activity detection
        if configuration.enableVAD {
            let (hasVoice, isSpeaking) = voiceDetector.processAudio(data)
            
            if hasVoice {
                await delegate?.audioStreamPipeline(didDetectVoice: true)
            } else if !isSpeaking {
                await delegate?.audioStreamPipeline(didDetectVoice: false)
            }
            
            // Only process if voice detected or still speaking
            guard hasVoice || isSpeaking else { return }
        }
        
        // Add to input buffer
        inputBuffer.append(data)
        
        // Notify delegate
        await delegate?.audioStreamPipeline(didCaptureAudio: data)
    }
    
    private func startInputProcessing() {
        inputProcessingTask = Task {
            while !Task.isCancelled {
                // Process input chunks
                if let chunk = inputBuffer.nextChunk() {
                    await processInputChunk(chunk)
                }
                
                // Small delay to prevent busy waiting
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }
    
    private func startOutputProcessing() {
        outputProcessingTask = Task {
            while !Task.isCancelled {
                // Process output chunks
                if let chunk = outputBuffer.nextChunk() {
                    await processOutputChunk(chunk)
                }
                
                // Small delay to prevent busy waiting
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }
    
    private func processInputChunk(_ chunk: Data) async {
        // Additional processing if needed
        // For now, just notify delegate
        await delegate?.audioStreamPipeline(didProcessInput: chunk)
    }
    
    private func processOutputChunk(_ chunk: Data) async {
        // Play the audio
        do {
            try await audioManager.playAudio(chunk)
            await delegate?.audioStreamPipeline(didProcessOutput: chunk)
        } catch {
            await delegate?.audioStreamPipeline(didEncounterError: error)
        }
    }
    
    // MARK: - Utilities
    
    /// Reset voice activity detection
    public func resetVAD() {
        voiceDetector.reset()
    }
    
    /// Flush all buffers
    public func flush() -> (input: Data, output: Data) {
        let inputData = inputBuffer.flush()
        let outputData = outputBuffer.flush()
        return (inputData, outputData)
    }
    
    /// Get current buffer sizes
    public var bufferSizes: (input: Int, output: Int) {
        (inputBuffer.count, outputBuffer.count)
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
public extension AudioStreamPipelineDelegate {
    func audioStreamPipelineDidStart() async {}
    func audioStreamPipelineDidStop() async {}
    func audioStreamPipeline(didCaptureAudio data: Data) async {}
    func audioStreamPipeline(didProcessInput data: Data) async {}
    func audioStreamPipeline(didProcessOutput data: Data) async {}
    func audioStreamPipeline(didDetectVoice: Bool) async {}
    func audioStreamPipeline(didUpdateInputLevel level: Float) {}
    func audioStreamPipeline(didEncounterError error: Error) async {}
}

// MARK: - Integration with Realtime Conversation

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension RealtimeConversation {
    /// Create and configure audio pipeline
    public func setupAudioPipeline() async throws -> AudioStreamPipeline {
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
        try? await conversation?.sendAudio(data)
    }
    
    func audioStreamPipeline(didDetectVoice hasVoice: Bool) async {
        // Handle voice detection
        if hasVoice {
            try? await conversation?.startListening()
        } else {
            await conversation?.stopListening()
        }
    }
    
    func audioStreamPipeline(didUpdateInputLevel level: Float) {
        // Forward to conversation's audio level updates
        // This would be connected to the audioLevelContinuation
    }
}

#endif // canImport(AVFoundation)
