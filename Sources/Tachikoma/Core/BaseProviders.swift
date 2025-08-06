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
        urlRequest.httpBody = try encoder.encode(anthropicRequest)

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
                // Convert input to AgentToolArgument dictionary
                var arguments: [String: AgentToolArgument] = [:]
                if let inputDict = toolUse.input as? [String: Any] {
                    for (key, value) in inputDict {
                        if let toolArg = try? AgentToolArgument.from(any: value) {
                            arguments[key] = toolArg
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
        urlRequest.httpBody = try encoder.encode(anthropicRequest)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TachikomaError.apiError("Anthropic Error (HTTP \(httpResponse.statusCode)): \(errorText)")
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
                            
                            if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" ||
                               jsonString.contains("\"type\":\"message_stop\"") {
                                continuation.yield(TextStreamDelta(type: .done))
                                break
                            }
                            
                            guard let data = jsonString.data(using: .utf8) else { continue }
                            
                            do {
                                let chunk = try JSONDecoder().decode(AnthropicStreamChunk.self, from: data)
                                if let delta = chunk.delta {
                                    switch delta {
                                    case .textDelta(let text):
                                        continuation.yield(TextStreamDelta(type: .textDelta, content: text))
                                    case .other:
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
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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
                let content = try message.content.compactMap { contentPart -> AnthropicContent? in
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
                let content = [AnthropicContent.text(AnthropicContent.TextContent(
                    type: "text",
                    text: message.content.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined()
                ))]
                anthropicMessages.append(AnthropicMessage(role: "assistant", content: content))
            case .tool:
                // Tool results go as user messages in Anthropic
                let content = [AnthropicContent.text(AnthropicContent.TextContent(
                    type: "text",
                    text: message.content.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined()
                ))]
                anthropicMessages.append(AnthropicMessage(role: "user", content: content))
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
                // Convert arguments dictionary to AgentToolArgument format
                var arguments: [String: AgentToolArgument] = [:]
                for (key, value) in ollamaCall.function.arguments {
                    if let toolArg = try? AgentToolArgument.from(any: value) {
                        arguments[key] = toolArg
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
                // Convert arguments to AgentToolArgument format
                var arguments: [String: AgentToolArgument] = [:]
                for (key, value) in json {
                    if key != "function", let toolArg = try? AgentToolArgument.from(any: value) {
                        arguments[key] = toolArg
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
                do {
                    // Split the data by lines for streaming JSON processing
                    let responseString = String(data: data, encoding: .utf8) ?? ""
                    let lines = responseString.components(separatedBy: .newlines)
                    
                    for line in lines {
                        guard let data = line.data(using: .utf8) else { continue }
                        
                        do {
                            let chunk = try JSONDecoder().decode(OllamaStreamChunk.self, from: data)
                            
                            if let content = chunk.message.content, !content.isEmpty {
                                continuation.yield(TextStreamDelta(type: .textDelta, content: content))
                            }
                            
                            if chunk.done {
                                continuation.yield(TextStreamDelta(type: .done))
                                break
                            }
                        } catch {
                            // Skip malformed chunks
                            continue
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