import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provider for OpenAI Responses API (GPT-5, o3, o4)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class OpenAIResponsesProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    private let model: LanguageModel.OpenAI
    private let configuration: TachikomaConfiguration
    private let session: URLSession

    private static let debugLogURL = URL(fileURLWithPath: "/tmp/tachikoma-gpt5.log")

    // Provider options (immutable for Sendable conformance)
    private let reasoningEffort: ReasoningEffort = .medium
    private let verbosity: TextVerbosity = .high // Set to high for preambles
    private let previousResponseId: String? = nil // For conversation persistence
    private let reasoningItemIds: [String] = [] // For stateful reasoning

    public init(
        model: LanguageModel.OpenAI,
        configuration: TachikomaConfiguration,
        session: URLSession = .shared,
    ) throws {
        self.model = model
        self.modelId = model.modelId
        self.configuration = configuration
        self.session = session
        self.baseURL = configuration.getBaseURL(for: .openai) ?? "https://api.openai.com/v1"

        // Get API key from configuration
        if let key = configuration.getAPIKey(for: .openai) {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("OPENAI_API_KEY not found")
        }

        // Set capabilities based on model
        let isReasoningModel = Self.isReasoningModel(model)
        let isGPT5 = Self.isGPT5Model(model)

        self.capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            contextLength: model.contextLength,
            maxOutputTokens: isReasoningModel || isGPT5 ? 128_000 : 4096,
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        // Build Responses API request
        let responsesRequest = try buildResponsesRequest(request: request)

        // Create URL for Responses API endpoint
        let url = URL(string: "\(baseURL!)/responses")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(self.apiKey!)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add OpenAI-specific headers
        if let orgId = ProcessInfo.processInfo.environment["OPENAI_ORG_ID"] {
            urlRequest.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
        }

        // Encode request
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(responsesRequest)

        // Log request in verbose mode (silent by default)

        // Send request
        #if canImport(FoundationNetworking)
        // Linux: Use data task
        let (data, response) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
            (Data, URLResponse),
            Error,
        >) in
            self.session.dataTask(with: urlRequest) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, let response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: TachikomaError.networkError(NSError(
                        domain: "Invalid response",
                        code: 0,
                    )))
                }
            }.resume()
        }
        #else
        // macOS/iOS: Use async API
        let (data, response) = try await session.data(for: urlRequest)
        #endif

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TachikomaError.apiError("OpenAI Responses API Error (HTTP \(httpResponse.statusCode)): \(errorText)")
        }

        // Decode response
        let decoder = JSONDecoder()
        let responsesResponse = try decoder.decode(OpenAIResponsesResponse.self, from: data)

        // TODO: Store response metadata for conversation persistence
        // Cannot mutate properties due to Sendable conformance
        // Need to implement a different approach for maintaining conversation state

        // Convert to ProviderResponse
        return try Self.convertToProviderResponse(responsesResponse)
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        // Build Responses API request with streaming enabled
        let responsesRequest = try buildResponsesRequest(request: request, streaming: true)

        // Add streaming flag (though not explicitly in request, handled by SSE)
        let url = URL(string: "\(baseURL!)/responses")!
        let finalURLRequest: URLRequest = {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(self.apiKey!)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("text/event-stream", forHTTPHeaderField: "Accept")

            // Add OpenAI-specific headers
            if let orgId = ProcessInfo.processInfo.environment["OPENAI_ORG_ID"] {
                req.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
            }

            // Encode request
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            req.httpBody = try? encoder.encode(responsesRequest)

            // Debug logging only when explicitly enabled
            if ProcessInfo.processInfo.environment["DEBUG_OPENAI"] != nil {
                print("🟢 DEBUG OpenAI Responses API Request to \(url.absoluteString):")
                print("   Model: \(responsesRequest.model)")
                print("   Tools count: \(responsesRequest.tools?.count ?? 0)")
                if let toolNames = responsesRequest.tools?.compactMap({ $0.function?.name }) {
                    print("   Tool names: \(toolNames.joined(separator: ", "))")
                }
            }

            return req
        }()

        // Create streaming response
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    #if canImport(FoundationNetworking)
                    // Linux: Use data task for now (streaming not available)
                    let (data, response) = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<
                        (Data, URLResponse),
                        Error,
                    >) in
                        self.session.dataTask(with: finalURLRequest) { data, response, error in
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
                        throw TachikomaError.apiError("Invalid response type")
                    }

                    if httpResponse.statusCode != 200 {
                        let errorBody = String(data: data, encoding: .utf8) ?? ""
                        let errorMessage = "HTTP \(httpResponse.statusCode): \(errorBody.prefix(1000))"
                        throw TachikomaError.apiError("OpenAI Responses API Error: \(errorMessage)")
                    }

                    // Parse the entire response for Linux
                    let responseText = String(data: data, encoding: .utf8) ?? ""
                    let lines = responseText.components(separatedBy: "\n")
                    #else
                    // macOS/iOS: Use streaming API
                    let (bytes, response) = try await self.session.bytes(for: finalURLRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw TachikomaError.apiError("Invalid response type")
                    }

                    if httpResponse.statusCode != 200 {
                        // Try to read error message from response
                        var errorMessage = "HTTP \(httpResponse.statusCode)"
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 1000 { break } // Limit error message size
                        }
                        if
                            let data = errorBody.data(using: .utf8),
                            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                            let error = errorResponse["error"] as? [String: Any],
                            let message = error["message"] as? String
                        {
                            errorMessage = "\(httpResponse.statusCode): \(message)"
                        } else if !errorBody.isEmpty {
                            errorMessage = "\(httpResponse.statusCode): \(errorBody.prefix(500))"
                        }
                        throw TachikomaError.apiError("Failed to start streaming: \(errorMessage)")
                    }

                    var previousContent = "" // Track previously sent content for GPT-5 preambles
                    struct PartialToolCall {
                        var id: String
                        var name: String?
                        var arguments: String
                    }
                    var pendingToolCalls: [String: PartialToolCall] = [:]

                    for try await line in bytes.lines {
                        // Handle SSE format
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))

                            if ProcessInfo.processInfo.environment["DEBUG_TACHIKOMA_STREAM"] != nil {
                                Self.debugLog("raw stream: \(jsonString)")
                            }

                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }

                            if let data = jsonString.data(using: .utf8) {
                                // Try GPT-5 format first
                                if Self.isGPT5Model(self.model) {
                                    if
                                        let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                        let eventType = event["type"] as? String
                                    {
                                        if ProcessInfo.processInfo.environment["DEBUG_TACHIKOMA"] != nil {
                                            Self.debugLog("event: \(eventType) payload: \(event)")
                                        }

                                        switch eventType {
                                        case "response.output_text.delta":
                                            if let delta = event["delta"] as? String, !delta.isEmpty {
                                                continuation.yield(TextStreamDelta.text(delta))
                                            }

                                        case "response.output_item.added":
                                            if
                                                let item = event["item"] as? [String: Any],
                                                let itemType = item["type"] as? String,
                                                itemType == "function_call"
                                            {
                                                let identifier = (item["id"] as? String) ??
                                                    (item["call_id"] as? String) ?? UUID().uuidString
                                                var partial = pendingToolCalls[identifier] ?? PartialToolCall(
                                                    id: identifier,
                                                    name: nil,
                                                    arguments: "",
                                                )
                                                if let name = item["name"] as? String {
                                                    partial.name = name
                                                }
                                                pendingToolCalls[identifier] = partial
                                            }

                                        case "response.function_call_arguments.delta":
                                            if
                                                let itemId = event["item_id"] as? String,
                                                let delta = event["delta"] as? String
                                            {
                                                var partial = pendingToolCalls[itemId] ?? PartialToolCall(
                                                    id: itemId,
                                                    name: nil,
                                                    arguments: "",
                                                )
                                                partial.arguments.append(delta)
                                                pendingToolCalls[itemId] = partial
                                            }

                                        case "response.function_call_arguments.done":
                                            if
                                                let itemId = event["item_id"] as? String,
                                                let arguments = event["arguments"] as? String
                                            {
                                                var partial = pendingToolCalls[itemId] ?? PartialToolCall(
                                                    id: itemId,
                                                    name: nil,
                                                    arguments: "",
                                                )
                                                partial.arguments = arguments
                                                pendingToolCalls[itemId] = partial

                                                if
                                                    let name = partial.name,
                                                    let toolCall = Self.makeToolCall(
                                                        id: itemId,
                                                        name: name,
                                                        argumentsJSON: arguments,
                                                    )
                                                {
                                                    continuation.yield(.tool(toolCall))
                                                    pendingToolCalls.removeValue(forKey: itemId)
                                                }
                                            }

                                        case "response.completed":
                                            continuation.finish()
                                            return

                                        default:
                                            break
                                        }
                                    }
                                } else {
                                    // Try standard Responses API format (O3, etc.)
                                    do {
                                        let chunk = try JSONDecoder().decode(
                                            OpenAIResponsesStreamChunk.self,
                                            from: data,
                                        )

                                        // Convert to TextStreamDelta
                                        if
                                            let choice = chunk.choices.first,
                                            let content = choice.delta.content,
                                            !content.isEmpty
                                        {
                                            // Handle accumulated content for models with preambles
                                            if content.hasPrefix(previousContent), !previousContent.isEmpty {
                                                // This is accumulated content, extract just the delta
                                                let delta = String(content.dropFirst(previousContent.count))
                                                if !delta.isEmpty {
                                                    continuation.yield(TextStreamDelta.text(delta))
                                                    previousContent = content // Update the accumulated content
                                                }
                                            } else {
                                                // This is a true delta or the first chunk
                                                continuation.yield(TextStreamDelta.text(content))
                                                previousContent += content // Accumulate for comparison
                                            }
                                        }

                                        // Check for finish
                                        if
                                            let choice = chunk.choices.first,
                                            choice.finishReason != nil
                                        {
                                            continuation.finish()
                                            return
                                        }
                                    } catch {
                                        // Ignore parsing errors for incomplete chunks
                                    }
                                }
                            }
                        } else if line.hasPrefix("event: ") {
                            // Track event types for GPT-5 streaming (but we handle them in data lines)
                            // This helps us understand the stream structure
                        }
                    }

                    continuation.finish()
                    #endif
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func buildResponsesRequest(
        request: ProviderRequest,
        streaming: Bool = false,
    ) throws
        -> OpenAIResponsesRequest
    {
        // Convert messages to Responses API format
        let messages = try sanitizeInputs(convertMessages(request.messages))

        // Convert tools if present
        let tools = try request.tools?.compactMap { tool in
            try self.convertTool(tool)
        }

        // Get validated settings and provider options
        let validatedSettings = request.settings.validated(for: .openai(self.model))
        let openaiOptions = validatedSettings.providerOptions.openai

        // Determine reasoning configuration
        let reasoning: ReasoningConfig?
        if Self.isReasoningModel(self.model) || Self.isGPT5Model(self.model) {
            let effort: OpenAIReasoningEffort = if let optionEffort = openaiOptions?.reasoningEffort {
                // Convert from public API to internal type
                OpenAIReasoningEffort(rawValue: optionEffort.rawValue) ?? .medium
            } else {
                .medium // Default
            }
            reasoning = ReasoningConfig(
                effort: effort,
                summary: .auto,
            )
        } else {
            reasoning = nil
        }

        // Determine text configuration for GPT-5 (enables preamble messages)
        let textConfig: TextConfig?
        if Self.isGPT5Model(self.model) {
            let verbosity: TextVerbosity = if let optionVerbosity = openaiOptions?.verbosity {
                // Convert from public API to internal type
                TextVerbosity(rawValue: optionVerbosity.rawValue) ?? .high
            } else {
                .high // Default for preambles
            }
            textConfig = TextConfig(verbosity: verbosity)
        } else {
            textConfig = nil
        }

        let responsesRequest = OpenAIResponsesRequest(
            model: modelId,
            input: messages,
            temperature: validatedSettings.temperature,
            topP: validatedSettings.topP,
            maxOutputTokens: validatedSettings.maxTokens,
            text: textConfig,
            tools: tools,
            toolChoice: nil, // TODO: Add tool choice support
            metadata: nil,
            parallelToolCalls: openaiOptions?.parallelToolCalls ?? true,
            previousResponseId: openaiOptions?.previousResponseId ?? self.previousResponseId,
            store: false,
            user: nil,
            instructions: nil,
            serviceTier: nil,
            include: nil,
            reasoning: reasoning,
            truncation: Self.isReasoningModel(self.model) ? "auto" : nil,
            stream: streaming,
        )

        if
            ProcessInfo.processInfo.environment["DEBUG_TACHIKOMA_STREAM"] != nil,
            let data = try? JSONEncoder().encode(responsesRequest),
            let jsonString = String(data: data, encoding: .utf8)
        {
            Self.debugLog("request payload: \(jsonString)")
        }

        return responsesRequest
    }

    private func convertMessages(_ messages: [ModelMessage]) throws -> [ResponsesInputItem] {
        var inputs: [ResponsesInputItem] = []

        for message in messages {
            switch message.role {
            case .system, .user:
                if let entry = makeMessageEntry(role: message.role.rawValue, message: message) {
                    inputs.append(.message(entry))
                }
            case .assistant:
                if let entry = makeMessageEntry(role: message.role.rawValue, message: message) {
                    inputs.append(.message(entry))
                }

                for part in message.content {
                    guard case let .toolCall(call) = part else { continue }
                    if let functionCall = makeFunctionCall(call) {
                        inputs.append(.functionCall(functionCall))
                    }
                }
            case .tool:
                for part in message.content {
                    switch part {
                    case let .toolResult(result):
                        if let output = makeFunctionCallOutput(result) {
                            inputs.append(.functionCallOutput(output))
                        }
                    case let .text(text):
                        guard !text.isEmpty else { continue }
                        let entry = ResponsesMessage(
                            role: normalizedRole("user"),
                            content: .parts([ResponsesContentPart(type: "input_text", text: text, imageUrl: nil)]),
                        )
                        inputs.append(.message(entry))
                    default:
                        continue
                    }
                }
            }
        }

        return inputs
    }

    private func sanitizeInputs(_ inputs: [ResponsesInputItem]) -> [ResponsesInputItem] {
        inputs.map { item in
            switch item {
            case let .message(message):
                let normalized = self.normalizedRole(message.role)
                if normalized == message.role {
                    return item
                }
                let sanitized = ResponsesMessage(role: normalized, content: message.content)
                return .message(sanitized)
            default:
                return item
            }
        }
    }

    private func makeMessageEntry(role: String, message: ModelMessage) -> ResponsesMessage? {
        let parts = self.convertContentParts(for: message)
        guard !parts.isEmpty else { return nil }

        return ResponsesMessage(
            role: self.normalizedRole(role),
            content: .parts(parts),
        )
    }

    private func normalizedRole(_ role: String) -> String {
        switch role {
        case "assistant", "system", "developer", "user":
            role
        default:
            "user"
        }
    }

    private func convertContentParts(for message: ModelMessage) -> [ResponsesContentPart] {
        var parts: [ResponsesContentPart] = []

        switch message.role {
        case .system, .user, .assistant:
            for segment in message.content {
                switch segment {
                case let .text(text):
                    guard !text.isEmpty else { continue }
                    let type = message.role == .assistant ? "output_text" : "input_text"
                    parts.append(ResponsesContentPart(type: type, text: text, imageUrl: nil))
                case let .image(image):
                    let dataURL = "data:\(image.mimeType);base64,\(image.data)"
                    // Keep detail locally for compatibility, but encode as string-only.
                    let imageRef = ResponsesContentPart.ImageURL(url: dataURL, detail: "auto")
                    parts.append(ResponsesContentPart(type: "input_image", text: nil, imageUrl: imageRef))
                case let .toolResult(result):
                    let rendered = self.convertToolResultToString(result.result)
                    if !rendered.isEmpty {
                        parts.append(ResponsesContentPart(type: "input_text", text: rendered, imageUrl: nil))
                    }
                case .toolCall:
                    continue
                }
            }
        case .tool:
            let aggregated = message.content.compactMap { segment -> String? in
                switch segment {
                case let .toolResult(result):
                    let rendered = self.convertToolResultToString(result.result)
                    return rendered.isEmpty ? nil : rendered
                case let .text(text):
                    return text.isEmpty ? nil : text
                default:
                    return nil
                }
            }.joined(separator: "\n")

            if !aggregated.isEmpty {
                parts.append(ResponsesContentPart(type: "input_text", text: aggregated, imageUrl: nil))
            }
        }

        return parts
    }

    private func makeFunctionCall(_ toolCall: AgentToolCall) -> ResponsesInputItem.FunctionCall? {
        guard let argumentsJSON = encodeToolCallArguments(toolCall.arguments) else {
            return nil
        }

        return ResponsesInputItem.FunctionCall(
            callId: toolCall.id,
            name: toolCall.name,
            arguments: argumentsJSON,
        )
    }

    private func makeFunctionCallOutput(_ result: AgentToolResult) -> ResponsesInputItem.FunctionCallOutput? {
        // OpenAI Responses API requires a tool output for every function call.
        // Some tools succeed with an empty stdout/result (e.g. file writes), so ensure we still emit a payload.
        let outputText = self.convertToolResultToString(result.result)
        let safeOutput = outputText.isEmpty ? "ok" : outputText

        return ResponsesInputItem.FunctionCallOutput(
            callId: result.toolCallId,
            output: safeOutput,
            status: result.isError ? "failed" : nil,
        )
    }

    private func convertToolResultToString(_ result: AnyAgentToolValue) -> String {
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
            // Convert array to JSON string
            if
                let data = try? JSONEncoder().encode(array),
                let jsonString = String(data: data, encoding: .utf8)
            {
                return jsonString
            }
            return "[]"
        } else if let dict = result.objectValue {
            // Convert object to JSON string
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

    private func encodeToolCallArguments(_ arguments: [String: AnyAgentToolValue]) -> String? {
        var jsonObject: [String: Any] = [:]
        for (key, value) in arguments {
            do {
                jsonObject[key] = try value.toJSON()
            } catch {
                continue
            }
        }

        guard
            JSONSerialization.isValidJSONObject(jsonObject),
            let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys]),
            let jsonString = String(data: data, encoding: .utf8) else
        {
            return nil
        }
        return jsonString
    }

    private func convertTool(_ tool: AgentTool) throws -> ResponsesTool {
        // Convert AgentToolParameters to [String: Any] for the API
        var parameters: [String: Any] = [
            "type": "object",
            "properties": [:],
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
            if let items = prop.items {
                var itemsDict: [String: Any] = ["type": items.type]
                if let itemDescription = items.description {
                    itemsDict["description"] = itemDescription
                }
                propDict["items"] = itemsDict
            }
            properties[key] = propDict
        }
        parameters["properties"] = properties

        // Add required fields (even if empty to satisfy Responses API validation)
        parameters["required"] = tool.parameters.required

        // Responses API requires additionalProperties=false for strict schemas
        parameters["additionalProperties"] = false

        let function = ResponsesTool.ToolFunction(
            name: tool.name,
            description: tool.description,
            parameters: parameters,
            inputSchema: nil,
        )

        return ResponsesTool(
            name: tool.name,
            type: "function",
            description: tool.description,
            parameters: parameters,
            inputSchema: nil,
            strict: nil,
            function: function,
        )
    }

    static func convertToProviderResponse(_ response: OpenAIResponsesResponse) throws -> ProviderResponse {
        // Handle GPT-5 format (output array) vs O3 format (choices array)
        let text: String
        let toolCalls: [AgentToolCall]?
        let finishReason: FinishReason?

        if let outputs = response.output {
            // GPT-5 format with output array
            var collectedText = ""
            var collectedToolCalls: [AgentToolCall] = []

            for output in outputs {
                if output.type == "message" {
                    if let content = output.content {
                        for chunk in content {
                            switch chunk.type {
                            case "output_text":
                                if let textSegment = chunk.text {
                                    collectedText.append(textSegment)
                                }
                            case "tool_call":
                                if
                                    let toolCall = chunk.toolCall,
                                    let converted = Self.convertToolCall(toolCall)
                                {
                                    collectedToolCalls.append(converted)
                                }
                            default:
                                continue
                            }
                        }
                    }
                } else if
                    output.type == "tool_call", let toolCall = output.toolCall,
                    let converted = Self.convertToolCall(toolCall)
                {
                    collectedToolCalls.append(converted)
                }
            }

            text = collectedText
            toolCalls = collectedToolCalls.isEmpty ? nil : collectedToolCalls
            if let toolCalls, !toolCalls.isEmpty {
                finishReason = .toolCalls
            } else {
                finishReason = .stop
            }
        } else if let choices = response.choices, let choice = choices.first {
            // O3 format with choices array
            text = choice.message.content ?? ""

            // Convert tool calls
            toolCalls = choice.message.toolCalls?.compactMap { Self.convertToolCall($0) }

            // Map finish reason
            if let reason = choice.finishReason {
                switch reason {
                case "stop": finishReason = .stop
                case "length": finishReason = .length
                case "tool_calls": finishReason = .toolCalls
                default: finishReason = .stop
                }
            } else {
                finishReason = nil
            }
        } else {
            throw TachikomaError.apiError("No output or choices in response")
        }

        // Convert usage (handle both GPT-5 and O3 formats)
        let usage: Usage?
        if let apiUsage = response.usage {
            // GPT-5 uses input_tokens/output_tokens
            // O3 uses prompt_tokens/completion_tokens
            let inputTokens = apiUsage.inputTokens ?? apiUsage.promptTokens ?? 0
            let outputTokens = apiUsage.outputTokens ?? apiUsage.completionTokens ?? 0

            usage = Usage(
                inputTokens: inputTokens,
                outputTokens: outputTokens,
            )
        } else {
            usage = nil
        }

        return ProviderResponse(
            text: text,
            usage: usage,
            finishReason: finishReason,
            toolCalls: toolCalls,
        )
    }

    private static func convertToolCall(_ toolCall: OpenAIResponsesResponse.ResponsesToolCall) -> AgentToolCall? {
        if
            ProcessInfo.processInfo.arguments.contains("--verbose") ||
            ProcessInfo.processInfo.arguments.contains("-v")
        {
            print("DEBUG: Tool call \(toolCall.function.name) raw arguments: \(toolCall.function.arguments)")
        }

        guard let argumentsJSON = toolCall.function.arguments.data(using: .utf8) else {
            return nil
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: argumentsJSON) as? [String: Any] else {
            return nil
        }

        var arguments: [String: AnyAgentToolValue] = [:]
        for (key, value) in jsonObject {
            do {
                arguments[key] = try AnyAgentToolValue.fromJSON(value)
            } catch {
                continue
            }
        }

        return AgentToolCall(
            id: toolCall.id,
            name: toolCall.function.name,
            arguments: arguments,
        )
    }

    private static func makeToolCall(id: String, name: String, argumentsJSON: String) -> AgentToolCall? {
        if
            ProcessInfo.processInfo.arguments.contains("--verbose") ||
            ProcessInfo.processInfo.arguments.contains("-v")
        {
            print("DEBUG: Streaming tool call \(name) raw arguments: \(argumentsJSON)")
        }

        guard
            let data = argumentsJSON.data(using: .utf8),
            let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else
        {
            return nil
        }

        var arguments: [String: AnyAgentToolValue] = [:]
        for (key, value) in jsonObject {
            do {
                arguments[key] = try AnyAgentToolValue.fromJSON(value)
            } catch {
                continue
            }
        }

        return AgentToolCall(id: id, name: name, arguments: arguments)
    }

    private static func debugLog(_ message: String) {
        guard ProcessInfo.processInfo.environment["DEBUG_TACHIKOMA_STREAM"] != nil else { return }
        let formatted = "🔵 DEBUG \(message)\n"
        if let data = formatted.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: Self.debugLogURL.path) {
                if let handle = try? FileHandle(forWritingTo: Self.debugLogURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: Self.debugLogURL)
            }
        }
    }

    private static func isReasoningModel(_ model: LanguageModel.OpenAI) -> Bool {
        switch model {
        case .o4Mini:
            true
        default:
            false
        }
    }

    private static func isGPT5Model(_ model: LanguageModel.OpenAI) -> Bool {
        switch model {
        case .gpt52,
             .gpt51,
             .gpt5,
             .gpt5Pro,
             .gpt5Mini,
             .gpt5Nano,
             .gpt5Thinking,
             .gpt5ThinkingMini,
             .gpt5ThinkingNano,
             .gpt5ChatLatest:
            true
        default:
            false
        }
    }
}

// Configuration extensions removed - properties are immutable for Sendable conformance
// TODO: Consider using a separate configuration object or factory pattern for customization
