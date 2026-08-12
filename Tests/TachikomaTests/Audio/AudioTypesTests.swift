import Foundation
import Testing
@testable import Tachikoma
@testable import TachikomaAudio

struct AudioTypesTests {
    // MARK: - AudioData Tests

    struct AudioDataTests {
        @Test
        func `AudioData initialization with basic properties`() {
            let testData = Data([0x01, 0x02, 0x03, 0x04])
            let audioData = AudioData(
                data: testData,
                format: .wav,
                sampleRate: 44100,
                channels: 2,
                duration: 5.0,
            )

            #expect(audioData.data == testData)
            #expect(audioData.format == .wav)
            #expect(audioData.sampleRate == 44100)
            #expect(audioData.channels == 2)
            #expect(audioData.duration == 5.0)
            #expect(audioData.size == 4)
        }

        @Test
        func `AudioData initialization with defaults`() {
            let testData = Data([0x01, 0x02])
            let audioData = AudioData(data: testData)

            #expect(audioData.data == testData)
            #expect(audioData.format == .wav) // Default format
            #expect(audioData.sampleRate == nil)
            #expect(audioData.channels == nil)
            #expect(audioData.duration == nil)
            #expect(audioData.size == 2)
        }

        @Test
        func `AudioData file URL initialization`() throws {
            // Create a temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let testFile = tempDir.appendingPathComponent("test_audio-\(UUID().uuidString).mp3")
            let testData = Data([0x01, 0x02, 0x03])
            try testData.write(to: testFile)

            // Test initialization from file
            let audioData = try AudioData(contentsOf: testFile)

            #expect(audioData.data == testData)
            #expect(audioData.format == .mp3) // Inferred from extension
            #expect(audioData.sampleRate == nil) // TODO: metadata extraction
            #expect(audioData.size == 3)

            // Clean up
            try? FileManager.default.removeItem(at: testFile)
        }

        @Test
        func `AudioData file URL with unknown extension`() throws {
            let tempDir = FileManager.default.temporaryDirectory
            let testFile = tempDir.appendingPathComponent("test_audio-\(UUID().uuidString).unknown")
            let testData = Data([0x01, 0x02])
            try testData.write(to: testFile)

            let audioData = try AudioData(contentsOf: testFile)

            #expect(audioData.format == .wav) // Default fallback

            // Clean up
            try? FileManager.default.removeItem(at: testFile)
        }

        @Test
        func `AudioData write to file`() throws {
            let testData = Data([0x01, 0x02, 0x03, 0x04])
            let audioData = AudioData(data: testData, format: .flac)

            let tempDir = FileManager.default.temporaryDirectory
            let outputFile = tempDir.appendingPathComponent("output_audio-\(UUID().uuidString).flac")

            try audioData.write(to: outputFile)

            let writtenData = try Data(contentsOf: outputFile)
            #expect(writtenData == testData)

            // Clean up
            try? FileManager.default.removeItem(at: outputFile)
        }
    }

    // MARK: - AudioFormat Tests

    struct AudioFormatTests {
        @Test
        func `AudioFormat MIME types`() {
            #expect(AudioFormat.wav.mimeType == "audio/wav")
            #expect(AudioFormat.mp3.mimeType == "audio/mpeg")
            #expect(AudioFormat.flac.mimeType == "audio/flac")
            #expect(AudioFormat.opus.mimeType == "audio/opus")
            #expect(AudioFormat.m4a.mimeType == "audio/mp4")
            #expect(AudioFormat.aac.mimeType == "audio/aac")
            #expect(AudioFormat.pcm.mimeType == "audio/pcm")
            #expect(AudioFormat.ogg.mimeType == "audio/ogg")
        }

        @Test
        func `AudioFormat lossless property`() {
            // Lossless formats
            #expect(AudioFormat.wav.isLossless == true)
            #expect(AudioFormat.flac.isLossless == true)
            #expect(AudioFormat.pcm.isLossless == true)

            // Lossy formats
            #expect(AudioFormat.mp3.isLossless == false)
            #expect(AudioFormat.opus.isLossless == false)
            #expect(AudioFormat.m4a.isLossless == false)
            #expect(AudioFormat.aac.isLossless == false)
            #expect(AudioFormat.ogg.isLossless == false)
        }

        @Test
        func `AudioFormat all cases completeness`() {
            let allCases = AudioFormat.allCases
            let expectedCases: [AudioFormat] = [.wav, .mp3, .flac, .opus, .m4a, .aac, .pcm, .ogg]

            #expect(allCases.count == expectedCases.count)
            for expectedCase in expectedCases {
                #expect(allCases.contains(expectedCase))
            }
        }
    }

    // MARK: - VoiceOption Tests

