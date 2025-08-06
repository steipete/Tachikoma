//
//  LMStudioProvider.swift
//  Tachikoma
//

import Foundation

/// Provider for LMStudio local model server
public actor LMStudioProvider: ModelProvider, Sendable {
    
    // MARK: - Properties
    
    // Store the actual URL internally as non-optional
    private let actualBaseURL: String
    
    // Expose as optional for protocol conformance, but it's never actually nil
    public nonisolated var baseURL: String? { actualBaseURL }
    
    public let apiKey: String?
    public let modelId: String
    public let capabilities: ModelCapabilities
    
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    public init(
        baseURL: String = "http://localhost:1234/v1",
        modelId: String = "current",
        apiKey: String? = nil
    ) {
        self.actualBaseURL = baseURL
        self.modelId = modelId
        self.apiKey = apiKey
        self.capabilities = ModelCapabilities(
            supportsTools: true,
            supportsStreaming: true,
            contextLength: 16384,
            maxOutputTokens: 4096
        )
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes for local models
        config.timeoutIntervalForResource = 600 // 10 minutes total
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Auto Detection
    
    /// Automatically detect if LMStudio is running
    public static func autoDetect() async throws -> LMStudioProvider? {
        let commonURLs = [
            "http://localhost:1234/v1",
            "http://127.0.0.1:1234/v1",
            "http://0.0.0.0:1234/v1"
        ]
        
        for url in commonURLs {
            let provider = LMStudioProvider(baseURL: url)
            if let _ = try? await provider.healthCheck() {
                return provider
            }
        }
        
        return nil
    }
    
    // MARK: - Health Check
    
    public struct HealthStatus: Codable, Sendable {
        public let status: String
        public let model: String?
        public let version: String?
    }
    
    public func healthCheck() async throws -> HealthStatus {
        let url = URL(string: "\(actualBaseURL)/models")!
        let (data, _) = try await session.data(from: url)
        
        // Parse models endpoint response
        let response = try decoder.decode(ModelsResponse.self, from: data)
        
        return HealthStatus(
            status: "ok",
            model: response.data.first?.id,
            version: "1.0"
        )
    }
    
    // MARK: - Model Management
    
    public struct Model: Codable, Sendable {
        public let id: String
        public let object: String
        public let created: Int
        public let owned_by: String
    }
    
    struct ModelsResponse: Codable {
        let data: [Model]
    }
    
    public func listModels() async throws -> [Model] {
        let url = URL(string: "\(actualBaseURL)/models")!
        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(ModelsResponse.self, from: data)
        return response.data
    }
    
    // MARK: - Text Generation
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        let openAIRequest = try mapToOpenAIRequest(request)
        
        var urlRequest = URLRequest(url: URL(string: "\(actualBaseURL)/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = apiKey {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try encoder.encode(openAIRequest)
        
        let (data, _) = try await session.data(for: urlRequest)
        let openAIResponse = try decoder.decode(LMStudioResponse.self, from: data)
        
        return try mapFromOpenAIResponse(openAIResponse, request: request)
    }
    
    // MARK: - Streaming
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        let openAIRequest = try mapToOpenAIRequest(request, streaming: true)
        
        var urlRequest = URLRequest(url: URL(string: "\(actualBaseURL)/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = apiKey {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try encoder.encode(openAIRequest)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, _) = try await session.bytes(for: urlRequest)
                    
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        
                        let jsonString = String(line.dropFirst(6))
                        guard jsonString != "[DONE]" else {
                            continuation.finish()
                            return
                        }
                        
                        if let data = jsonString.data(using: .utf8),
                           let chunk = try? self.decoder.decode(LMStudioStreamChunk.self, from: data),
                           let delta = chunk.choices.first?.delta {
                            
                            // Parse multi-channel responses
                            if let content = delta.content {
                                let channels = LocalModelResponseParser.parseChanneledResponse(content)
                                
                                for (channel, text) in channels {
                                    continuation.yield(.init(type: .channelStart(channel), content: nil))
                                    continuation.yield(.init(type: .textDelta, content: text))
                                    continuation.yield(.init(type: .channelEnd(channel), content: nil))
                                }
                            }
                            
                            // Handle tool calls - emit as text for now
                            if let toolCalls = delta.tool_calls {
                                for toolCall in toolCalls {
                                    if let name = toolCall.function?.name {
                                        continuation.yield(.init(type: .textDelta, content: "[Calling tool: \(name)]"))
                                    }
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
    
    // MARK: - Request Mapping
    
    private func mapToOpenAIRequest(_ request: ProviderRequest, streaming: Bool = false) throws -> LMStudioRequest {
        var messages: [[String: Any]] = []
        
        for message in request.messages {
            let msg: [String: Any] = [
                "role": message.role.rawValue,
                "content": message.content
            ]
            
            // Add metadata if present
            if message.metadata != nil {
                // For now, we'll skip metadata as it's not directly mappable
                // Future: Add channel support when LMStudio supports it
            }
            
            messages.append(msg)
        }
        
        var body: [String: Any] = [
            "model": modelId,
            "messages": messages,
            "stream": streaming
        ]
        
        // Map generation settings
        let settings = request.settings
        if let maxTokens = settings.maxTokens {
            body["max_tokens"] = maxTokens
        }
        if let temperature = settings.temperature {
            body["temperature"] = mapTemperatureForReasoningEffort(
                temperature,
                effort: settings.reasoningEffort
            )
        }
        if let topP = settings.topP {
            body["top_p"] = topP
        }
        if let stopSequences = settings.stopSequences {
            body["stop"] = stopSequences
        }
        
        // Map reasoning effort to LMStudio parameters
        if let effort = settings.reasoningEffort {
            let params = mapReasoningEffortToParams(effort)
            body.merge(params) { _, new in new }
        }
        
        // Add tools if present
        if let tools = request.tools {
            body["tools"] = tools.map { tool in
                [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": [
                            "type": "object",
                            "properties": tool.parameters.properties.reduce(into: [String: Any]()) { result, element in
                                let (key, prop) = element
                                result[key] = [
                                    "type": prop.type.rawValue,
                                    "description": prop.description
                                ]
                            },
                            "required": tool.parameters.required
                        ]
                    ]
                ]
            }
        }
        
        return LMStudioRequest(body: body)
    }
    
    private func mapReasoningEffortToParams(_ effort: ReasoningEffort) -> [String: Any] {
        switch effort {
        case .high:
            return [
                "repeat_penalty": 1.1,
                "presence_penalty": 0.1,
                "frequency_penalty": 0.1,
                "top_k": 50,
                "typical_p": 1.0,
                "min_p": 0.05,
                "tfs_z": 1.0,
                "mirostat": 0
            ]
        case .medium:
            return [
                "repeat_penalty": 1.05,
                "top_k": 40,
                "typical_p": 0.95,
                "min_p": 0.1
            ]
        case .low:
            return [
                "repeat_penalty": 1.0,
                "top_k": 30,
                "typical_p": 0.9,
                "min_p": 0.2
            ]
        }
    }
    
    private func mapTemperatureForReasoningEffort(_ base: Double, effort: ReasoningEffort?) -> Double {
        guard let effort = effort else { return base }
        
        switch effort {
        case .high:
            return min(base * 1.2, 1.5)  // Increase temperature for exploration
        case .medium:
            return base
        case .low:
            return base * 0.7  // Decrease for focused responses
        }
    }
    
    // MARK: - Response Mapping
    
    private func mapFromOpenAIResponse(_ response: LMStudioResponse, request: ProviderRequest) throws -> ProviderResponse {
        guard let choice = response.choices.first else {
            throw TachikomaError.apiError("No choices in response")
        }
        
        let content = choice.message.content ?? ""
        
        // Parse multi-channel responses
        let channels = LocalModelResponseParser.parseChanneledResponse(content)
        
        // Extract final response or use full content
        let finalText = channels[.final] ?? content
        
        return ProviderResponse(
            text: finalText,
            usage: response.usage.map { usage in
                Usage(
                    inputTokens: usage.prompt_tokens,
                    outputTokens: usage.completion_tokens,
                    cost: nil
                )
            },
            finishReason: mapFinishReason(choice.finish_reason),
            toolCalls: try choice.message.tool_calls?.map { toolCall in
                ToolCall(
                    id: toolCall.id,
                    name: toolCall.function.name,
                    arguments: try parseToolArguments(toolCall.function.arguments)
                )
            }
        )
    }
    
    private func mapFinishReason(_ reason: String?) -> FinishReason? {
        switch reason {
        case "stop": return .stop
        case "length": return .length
        case "tool_calls": return .toolCalls
        default: return nil
        }
    }
    
    private func parseToolArguments(_ json: String?) throws -> [String: ToolArgument] {
        guard let json = json,
              let data = json.data(using: .utf8) else {
            return [:]
        }
        
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        var args: [String: ToolArgument] = [:]
        
        for (key, value) in dict {
            if let string = value as? String {
                args[key] = .string(string)
            } else if let number = value as? Double {
                args[key] = .double(number)
            } else if let bool = value as? Bool {
                args[key] = .bool(bool)
            } else if let array = value as? [Any] {
                args[key] = .array(array.compactMap { item in
                    if let str = item as? String { return .string(str) }
                    if let num = item as? Double { return .double(num) }
                    if let bool = item as? Bool { return .bool(bool) }
                    return nil
                })
            } else if let object = value as? [String: Any] {
                args[key] = .object(object.compactMapValues { item in
                    if let str = item as? String { return .string(str) }
                    if let num = item as? Double { return .double(num) }
                    if let bool = item as? Bool { return .bool(bool) }
                    return nil
                })
            }
        }
        
        return args
    }
}

// MARK: - OpenAI Format Types

private struct LMStudioRequest: Encodable {
    let body: [String: Any]
    
    func encode(to encoder: Encoder) throws {
        // Convert dictionary to JSON data and then to a temporary encodable structure
        let data = try JSONSerialization.data(withJSONObject: body, options: [])
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        
        // Create a container and encode each key-value pair
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        if let dict = json as? [String: Any] {
            for (key, value) in dict {
                let codingKey = DynamicCodingKey(stringValue: key)!
                try encodeValue(value, forKey: codingKey, container: &container)
            }
        }
    }
    
    private func encodeValue(_ value: Any, forKey key: DynamicCodingKey, container: inout KeyedEncodingContainer<DynamicCodingKey>) throws {
        switch value {
        case let bool as Bool:
            try container.encode(bool, forKey: key)
        case let int as Int:
            try container.encode(int, forKey: key)
        case let double as Double:
            try container.encode(double, forKey: key)
        case let string as String:
            try container.encode(string, forKey: key)
        case let array as [Any]:
            var nestedContainer = container.nestedUnkeyedContainer(forKey: key)
            for item in array {
                try encodeArrayValue(item, container: &nestedContainer)
            }
        case let dict as [String: Any]:
            var nestedContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: key)
            for (nestedKey, nestedValue) in dict {
                let nestedCodingKey = DynamicCodingKey(stringValue: nestedKey)!
                try encodeValue(nestedValue, forKey: nestedCodingKey, container: &nestedContainer)
            }
        case is NSNull:
            try container.encodeNil(forKey: key)
        default:
            // Skip values we can't encode
            break
        }
    }
    
    private func encodeArrayValue(_ value: Any, container: inout UnkeyedEncodingContainer) throws {
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            var nestedContainer = container.nestedUnkeyedContainer()
            for item in array {
                try encodeArrayValue(item, container: &nestedContainer)
            }
        case let dict as [String: Any]:
            var nestedContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self)
            for (nestedKey, nestedValue) in dict {
                let nestedCodingKey = DynamicCodingKey(stringValue: nestedKey)!
                try encodeValue(nestedValue, forKey: nestedCodingKey, container: &nestedContainer)
            }
        case is NSNull:
            try container.encodeNil()
        default:
            // Skip values we can't encode
            break
        }
    }
}

// MARK: - OpenAI Format Types (continued)

private struct LMStudioResponse: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String?
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Decodable {
        let index: Int
        let message: Message
        let finish_reason: String?
        
        struct Message: Decodable {
            let role: String
            let content: String?
            let tool_calls: [ToolCall]?
            
            struct ToolCall: Decodable {
                let id: String
                let type: String
                let function: Function
                
                struct Function: Decodable {
                    let name: String
                    let arguments: String
                }
            }
        }
    }
    
    struct Usage: Decodable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }
}

