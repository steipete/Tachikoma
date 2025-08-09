//
//  OpenAIResponsesProvider.swift
//  Tachikoma
//

import Foundation

/// Provider for OpenAI Responses API (GPT-5, o3, o4)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class OpenAIResponsesProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    
    private let model: LanguageModel.OpenAI
    private let configuration: TachikomaConfiguration
    
    // Provider options (immutable for Sendable conformance)
    private let reasoningEffort: String = "medium"  // minimal, low, medium, high
    private let verbosity: String = "medium"  // low, medium, high (GPT-5 only)
    private let previousResponseId: String? = nil  // For conversation persistence
    private let reasoningItemIds: [String] = []  // For stateful reasoning
    
    public init(model: LanguageModel.OpenAI, configuration: TachikomaConfiguration) throws {
        self.model = model
        self.modelId = model.modelId
        self.configuration = configuration
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
            maxOutputTokens: isReasoningModel || isGPT5 ? 128_000 : 4096
        )
    }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        // Build Responses API request
        let responsesRequest = try buildResponsesRequest(request: request)
        
        // Create URL for Responses API endpoint
        let url = URL(string: "\(baseURL!)/responses")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey!)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add OpenAI-specific headers
        if let orgId = ProcessInfo.processInfo.environment["OPENAI_ORG_ID"] {
            urlRequest.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        // Encode request
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(responsesRequest)
        
        // Log request in verbose mode
        if ProcessInfo.processInfo.arguments.contains("--verbose") ||
           ProcessInfo.processInfo.arguments.contains("-v") {
            if let jsonString = String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) {
                print("DEBUG OpenAI Responses API Request: \(jsonString.prefix(500))")
            }
        }
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
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
        return try convertToProviderResponse(responsesResponse)
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        // Build Responses API request with streaming
        let responsesRequest = try buildResponsesRequest(request: request)
        
        // Add streaming flag (though not explicitly in request, handled by SSE)
        let url = URL(string: "\(baseURL!)/responses")!
        let finalURLRequest: URLRequest = {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(apiKey!)", forHTTPHeaderField: "Authorization")
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
            
            // Debug logging for GPT-5 and other models
            if modelId.contains("gpt-5") || ProcessInfo.processInfo.environment["DEBUG_OPENAI"] != nil {
                print("🟢 DEBUG OpenAI Responses API Request to \(url.absoluteString):")
                print("   Model: \(responsesRequest.model)")
                print("   Tools count: \(responsesRequest.tools?.count ?? 0)")
                if let toolNames = responsesRequest.tools?.map({ $0.function.name }) {
                    print("   Tool names: \(toolNames.joined(separator: ", "))")
                }
                if let jsonData = req.httpBody,
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    let preview = String(jsonString.prefix(2000))
                    print("   Request JSON (first 2000 chars):\n\(preview)")
                }
            }
            
            return req
        }()
        
        // Create streaming response
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: finalURLRequest)
                    
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
                        if let data = errorBody.data(using: .utf8),
                           let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let error = errorResponse["error"] as? [String: Any],
                           let message = error["message"] as? String {
                            errorMessage = "\(httpResponse.statusCode): \(message)"
                        } else if !errorBody.isEmpty {
                            errorMessage = "\(httpResponse.statusCode): \(errorBody.prefix(500))"
                        }
                        throw TachikomaError.apiError("Failed to start streaming: \(errorMessage)")
                    }
                    
                    var previousContent = ""  // Track previously sent content for GPT-5 preambles
                    
                    for try await line in bytes.lines {
                        // Handle SSE format
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            if let data = jsonString.data(using: .utf8) {
                                do {
                                    let chunk = try JSONDecoder().decode(OpenAIResponsesStreamChunk.self, from: data)
                                    
                                    // Convert to TextStreamDelta
                                    if let choice = chunk.choices.first,
                                       let content = choice.delta.content,
                                       !content.isEmpty {
                                        // Debug logging for GPT-5 streaming issue
                                        if ProcessInfo.processInfo.environment["DEBUG_STREAMING"] != nil {
                                            print("DEBUG: Received content: '\(content)'")
                                            print("DEBUG: Previous content: '\(previousContent)'")
                                        }
                                        
                                        // GPT-5 preamble messages might send accumulated content instead of deltas
                                        // Check if this is accumulated content or a true delta
                                        if content.hasPrefix(previousContent) && !previousContent.isEmpty {
                                            // This is accumulated content, extract just the delta
                                            let delta = String(content.dropFirst(previousContent.count))
                                            if !delta.isEmpty {
                                                if ProcessInfo.processInfo.environment["DEBUG_STREAMING"] != nil {
                                                    print("DEBUG: Yielding delta: '\(delta)'")
                                                }
                                                continuation.yield(TextStreamDelta.text(delta))
                                                previousContent = content  // Update the accumulated content
                                            }
                                        } else {
                                            // This is a true delta or the first chunk
                                            if ProcessInfo.processInfo.environment["DEBUG_STREAMING"] != nil {
                                                print("DEBUG: Yielding content as-is: '\(content)'")
                                            }
                                            continuation.yield(TextStreamDelta.text(content))
                                            previousContent += content  // Accumulate for comparison
                                        }
                                    }
                                    
                                    // Handle tool calls
                                    // Note: OpenAIStreamChunk doesn't have toolCalls in delta yet
                                    // This would need to be added to the type definition if needed
                                    
                                    // Check for finish
                                    if let choice = chunk.choices.first,
                                       choice.finishReason != nil {
                                        continuation.finish()
                                        return
                                    }
                                } catch {
                                    // Ignore parsing errors for incomplete chunks
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
    
    // MARK: - Private Helpers
    
    private func buildResponsesRequest(request: ProviderRequest) throws -> OpenAIResponsesRequest {
        // Convert messages to Responses API format
        let messages = try convertMessages(request.messages)
        
        // Convert tools if present
        let tools = try request.tools?.compactMap { tool in
            try convertTool(tool)
        }
        
        // Determine reasoning configuration
        let reasoning: ReasoningConfig? = if Self.isReasoningModel(model) || Self.isGPT5Model(model) {
            ReasoningConfig(
                effort: reasoningEffort,
                summary: false  // TODO: Add includeReasoning to GenerationSettings
            )
        } else {
            nil
        }
        
        // Determine verbosity (GPT-5 doesn't actually support this parameter)
        let verbosity: String? = nil
        
        // Build request
        return OpenAIResponsesRequest(
            model: modelId,
            input: messages,
            temperature: request.settings.temperature,
            topP: request.settings.topP,
            maxOutputTokens: request.settings.maxTokens,
            text: nil,  // TODO: Add response format support
            tools: tools,
            toolChoice: nil,  // TODO: Add tool choice support
            metadata: nil,
            parallelToolCalls: true,
            previousResponseId: previousResponseId,
            store: false,
            user: nil,
            instructions: nil,
            serviceTier: nil,
            include: nil,
            reasoning: reasoning,
            verbosity: verbosity,
            truncation: Self.isReasoningModel(model) ? "auto" : nil
        )
    }
    
    private func convertMessages(_ messages: [ModelMessage]) throws -> [ResponsesMessage] {
        return messages.map { message in
            var content: ResponsesMessage.ResponsesContent
            
            switch message.role {
            case .system, .user:
                let text = message.content.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined()
                content = .text(text)
                
            case .assistant:
                // Get text content
                let text = message.content.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined()
                
                // For now, just use text content
                // TODO: Handle tool calls in assistant messages
                content = .text(text.isEmpty ? "" : text)
                
            case .tool:
                // Handle tool responses
                var resultContent = ""
                
                for part in message.content {
                    switch part {
                    case .toolResult(let result):
                        // Convert result to string
                        resultContent = convertToolResultToString(result.result)
                    case .text(let text):
                        resultContent = text
                    default:
                        break
                    }
                }
                
                content = .text(resultContent)
            }
            
            return ResponsesMessage(
                role: message.role.rawValue,
                content: content
            )
        }
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
            if let data = try? JSONEncoder().encode(array),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            return "[]"
        } else if let dict = result.objectValue {
            // Convert object to JSON string
            if let data = try? JSONEncoder().encode(dict),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            return "{}"
        } else {
            return "unknown"
        }
    }
    
    private func convertTool(_ tool: AgentTool) throws -> ResponsesTool {
        // Convert AgentToolParameters to [String: Any] for the API
        var parameters: [String: Any] = [
            "type": "object",
            "properties": [:]
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
        
        // Add required fields
        if !tool.parameters.required.isEmpty {
            parameters["required"] = tool.parameters.required
        }
        
        let function = ResponsesTool.ToolFunction(
            name: tool.name,
            description: tool.description,
            parameters: parameters
        )
        
        return ResponsesTool(
            type: "function",
            function: function
        )
    }
    
    private func convertToProviderResponse(_ response: OpenAIResponsesResponse) throws -> ProviderResponse {
        guard let choice = response.choices.first else {
            throw TachikomaError.apiError("No choices in response")
        }
        
        // Extract text content
        let text = choice.message.content ?? ""
        
        // Convert tool calls
        let toolCalls = choice.message.toolCalls?.compactMap { toolCall -> AgentToolCall? in
            // Parse arguments from JSON string to dictionary
            guard let data = toolCall.function.arguments.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            var arguments: [String: AnyAgentToolValue] = [:]
            for (key, value) in json {
                do {
                    arguments[key] = try AnyAgentToolValue.fromJSON(value)
                } catch {
                    // Skip arguments that can't be converted
                    continue
                }
            }
            
            return AgentToolCall(
                id: toolCall.id,
                name: toolCall.function.name,
                arguments: arguments
            )
        }
        
        // Convert usage
        let usage: Usage? = if let apiUsage = response.usage {
            Usage(
                inputTokens: apiUsage.promptTokens,
                outputTokens: apiUsage.completionTokens
            )
        } else {
            nil
        }
        
        // Map finish reason
        let finishReason: FinishReason?
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
        
        return ProviderResponse(
            text: text,
            usage: usage,
            finishReason: finishReason,
            toolCalls: toolCalls
        )
    }
    
    private static func isReasoningModel(_ model: LanguageModel.OpenAI) -> Bool {
        switch model {
        case .o3, .o3Mini, .o3Pro, .o4Mini:
            return true
        default:
            return false
        }
    }
    
    private static func isGPT5Model(_ model: LanguageModel.OpenAI) -> Bool {
        switch model {
        case .gpt5, .gpt5Mini, .gpt5Nano:
            return true
        default:
            return false
        }
    }
}

// Configuration extensions removed - properties are immutable for Sendable conformance
// TODO: Consider using a separate configuration object or factory pattern for customization