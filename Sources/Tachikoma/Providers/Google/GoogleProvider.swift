import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Provider for Google Gemini models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class GoogleProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    private let model: LanguageModel.Google
    private var apiModelName: String { modelId }

    public init(model: LanguageModel.Google, configuration: TachikomaConfiguration) throws {
        self.model = model
        modelId = model.rawValue
        baseURL = configuration.getBaseURL(for: .google) ?? "https://generativelanguage.googleapis.com/v1beta"

        if let key = configuration.getAPIKey(for: .google) {
            apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("GEMINI_API_KEY not found")
        }

        capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            contextLength: model.contextLength,
            maxOutputTokens: 8192,
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        // For now, collect the stream and return as a single response
        let stream = try await streamText(request: request)
        var fullText = ""
        var usage: Usage?
        var finishReason: FinishReason = .stop

        for try await delta in stream {
            if case .textDelta = delta.type, let content = delta.content {
                fullText += content
            }
            if case .done = delta.type {
                usage = delta.usage
                finishReason = delta.finishReason ?? .stop
            }
        }

        return ProviderResponse(
            text: fullText,
            usage: usage,
            finishReason: finishReason,
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Convert messages to Google format
                    let googleRequest = try self.buildGoogleRequest(request)
                    let requestBody = try JSONEncoder().encode(googleRequest)
                    let urlRequest = try self.makeStreamRequest(body: requestBody)

                    #if canImport(FoundationNetworking)
                        let (data, response) = try await URLSession.shared.data(for: urlRequest)
                        let httpResponse = try self.httpResponse(response)
                        guard 200..<300 ~= httpResponse.statusCode else {
                            let body = String(data: data, encoding: .utf8) ?? ""
                            throw TachikomaError.apiError(
                                "Google API request failed (HTTP \(httpResponse.statusCode)): \(body)",
                            )
                        }

                        var parser = GoogleSSEParser { text in
                            continuation.yield(TextStreamDelta.text(text))
                        }
                        try parser.feed(data: data)
                        continuation.yield(parser.makeDoneDelta())
                    #else
                        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                        let httpResponse = try self.httpResponse(response)
                        if !(200..<300 ~= httpResponse.statusCode) {
                            var errorBody = ""
                            var iterator = bytes.makeAsyncIterator()
                            while let byte = try await iterator.next() {
                                errorBody.append(Character(UnicodeScalar(byte)))
                                if errorBody.count >= 512 {
                                    errorBody.append("…")
                                    break
                                }
                            }
                            throw TachikomaError.apiError(
                                "Google API request failed (HTTP \(httpResponse.statusCode)): \(errorBody)",
                            )
                        }

                        var parser = GoogleSSEParser { text in
                            continuation.yield(TextStreamDelta.text(text))
                        }
                        for try await line in bytes.lines {
                            try parser.feed(line: line)
                        }
                        parser.finish()
                        continuation.yield(parser.makeDoneDelta())
                    #endif

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func buildGoogleRequest(_ request: ProviderRequest) throws -> GoogleGenerateRequest {
        var contents: [GoogleGenerateRequest.Content] = []

        for message in request.messages {
            var parts: [GoogleGenerateRequest.Content.Part] = []

            for contentPart in message.content {
                switch contentPart {
                case let .text(text):
                    parts.append(.init(text: text, inlineData: nil))
                case let .image(imageContent):
                    let inline = GoogleGenerateRequest.Content.InlineData(
                        mimeType: imageContent.mimeType,
                        data: imageContent.data,
                    )
                    parts.append(.init(text: nil, inlineData: inline))
                default:
                    continue
                }
            }

            guard !parts.isEmpty else { continue }
            let role = message.role == .assistant ? "model" : "user"
            contents.append(.init(role: role, parts: parts))
        }

        let config = GoogleGenerateRequest.GenerationConfig(
            temperature: request.settings.temperature ?? 0.7,
            maxOutputTokens: request.settings.maxTokens ?? 2048,
            topP: request.settings.topP ?? 0.95,
            topK: request.settings.topK ?? 40,
        )

        return GoogleGenerateRequest(contents: contents, generationConfig: config)
    }
}

// MARK: - Streaming Helpers

extension GoogleProvider {
    private func makeStreamRequest(body: Data) throws -> URLRequest {
        guard let baseURL else {
            throw TachikomaError.invalidConfiguration("Google base URL is missing")
        }
        guard let apiKey else {
            throw TachikomaError.authenticationFailed("GEMINI_API_KEY not found")
        }

        var components = URLComponents(string: "\(baseURL)/models/\(apiModelName):streamGenerateContent")
        var items = components?.queryItems ?? []
        items.append(URLQueryItem(name: "alt", value: "sse"))
        items.append(URLQueryItem(name: "key", value: apiKey))
        components?.queryItems = items

        guard let url = components?.url else {
            throw TachikomaError.invalidConfiguration("Invalid Google streaming URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        return request
    }

    private func httpResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "GoogleProvider", code: -1))
        }
        return httpResponse
    }

    fileprivate static func mapFinishReason(_ reason: String) -> FinishReason {
        switch reason.lowercased() {
        case "stop", "stop_sequence":
            .stop
        case "max_tokens", "length":
            .length
        case "safety":
            .contentFilter
        default:
            .other
        }
    }
}