    struct VoiceOptionTests {
        @Test
        func `VoiceOption string values`() {
            #expect(VoiceOption.alloy.stringValue == "alloy")
            #expect(VoiceOption.echo.stringValue == "echo")
            #expect(VoiceOption.fable.stringValue == "fable")
            #expect(VoiceOption.onyx.stringValue == "onyx")
            #expect(VoiceOption.nova.stringValue == "nova")
            #expect(VoiceOption.shimmer.stringValue == "shimmer")

            let customVoice = VoiceOption.custom("my-custom-voice")
            #expect(customVoice.stringValue == "my-custom-voice")
        }

        @Test
        func `VoiceOption defaults and recommendations`() {
            #expect(VoiceOption.default == .alloy)

            let femaleVoices = VoiceOption.female
            #expect(femaleVoices.contains(.alloy))
            #expect(femaleVoices.contains(.nova))
            #expect(femaleVoices.contains(.shimmer))
            #expect(femaleVoices.count == 3)

            let maleVoices = VoiceOption.male
            #expect(maleVoices.contains(.echo))
            #expect(maleVoices.contains(.fable))
            #expect(maleVoices.contains(.onyx))
            #expect(maleVoices.count == 3)
        }

        @Test
        func `VoiceOption hashable and equatable`() {
            let voice1 = VoiceOption.alloy
            let voice2 = VoiceOption.alloy
            let voice3 = VoiceOption.echo

            #expect(voice1 == voice2)
            #expect(voice1 != voice3)

            let custom1 = VoiceOption.custom("test")
            let custom2 = VoiceOption.custom("test")
            let custom3 = VoiceOption.custom("different")

            #expect(custom1 == custom2)
            #expect(custom1 != custom3)
        }
    }

    // MARK: - Result Types Tests

    struct ResultTypesTests {
        @Test
        func `TranscriptionResult initialization`() {
            let segments = [
                TranscriptionSegment(text: "Hello", start: 0.0, end: 1.0),
                TranscriptionSegment(text: "world", start: 1.0, end: 2.0),
            ]
            let usage = TranscriptionUsage(durationSeconds: 2.0, cost: 0.01)

            let result = TranscriptionResult(
                text: "Hello world",
                language: "en",
                duration: 2.0,
                segments: segments,
                usage: usage,
                warnings: ["Test warning"],
            )

            #expect(result.text == "Hello world")
            #expect(result.language == "en")
            #expect(result.duration == 2.0)
            #expect(result.segments?.count == 2)
            #expect(result.usage?.durationSeconds == 2.0)
            #expect(result.warnings?.first == "Test warning")
        }

        @Test
        func `TranscriptionSegment duration calculation`() {
            let segment = TranscriptionSegment(text: "test", start: 1.5, end: 3.7)
            #expect(segment.duration == 2.2)
        }

        @Test
        func `SpeechResult initialization`() {
            let audioData = AudioData(data: Data([0x01, 0x02]), format: .mp3)
            let usage = SpeechUsage(charactersProcessed: 10, cost: 0.05)

            let result = SpeechResult(
                audioData: audioData,
                usage: usage,
                warnings: ["Speed too fast"],
            )

            #expect(result.audioData.format == .mp3)
            #expect(result.usage?.charactersProcessed == 10)
            #expect(result.warnings?.first == "Speed too fast")
        }
    }

    // MARK: - Request Types Tests

    struct RequestTypesTests {
        @Test
        func `TranscriptionRequest initialization`() {
            let audioData = AudioData(data: Data([0x01]), format: .wav)
            let abortSignal = AbortSignal()

            let request = TranscriptionRequest(
                audio: audioData,
                language: "en",
                prompt: "Test prompt",
                timestampGranularities: [.word, .segment],
                responseFormat: .verbose,
                abortSignal: abortSignal,
                headers: ["Custom-Header": "value"],
            )

            #expect(request.audio.format == .wav)
            #expect(request.language == "en")
            #expect(request.prompt == "Test prompt")
            #expect(request.timestampGranularities.contains(.word))
            #expect(request.timestampGranularities.contains(.segment))
            #expect(request.responseFormat == .verbose)
            #expect(request.headers["Custom-Header"] == "value")
        }

        @Test
        func `SpeechRequest initialization`() {
            let abortSignal = AbortSignal()

            let request = SpeechRequest(
                text: "Hello world",
                voice: .nova,
                language: "en",
                speed: 1.2,
                format: .flac,
                instructions: "Speak clearly",
                abortSignal: abortSignal,
                headers: ["API-Version": "v1"],
            )

            #expect(request.text == "Hello world")
            #expect(request.voice == .nova)
            #expect(request.language == "en")
            #expect(request.speed == 1.2)
            #expect(request.format == .flac)
            #expect(request.instructions == "Speak clearly")
            #expect(request.headers["API-Version"] == "v1")
        }