private struct LMStudioStreamChunk: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String?
    let choices: [Choice]
    
    struct Choice: Decodable {
        let index: Int
        let delta: Delta
        let finish_reason: String?
        
        struct Delta: Decodable {
            let role: String?
            let content: String?
            let tool_calls: [ToolCall]?
            
            struct ToolCall: Decodable {
                let index: Int?
                let id: String?
                let type: String?
                let function: Function?
                
                struct Function: Decodable {
                    let name: String?
                    let arguments: String?
                }
            }
        }
    }
}

// MARK: - Response Parser

public struct LocalModelResponseParser {
    /// Parse multi-channel responses from local models
    public static func parseChanneledResponse(_ text: String) -> [ResponseChannel: String] {
        var channels: [ResponseChannel: String] = [:]
        
        // Parse XML-style tags
        if let thinking = extractTag(text, "thinking") {
            channels[.thinking] = thinking
        }
        if let analysis = extractTag(text, "analysis") {
            channels[.analysis] = analysis
        }
        if let commentary = extractTag(text, "commentary") {
            channels[.commentary] = commentary
        }
        if let final = extractTag(text, "final") {
            channels[.final] = final
        } else {
            // If no explicit final tag, clean the text of all tags
            let cleaned = removeAllTags(text)
            if !cleaned.isEmpty {
                channels[.final] = cleaned
            }
        }
        
        // If no channels found, treat entire text as final
        if channels.isEmpty {
            channels[.final] = text
        }
        
        return channels
    }
    
