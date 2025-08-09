//
//  GoogleProvider.swift
//  Tachikoma
//

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

    public init(model: LanguageModel.Google, configuration: TachikomaConfiguration) throws {
        self.model = model
        self.modelId = model.rawValue
        self.baseURL = configuration.getBaseURL(for: .google) ?? "https://generativelanguage.googleapis.com/v1beta"

        if let key = configuration.getAPIKey(for: .google) {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("GOOGLE_API_KEY not found")
        }

        self.capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            contextLength: model.contextLength,
            maxOutputTokens: 8192
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
            finishReason: finishReason
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        // Google Gemini API implementation
        // Note: This is a placeholder implementation that needs proper Google API integration
        // The actual implementation would use Google's generateContent endpoint with stream=true
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Convert messages to Google format
                    let googleRequest = try self.buildGoogleRequest(request)
                    
                    // Make streaming request to Google API
                    let url = URL(string: "\(self.baseURL!)/models/\(self.modelId):streamGenerateContent?key=\(self.apiKey!)")!
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try JSONEncoder().encode(googleRequest)
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          200..<300 ~= httpResponse.statusCode else {
                        throw TachikomaError.apiError("Google API request failed")
                    }
                    
                    // Parse SSE stream
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if let data = jsonString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let candidates = json["candidates"] as? [[String: Any]],
                               let content = candidates.first?["content"] as? [String: Any],
                               let parts = content["parts"] as? [[String: Any]] {
                                
                                for part in parts {
                                    if let text = part["text"] as? String {
                                        continuation.yield(TextStreamDelta.text(text))
                                    }
                                }
                            }
                        }
                    }
                    
                    continuation.yield(TextStreamDelta.done())
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func buildGoogleRequest(_ request: ProviderRequest) throws -> GoogleGenerateRequest {
        // Convert messages to Google format
        var contents: [[String: Any]] = []
        
        for message in request.messages {
            var parts: [[String: Any]] = []
            
            for contentPart in message.content {
                switch contentPart {
                case .text(let text):
                    parts.append(["text": text])
                case .image(let imageContent):
                    parts.append([
                        "inline_data": [
                            "mime_type": imageContent.mimeType,
                            "data": imageContent.data
                        ]
                    ])
                default:
                    break
                }
            }
            
            let role = message.role == .assistant ? "model" : "user"
            contents.append([
                "role": role,
                "parts": parts
            ])
        }
        
        return GoogleGenerateRequest(
            contents: contents,
            generationConfig: [
                "temperature": request.settings.temperature ?? 0.7,
                "maxOutputTokens": request.settings.maxTokens ?? 2048,
                "topP": request.settings.topP ?? 0.95,
                "topK": request.settings.topK ?? 40
            ]
        )
    }
}

// Google API request structure
private struct GoogleGenerateRequest: Encodable {
    let contents: [[String: Any]]
    let generationConfig: [String: Any]
    
    func encode(to encoder: Encoder) throws {
        // Properly encode as JSON objects, not strings
        let data = try JSONSerialization.data(withJSONObject: [
            "contents": contents,
            "generationConfig": generationConfig
        ])
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in json {
                try container.encode(AnyEncodable(value), forKey: DynamicCodingKey(stringValue: key)!)
            }
        }
    }
}