        @Test
        func `Request default values`() {
            let audioData = AudioData(data: Data(), format: .wav)
            let transcriptionRequest = TranscriptionRequest(audio: audioData)

            #expect(transcriptionRequest.language == nil)
            #expect(transcriptionRequest.prompt == nil)
            #expect(transcriptionRequest.timestampGranularities.isEmpty)
            #expect(transcriptionRequest.responseFormat == .verbose)
            #expect(transcriptionRequest.headers.isEmpty)

            let speechRequest = SpeechRequest(text: "test")

            #expect(speechRequest.voice == .alloy)
            #expect(speechRequest.language == nil)
            #expect(speechRequest.speed == 1.0)
            #expect(speechRequest.format == .mp3)
            #expect(speechRequest.instructions == nil)
            #expect(speechRequest.headers.isEmpty)
        }
    }

    // MARK: - AbortSignal Tests

    struct AbortSignalTests {
        @Test
        func `AbortSignal basic functionality`() {
            let signal = AbortSignal()

            #expect(signal.cancelled == false)

            signal.cancel()

            #expect(signal.cancelled == true)
        }

        @Test
        func `AbortSignal throwIfCancelled`() throws {
            let signal = AbortSignal()

            // Should not throw when not cancelled
            try signal.throwIfCancelled()

            signal.cancel()

            // Should throw when cancelled
            #expect(throws: TachikomaError.self) {
                try signal.throwIfCancelled()
            }
        }

        @Test
        func `AbortSignal timeout functionality`() async throws {
            let signal = AbortSignal.timeout(0.1) // 100ms timeout

            #expect(signal.cancelled == false)

            // Wait a bit longer than the timeout
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms

            #expect(signal.cancelled == true)
        }

        @Test(arguments: [0, -1, .infinity, .nan])
        func `AbortSignal invalid timeouts cancel immediately`(timeout: TimeInterval) {
            let signal = AbortSignal.timeout(timeout)

            #expect(signal.cancelled == true)
        }

        @Test
        func `AbortSignal accepts the maximum supported timeout`() {
            let signal = AbortSignal.timeout(Double(Int64.max / 2))

            #expect(signal.cancelled == false)
        }

        @Test(arguments: [Double(Int64.max / 2).nextUp, Double.greatestFiniteMagnitude])
        func `AbortSignal overflowing timeouts cancel immediately`(timeout: TimeInterval) {
            let signal = AbortSignal.timeout(timeout)

            #expect(signal.cancelled == true)
        }

        @Test
        func `AbortSignal thread safety`() async {
            let signal = AbortSignal()

            // Start multiple concurrent tasks that check and cancel the signal
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<10 {
                    group.addTask {
                        for _ in 0..<100 {
                            _ = signal.cancelled
                            signal.cancel()
                        }
                    }
                }
            }

            #expect(signal.cancelled == true)
        }
    }

    // MARK: - Enum Tests

    @Test
    func `TimestampGranularity enum`() {
        #expect(TimestampGranularity.word.rawValue == "word")
        #expect(TimestampGranularity.segment.rawValue == "segment")

        let allCases = TimestampGranularity.allCases
        #expect(allCases.contains(.word))
        #expect(allCases.contains(.segment))
        #expect(allCases.count == 2)
    }

    @Test
    func `TranscriptionResponseFormat enum`() {
        #expect(TranscriptionResponseFormat.json.rawValue == "json")
        #expect(TranscriptionResponseFormat.text.rawValue == "text")
        #expect(TranscriptionResponseFormat.srt.rawValue == "srt")
        #expect(TranscriptionResponseFormat.verbose.rawValue == "verbose_json")
        #expect(TranscriptionResponseFormat.vtt.rawValue == "vtt")

        let allCases = TranscriptionResponseFormat.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.json))
        #expect(allCases.contains(.verbose))
    }

    // MARK: - Error Types Tests

    @Test
    func `Audio error types`() {
        let operationCancelled = TachikomaError.operationCancelled
        let noAudioData = TachikomaError.noAudioData
        let unsupportedFormat = TachikomaError.unsupportedAudioFormat
        let transcriptionFailed = TachikomaError.transcriptionFailed
        let speechFailed = TachikomaError.speechGenerationFailed

        // Test that these are properly defined
        #expect(operationCancelled.localizedDescription.contains("cancelled"))
        #expect(noAudioData.localizedDescription.contains("audio data"))
        #expect(unsupportedFormat.localizedDescription.contains("format"))
        #expect(transcriptionFailed.localizedDescription.contains("Transcription"))
        #expect(speechFailed.localizedDescription.contains("Speech"))
    }
}
