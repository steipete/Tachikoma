import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - OpenAI-Compatible Helper

/// Shared helper for OpenAI-compatible APIs (OpenAI, Grok, etc.)
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
struct OpenAICompatibleHelper {
    static func generateText(
        request: ProviderRequest,
        modelId: String,
        baseURL: String,
        apiKey: String,
        providerName: String,
        additionalHeaders: [String: String] = [:]
    ) async throws -> ProviderResponse {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add any additional headers (for specific providers)
        for (key, value) in additionalHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Convert request to OpenAI-compatible format
        let openAIRequest = OpenAIChatRequest(
            model: modelId,
            messages: try convertMessages(request.messages),
            temperature: request.settings.temperature,
            maxTokens: request.settings.maxTokens,
            tools: try request.tools?.compactMap { try convertTool($0) },
            stream: false
        )

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(openAIRequest)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            // Try to parse OpenAI error format
            if let errorData = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw TachikomaError.apiError("\(providerName) Error: \(errorData.error.message)")
            }
            
            throw TachikomaError.apiError("\(providerName) Error (HTTP \(httpResponse.statusCode)): \(errorText)")
        }

        let decoder = JSONDecoder()
        let openAIResponse = try decoder.decode(OpenAIChatResponse.self, from: data)

        guard let choice = openAIResponse.choices.first else {
            throw TachikomaError.apiError("\(providerName) returned no choices")
        }

        let text = choice.message.content ?? ""
        let usage = openAIResponse.usage.map {
            Usage(inputTokens: $0.promptTokens, outputTokens: $0.completionTokens)
        }

        let finishReason: FinishReason? = {
            switch choice.finishReason {
            case "stop": return .stop
            case "length": return .length
            case "tool_calls": return .toolCalls
            case "content_filter": return .contentFilter
            default: return .other
            }
        }()

        // Convert tool calls if present
        let toolCalls = choice.message.toolCalls?.compactMap { openAIToolCall -> ToolCall? in
            // Parse JSON string to dictionary and convert to ToolArgument format
            guard let data = openAIToolCall.function.arguments.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            var arguments: [String: ToolArgument] = [:]
            for (key, value) in json {
                if let toolArg = try? ToolArgument.from(any: value) {
                    arguments[key] = toolArg
                }
            }
            
            return ToolCall(
                id: openAIToolCall.id,
                name: openAIToolCall.function.name,
                arguments: arguments
            )
        }

        return ProviderResponse(
            text: text,
            usage: usage,
            finishReason: finishReason,
            toolCalls: toolCalls
        )
    }

    static func streamText(
        request: ProviderRequest,
        modelId: String,
        baseURL: String,
        apiKey: String,
        providerName: String,
        additionalHeaders: [String: String] = [:]
    ) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add any additional headers (for specific providers)
        for (key, value) in additionalHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Convert request to OpenAI-compatible format
        let openAIRequest = OpenAIChatRequest(
            model: modelId,
            messages: try convertMessages(request.messages),
            temperature: request.settings.temperature,
            maxTokens: request.settings.maxTokens,
            tools: try request.tools?.compactMap { try convertTool($0) },
            stream: true
        )

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(openAIRequest)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TachikomaError.apiError("\(providerName) Error (HTTP \(httpResponse.statusCode)): \(errorText)")
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Split the data by lines for SSE processing
                    let responseString = String(data: data, encoding: .utf8) ?? ""
                    let lines = responseString.components(separatedBy: .newlines)
                    
                    for line in lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                                continuation.yield(TextStreamDelta(type: .done))
                                break
                            }
                            
                            guard let data = jsonString.data(using: .utf8) else { continue }
                            
                            do {
                                let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: data)
                                if let choice = chunk.choices.first {
                                    if let content = choice.delta.content {
                                        continuation.yield(TextStreamDelta(type: .textDelta, content: content))
                                    }
                                    
                                    if choice.finishReason != nil {
                                        continuation.yield(TextStreamDelta(type: .done))
                                        break
                                    }
                                }
                            } catch {
                                // Skip malformed chunks
                                continue
                            }
                        }
                    }
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Helper Methods

    private static func convertMessages(_ messages: [ModelMessage]) throws -> [OpenAIChatMessage] {
        return messages.map { message in
            switch message.role {
            case .system:
                return OpenAIChatMessage(role: "system", content: message.content.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined())
            case .user:
                if message.content.count == 1, case .text(let text) = message.content.first! {
                    // Simple text message
                    return OpenAIChatMessage(role: "user", content: text)
                } else {
                    // Multi-modal message
                    let content = message.content.compactMap { contentPart -> OpenAIChatMessageContent? in
                        switch contentPart {
                        case .text(let text):
                            return .text(OpenAIChatMessageContent.TextContent(type: "text", text: text))
                        case .image(let imageContent):
                            let base64URL = "data:\(imageContent.mimeType);base64,\(imageContent.data)"
                            return .imageUrl(OpenAIChatMessageContent.ImageUrlContent(
                                type: "image_url",
                                imageUrl: OpenAIChatMessageContent.ImageUrl(url: base64URL)
                            ))
                        case .toolCall, .toolResult:
                            return nil // Skip tool calls and results in user messages
                        }
                    }
                    return OpenAIChatMessage(role: "user", content: content)
                }
            case .assistant:
                return OpenAIChatMessage(role: "assistant", content: message.content.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined())
            case .tool:
                // Extract tool call ID from tool result
                let toolCallId = message.content.compactMap { part in
                    if case .toolResult(let result) = part { return result.toolCallId }
                    return nil
                }.first
                
                return OpenAIChatMessage(role: "tool", content: message.content.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined(), toolCallId: toolCallId)
            }
        }
    }

    private static func convertTool(_ tool: SimpleTool) throws -> OpenAITool {
        // Convert ToolParameters to [String: Any]
        var parameters: [String: Any] = [
            "type": tool.parameters.type
        ]
        
        // Convert properties
        var properties: [String: Any] = [:]
        for (key, prop) in tool.parameters.properties {
            var propDict: [String: Any] = [
                "type": prop.type.rawValue,
                "description": prop.description
            ]
            
            if let enumValues = prop.enumValues {
                propDict["enum"] = enumValues
            }
            
            properties[key] = propDict
        }
        
        parameters["properties"] = properties
        parameters["required"] = tool.parameters.required
        
        return OpenAITool(
            type: "function",
            function: OpenAITool.Function(
                name: tool.name,
                description: tool.description,
                parameters: parameters
            )
        )
    }
}