#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import Foundation
import Tachikoma

// MARK: - Audio Processor

/// Handles audio format conversion and processing for the Realtime API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class RealtimeAudioProcessor: @unchecked Sendable {
    // MARK: - Properties

    /// Input format from device (typically 48kHz)
    private let inputFormat: AVAudioFormat

    /// Output format for API (24kHz PCM16)
    private let outputFormat: AVAudioFormat

    /// Audio converter for format conversion
    private var converter: AVAudioConverter?

    /// Lock for thread safety
    private let lock = NSLock()

    // Audio processing settings
    private let targetSampleRate: Double = 24000 // Realtime API expects 24kHz
    private let targetChannels: AVAudioChannelCount = 1 // Mono

    // MARK: - Initialization

    public init() throws {
        // Set up input format (device default, usually 48kHz)
        guard
            let inputFormat = AVAudioFormat(
                standardFormatWithSampleRate: 48000,
                channels: 1,
            ) else
        {
            throw TachikomaError.invalidConfiguration("Failed to create input audio format")
        }
        self.inputFormat = inputFormat

        // Set up output format (24kHz PCM16 for Realtime API)
        guard
            let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: targetSampleRate,
                channels: targetChannels,
                interleaved: true,
            ) else
        {
            throw TachikomaError.invalidConfiguration("Failed to create output audio format")
        }
        self.outputFormat = outputFormat

        // Create converter
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw TachikomaError.invalidConfiguration("Failed to create audio converter")
        }
        self.converter = converter
    }

    // MARK: - Audio Processing

    /// Process input audio buffer to API format
    public func processInput(_ buffer: AVAudioPCMBuffer) throws -> Data {
        // Process input audio buffer to API format
        self.lock.lock()
        defer { lock.unlock() }

        guard let converter else {
            throw TachikomaError.invalidConfiguration("Audio converter not initialized")
        }

        // Calculate output buffer size
        let outputFrameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * (self.outputFormat.sampleRate / self.inputFormat.sampleRate),
        )

        guard
            let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: outputFrameCapacity,
            ) else
        {
            throw TachikomaError.invalidConfiguration("Failed to create output buffer")
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error {
            throw TachikomaError.audioProcessingFailed("Conversion failed: \(error)")
        }

        guard status == .haveData else {
            throw TachikomaError.audioProcessingFailed("Conversion status: \(status)")
        }

        // Convert PCM buffer to Data
        return self.bufferToData(outputBuffer)
    }

    /// Process output audio data from API to playback format
    public func processOutput(_ data: Data) throws -> AVAudioPCMBuffer {
        // Process output audio data from API to playback format
        self.lock.lock()
        defer { lock.unlock() }

        // Create buffer from data
        let frameCount = AVAudioFrameCount(data.count / 2) // 16-bit = 2 bytes per sample

        guard
            let buffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: frameCount,
            ) else
        {
            throw TachikomaError.invalidConfiguration("Failed to create audio buffer")
        }

        buffer.frameLength = frameCount

        // Copy data to buffer
        data.withUnsafeBytes { bytes in
            if let audioBuffer = buffer.int16ChannelData?[0] {
                bytes.copyBytes(to: UnsafeMutableBufferPointer(
                    start: audioBuffer,
                    count: Int(frameCount),
                ))
            }
        }

        return buffer
    }

    /// Convert audio data between formats
    public func convert(
        data: Data,
        from sourceFormat: RealtimeAudioFormat,
        to targetFormat: RealtimeAudioFormat,
    ) throws
        -> Data
    {
        // Convert audio data between formats
        guard sourceFormat != targetFormat else {
            return data // No conversion needed
        }

        // Handle different format conversions
        switch (sourceFormat, targetFormat) {
        case (.pcm16, .g711Ulaw):
            return try self.pcm16ToG711Ulaw(data)
        case (.g711Ulaw, .pcm16):
            return try self.g711UlawToPCM16(data)
        case (.pcm16, .g711Alaw):
            return try self.pcm16ToG711Alaw(data)
        case (.g711Alaw, .pcm16):
            return try self.g711AlawToPCM16(data)
        default:
            throw TachikomaError
                .unsupportedOperation("Conversion from \(sourceFormat) to \(targetFormat) not supported")
        }
    }

    // MARK: - Audio Analysis

    /// Calculate RMS (Root Mean Square) level for audio buffer
    public func calculateRMS(_ buffer: AVAudioPCMBuffer) -> Float {
        // Calculate RMS (Root Mean Square) level for audio buffer
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }

        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0

        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        return min(1.0, rms * 2) // Normalize and clamp to 0-1
    }

    /// Detect silence in audio buffer
    public func detectSilence(_ buffer: AVAudioPCMBuffer, threshold: Float = 0.01) -> Bool {
        // Detect silence in audio buffer
        self.calculateRMS(buffer) < threshold
    }

    /// Calculate audio energy for voice activity detection
    public func calculateEnergy(_ data: Data) -> Float {
        // Calculate audio energy for voice activity detection
        let samples = data.withUnsafeBytes { bytes in
            bytes.bindMemory(to: Int16.self)
        }

        var sum: Float = 0
        for sample in samples {
            let normalized = Float(sample) / Float(Int16.max)
            sum += normalized * normalized
        }

        let energy = sqrt(sum / Float(samples.count))
        return min(1.0, energy)
    }

    // MARK: - Private Methods

    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        return Data(
            bytes: audioBuffer.mData!,
            count: Int(audioBuffer.mDataByteSize),
        )
    }

    // MARK: - Format Conversion Methods

    private func pcm16ToG711Ulaw(_ data: Data) throws -> Data {
        // G.711 µ-law encoding
        var output = Data(capacity: data.count / 2)

        data.withUnsafeBytes { bytes in
            let samples = bytes.bindMemory(to: Int16.self)

            for sample in samples {
                let encoded = self.encodeUlaw(sample)
                output.append(encoded)
            }
        }

        return output
    }

    private func g711UlawToPCM16(_ data: Data) throws -> Data {
        // G.711 µ-law decoding
        var output = Data(capacity: data.count * 2)

        for byte in data {
            let decoded = self.decodeUlaw(byte)
            withUnsafeBytes(of: decoded) { bytes in
                output.append(contentsOf: bytes)
            }
        }

        return output
    }

    private func pcm16ToG711Alaw(_ data: Data) throws -> Data {
        // G.711 A-law encoding
        var output = Data(capacity: data.count / 2)

        data.withUnsafeBytes { bytes in
            let samples = bytes.bindMemory(to: Int16.self)

            for sample in samples {
                let encoded = self.encodeAlaw(sample)
                output.append(encoded)
            }
        }

        return output
    }

    private func g711AlawToPCM16(_ data: Data) throws -> Data {
        // G.711 A-law decoding
        var output = Data(capacity: data.count * 2)

        for byte in data {
            let decoded = self.decodeAlaw(byte)
            withUnsafeBytes(of: decoded) { bytes in
                output.append(contentsOf: bytes)
            }
        }

        return output
    }

    // MARK: - G.711 Encoding/Decoding

    private func encodeUlaw(_ sample: Int16) -> UInt8 {
        // Simplified µ-law encoding
        let BIAS: Int16 = 0x84
        let CLIP: Int16 = 32635

        var s = max(-CLIP, min(sample, CLIP))
        let sign: UInt8 = s < 0 ? 0x80 : 0x00
        if s < 0 { s = -s }

        s += BIAS

        var exponent: UInt8 = 7
        var expMask: Int16 = 0x4000

        while exponent > 0, (s & expMask) == 0 {
            exponent -= 1
            expMask >>= 1
        }

        let mantissa = UInt8((s >> (exponent + 3)) & 0x0F)
        let encoded = ~(sign | (exponent << 4) | mantissa)

        return encoded
    }

    private func decodeUlaw(_ ulaw: UInt8) -> Int16 {
        // Simplified µ-law decoding
        let BIAS: Int16 = 0x84
        let u = ~ulaw

        let sign = (u & 0x80) != 0
        let exponent = Int16((u >> 4) & 0x07)
        let mantissa = Int16(u & 0x0F)

        var sample = ((mantissa << 3) | 0x84) << exponent
        sample -= BIAS

        return sign ? -sample : sample
    }

    private func encodeAlaw(_ sample: Int16) -> UInt8 {
        // Simplified A-law encoding
        let sign: UInt8 = sample < 0 ? 0x80 : 0x00
        let s = abs(sample)

        let encoded = if s < 256 {
            UInt8(s >> 4)
        } else if s < 512 {
            UInt8(0x10 | ((s >> 5) & 0x0F))
        } else if s < 1024 {
            UInt8(0x20 | ((s >> 6) & 0x0F))
        } else if s < 2048 {
            UInt8(0x30 | ((s >> 7) & 0x0F))
        } else if s < 4096 {
            UInt8(0x40 | ((s >> 8) & 0x0F))
        } else if s < 8192 {
            UInt8(0x50 | ((s >> 9) & 0x0F))
        } else if s < 16384 {
            UInt8(0x60 | ((s >> 10) & 0x0F))
        } else {
            UInt8(0x70 | ((s >> 11) & 0x0F))
        }

        return encoded ^ sign ^ 0x55
    }

    private func decodeAlaw(_ alaw: UInt8) -> Int16 {
        // Simplified A-law decoding
        var a = alaw ^ 0x55
        let sign = (a & 0x80) != 0
        a &= 0x7F

        let exponent = (a >> 4) & 0x07
        let mantissa = Int16(a & 0x0F)

        let sample: Int16 = if exponent == 0 {
            (mantissa << 4) | 0x08
        } else {
            ((mantissa | 0x10) << 4) << (exponent - 1)
        }

        return sign ? -sample : sample
    }
}

// MARK: - Audio Processing Errors

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension TachikomaError {
    public static func audioProcessingFailed(_ message: String) -> TachikomaError {
        .invalidConfiguration("Audio processing failed: \(message)")
    }
}

#endif // canImport(AVFoundation)
