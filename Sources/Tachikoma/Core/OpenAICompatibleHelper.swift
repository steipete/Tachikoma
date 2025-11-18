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
        path: String = "/chat/completions",
        queryItems: [URLQueryItem] = [],
        authHeaderName: String = "Authorization",
        authHeaderValuePrefix: String = "Bearer ",
        additionalHeaders: [String: String] = [:],
        session: URLSession = .shared,
    ) async throws
        -> ProviderResponse
    {
        let url = try self.buildURL(baseURL: baseURL, path: path, queryItems: queryItems)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        let headerValue = authHeaderValuePrefix.isEmpty ? apiKey : "\(authHeaderValuePrefix)\(apiKey)"
        urlRequest.setValue(headerValue, forHTTPHeaderField: authHeaderName)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add any additional headers (for specific providers)
        for (key, value) in additionalHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Extract stop sequences from stop conditions
        let stopSequences = Self.extractStopSequences(from: request.settings.stopConditions)

        // Convert request to OpenAI-compatible format
        let openAIRequest = try OpenAIChatRequest(
            model: modelId,
            messages: convertMessages(request.messages),
            temperature: request.settings.temperature,
            maxTokens: request.settings.maxTokens,
            tools: request.tools?.compactMap { try self.convertTool($0) },
            stream: false,
            stop: stopSequences.isEmpty ? nil : stopSequences,
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // For debugging
        urlRequest.httpBody = try encoder.encode(openAIRequest)

        // Debug: Log the request JSON for verbose mode
        if
            ProcessInfo.processInfo.arguments.contains("--verbose") ||
            ProcessInfo.processInfo.arguments.contains("-v")
        {
            if let jsonString = String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) {
                // Find and log just the tools section to avoid massive output
                if let toolsRange = jsonString.range(of: "\"tools\"") {
                    let startIndex = toolsRange.lowerBound
                    let endIndex = jsonString.index(
                        startIndex,
                        offsetBy: min(500, jsonString.distance(from: startIndex, to: jsonString.endIndex)),
                    )
                    let toolsSubstring = String(jsonString[startIndex..<endIndex])
                    print("DEBUG OpenAI Request Tools (first 500 chars): \(toolsSubstring)")
                }
            }
        }

        let (data, response) = try await session.data(for: urlRequest)

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

        guard let choice = openAIResponse.choices?.first else {
            throw TachikomaError.apiError("\(providerName) returned no choices")
        }

        let text = choice.message.content ?? ""
        let usage = openAIResponse.usage.map {
            Usage(inputTokens: $0.promptTokens ?? 0, outputTokens: $0.completionTokens ?? 0)
        }

        let finishReason: FinishReason? = switch choice.finishReason {
        case "stop": .stop
        case "length": .length
        case "tool_calls": .toolCalls
        case "content_filter": .contentFilter
        default: .other
        }

        // Convert tool calls if present
        let toolCalls = choice.message.toolCalls?.compactMap { openAIToolCall -> AgentToolCall? in
            // Parse JSON string to dictionary and convert to AnyAgentToolValue format
            guard
                let data = openAIToolCall.function.arguments.data(using: String.Encoding.utf8),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else
            {
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
                arguments: arguments,
            )
        }

        return ProviderResponse(
            text: text,
            usage: usage,
            finishReason: finishReason,
            toolCalls: toolCalls,
        )
    }

    static func streamText(
        request: ProviderRequest,
        modelId: String,
        baseURL: String,
        apiKey: String,
        providerName: String,
        path: String = "/chat/completions",
        queryItems: [URLQueryItem] = [],
        authHeaderName: String = "Authorization",
        authHeaderValuePrefix: String = "Bearer ",
        additionalHeaders: [String: String] = [:],
        session: URLSession = .shared,
    ) async throws
        -> AsyncThrowingStream<TextStreamDelta, Error>
    {
        let url = try self.buildURL(baseURL: baseURL, path: path, queryItems: queryItems)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        let headerValue = authHeaderValuePrefix.isEmpty ? apiKey : "\(authHeaderValuePrefix)\(apiKey)"
        urlRequest.setValue(headerValue, forHTTPHeaderField: authHeaderName)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add any additional headers (for specific providers)
        for (key, value) in additionalHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Extract stop sequences from stop conditions
        let stopSequences = Self.extractStopSequences(from: request.settings.stopConditions)

        // Convert request to OpenAI-compatible format
        let openAIRequest = try OpenAIChatRequest(
            model: modelId,
            messages: convertMessages(request.messages),
            temperature: request.settings.temperature,
            maxTokens: request.settings.maxTokens,
            tools: request.tools?.compactMap { try self.convertTool($0) },
            stream: true,
            stop: stopSequences.isEmpty ? nil : stopSequences,
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        urlRequest.httpBody = try encoder.encode(openAIRequest)

        // Debug logging for GPT-5 and other models
        if modelId.contains("gpt-5") || ProcessInfo.processInfo.environment["DEBUG_OPENAI"] != nil {
            print("🔵 DEBUG OpenAI Request to \(url.absoluteString):")
            print("   Model: \(modelId)")
            print("   Tools count: \(openAIRequest.tools?.count ?? 0)")
            if let toolNames = openAIRequest.tools?.map(\.function.name) {
                print("   Tool names: \(toolNames.joined(separator: ", "))")
            }
            if
                let jsonData = urlRequest.httpBody,
                let jsonString = String(data: jsonData, encoding: .utf8)
            {
                let preview = String(jsonString.prefix(2000))
                print("   Request JSON (first 2000 chars):\n\(preview)")
            }
        }

        // Create a copy to avoid capturing mutable reference
        let finalRequest = urlRequest

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    #if canImport(FoundationNetworking)
                    // Linux: Use data task
                    let (data, response) = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<
                        (Data, URLResponse),
                        Error,
                    >) in
                        session.dataTask(with: finalRequest) { data, response, error in
                            if let error {
                                cont.resume(throwing: error)
                            } else if let data, let response {
                                cont.resume(returning: (data, response))
                            } else {
                                cont.resume(throwing: TachikomaError.networkError(NSError(
                                    domain: "Invalid response",
                                    code: 0,
                                )))
                            }
                        }.resume()
                    }

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
                    }

                    guard httpResponse.statusCode == 200 else {
                        let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                        throw TachikomaError
                            .apiError("\(providerName) Error (HTTP \(httpResponse.statusCode)): \(errorText)")
                    }

                    // Process the entire response for Linux
                    let lines = String(data: data, encoding: .utf8)?.components(separatedBy: "\n") ?? []
                    #else
                    // macOS/iOS: Use streaming API
                    let (bytes, response) = try await session.bytes(for: finalRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
                    }

                    guard httpResponse.statusCode == 200 else {
                        // Try to read error message from response
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 1000 { break }
                        }
                        let errorText = errorBody.isEmpty ? "Unknown error" : errorBody
                        throw TachikomaError
                            .apiError("\(providerName) Error (HTTP \(httpResponse.statusCode)): \(errorText)")
                    }
                    #endif

                    // Process the streaming response
                    var hasReceivedContent = false

                    #if canImport(FoundationNetworking)
                    // Linux: Process all lines at once
                    for line in lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))

                            if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                                // If we haven't received any content yet and see [DONE],
                                // yield an empty text delta to prevent hanging
                                if !hasReceivedContent {
                                    continuation.yield(TextStreamDelta.text(""))
                                }
                                continuation.yield(TextStreamDelta.done())
                                break
                            }

                            guard let data = jsonString.data(using: .utf8) else { continue }

                            do {
                                let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: data)
                                if let choice = chunk.choices.first {
                                    // Debug logging for Grok models
                                    if
                                        modelId.contains("grok"),
                                        ProcessInfo.processInfo.environment["DEBUG_GROK"] != nil
                                    {
                                        print("🔵 DEBUG Grok chunk: \(jsonString)")
                                    }

                                    if let content = choice.delta.content, !content.isEmpty {
                                        continuation.yield(TextStreamDelta.text(content))
                                        hasReceivedContent = true
                                    }

                                    // Handle tool calls - Grok sends them all at once
                                    if let toolCalls = choice.delta.toolCalls {
                                        for toolCall in toolCalls {
                                            // For Grok, function data comes directly in the toolCall
                                            if let function = toolCall.function {
                                                // Grok always provides name and arguments together
                                                if let name = function.name, let argumentsStr = function.arguments {
                                                    // Parse arguments JSON string into dictionary
                                                    let argumentsDict: [String: AnyAgentToolValue] = if
                                                        !argumentsStr.isEmpty,
                                                        let data = argumentsStr.data(using: .utf8),
                                                        let json = try? JSONSerialization
                                                            .jsonObject(with: data) as? [String: Any]
                                                    {
                                                        // Convert JSON to AnyAgentToolValue dictionary
                                                        json.compactMapValues { value in
                                                            if let stringValue = value as? String {
                                                                return AnyAgentToolValue(string: stringValue)
                                                            } else if let intValue = value as? Int {
                                                                return AnyAgentToolValue(int: intValue)
                                                            } else if let doubleValue = value as? Double {
                                                                return AnyAgentToolValue(double: doubleValue)
                                                            } else if let boolValue = value as? Bool {
                                                                return AnyAgentToolValue(bool: boolValue)
                                                            }
                                                            return nil
                                                        }
                                                    } else {
                                                        [:]
                                                    }

                                                    let agentToolCall = AgentToolCall(
                                                        id: toolCall.id ?? UUID().uuidString,
                                                        name: name,
                                                        arguments: argumentsDict,
                                                    )
                                                    continuation.yield(TextStreamDelta.tool(agentToolCall))
                                                    hasReceivedContent = true
                                                }
                                            }
                                        }
                                    }

                                    if choice.finishReason != nil {
                                        continuation.yield(TextStreamDelta.done())
                                        break
                                    }
                                }
                            } catch {
                                // Log decoding errors for debugging
                                if modelId.contains("grok") {
                                    print("⚠️ Grok streaming decode error: \(error)")
                                    print("   Raw JSON: \(jsonString)")
                                }
                                // Skip malformed chunks
                                continue
                            }
                        }
                    } // End of Linux for loop
                    #else
                    // macOS/iOS: Stream lines
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))

                            if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                                // If we haven't received any content yet and see [DONE],
                                // yield an empty text delta to prevent hanging
                                if !hasReceivedContent {
                                    continuation.yield(TextStreamDelta.text(""))
                                }
                                continuation.yield(TextStreamDelta.done())
                                break
                            }

                            guard let data = jsonString.data(using: .utf8) else { continue }

                            do {
                                let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: data)
                                if let choice = chunk.choices.first {
                                    // Debug logging for Grok models
                                    if
                                        modelId.contains("grok"),
                                        ProcessInfo.processInfo.environment["DEBUG_GROK"] != nil
                                    {
                                        print("🔵 DEBUG Grok chunk: \(jsonString)")
                                    }

                                    if let content = choice.delta.content, !content.isEmpty {
                                        continuation.yield(TextStreamDelta.text(content))
                                        hasReceivedContent = true
                                    }

                                    // Handle tool calls - Grok sends them all at once
                                    if let toolCalls = choice.delta.toolCalls {
                                        for toolCall in toolCalls {
                                            // For Grok, function data comes directly in the toolCall
                                            if let function = toolCall.function {
                                                // Grok always provides name and arguments together
                                                if let name = function.name, let argumentsStr = function.arguments {
                                                    // Parse arguments JSON string into dictionary
                                                    let argumentsDict: [String: AnyAgentToolValue] = if
                                                        let data = argumentsStr.data(using: .utf8),
                                                        let parsed = try? JSONSerialization
                                                            .jsonObject(with: data) as? [String: Any]
                                                    {
                                                        parsed.mapValues { AnyAgentToolValue.from($0) }
                                                    } else {
                                                        [:]
                                                    }

                                                    let call = AgentToolCall(
                                                        id: toolCall.id ?? UUID().uuidString,
                                                        name: name,
                                                        arguments: argumentsDict,
                                                    )
                                                    continuation.yield(TextStreamDelta.tool(call))
                                                    hasReceivedContent = true
                                                }
                                            }
                                        }
                                    }

                                    if let finishReason = choice.finishReason {
                                        if finishReason == "stop" || finishReason == "tool_calls" {
                                            continuation.yield(TextStreamDelta.done())
                                        }
                                    }
                                }
                            } catch {
                                // Log error in verbose mode
                                let config = TachikomaConfiguration.current
                                if config.verbose || modelId.contains("grok") {
                                    print("[\(providerName)] Failed to parse chunk: \(error)")
                                    print("   Raw JSON: \(jsonString)")
                                }
                                // Skip malformed chunks
                                continue
                            }
                        }
                    } // End of macOS for loop
                    #endif

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        } // End of AsyncThrowingStream closure
    } // End of streamText function

    // MARK: - Helper Methods

    /// Extract native stop sequences from stop conditions
    private static func extractStopSequences(from stopCondition: (any StopCondition)?) -> [String] {
        // Extract native stop sequences from stop conditions
        guard let stopCondition else { return [] }

        // Check if it's a string stop condition
        if let stringStop = stopCondition as? StringStopCondition {
            return [stringStop.stopString]
        }

        // Check if it's a composite condition
        if stopCondition is AnyStopCondition {
            // Extract stop strings from all conditions
            // Note: We'd need to expose the conditions array in AnyStopCondition
            // For now, we can't extract from composite conditions
            return []
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
            if
                let data = try? JSONEncoder().encode(array),
                let jsonString = String(data: data, encoding: .utf8)
            {
                return jsonString
            }
            return "[]"
        } else if let dict = result.objectValue {
            // Convert object to JSON string for complex results
            if
                let data = try? JSONEncoder().encode(dict),
                let jsonString = String(data: data, encoding: .utf8)
            {
                return jsonString
            }
            return "{}"
        } else {
            return "unknown"
        }
    }

    private static func convertMessages(_ messages: [ModelMessage]) throws -> [OpenAIChatMessage] {
        messages.map { message in
            switch message.role {
            case .system:
                return OpenAIChatMessage(role: "system", content: message.content.compactMap { part in
                    if case let .text(text) = part { return text }
                    return nil
                }.joined())
            case .user:
                if message.content.count == 1, case let .text(text) = message.content.first! {
                    // Simple text message
                    return OpenAIChatMessage(role: "user", content: text)
                } else {
                    // Multi-modal message
                    let content = message.content.compactMap { contentPart -> OpenAIChatMessageContent? in
                        switch contentPart {
                        case let .text(text):
                            return .text(OpenAIChatMessageContent.TextContent(type: "text", text: text))
                        case let .image(imageContent):
                            let base64URL = "data:\(imageContent.mimeType);base64,\(imageContent.data)"
                            return .imageUrl(OpenAIChatMessageContent.ImageUrlContent(
                                type: "image_url",
                                imageUrl: OpenAIChatMessageContent.ImageUrl(url: base64URL),
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
                    if case let .toolCall(toolCall) = part {
                        // Convert AgentToolCall to OpenAI format
                        // Convert arguments dictionary to JSON string
                        let jsonData = try? JSONEncoder().encode(toolCall.arguments)
                        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

                        return OpenAIChatMessage.AgentToolCall(
                            id: toolCall.id,
                            type: "function",
                            function: OpenAIChatMessage.AgentToolCall.Function(
                                name: toolCall.name,
                                arguments: jsonString,
                            ),
                        )
                    }
                    return nil
                }

                // Extract text content
                let textContent = message.content.compactMap { part in
                    if case let .text(text) = part { return text }
                    return nil
                }.joined()

                // If we have tool calls, create a message with tool calls
                if !toolCalls.isEmpty {
                    return OpenAIChatMessage(
                        role: "assistant",
                        content: textContent.isEmpty ? nil : textContent,
                        toolCalls: toolCalls,
                    )
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
                    case let .toolResult(result):
                        toolCallId = result.toolCallId
                        // Convert the result to a string representation
                        resultContent = self.convertToolResultToString(result.result)
                    case let .text(text):
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
            "type": tool.parameters.type,
        ]

        // Convert properties
        var properties: [String: Any] = [:]
        for (key, prop) in tool.parameters.properties {
            var propDict: [String: Any] = [
                "type": prop.type.rawValue,
                "description": prop.description,
            ]

            if let enumValues = prop.enumValues {
                propDict["enum"] = enumValues
            }

            // Handle array items if present
            if prop.type == .array {
                if let items = prop.items {
                    var itemsDict: [String: Any] = [
                        "type": items.type,
                    ]
                    if let itemDescription = items.description {
                        itemsDict["description"] = itemDescription
                    }
                    propDict["items"] = itemsDict
                } else {
                    // OpenAI requires items for array types - default to string
                    propDict["items"] = ["type": "string"]
                    if
                        ProcessInfo.processInfo.arguments.contains("--verbose") ||
                        ProcessInfo.processInfo.arguments.contains("-v")
                    {
                        print("DEBUG: Adding default string items for array property '\(key)' in tool '\(tool.name)'")
                    }
                }
            }

            properties[key] = propDict
        }

        parameters["properties"] = properties

        // Only include required field if it's not empty
        if !tool.parameters.required.isEmpty {
            parameters["required"] = tool.parameters.required
        }

        // Debug logging
        if
            ProcessInfo.processInfo.arguments.contains("--verbose") ||
            ProcessInfo.processInfo.arguments.contains("-v")
        {
            print(
                "DEBUG: Converting tool '\(tool.name)' with \(tool.parameters.properties.count) properties, \(tool.parameters.required.count) required",
            )
            if tool.parameters.required.isEmpty {
                print("DEBUG: Omitting required field for '\(tool.name)' as it's empty")
            }
        }

        return OpenAITool(
            type: "function",
            function: OpenAITool.Function(
                name: tool.name,
                description: tool.description,
                parameters: parameters,
            ),
        )
    }

    // MARK: - URL Construction

    private static func buildURL(baseURL: String, path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw TachikomaError.invalidConfiguration("Invalid base URL: \(baseURL)")
        }

        let basePath = components.path
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        let trimmedBase = basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath
        components.path = trimmedBase + normalizedPath

        var mergedQueryItems = components.queryItems ?? []
        mergedQueryItems.append(contentsOf: queryItems)
        components.queryItems = mergedQueryItems.isEmpty ? nil : mergedQueryItems

        guard let finalURL = components.url else {
            throw TachikomaError.invalidConfiguration("Failed to build URL from \(baseURL) and path \(path)")
        }
        return finalURL
    }
}
