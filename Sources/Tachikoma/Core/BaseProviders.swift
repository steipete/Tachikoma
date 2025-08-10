import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Provider Base Classes


/// Provider for Anthropic Claude models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class AnthropicProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    private let model: LanguageModel.Anthropic

    public init(model: LanguageModel.Anthropic, configuration: TachikomaConfiguration) throws {
        self.model = model
        self.modelId = model.modelId
        self.baseURL = configuration.getBaseURL(for: .anthropic) ?? "https://api.anthropic.com"

        // Get API key from configuration system (environment or credentials)
        if let key = configuration.getAPIKey(for: .anthropic) {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("ANTHROPIC_API_KEY not found")
        }

        self.capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            supportsAudioInput: model.supportsAudioInput,
            supportsAudioOutput: model.supportsAudioOutput,
            contextLength: model.contextLength,
            maxOutputTokens: 4096
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        guard let apiKey = self.apiKey else {
            throw TachikomaError.authenticationFailed("Anthropic API key not found")
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Convert messages to Anthropic format
        let (systemMessage, messages) = try convertMessagesToAnthropic(request.messages)

        let anthropicRequest = AnthropicMessageRequest(
            model: modelId,
            maxTokens: request.settings.maxTokens ?? 1024,
            temperature: request.settings.temperature,
            system: systemMessage,
            messages: messages,
            tools: try request.tools?.map { try convertToolToAnthropic($0) },
            stream: false
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // For debugging
        let requestData = try encoder.encode(anthropicRequest)
        urlRequest.httpBody = requestData
        
        // Debug logging only when explicitly enabled
        let tachikomaConfig = TachikomaConfiguration.current
        if ProcessInfo.processInfo.environment["DEBUG_ANTHROPIC"] != nil || tachikomaConfig.verbose {
            if let jsonString = String(data: requestData, encoding: .utf8) {
                print("DEBUG AnthropicProvider: Request JSON (tools count: \(anthropicRequest.tools?.count ?? 0)):")
                // Only print the first part to avoid flooding
                let preview = String(jsonString.prefix(2000))
                print(preview)
                if jsonString.count > 2000 {
                    print("... (truncated, total \(jsonString.count) chars)")
                }
            }
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            // Try to parse Anthropic error format
            if let errorData = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data) {
                throw TachikomaError.apiError("Anthropic Error: \(errorData.error.message)")
            }
            
            throw TachikomaError.apiError("Anthropic Error (HTTP \(httpResponse.statusCode)): \(errorText)")
        }

        let decoder = JSONDecoder()
        let anthropicResponse = try decoder.decode(AnthropicMessageResponse.self, from: data)
        
        // Debug: Print the response when verbose
        if TachikomaConfiguration.current.verbose {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("DEBUG: Anthropic response JSON:")
                print(jsonString)
            }
        }

        let text = anthropicResponse.content.compactMap { content in
            switch content {
            case .text(let textContent):
                return textContent.text
            case .toolUse:
                return nil
            }
        }.joined()

        let usage = Usage(
            inputTokens: anthropicResponse.usage.inputTokens,
            outputTokens: anthropicResponse.usage.outputTokens
        )

        let finishReason: FinishReason? = {
            switch anthropicResponse.stopReason {
            case "end_turn": return .stop
            case "max_tokens": return .length
            case "tool_use": return .toolCalls
            case "stop_sequence": return .stop
            default: return .other
            }
        }()

        // Convert tool calls if present
        let toolCalls = anthropicResponse.content.compactMap { content -> AgentToolCall? in
            switch content {
            case .text:
                return nil
            case .toolUse(let toolUse):
                // Convert input to AnyAgentToolValue dictionary
                var arguments: [String: AnyAgentToolValue] = [:]
                if let inputDict = toolUse.input as? [String: Any] {
                    for (key, value) in inputDict {
                        do {
                            arguments[key] = try AnyAgentToolValue.fromJSON(value)
                        } catch {
                            // Log warning and skip arguments that can't be converted
                            print("[WARNING] Failed to convert tool argument '\(key)': \(error)")
                            continue
                        }
                    }
                }
                
                return AgentToolCall(
                    id: toolUse.id,
                    name: toolUse.name,
                    arguments: arguments
                )
            }
        }

        return ProviderResponse(
            text: text,
            usage: usage,
            finishReason: finishReason,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        guard let apiKey = self.apiKey else {
            throw TachikomaError.authenticationFailed("Anthropic API key not found")
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Convert messages to Anthropic format
        let (systemMessage, messages) = try convertMessagesToAnthropic(request.messages)

        let anthropicRequest = AnthropicMessageRequest(
            model: modelId,
            maxTokens: request.settings.maxTokens ?? 1024,
            temperature: request.settings.temperature,
            system: systemMessage,
            messages: messages,
            tools: try request.tools?.map { try convertToolToAnthropic($0) },
            stream: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted  // For debugging
        let requestData = try encoder.encode(anthropicRequest)
        urlRequest.httpBody = requestData
        
        // Debug logging only when explicitly enabled
        let config = TachikomaConfiguration.current
        if ProcessInfo.processInfo.environment["DEBUG_ANTHROPIC"] != nil ||
           config.verbose {
            print("\n🔴 DEBUG AnthropicProvider.streamText called with:")
            print("   Model: \(modelId)")
            print("   Tools count: \(anthropicRequest.tools?.count ?? 0)")
            if let tools = anthropicRequest.tools {
                print("   Tool names: \(tools.map { $0.name }.joined(separator: ", "))")
            }
            print("   Messages: \(messages.count)")
            print("   System prompt: \(systemMessage?.prefix(100) ?? "none")...")
            
            // Debug: Log the actual messages being sent
            for (idx, msg) in messages.enumerated() {
                print("   Message \(idx): role=\(msg.role)")
                for content in msg.content {
                    switch content {
                    case .text(let text):
                        print("     - text: \(text.text.prefix(100))...")
                    case .toolUse(let tool):
                        print("     - tool_use: id=\(tool.id), name=\(tool.name)")
                    case .toolResult(let result):
                        print("     - tool_result: tool_use_id=\(result.toolUseId)")
                    default:
                        print("     - other content")
                    }
                }
            }
            
            // Debug: Show first 2000 chars of JSON request
            if let jsonString = String(data: requestData, encoding: .utf8) {
                print("\n🔴 Anthropic Request JSON (first 2000 chars):")
                print(jsonString.prefix(2000))
            }
        }

        // Use URLSession's bytes API for proper streaming
        #if canImport(FoundationNetworking)
        // Linux: Use data task for now (streaming not available)
        let (data, response) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
            URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: TachikomaError.networkError(NSError(domain: "Invalid response", code: 0)))
                }
            }.resume()
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }
        
        guard httpResponse.statusCode == 200 else {
            // Return error data
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TachikomaError.apiError("Anthropic Error (HTTP \(httpResponse.statusCode)): \(errorText)")
        }
        
        // For Linux, parse the entire response at once
        let lines = String(data: data, encoding: .utf8)?.components(separatedBy: "\n") ?? []
        #else
        // macOS/iOS: Use streaming API
        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        guard httpResponse.statusCode == 200 else {
            // Collect error data
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorText = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw TachikomaError.apiError("Anthropic Error (HTTP \(httpResponse.statusCode)): \(errorText)")
        }

        return AsyncThrowingStream { continuation in
            Task {
                var currentToolCall: (id: String, name: String, partialInput: String)?
                var accumulatedText = ""
                
                do {
                    for try await line in bytes.lines {
                        // Skip empty lines
                        guard !line.isEmpty else { continue }
                        
                        // Process SSE events
                        if line.hasPrefix("event: ") {
                            // We'll use the event type in the next data line
                            continue
                        }
                        
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            // Check for stream end
                            if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                                // Yield accumulated text if any
                                if !accumulatedText.isEmpty {
                                    continuation.yield(TextStreamDelta.text(accumulatedText))
                                    accumulatedText = ""
                                }
                                continuation.yield(TextStreamDelta.done())
                                break
                            }
                            
                            guard let data = jsonString.data(using: .utf8) else { continue }
                            
                            do {
                                let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: data)
                                
                                switch event.type {
                                case "message_start":
                                    // Message is starting
                                    continue
                                    
                                case "content_block_start":
                                    if let block = event.contentBlock {
                                        if block.type == "tool_use" {
                                            // Starting a tool call
                                            currentToolCall = (id: block.id ?? "", name: block.name ?? "", partialInput: "")
                                        } else if block.type == "text" {
                                            // Text block starting
                                            continue
                                        }
                                    }
                                    
                                case "content_block_delta":
                                    if let delta = event.delta {
                                        if delta.type == "text_delta", let text = delta.text {
                                            // Accumulate text
                                            accumulatedText += text
                                            // Yield text in chunks
                                            if accumulatedText.count >= 20 {
                                                continuation.yield(TextStreamDelta.text(accumulatedText))
                                                accumulatedText = ""
                                            }
                                        } else if delta.type == "input_json_delta", let partialJson = delta.partialJson {
                                            // Accumulate tool input
                                            if var toolCall = currentToolCall {
                                                toolCall.partialInput += partialJson
                                                currentToolCall = toolCall
                                            }
                                        }
                                    }
                                    
                                case "content_block_stop":
                                    // Yield any remaining text
                                    if !accumulatedText.isEmpty {
                                        continuation.yield(TextStreamDelta.text(accumulatedText))
                                        accumulatedText = ""
                                    }
                                    
                                    // Complete tool call if we have one
                                    if let toolCall = currentToolCall {
                                        // Parse the complete JSON input
                                        if let inputData = toolCall.partialInput.data(using: .utf8),
                                           let inputJson = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] {
                                            // Convert to AnyAgentToolValue arguments
                                            var arguments: [String: AnyAgentToolValue] = [:]
                                            for (key, value) in inputJson {
                                                do {
                                                    arguments[key] = try AnyAgentToolValue.fromJSON(value)
                                                } catch {
                                                    print("[WARNING] Failed to convert tool argument '\(key)': \(error)")
                                                }
                                            }
                                            
                                            let agentToolCall = AgentToolCall(
                                                id: toolCall.id,
                                                name: toolCall.name,
                                                arguments: arguments
                                            )
                                            continuation.yield(TextStreamDelta.tool(agentToolCall))
                                        }
                                        currentToolCall = nil
                                    }
                                    
                                case "message_delta":
                                    // Message-level updates (usage, etc.)
                                    // Usage is typically included in the done event, not separately
                                    continue
                                    
                                case "message_stop":
                                    // Yield any final accumulated text
                                    if !accumulatedText.isEmpty {
                                        continuation.yield(TextStreamDelta.text(accumulatedText))
                                        accumulatedText = ""
                                    }
                                    continuation.yield(TextStreamDelta.done())
                                    break
                                    
                                default:
                                    // Unknown event type, skip
                                    continue
                                }
                            } catch {
                                // Log parsing error in verbose mode
                                let config = TachikomaConfiguration.current
                                if config.verbose {
                                    print("[WARNING] Failed to parse stream event: \(error)")
                                    print("Raw JSON: \(jsonString)")
                                }
                                continue
                            }
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                    return
                }
                
                continuation.finish()
            }
        }
        #endif  // End of macOS/iOS streaming implementation
        
        #if canImport(FoundationNetworking)
        // Linux implementation: Parse the entire response
        return AsyncThrowingStream { continuation in
            Task {
                var currentToolCall: (id: String, name: String, partialInput: String)?
                var accumulatedText = ""
                
                do {
                    for line in lines {
                        // Skip empty lines
                        guard !line.isEmpty else { continue }
                        
                        // Process SSE events
                        if line.hasPrefix("event: ") {
                            continue
                        }
                        
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            // Check for stream end
                            if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                                if !accumulatedText.isEmpty {
                                    continuation.yield(TextStreamDelta.text(accumulatedText))
                                }
                                continuation.yield(TextStreamDelta.done())
                                break
                            }
                            
                            guard let data = jsonString.data(using: .utf8) else { continue }
                            
                            do {
                                let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: data)
                                
                                // Process events similar to macOS implementation
                                switch event.type {
                                case "content_block_delta":
                                    if let delta = event.delta {
                                        if let text = delta.text {
                                            accumulatedText += text
                                        }
                                    }
                                case "message_stop":
                                    if !accumulatedText.isEmpty {
                                        continuation.yield(TextStreamDelta.text(accumulatedText))
                                    }
                                    continuation.yield(TextStreamDelta.done())
                                    break
                                default:
                                    continue
                                }
                            } catch {
                                continue
                            }
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                    return
                }
                
                continuation.finish()
            }
        }
        #endif
    }

    // MARK: - Helper Methods

    private func convertMessagesToAnthropic(_ messages: [ModelMessage]) throws -> (String?, [AnthropicMessage]) {
        var systemMessage: String?
        var anthropicMessages: [AnthropicMessage] = []

        for message in messages {
            switch message.role {
            case .system:
                // Anthropic uses a separate system field
                systemMessage = message.content.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined()
            case .user:
                let content = message.content.compactMap { contentPart -> AnthropicContent? in
                    switch contentPart {
                    case .text(let text):
                        return .text(AnthropicContent.TextContent(type: "text", text: text))
                    case .image(let imageContent):
                        return .image(AnthropicContent.ImageContent(
                            type: "image",
                            source: AnthropicContent.ImageSource(
                                type: "base64",
                                mediaType: imageContent.mimeType,
                                data: imageContent.data
                            )
                        ))
                    case .toolCall, .toolResult:
                        return nil // Skip tool calls and results in user messages
                    }
                }
                anthropicMessages.append(AnthropicMessage(role: "user", content: content))
            case .assistant:
                var content: [AnthropicContent] = []
                
                // Process each content part
                for part in message.content {
                    switch part {
                    case .text(let text):
                        if !text.isEmpty {
                            content.append(.text(AnthropicContent.TextContent(type: "text", text: text)))
                        }
                    case .toolCall(let toolCall):
                        // Convert tool call to Anthropic format
                        var arguments: [String: Any] = [:]
                        for (key, value) in toolCall.arguments {
                            // Convert AnyAgentToolValue to Any using toJSON
                            if let jsonValue = try? value.toJSON() {
                                arguments[key] = jsonValue
                            }
                        }
                        content.append(.toolUse(AnthropicContent.ToolUseContent(
                            id: toolCall.id,
                            name: toolCall.name,
                            input: arguments
                        )))
                    default:
                        continue
                    }
                }
                
                // Only add message if it has content
                if !content.isEmpty {
                    anthropicMessages.append(AnthropicMessage(role: "assistant", content: content))
                }
            case .tool:
                // Process tool results
                var content: [AnthropicContent] = []
                
                for part in message.content {
                    switch part {
                    case .toolResult(let result):
                        // Convert tool result to Anthropic format
                        let resultContent: String
                        if result.isError {
                            // Error result - get the error message
                            resultContent = result.result.stringValue ?? "Error occurred"
                        } else {
                            // Success result - convert to JSON string
                            if let json = try? result.result.toJSON(),
                               let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed),
                               let jsonString = String(data: jsonData, encoding: .utf8) {
                                resultContent = jsonString
                            } else {
                                // Fallback to string value if available
                                resultContent = result.result.stringValue ?? "Success"
                            }
                        }
                        
                        // Tool results need to be sent as user messages with tool_result blocks
                        content.append(.toolResult(AnthropicContent.ToolResultContent(
                            toolUseId: result.toolCallId,
                            content: resultContent
                        )))
                    case .text(let text):
                        // Sometimes tool messages include text
                        if !text.isEmpty {
                            content.append(.text(AnthropicContent.TextContent(type: "text", text: text)))
                        }
                    default:
                        continue
                    }
                }
                
                // Tool results are sent as user messages in Anthropic's format
                if !content.isEmpty {
                    anthropicMessages.append(AnthropicMessage(role: "user", content: content))
                }
            }
        }

        return (systemMessage, anthropicMessages)
    }

    private func convertToolToAnthropic(_ tool: AgentTool) throws -> AnthropicTool {
        // Convert AgentToolParameters to [String: Any]
        var properties: [String: Any] = [:]
        for (key, prop) in tool.parameters.properties {
            var propDict: [String: Any] = [
                "type": prop.type.rawValue,
                "description": prop.description
            ]
            
            if let enumValues = prop.enumValues {
                propDict["enum"] = enumValues
            }
            
            // Add items for array type
            if prop.type == .array {
                if let items = prop.items {
                    // Convert items to dictionary
                    var itemsDict: [String: Any] = ["type": items.type]
                    // Add description if present
                    if let itemDescription = items.description {
                        itemsDict["description"] = itemDescription
                    }
                    propDict["items"] = itemsDict
                } else {
                    // Default items for array
                    propDict["items"] = ["type": "string"]
                }
            }
            
            properties[key] = propDict
        }
        
        return AnthropicTool(
            name: tool.name,
            description: tool.description,
            inputSchema: AnthropicInputSchema(
                type: tool.parameters.type,
                properties: properties,
                required: tool.parameters.required
            )
        )
    }
}

