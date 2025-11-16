import Foundation
import Tachikoma // For TachikomaError
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - OpenAI Error Response

struct OpenAIErrorResponse: Codable {
    let error: OpenAIErrorDetail
}

struct OpenAIErrorDetail: Codable {
    let message: String
    let type: String?
    let code: String?
}

// MARK: - OpenAI Audio API Types

struct OpenAITranscriptionRequest: Codable {
    let file: String // base64 encoded audio
    let model: String
    let language: String?
    let prompt: String?
    let responseFormat: String
    let temperature: Double?
    let timestampGranularities: [String]?

    enum CodingKeys: String, CodingKey {
        case file, model, language, prompt, temperature
        case responseFormat = "response_format"
        case timestampGranularities = "timestamp_granularities"
    }
}

struct OpenAITranscriptionResponse: Codable {
    let text: String
    let language: String?
    let duration: Double?
    let words: [OpenAIWord]?
    let segments: [OpenAISegment]?
}

struct OpenAIWord: Codable {
    let word: String
    let start: Double
    let end: Double
}

struct OpenAISegment: Codable {
    let id: Int
    let seek: Int
    let start: Double
    let end: Double
    let text: String
    let tokens: [Int]
    let temperature: Double
    let avgLogprob: Double
    let compressionRatio: Double
    let noSpeechProb: Double

    enum CodingKeys: String, CodingKey {
        case id, seek, start, end, text, tokens, temperature
        case avgLogprob = "avg_logprob"
        case compressionRatio = "compression_ratio"
        case noSpeechProb = "no_speech_prob"
    }
}

struct OpenAISpeechRequest: Codable {
    let model: String
    let input: String
    let voice: String
    let responseFormat: String?
    let speed: Double?

    enum CodingKeys: String, CodingKey {
        case model, input, voice, speed
        case responseFormat = "response_format"
    }
}

