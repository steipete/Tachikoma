import Algorithms
import Foundation
import Tachikoma // For TachikomaConfiguration and types

// MARK: - Global Audio Functions

/// Transcribe audio to text using a transcription model
///
/// ## Usage
///
/// ```swift
/// // Basic transcription
/// let audio = try AudioData(contentsOf: audioURL)
/// let result = try await transcribe(audio, using: .openai(.whisper1))
/// print(result.text)
///
/// // With language hint and timestamps
/// let result = try await transcribe(
///     audio,
///     using: .openai(.whisper1),
///     language: "en",
///     timestampGranularities: [.word, .segment]
/// )
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func transcribe(
    _ audio: AudioData,
    using model: TranscriptionModel,
    language: String? = nil,
    prompt: String? = nil,
    timestampGranularities: [TimestampGranularity] = [],
    responseFormat: TranscriptionResponseFormat = .verbose,
    abortSignal: AbortSignal? = nil,
    headers: [String: String] = [:],
    configuration: TachikomaConfiguration = TachikomaConfiguration(),
) async throws
    -> TranscriptionResult
{
    guard !audio.data.isEmpty else {
        throw TachikomaError.invalidInput("Audio data is empty")
    }

    let provider = try TranscriptionProviderFactory.createProvider(for: model, configuration: configuration)

    let request = TranscriptionRequest(
        audio: audio,
        language: language,
        prompt: prompt,
        timestampGranularities: timestampGranularities,
        responseFormat: responseFormat,
        abortSignal: abortSignal,
        headers: headers,
    )

    return try await provider.transcribe(request: request)
}

/// Generate speech from text using a speech model
///
/// ## Usage
///
/// ```swift
/// // Basic speech generation
/// let result = try await generateSpeech(
///     "Hello, world!",
///     using: .openai(.tts1),
///     voice: .alloy
/// )
/// try result.audioData.write(to: outputURL)
///
/// // With custom speed and format
/// let result = try await generateSpeech(
///     "This is a test",
///     using: .openai(.tts1HD),
///     voice: .nova,
///     speed: 1.2,
///     format: .wav
/// )
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func generateSpeech(
    _ text: String,
    using model: SpeechModel,
    voice: VoiceOption = .alloy,
    language: String? = nil,
    speed: Double = 1.0,
    format: AudioFormat = .mp3,
    instructions: String? = nil,
    abortSignal: AbortSignal? = nil,
    headers: [String: String] = [:],
    configuration: TachikomaConfiguration = TachikomaConfiguration(),
) async throws
    -> SpeechResult
{
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw TachikomaError.invalidInput("Text must not be empty for text-to-speech.")
    }
    let provider = try SpeechProviderFactory.createProvider(for: model, configuration: configuration)

    let request = SpeechRequest(
        text: text,
        voice: voice,
        language: language,
        speed: speed,
        format: format,
        instructions: instructions,
        abortSignal: abortSignal,
        headers: headers,
    )

    return try await provider.generateSpeech(request: request)
}

// MARK: - Convenience Functions

/// Convenience function for quick transcription with default settings
///
/// Uses OpenAI Whisper with default settings for simple transcription tasks.
///
/// ```swift
/// let audio = try AudioData(contentsOf: audioURL)
/// let text = try await transcribe(audio, language: "en")
/// print(text)
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func transcribe(
    _ audio: AudioData,
    language: String? = nil,
    configuration: TachikomaConfiguration = TachikomaConfiguration(),
) async throws
    -> String
{
    let result = try await transcribe(
        audio,
        using: .default,
        language: language,
        configuration: configuration,
    )
    return result.text
}

/// Convenience function for transcribing from a file URL
///
/// ```swift
/// let text = try await transcribe(contentsOf: audioFileURL)
/// print(text)
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func transcribe(
    contentsOf url: URL,
    using model: TranscriptionModel = .default,
    language: String? = nil,
    configuration: TachikomaConfiguration = TachikomaConfiguration(),
) async throws
    -> String
{
    let audio = try AudioData(contentsOf: url)
    let result = try await transcribe(audio, using: model, language: language, configuration: configuration)
    return result.text
}

/// Convenience function for quick speech generation with default settings
///
/// Uses OpenAI TTS with default voice for simple speech synthesis.
///
/// ```swift
/// let audioData = try await generateSpeech("Hello, world!", voice: .nova)
/// try audioData.write(to: outputURL)
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func generateSpeech(
    _ text: String,
    voice: VoiceOption = .alloy,
    configuration: TachikomaConfiguration = TachikomaConfiguration(),
) async throws
    -> AudioData
{
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw TachikomaError.invalidInput("Text must not be empty for text-to-speech.")
    }
    let result = try await generateSpeech(
        text,
        using: .default,
        voice: voice,
        configuration: configuration,
    )
    return result.audioData
}

/// Convenience function for generating speech directly to a file
///
/// ```swift
/// try await generateSpeech("Hello, world!", to: outputURL, voice: .echo)
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func generateSpeech(
    _ text: String,
    to url: URL,
    using model: SpeechModel = .default,
    voice: VoiceOption = .alloy,
    speed: Double = 1.0,
    format: AudioFormat = .mp3,
    configuration: TachikomaConfiguration = TachikomaConfiguration(),
) async throws {
    let result = try await generateSpeech(
        text,
        using: model,
        voice: voice,
        speed: speed,
        format: format,
        configuration: configuration,
    )
    try result.audioData.write(to: url)
}