/// Provider for Ollama models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class OllamaProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    private let model: LanguageModel.Ollama

    public init(model: LanguageModel.Ollama, configuration: TachikomaConfiguration) throws {
        self.model = model
        self.modelId = model.modelId
        
        // Get base URL from configuration or environment or use default
        if let configURL = configuration.getBaseURL(for: .ollama) {
            self.baseURL = configURL
        } else if let customURL = ProcessInfo.processInfo.environment["PEEKABOO_OLLAMA_BASE_URL"] {
            self.baseURL = customURL
        } else {
            self.baseURL = "http://localhost:11434"
        }
        
        // Ollama doesn't typically require an API key for local usage, but allow configuration
        self.apiKey = configuration.getAPIKey(for: .ollama)

        self.capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            supportsAudioInput: model.supportsAudioInput,
            supportsAudioOutput: model.supportsAudioOutput,
            contextLength: model.contextLength,
            maxOutputTokens: 4096
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        guard let baseURL = self.baseURL else {
            throw TachikomaError.invalidConfiguration("Ollama base URL not configured")
        }

        let url = URL(string: "\(baseURL)/api/chat")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 300 // 5 minutes for local processing

        // Convert messages to Ollama format
        let messages = request.messages.map { message in
            OllamaChatMessage(
                role: message.role.rawValue,
                content: message.content.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined()
            )
        }

        var options: OllamaChatRequest.OllamaOptions?
        if request.settings.temperature != nil || request.settings.maxTokens != nil {
            options = OllamaChatRequest.OllamaOptions(
                temperature: request.settings.temperature,
                numCtx: nil, // Context length managed by model
                numPredict: request.settings.maxTokens
            )
        }

        let ollamaRequest = OllamaChatRequest(
            model: modelId,
            messages: messages,
            tools: try request.tools?.map { try convertToolToOllama($0) },
            stream: false,
            options: options
        )

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(ollamaRequest)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            // Try to parse Ollama error format
            if let errorData = try? JSONDecoder().decode(OllamaErrorResponse.self, from: data) {
                throw TachikomaError.apiError("Ollama Error: \(errorData.error)")
            }
            
            throw TachikomaError.apiError("Ollama Error (HTTP \(httpResponse.statusCode)): \(errorText)")
        }

        let decoder = JSONDecoder()
        let ollamaResponse = try decoder.decode(OllamaChatResponse.self, from: data)

        let text = ollamaResponse.message.content
        
        // Ollama doesn't provide detailed token usage, estimate based on content
        let usage = Usage(
            inputTokens: request.messages.map { $0.content.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined().count / 4 }.reduce(0, +),
            outputTokens: text.count / 4
        )

        let finishReason: FinishReason = ollamaResponse.done ? .stop : .other

        // Handle tool calls - Ollama might return them in different formats
        var toolCalls: [AgentToolCall]? = nil
        if let messageCalls = ollamaResponse.message.toolCalls {
            toolCalls = messageCalls.compactMap { ollamaCall in
                // Convert arguments dictionary to AnyAgentToolValue format
                var arguments: [String: AnyAgentToolValue] = [:]
                for (key, value) in ollamaCall.function.arguments {
                    do {
                        arguments[key] = try AnyAgentToolValue.fromJSON(value)
                    } catch {
                        // Log warning and skip arguments that can't be converted
                        print("[WARNING] Failed to convert tool argument '\(key)': \(error)")
                        continue
                    }
                }
                
                return AgentToolCall(
                    id: "ollama_\(UUID().uuidString)",
                    name: ollamaCall.function.name,
                    arguments: arguments
                )
            }
        }

        // Some Ollama models output tool calls as JSON in the content
        if toolCalls == nil, text.contains("{") && text.contains("\"function\"") {
            // Try to parse tool calls from content
            if let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let functionName = json["function"] as? String {
                // Convert arguments to AnyAgentToolValue format
                var arguments: [String: AnyAgentToolValue] = [:]
                for (key, value) in json {
                    if key != "function" {
                        do {
                            arguments[key] = try AnyAgentToolValue.fromJSON(value)
                        } catch {
                            // Log warning and skip arguments that can't be converted
                            print("[WARNING] Failed to convert tool argument '\(key)': \(error)")
                            continue
                        }
                    }
                }
                
                toolCalls = [AgentToolCall(
                    id: "ollama_\(UUID().uuidString)",
                    name: functionName,
                    arguments: arguments
                )]
            }
        }

        return ProviderResponse(
            text: text,
            usage: usage,
            finishReason: finishReason,
            toolCalls: toolCalls
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        guard let baseURL = self.baseURL else {
            throw TachikomaError.invalidConfiguration("Ollama base URL not configured")
        }

        let url = URL(string: "\(baseURL)/api/chat")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 300 // 5 minutes for local processing

        // Convert messages to Ollama format
        let messages = request.messages.map { message in
            OllamaChatMessage(
                role: message.role.rawValue,
                content: message.content.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined()
            )
        }

        var options: OllamaChatRequest.OllamaOptions?
        if request.settings.temperature != nil || request.settings.maxTokens != nil {
            options = OllamaChatRequest.OllamaOptions(
                temperature: request.settings.temperature,
                numCtx: nil,
                numPredict: request.settings.maxTokens
            )
        }

        let ollamaRequest = OllamaChatRequest(
            model: modelId,
            messages: messages,
            tools: try request.tools?.map { try convertToolToOllama($0) },
            stream: true,
            options: options
        )

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(ollamaRequest)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TachikomaError.apiError("Ollama Error (HTTP \(httpResponse.statusCode)): \(errorText)")
        }

        return AsyncThrowingStream { continuation in
            Task {
                // Split the data by lines for streaming JSON processing
                let responseString = String(data: data, encoding: .utf8) ?? ""
                let lines = responseString.components(separatedBy: .newlines)
                
                for line in lines {
                    guard let data = line.data(using: .utf8) else { continue }
                    
                    do {
                        let chunk = try JSONDecoder().decode(OllamaStreamChunk.self, from: data)
                        
                        if let content = chunk.message.content, !content.isEmpty {
                            continuation.yield(TextStreamDelta.text(content))
                        }
                        
                        if chunk.done {
                            continuation.yield(TextStreamDelta.done())
                            break
                        }
                    } catch {
                        // Skip malformed chunks
                        continue
                    }
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Helper Methods

    private func convertToolToOllama(_ tool: AgentTool) throws -> OllamaTool {
        // Convert AgentToolParameters to [String: Any]
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
        
        let parameters: [String: Any] = [
            "type": tool.parameters.type,
            "properties": properties,
            "required": tool.parameters.required
        ]
        
        return OllamaTool(
            type: "function",
            function: OllamaTool.Function(
                name: tool.name,
                description: tool.description,
                parameters: parameters
            )
        )
    }
}