private struct GoogleSSEParser {
    private let onText: (String) -> Void
    private(set) var usage: Usage?
    private(set) var finishReason: FinishReason?

    init(onText: @escaping (String) -> Void) {
        self.onText = onText
    }

    mutating func feed(line: String) throws {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return }
        let payload = trimmed.dropFirst(5).drop { $0 == " " }
        try process(payload: String(payload))
    }

    mutating func feed(data: Data) throws {
        guard let body = String(data: data, encoding: .utf8) else {
            return
        }
        let lines = body.components(separatedBy: .newlines)
        for line in lines {
            try feed(line: line)
        }
    }

    mutating func finish() {}

    mutating func process(payload: String) throws {
        guard payload != "[DONE]" else { return }
        guard let data = payload.data(using: .utf8) else { return }
        let chunk = try JSONDecoder().decode(GoogleStreamChunk.self, from: data)

        if let candidates = chunk.candidates {
            for candidate in candidates {
                if let textParts = candidate.content?.parts?.compactMap(\.text), !textParts.isEmpty {
                    let text = textParts.joined()
                    if !text.isEmpty {
                        onText(text)
                    }
                }
                if let reason = candidate.finishReason {
                    finishReason = GoogleProvider.mapFinishReason(reason)
                }
            }
        }

        if let metadata = chunk.usageMetadata {
            let input = metadata.promptTokenCount ?? 0
            let output = metadata.candidatesTokenCount
                ?? max(0, (metadata.totalTokenCount ?? 0) - (metadata.promptTokenCount ?? 0))
            usage = Usage(inputTokens: input, outputTokens: output)
        }
    }

    func makeDoneDelta() -> TextStreamDelta {
        TextStreamDelta.done(usage: usage, finishReason: finishReason)
    }
}

private struct GoogleStreamChunk: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }

            let parts: [Part]?
        }

        let content: Content?
        let finishReason: String?
    }

    struct UsageMetadata: Decodable {
        let promptTokenCount: Int?
        let candidatesTokenCount: Int?
        let totalTokenCount: Int?
    }

    let candidates: [Candidate]?
    let usageMetadata: UsageMetadata?
}

private struct GoogleGenerateRequest: Encodable {
    struct Content: Encodable {
        struct InlineData: Encodable {
            let mimeType: String
            let data: String

            enum CodingKeys: String, CodingKey {
                case mimeType = "mime_type"
                case data
            }
        }

        struct Part: Encodable {
            let text: String?
            let inlineData: InlineData?

            enum CodingKeys: String, CodingKey {
                case text
                case inlineData = "inline_data"
            }
        }

        let role: String
        let parts: [Part]
    }

    struct GenerationConfig: Encodable {
        let temperature: Double
        let maxOutputTokens: Int
        let topP: Double
        let topK: Int

        enum CodingKeys: String, CodingKey {
            case temperature
            case maxOutputTokens
            case topP
            case topK
        }
    }

    let contents: [Content]
    let generationConfig: GenerationConfig
}