    private static func extractTag(_ text: String, _ tag: String) -> String? {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        
        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        guard let match = matches.first else { return nil }
        
        if match.numberOfRanges >= 2 {
            let contentRange = match.range(at: 1)
            return nsString.substring(with: contentRange)
        }
        
        return nil
    }
    
    private static func removeAllTags(_ text: String) -> String {
        let tags = ["thinking", "analysis", "commentary", "final"]
        var result = text
        
        for tag in tags {
            let pattern = "<\(tag)>.*?</\(tag)>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(location: 0, length: result.count),
                    withTemplate: ""
                )
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Error Types

public enum LMStudioError: Error, LocalizedError {
    case serverNotRunning
    case modelNotLoaded
    case insufficientMemory(required: Int, available: Int)
    case modelNotFound(String)
    case connectionFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .serverNotRunning:
            return "LMStudio server is not running. Please start the server in LMStudio."
        case .modelNotLoaded:
            return "No model is currently loaded in LMStudio."
        case .insufficientMemory(let required, let available):
            return "Insufficient memory: \(required)GB required, \(available)GB available."
        case .modelNotFound(let name):
            return "Model '\(name)' not found in LMStudio."
        case .connectionFailed(let error):
            return "Connection to LMStudio failed: \(error.localizedDescription)"
        }
    }
}