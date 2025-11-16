#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import Foundation
import Tachikoma

// MARK: - Audio Format Utilities

/// Audio format specifications for the Realtime API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct RealtimeAudioFormats {
    /// Default sample rate for Realtime API (24kHz)
    public static let apiSampleRate: Double = 24000

    /// Default device sample rate (48kHz)
    public static let deviceSampleRate: Double = 48000

    /// Default number of channels (mono)
    public static let channelCount: AVAudioChannelCount = 1

    /// Default buffer size in frames
    public static let bufferSize: AVAudioFrameCount = 1024

    /// Create PCM16 format for API
    public static func pcm16Format(sampleRate: Double = apiSampleRate) -> AVAudioFormat {
        // Create PCM16 format for API
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: self.channelCount,
            interleaved: true,
        )!
    }

    /// Create float format for device
    public static func floatFormat(sampleRate: Double = deviceSampleRate) -> AVAudioFormat {
        // Create float format for device
        AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: self.channelCount,
        )!
    }

    /// Create format for G.711 µ-law
    public static func g711UlawFormat() -> AVAudioFormat {
        // Create format for G.711 µ-law
        AVAudioFormat(
            commonFormat: .pcmFormatInt16, // Will be converted
            sampleRate: self.apiSampleRate,
            channels: self.channelCount,
            interleaved: true,
        )!
    }

    /// Create format for G.711 A-law
    public static func g711AlawFormat() -> AVAudioFormat {
        // Create format for G.711 A-law
        AVAudioFormat(
            commonFormat: .pcmFormatInt16, // Will be converted
            sampleRate: self.apiSampleRate,
            channels: self.channelCount,
            interleaved: true,
        )!
    }
}

// MARK: - Audio Buffer Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension AVAudioPCMBuffer {
    /// Convert buffer to base64 encoded string
    public func toBase64() -> String {
        // Convert buffer to base64 encoded string
        let audioBuffer = audioBufferList.pointee.mBuffers
        let data = Data(
            bytes: audioBuffer.mData!,
            count: Int(audioBuffer.mDataByteSize),
        )
        return data.base64EncodedString()
    }

    /// Create buffer from base64 encoded string
    public static func from(base64: String, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        // Create buffer from base64 encoded string
        guard let data = Data(base64Encoded: base64) else { return nil }

        let frameCount = AVAudioFrameCount(data.count / Int(format.streamDescription.pointee.mBytesPerFrame))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount

        // Copy data to buffer
        data.withUnsafeBytes { bytes in
            if
                format.commonFormat == .pcmFormatInt16,
                let audioBuffer = buffer.int16ChannelData?[0]
            {
                bytes.copyBytes(to: UnsafeMutableBufferPointer(
                    start: audioBuffer,
                    count: Int(frameCount),
                ))
            } else if
                format.commonFormat == .pcmFormatFloat32,
                let audioBuffer = buffer.floatChannelData?[0]
            {
                bytes.copyBytes(to: UnsafeMutableBufferPointer(
                    start: audioBuffer,
                    count: Int(frameCount),
                ))
            }
        }

        return buffer
    }

    /// Calculate RMS level
    public func rmsLevel() -> Float {
        // Calculate RMS level
        guard let channelData = floatChannelData?[0] else {
            // Try int16 data
            if let int16Data = int16ChannelData?[0] {
                return self.calculateRMSFromInt16(int16Data, frameLength: frameLength)
            }
            return 0
        }

        let frameLength = Int(frameLength)
        var sum: Float = 0

        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        return min(1.0, rms * 2) // Normalize and clamp
    }

    private func calculateRMSFromInt16(_ data: UnsafePointer<Int16>, frameLength: AVAudioFrameCount) -> Float {
        var sum: Float = 0

        for i in 0..<Int(frameLength) {
            let normalized = Float(data[i]) / Float(Int16.max)
            sum += normalized * normalized
        }

        let rms = sqrt(sum / Float(frameLength))
        return min(1.0, rms * 2)
    }
}