// MARK: - Batch Operations

/// Transcribe multiple audio files concurrently
///
/// ```swift
/// let audioFiles = [url1, url2, url3]
/// let results = try await transcribeBatch(audioFiles, using: .openai(.whisper1))
/// for (url, result) in zip(audioFiles, results) {
///     print("\(url.lastPathComponent): \(result.text)")
/// }
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func transcribeBatch(
    _ audioURLs: [URL],
    using model: TranscriptionModel,
    language: String? = nil,
    concurrency: Int = 3,
    configuration: TachikomaConfiguration = TachikomaConfiguration(),
) async throws
    -> [TranscriptionResult]
{
    try await withThrowingTaskGroup(
        of: (Int, TranscriptionResult).self,
        returning: [TranscriptionResult].self,
    ) { group in
        let semaphore = AsyncSemaphore(value: concurrency)

        for (index, url) in audioURLs.indexed() {
            group.addTask {
                await semaphore.wait()
                defer { Task { await semaphore.signal() } }

                let audio = try AudioData(contentsOf: url)
                let result = try await transcribe(audio, using: model, language: language, configuration: configuration)
                return (index, result)
            }
        }

        var results: [(Int, TranscriptionResult)] = []
        for try await result in group {
            results.append(result)
        }

        // Sort by original index to maintain order
        results.sort { $0.0 < $1.0 }
        return results.map(\.1)
    }
}

/// Generate speech for multiple texts concurrently
///
/// ```swift
/// let texts = ["Hello", "World", "How are you?"]
/// let results = try await generateSpeechBatch(texts, using: .openai(.tts1))
/// for (text, result) in zip(texts, results) {
///     try result.audioData.write(to: URL(fileURLWithPath: "\(text).mp3"))
/// }
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func generateSpeechBatch(
    _ texts: [String],
    using model: SpeechModel,
    voice: VoiceOption = .alloy,
    concurrency: Int = 3,
    configuration: TachikomaConfiguration = TachikomaConfiguration(),
) async throws
    -> [SpeechResult]
{
    try await withThrowingTaskGroup(of: (Int, SpeechResult).self, returning: [SpeechResult].self) { group in
        let semaphore = AsyncSemaphore(value: concurrency)

        for (index, text) in texts.indexed() {
            group.addTask {
                await semaphore.wait()
                defer { Task { await semaphore.signal() } }

                let result = try await generateSpeech(text, using: model, voice: voice, configuration: configuration)
                return (index, result)
            }
        }

        var results: [(Int, SpeechResult)] = []
        for try await result in group {
            results.append(result)
        }

        // Sort by original index to maintain order
        results.sort { $0.0 < $1.0 }
        return results.map(\.1)
    }
}

// MARK: - Provider Information

/// Get available transcription models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func availableTranscriptionModels() -> [TranscriptionModel] {
    var models: [TranscriptionModel] = []

    // OpenAI models
    for openaiModel in TranscriptionModel.OpenAI.allCases {
        models.append(.openai(openaiModel))
    }

    // Groq models
    for groqModel in TranscriptionModel.Groq.allCases {
        models.append(.groq(groqModel))
    }

    // Deepgram models
    for deepgramModel in TranscriptionModel.Deepgram.allCases {
        models.append(.deepgram(deepgramModel))
    }

    // ElevenLabs models
    for elevenlabsModel in TranscriptionModel.ElevenLabs.allCases {
        models.append(.elevenlabs(elevenlabsModel))
    }

    return models
}

/// Get available speech models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func availableSpeechModels() -> [SpeechModel] {
    var models: [SpeechModel] = []

    // OpenAI models
    for openaiModel in SpeechModel.OpenAI.allCases {
        models.append(.openai(openaiModel))
    }

    // ElevenLabs models
    for elevenlabsModel in SpeechModel.ElevenLabs.allCases {
        models.append(.elevenlabs(elevenlabsModel))
    }

    return models
}

/// Get capabilities for a transcription model
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func capabilities(
    for model: TranscriptionModel,
    configuration: TachikomaConfiguration = TachikomaConfiguration(),
) throws
    -> TranscriptionCapabilities
{
    let provider = try TranscriptionProviderFactory.createProvider(for: model, configuration: configuration)
    return provider.capabilities
}

/// Get capabilities for a speech model
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func capabilities(
    for model: SpeechModel,
    configuration: TachikomaConfiguration = TachikomaConfiguration(),
) throws
    -> SpeechCapabilities
{
    let provider = try SpeechProviderFactory.createProvider(for: model, configuration: configuration)
    return provider.capabilities
}

// MARK: - Helper Types

/// Simple semaphore for controlling concurrency
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func wait() async {
        if self.value > 0 {
            self.value -= 1
            return
        }

        await withCheckedContinuation { continuation in
            self.waiters.append(continuation)
        }
    }

    func signal() {
        if self.waiters.isEmpty {
            self.value += 1
        } else {
            let waiter = self.waiters.removeFirst()
            waiter.resume()
        }
    }
}
