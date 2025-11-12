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
        additionalHeaders: [String: String] = [:],
        session: URLSession = .shared,
    ) async throws
    -> ProviderResponse {
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

        guard let choice = openAIResponse.choices.first else {
            throw TachikomaError.apiError("\(providerName) returned no choices")
        }

        let text = choice.message.content ?? ""
        let usage = openAIResponse.usage.map {
            Usage(inputTokens: $0.promptTokens, outputTokens: $0.completionTokens)
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
                let data = openAIToolCall.function.arguments.data(using: .utf8),
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
        additionalHeaders: [String: String] = [:],
        session: URLSession = .shared,
    ) async throws
    -> AsyncThrowingStream<TextStreamDelta, Error> {
        let context = try self.buildStreamingRequestContext(
            request: request,
            modelId: modelId,
            baseURL: baseURL,
            apiKey: apiKey,
            additionalHeaders: additionalHeaders,
        )

        self.logStreamingRequestIfNeeded(context: context, modelId: modelId)

        return self.streamResponse(
            urlRequest: context.urlRequest,
            providerName: providerName,
            modelId: modelId,
            session: session,
        )
    }

    private struct StreamingRequestContext {
        let urlRequest: URLRequest
        let openAIRequest: OpenAIChatRequest
    }

    private static func buildStreamingRequestContext(
        request: ProviderRequest,
        modelId: String,
        baseURL: String,
        apiKey: String,
        additionalHeaders: [String: String],
    ) throws
    -> StreamingRequestContext {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw TachikomaError.invalidConfiguration("Invalid base URL: \(baseURL)")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        additionalHeaders.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }

        let stopSequences = Self.extractStopSequences(from: request.settings.stopConditions)

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

        return StreamingRequestContext(urlRequest: urlRequest, openAIRequest: openAIRequest)
    }

    private static func logStreamingRequestIfNeeded(context: StreamingRequestContext, modelId: String) {
        guard modelId.contains("gpt-5") || ProcessInfo.processInfo.environment["DEBUG_OPENAI"] != nil else {
            return
        }
        let url = context.urlRequest.url?.absoluteString ?? "<unknown>"
        print("🔵 DEBUG OpenAI Request to \(url):")
        print("   Model: \(modelId)")
        print("   Tools count: \(context.openAIRequest.tools?.count ?? 0)")
        if let toolNames = context.openAIRequest.tools?.map(\.function.name) {
            print("   Tool names: \(toolNames.joined(separator: ", "))")
        }
        if
            let body = context.urlRequest.httpBody,
            let jsonString = String(data: body, encoding: .utf8)
        {
            let preview = String(jsonString.prefix(2000))
            print("   Request JSON (first 2000 chars):\n\(preview)")
        }
    }

    private static func streamResponse(
        urlRequest: URLRequest,
        providerName: String,
        modelId: String,
        session: URLSession,
    )
    -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    #if canImport(FoundationNetworking)
                    try await self.streamOnLinux(
                        urlRequest: urlRequest,
                        providerName: providerName,
                        modelId: modelId,
                        session: session,
                        continuation: continuation,
                    )
                    #else
                    try await self.streamOnApple(
                        urlRequest: urlRequest,
                        providerName: providerName,
                        modelId: modelId,
                        session: session,
                        continuation: continuation,
                    )
                    #endif
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    #if canImport(FoundationNetworking)
    private static func streamOnLinux(
        urlRequest: URLRequest,
        providerName: String,
        modelId: String,
        session: URLSession,
        continuation: AsyncThrowingStream<TextStreamDelta, Error>.Continuation,
    ) async throws {
        let (data, response) = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<
            (Data, URLResponse),
            Error,
        >) in
            session.dataTask(with: urlRequest) { data, response, error in
                if let error {
                    cont.resume(throwing: error)
                } else if let data, let response {
                    cont.resume(returning: (data, response))
                } else {
                    cont.resume(throwing: TachikomaError.networkError(NSError(domain: "Invalid response", code: 0)))
                }
            }.resume()
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TachikomaError.apiError("\(providerName) Error (HTTP \(httpResponse.statusCode)): \(errorText)")
        }

        let lines = String(data: data, encoding: .utf8)?.components(separatedBy: "\n") ?? []
        try self.consumeStreamLines(
            lines: lines,
            modelId: modelId,
            providerName: providerName,
            continuation: continuation,
        )
    }
    #else
    private static func streamOnApple(
        urlRequest: URLRequest,
        providerName: String,
        modelId: String,
        session: URLSession,
        continuation: AsyncThrowingStream<TextStreamDelta, Error>.Continuation,
    ) async throws {
        let (bytes, response) = try await session.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
                if errorBody.count > 1000 { break }
            }
            let errorText = errorBody.isEmpty ? "Unknown error" : errorBody
            throw TachikomaError.apiError("\(providerName) Error (HTTP \(httpResponse.statusCode)): \(errorText)")
        }

        var hasReceivedContent = false
        for try await line in bytes.lines {
            if
                try self.processStreamLine(
                    line,
                    modelId: modelId,
                    providerName: providerName,
                    hasReceivedContent: &hasReceivedContent,
                    continuation: continuation,
                )
            {
                return
            }
        }

        if !hasReceivedContent {
            continuation.yield(TextStreamDelta.text(""))
            continuation.yield(TextStreamDelta.done())
        }
    }
    #endif

    private static func consumeStreamLines(
        lines: [String],
        modelId: String,
        providerName: String,
        continuation: AsyncThrowingStream<TextStreamDelta, Error>.Continuation,
    ) throws {
        var hasReceivedContent = false
        for line in lines {
            if
                try self.processStreamLine(
                    line,
                    modelId: modelId,
                    providerName: providerName,
                    hasReceivedContent: &hasReceivedContent,
                    continuation: continuation,
                )
            {
                return
            }
        }

        if !hasReceivedContent {
            continuation.yield(TextStreamDelta.text(""))
            continuation.yield(TextStreamDelta.done())
        }
    }

    private static func processStreamLine(
        _ line: String,
        modelId: String,
        providerName: String,
        hasReceivedContent: inout Bool,
        continuation: AsyncThrowingStream<TextStreamDelta, Error>.Continuation,
    ) throws
    -> Bool {
        guard line.hasPrefix("data: ") else { return false }
        let payload = String(line.dropFirst(6))
        return try self.processStreamPayload(
            payload: payload,
            modelId: modelId,
            providerName: providerName,
            hasReceivedContent: &hasReceivedContent,
            continuation: continuation,
        )
    }

    private static func processStreamPayload(
        payload: String,
        modelId: String,
        providerName: String,
        hasReceivedContent: inout Bool,
        continuation: AsyncThrowingStream<TextStreamDelta, Error>.Continuation,
    ) throws
    -> Bool {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "[DONE]" {
            if !hasReceivedContent {
                continuation.yield(TextStreamDelta.text(""))
            }
            continuation.yield(TextStreamDelta.done())
            return true
        }

        guard let data = payload.data(using: .utf8) else { return false }

        do {
            let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: data)
            try self.emitStreamChunk(
                chunk,
                rawPayload: payload,
                modelId: modelId,
                providerName: providerName,
                hasReceivedContent: &hasReceivedContent,
                continuation: continuation,
            )
        } catch {
            let config = TachikomaConfiguration.current
            if config.verbose || modelId.contains("grok") {
                print("[\(providerName)] Failed to parse chunk: \(error)")
                print("   Raw JSON: \(payload)")
            }
        }

        return false
    }

    private static func emitStreamChunk(
        _ chunk: OpenAIStreamChunk,
        rawPayload: String,
        modelId: String,
        providerName: String,
        hasReceivedContent: inout Bool,
        continuation: AsyncThrowingStream<TextStreamDelta, Error>.Continuation,
    ) throws {
        guard let choice = chunk.choices.first else { return }

        if modelId.contains("grok"), ProcessInfo.processInfo.environment["DEBUG_GROK"] != nil {
            print("🔵 DEBUG Grok chunk: \(rawPayload)")
        }

        if let content = choice.delta.content, !content.isEmpty {
            continuation.yield(TextStreamDelta.text(content))
            hasReceivedContent = true
        }

        if let toolCalls = choice.delta.toolCalls {
            for toolCall in toolCalls {
                if let call = self.makeAgentToolCall(from: toolCall) {
                    continuation.yield(TextStreamDelta.tool(call))
                    hasReceivedContent = true
                }
            }
        }

        if let finishReason = choice.finishReason, finishReason == "stop" || finishReason == "tool_calls" {
            continuation.yield(TextStreamDelta.done())
        }
    }

    private static func makeAgentToolCall(
        from toolCall: OpenAIStreamChunk.Delta.ToolCall,
    )
    -> AgentToolCall? {
        guard let function = toolCall.function, let name = function.name else { return nil }
        let arguments = self.decodeToolArguments(from: function.arguments)
        return AgentToolCall(
            id: toolCall.id ?? UUID().uuidString,
            name: name,
            arguments: arguments,
        )
    }

    private static func decodeToolArguments(from jsonString: String?) -> [String: AnyAgentToolValue] {
        guard
            let jsonString,
            !jsonString.isEmpty,
            let data = jsonString.data(using: .utf8),
            let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else
        {
            return [:]
        }

        var arguments: [String: AnyAgentToolValue] = [:]
        for (key, value) in raw {
            arguments[key] = AnyAgentToolValue.from(value)
        }
        return arguments
    }

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
}