// MARK: - Audio Data Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension Data {
    /// Convert PCM16 data to float samples
    public func pcm16ToFloat() -> [Float] {
        // Convert PCM16 data to float samples
        withUnsafeBytes { bytes in
            let samples = bytes.bindMemory(to: Int16.self)
            return samples.map { Float($0) / Float(Int16.max) }
        }
    }

    /// Convert float samples to PCM16 data
    public static func fromFloatSamples(_ samples: [Float]) -> Data {
        // Convert float samples to PCM16 data
        var data = Data(capacity: samples.count * 2)

        for sample in samples {
            let clamped = Swift.max(-1.0, Swift.min(1.0, sample))
            let int16Value = Int16(clamped * Float(Int16.max))
            Swift.withUnsafeBytes(of: int16Value) { bytes in
                data.append(contentsOf: bytes)
            }
        }

        return data
    }

    /// Calculate audio energy
    public func audioEnergy() -> Float {
        // Calculate audio energy
        let samples = withUnsafeBytes { bytes in
            bytes.bindMemory(to: Int16.self)
        }

        var sum: Float = 0
        for sample in samples {
            let normalized = Float(sample) / Float(Int16.max)
            sum += normalized * normalized
        }

        let energy = sqrt(sum / Float(samples.count))
        return Swift.min(1.0, energy)
    }

    /// Detect voice activity
    public func detectVoiceActivity(threshold: Float = 0.01) -> Bool {
        // Detect voice activity
        self.audioEnergy() > threshold
    }
}

// MARK: - Audio Stream Buffer

/// Buffer for streaming audio data
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class AudioStreamBuffer: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()
    private let chunkSize: Int
    private let maxBufferSize: Int

    public init(chunkSize: Int = 4096, maxBufferSize: Int = 65536) {
        self.chunkSize = chunkSize
        self.maxBufferSize = maxBufferSize
    }

    /// Append audio data
    public func append(_ data: Data) {
        // Append audio data
        self.lock.lock()
        defer { lock.unlock() }

        self.buffer.append(data)

        // Trim if exceeds max size
        if self.buffer.count > self.maxBufferSize {
            let excess = self.buffer.count - self.maxBufferSize
            self.buffer.removeFirst(excess)
        }
    }

    /// Get next chunk if available
    public func nextChunk() -> Data? {
        // Get next chunk if available
        self.lock.lock()
        defer { lock.unlock() }

        guard self.buffer.count >= self.chunkSize else { return nil }

        let chunk = self.buffer.prefix(self.chunkSize)
        self.buffer.removeFirst(self.chunkSize)
        return Data(chunk)
    }

    /// Get all available data
    public func flush() -> Data {
        // Get all available data
        self.lock.lock()
        defer { lock.unlock() }

        let data = self.buffer
        self.buffer = Data()
        return data
    }

    /// Current buffer size
    public var count: Int {
        self.lock.lock()
        defer { lock.unlock() }
        return self.buffer.count
    }

    /// Clear the buffer
    public func clear() {
        // Clear the buffer
        self.lock.lock()
        defer { lock.unlock() }
        self.buffer = Data()
    }
}

// MARK: - Voice Activity Detection

/// Simple voice activity detector
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class VoiceActivityDetector: @unchecked Sendable {
    private let energyThreshold: Float
    private let silenceDuration: TimeInterval
    private var lastVoiceTime: Date?
    private let lock = NSLock()

    public init(energyThreshold: Float = 0.01, silenceDuration: TimeInterval = 0.5) {
        self.energyThreshold = energyThreshold
        self.silenceDuration = silenceDuration
    }

    /// Process audio data and detect voice activity
    public func processAudio(_ data: Data) -> (hasVoice: Bool, isSpeaking: Bool) {
        // Process audio data and detect voice activity
        let energy = data.audioEnergy()
        let hasVoice = energy > self.energyThreshold

        self.lock.lock()
        defer { lock.unlock() }

        if hasVoice {
            self.lastVoiceTime = Date()
            return (true, true)
        } else if let lastTime = lastVoiceTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            let stillSpeaking = elapsed < self.silenceDuration
            return (false, stillSpeaking)
        } else {
            return (false, false)
        }
    }

    /// Reset the detector
    public func reset() {
        // Reset the detector
        self.lock.lock()
        defer { lock.unlock() }
        self.lastVoiceTime = nil
    }
}

#endif // canImport(AVFoundation)