// MARK: - OpenAI Provider Implementations

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension OpenAITranscriptionProvider {
    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        try request.abortSignal?.throwIfCancelled()

        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Add custom headers
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Create multipart form data
        let boundary = "----TachikomaAudioBoundary\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add file data
        body.append("--\(boundary)\r\n".utf8Data())
        body
            .append(
                "Content-Disposition: form-data; name=\"file\"; filename=\"audio.\(request.audio.format.rawValue)\"\r\n"
                    .utf8Data(),
            )
        body.append("Content-Type: \(request.audio.format.mimeType)\r\n\r\n".utf8Data())
        body.append(request.audio.data)
        body.append("\r\n".utf8Data())

        // Add model
        body.append("--\(boundary)\r\n".utf8Data())
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".utf8Data())
        body.append(modelId.utf8Data())
        body.append("\r\n".utf8Data())

        // Add optional parameters
        if let language = request.language {
            body.append("--\(boundary)\r\n".utf8Data())
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".utf8Data())
            body.append(language.utf8Data())
            body.append("\r\n".utf8Data())
        }

        if let prompt = request.prompt {
            body.append("--\(boundary)\r\n".utf8Data())
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".utf8Data())
            body.append(prompt.utf8Data())
            body.append("\r\n".utf8Data())
        }

        // Add response format
        let responseFormat = request.responseFormat.rawValue
        body.append("--\(boundary)\r\n".utf8Data())
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".utf8Data())
        body.append(responseFormat.utf8Data())
        body.append("\r\n".utf8Data())

        // Add timestamp granularities if supported and requested
        if capabilities.supportsTimestamps, !request.timestampGranularities.isEmpty {
            for granularity in request.timestampGranularities {
                body.append("--\(boundary)\r\n".utf8Data())
                body
                    .append(
                        "Content-Disposition: form-data; name=\"timestamp_granularities[]\"\r\n\r\n"
                            .utf8Data(),
                    )
                body.append(granularity.rawValue.utf8Data())
                body.append("\r\n".utf8Data())
            }
        }

        // Close boundary
        body.append("--\(boundary)--\r\n".utf8Data())

        urlRequest.httpBody = body

        // Make request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        try request.abortSignal?.throwIfCancelled()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw TachikomaError.apiError("OpenAI Transcription Error: \(errorData.error.message)")
            } else {
                throw TachikomaError.apiError("OpenAI Transcription Error: HTTP \(httpResponse.statusCode)")
            }
        }

        // Handle different response formats
        switch request.responseFormat {
        case .text:
            // Simple text response
            guard let text = String(data: data, encoding: .utf8) else {
                throw TachikomaError.transcriptionFailed
            }
            return TranscriptionResult(text: text.trimmingCharacters(in: .whitespacesAndNewlines))

        case .json, .verbose:
            // JSON response with metadata
            let openaiResponse = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data)

            let segments = openaiResponse.segments?.map { segment in
                let words = openaiResponse.words?.compactMap { word in
                    // Only include words that belong to this segment
                    if word.start >= segment.start, word.end <= segment.end {
                        return TranscriptionWord(
                            word: word.word,
                            start: word.start,
                            end: word.end,
                        )
                    }
                    return nil
                }

                return TranscriptionSegment(
                    text: segment.text,
                    start: segment.start,
                    end: segment.end,
                    words: words,
                )
            }

            let usage = openaiResponse.duration.map { duration in
                TranscriptionUsage(durationSeconds: duration)
            }

            return TranscriptionResult(
                text: openaiResponse.text,
                language: openaiResponse.language,
                duration: openaiResponse.duration,
                segments: segments,
                usage: usage,
            )

        case .srt, .vtt:
            // Subtitle formats - return as text for now
            guard let text = String(data: data, encoding: .utf8) else {
                throw TachikomaError.transcriptionFailed
            }
            return TranscriptionResult(text: text)
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension OpenAISpeechProvider {
    public func generateSpeech(request: SpeechRequest) async throws -> SpeechResult {
        try request.abortSignal?.throwIfCancelled()

        let url = URL(string: "https://api.openai.com/v1/audio/speech")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add custom headers
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Validate text length
        if let maxLength = capabilities.maxTextLength, request.text.count > maxLength {
            throw TachikomaError.invalidInput("Text too long: \(request.text.count) characters (max: \(maxLength))")
        }

        // Validate voice
        if !capabilities.supportedVoices.contains(request.voice) {
            throw TachikomaError.invalidInput("Unsupported voice: \(request.voice.stringValue)")
        }

        // Validate format
        if !capabilities.supportedFormats.contains(request.format) {
            throw TachikomaError.invalidInput("Unsupported format: \(request.format.rawValue)")
        }

        // Validate speed
        if request.speed < 0.25 || request.speed > 4.0 {
            throw TachikomaError.invalidInput("Speed must be between 0.25 and 4.0")
        }

        // Create request body
        var requestBody: [String: Any] = [
            "model": modelId,
            "input": request.text,
            "voice": request.voice.stringValue,
        ]

        if request.format != .mp3 {
            requestBody["response_format"] = request.format.rawValue
        }

        if request.speed != 1.0 {
            requestBody["speed"] = request.speed
        }

        // Add instructions for models that support them
        if capabilities.supportsVoiceInstructions, let instructions = request.instructions {
            requestBody["instructions"] = instructions
        }

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        urlRequest.httpBody = jsonData

        // Make request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        try request.abortSignal?.throwIfCancelled()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw TachikomaError.apiError("OpenAI Speech Error: \(errorData.error.message)")
            } else {
                throw TachikomaError.apiError("OpenAI Speech Error: HTTP \(httpResponse.statusCode)")
            }
        }

        // Response is raw audio data
        let audioData = AudioData(
            data: data,
            format: request.format,
        )

        let usage = SpeechUsage(charactersProcessed: request.text.count)

        return SpeechResult(
            audioData: audioData,
            usage: usage,
        )
    }
}

// MARK: - Helper Extensions

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}
