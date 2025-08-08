import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - OpenAI-Compatible Helper

/// Shared helper for OpenAI-compatible APIs (OpenAI, Grok, etc.)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
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

        // Extract stop sequences from stop conditions
        let stopSequences = Self.extractStopSequences(from: request.settings.stopConditions)
        
        // Convert request to OpenAI-compatible format
        let openAIRequest = OpenAIChatRequest(
            model: modelId,
            messages: try convertMessages(request.messages),
            temperature: request.settings.temperature,
            maxTokens: request.settings.maxTokens,
            tools: try request.tools?.compactMap { try convertTool($0) },
            stream: false,
            stop: stopSequences.isEmpty ? nil : stopSequences
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // For debugging
        urlRequest.httpBody = try encoder.encode(openAIRequest)
        
        // Debug: Log the request JSON for verbose mode
        if ProcessInfo.processInfo.arguments.contains("--verbose") ||
           ProcessInfo.processInfo.arguments.contains("-v") {
            if let jsonString = String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) {
                // Find and log just the tools section to avoid massive output
                if let toolsRange = jsonString.range(of: "\"tools\"") {
                    let startIndex = toolsRange.lowerBound
                    let endIndex = jsonString.index(startIndex, offsetBy: min(500, jsonString.distance(from: startIndex, to: jsonString.endIndex)))
                    let toolsSubstring = String(jsonString[startIndex..<endIndex])
                    print("DEBUG OpenAI Request Tools (first 500 chars): \(toolsSubstring)")
                }
            }
        }

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
        let toolCalls = choice.message.toolCalls?.compactMap { openAIToolCall -> AgentToolCall? in
            // Parse JSON string to dictionary and convert to AnyAgentToolValue format
            guard let data = openAIToolCall.function.arguments.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            var arguments: [String: AnyAgentToolValue] = [:]
            for (key, value) in json {
                do {
                    arguments[key] = try AnyAgentToolValue.fromJSON(value)
                } catch {
                    // Log warning and skip arguments that can't be converted
                    print("[WARNING] Failed to convert tool argument '\(key)': \(error)")
                    continue
                }
            }
            
            return AgentToolCall(
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

        // Extract stop sequences from stop conditions
        let stopSequences = Self.extractStopSequences(from: request.settings.stopConditions)
        
        // Convert request to OpenAI-compatible format
        let openAIRequest = OpenAIChatRequest(
            model: modelId,
            messages: try convertMessages(request.messages),
            temperature: request.settings.temperature,
            maxTokens: request.settings.maxTokens,
            tools: try request.tools?.compactMap { try convertTool($0) },
            stream: true,
            stop: stopSequences.isEmpty ? nil : stopSequences
        )

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(openAIRequest)
        let finalRequest = urlRequest

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: finalRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: TachikomaError.networkError(NSError(domain: "Invalid response", code: 0)))
                        return
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        // Try to read first few bytes for error message
                        var errorData = Data()
                        var bytesIterator = bytes.makeAsyncIterator()
                        for _ in 0..<1024 { // Read up to 1KB for error message
                            if let byte = try await bytesIterator.next() {
                                errorData.append(byte)
                            } else {
                                break
                            }
                        }
                        let errorText = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.finish(throwing: TachikomaError.apiError("\(providerName) Error (HTTP \(httpResponse.statusCode)): \(errorText)"))
                        return
                    }
                    
                    // Process the streaming data
                    var buffer = ""
                    for try await byte in bytes {
                        let char = Character(UnicodeScalar(byte))
                        buffer.append(char)
                        
                        // Process complete lines
                        if char == "\n" {
                            let line = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                            buffer = ""
                            
                            if line.hasPrefix("data: ") {
                                let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                if jsonString == "[DONE]" {
                                    continuation.yield(TextStreamDelta.done())
                                    break
                                }
                                
                                guard let data = jsonString.data(using: .utf8) else { continue }
                                
                                do {
                                    let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: data)
                                    if let choice = chunk.choices.first {
                                        if let content = choice.delta.content {
                                            continuation.yield(TextStreamDelta.text(content))
                                        }
                                        
                                        if choice.finishReason != nil {
                                            continuation.yield(TextStreamDelta.done())
                                            break
                                        }
                                    }
                                } catch {
                                    // Skip malformed chunks
                                    continue
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Extract native stop sequences from stop conditions
    private static func extractStopSequences(from stopCondition: (any StopCondition)?) -> [String] {
        guard let stopCondition else { return [] }
        
        // Check if it's a string stop condition
        if let stringStop = stopCondition as? StringStopCondition {
            return [stringStop.stopString]
        }
        
        // Check if it's a composite condition
        if let anyStop = stopCondition as? AnyStopCondition {
            // Extract stop strings from all conditions
            var sequences: [String] = []
            // Note: We'd need to expose the conditions array in AnyStopCondition
            // For now, we can't extract from composite conditions
            return sequences
        }
        
        // For other types of stop conditions, we can't extract native sequences
        return []
    }
    
    private static func convertToolResultToString(_ result: AnyAgentToolValue) -> String {
        if result.isNull {
            return "null"
        } else if let value = result.boolValue {
            return String(value)
        } else if let value = result.intValue {
            return String(value)
        } else if let value = result.doubleValue {
            return String(value)
        } else if let value = result.stringValue {
            return value
        } else if let array = result.arrayValue {
            // Convert array to JSON string for complex results
            if let data = try? JSONEncoder().encode(array),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            return "[]"
        } else if let dict = result.objectValue {
            // Convert object to JSON string for complex results
            if let data = try? JSONEncoder().encode(dict),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            return "{}"
        } else {
            return "unknown"
        }
    }

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
                // Check if this assistant message contains tool calls
                let toolCalls = message.content.compactMap { part -> OpenAIChatMessage.AgentToolCall? in
                    if case .toolCall(let toolCall) = part {
                        // Convert AgentToolCall to OpenAI format
                        // Convert arguments dictionary to JSON string
                        let jsonData = try? JSONEncoder().encode(toolCall.arguments)
                        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                        
                        return OpenAIChatMessage.AgentToolCall(
                            id: toolCall.id,
                            type: "function",
                            function: OpenAIChatMessage.AgentToolCall.Function(
                                name: toolCall.name,
                                arguments: jsonString
                            )
                        )
                    }
                    return nil
                }
                
                // Extract text content
                let textContent = message.content.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined()
                
                // If we have tool calls, create a message with tool calls
                if !toolCalls.isEmpty {
                    return OpenAIChatMessage(role: "assistant", content: textContent.isEmpty ? nil : textContent, toolCalls: toolCalls)
                } else {
                    // Regular text message
                    return OpenAIChatMessage(role: "assistant", content: textContent)
                }
            case .tool:
                // Extract tool call ID and result content from tool result
                var toolCallId: String?
                var resultContent = ""
                
                for part in message.content {
                    switch part {
                    case .toolResult(let result):
                        toolCallId = result.toolCallId
                        // Convert the result to a string representation
                        resultContent = convertToolResultToString(result.result)
                    case .text(let text):
                        resultContent = text
                    default:
                        break
                    }
                }
                
                return OpenAIChatMessage(role: "tool", content: resultContent, toolCallId: toolCallId)
            }
        }
    }

    private static func convertTool(_ tool: AgentTool) throws -> OpenAITool {
        // Convert AgentToolParameters to [String: Any]
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
            
            // Handle array items if present
            if prop.type == .array, let items = prop.items {
                var itemsDict: [String: Any] = [
                    "type": items.type.rawValue
                ]
                if let itemEnumValues = items.enumValues {
                    itemsDict["enum"] = itemEnumValues
                }
                propDict["items"] = itemsDict
            }
            
            properties[key] = propDict
        }
        
        parameters["properties"] = properties
        
        // Only include required field if it's not empty
        if !tool.parameters.required.isEmpty {
            parameters["required"] = tool.parameters.required
        }
        
        // Debug logging
        if ProcessInfo.processInfo.arguments.contains("--verbose") ||
           ProcessInfo.processInfo.arguments.contains("-v") {
            print("DEBUG: Converting tool '\(tool.name)' with \(tool.parameters.properties.count) properties, \(tool.parameters.required.count) required")
            if tool.parameters.required.isEmpty {
                print("DEBUG: Omitting required field for '\(tool.name)' as it's empty")
            }
        }
        
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