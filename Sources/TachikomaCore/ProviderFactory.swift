import Foundation

// MARK: - OpenAI API Types

struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double?
    let maxTokens: Int?
    let tools: [OpenAITool]?
    let stream: Bool?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, tools, stream
        case maxTokens = "max_tokens"
    }
}

struct OpenAIChatMessage: Codable {
    let role: String
    let content: Either<String, [OpenAIChatMessageContent]>
    let toolCallId: String?
    
    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCallId = "tool_call_id"
    }
    
    init(role: String, content: String, toolCallId: String? = nil) {
        self.role = role
        self.content = .left(content)
        self.toolCallId = toolCallId
    }
    
    init(role: String, content: [OpenAIChatMessageContent], toolCallId: String? = nil) {
        self.role = role
        self.content = .right(content)
        self.toolCallId = toolCallId
    }
}

enum OpenAIChatMessageContent: Codable {
    case text(TextContent)
    case imageUrl(ImageUrlContent)
    
    struct TextContent: Codable {
        let type: String
        let text: String
    }
    
    struct ImageUrlContent: Codable {
        let type: String
        let imageUrl: ImageUrl
        
        enum CodingKeys: String, CodingKey {
            case type
            case imageUrl = "image_url"
        }
    }
    
    struct ImageUrl: Codable {
        let url: String
    }
}

struct OpenAITool: Codable {
    let type: String
    let function: Function
    
    struct Function: Codable {
        let name: String
        let description: String
        let parameters: [String: Any]
        
        init(name: String, description: String, parameters: [String: Any]) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
        
        enum CodingKeys: String, CodingKey {
            case name, description, parameters
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            description = try container.decode(String.self, forKey: .description)
            
            // Decode parameters as generic dictionary
            if let data = try? container.decode(Data.self, forKey: .parameters),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                parameters = dict
            } else {
                parameters = [:]
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(description, forKey: .description)
            
            let data = try JSONSerialization.data(withJSONObject: parameters)
            try container.encode(data, forKey: .parameters)
        }
    }
}

struct OpenAIChatResponse: Codable {
    let id: String
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String?
        let toolCalls: [ToolCall]?
        
        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCalls = "tool_calls"
        }
    }
    
    struct ToolCall: Codable {
        let id: String
        let type: String
        let function: Function
        
        struct Function: Codable {
            let name: String
            let arguments: String
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct OpenAIStreamChunk: Codable {
    let id: String
    let choices: [Choice]
    
    struct Choice: Codable {
        let index: Int
        let delta: Delta
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, delta
            case finishReason = "finish_reason"
        }
    }
    
    struct Delta: Codable {
        let role: String?
        let content: String?
    }
}

struct OpenAIErrorResponse: Codable {
    let error: Error
    
    struct Error: Codable {
        let message: String
        let type: String?
        let code: String?
    }
}

// Helper type for Either content
enum Either<Left, Right>: Codable where Left: Codable, Right: Codable {
    case left(Left)
    case right(Right)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let leftValue = try? container.decode(Left.self) {
            self = .left(leftValue)
        } else if let rightValue = try? container.decode(Right.self) {
            self = .right(rightValue)
        } else {
            throw DecodingError.typeMismatch(Either.self, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Could not decode Either<\(Left.self), \(Right.self)>"
            ))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .left(let value):
            try container.encode(value)
        case .right(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Anthropic API Types

struct AnthropicMessageRequest: Codable {
    let model: String
    let maxTokens: Int
    let temperature: Double?
    let system: String?
    let messages: [AnthropicMessage]
    let tools: [AnthropicTool]?
    let stream: Bool?
    
    enum CodingKeys: String, CodingKey {
        case model, temperature, system, messages, tools, stream
        case maxTokens = "max_tokens"
    }
}

struct AnthropicMessage: Codable {
    let role: String
    let content: [AnthropicContent]
}

enum AnthropicContent: Codable {
    case text(TextContent)
    case image(ImageContent)
    
    struct TextContent: Codable {
        let type: String
        let text: String
    }
    
    struct ImageContent: Codable {
        let type: String
        let source: ImageSource
    }
    
    struct ImageSource: Codable {
        let type: String
        let mediaType: String
        let data: String
        
        enum CodingKeys: String, CodingKey {
            case type, data
            case mediaType = "media_type"
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            self = .text(try TextContent(from: decoder))
        case "image":
            self = .image(try ImageContent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type: \(type)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let content):
            try content.encode(to: encoder)
        case .image(let content):
            try content.encode(to: encoder)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
    }
}

struct AnthropicTool: Codable {
    let name: String
    let description: String
    let inputSchema: AnthropicInputSchema
    
    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

struct AnthropicInputSchema: Codable {
    let type: String
    let properties: [String: Any]
    let required: [String]
    
    init(type: String, properties: [String: Any], required: [String]) {
        self.type = type
        self.properties = properties
        self.required = required
    }
    
    enum CodingKeys: String, CodingKey {
        case type, properties, required
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        required = try container.decode([String].self, forKey: .required)
        
        if let data = try? container.decode(Data.self, forKey: .properties),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            properties = dict
        } else {
            properties = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(required, forKey: .required)
        
        let data = try JSONSerialization.data(withJSONObject: properties)
        try container.encode(data, forKey: .properties)
    }
}

struct AnthropicMessageResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [AnthropicResponseContent]
    let model: String
    let stopReason: String?
    let stopSequence: String?
    let usage: AnthropicUsage
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model, usage
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }
}

enum AnthropicResponseContent: Codable {
    case text(TextContent)
    case toolUse(ToolUseContent)
    
    struct TextContent: Codable {
        let type: String
        let text: String
    }
    
    struct ToolUseContent: Codable {
        let type: String
        let id: String
        let name: String
        let input: Any
        
        enum CodingKeys: String, CodingKey {
            case type, id, name, input
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(String.self, forKey: .type)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            
            // Decode input as generic value
            if let data = try? container.decode(Data.self, forKey: .input),
               let obj = try? JSONSerialization.jsonObject(with: data) {
                input = obj
            } else {
                input = [:]
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            
            let data = try JSONSerialization.data(withJSONObject: input)
            try container.encode(data, forKey: .input)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            self = .text(try TextContent(from: decoder))
        case "tool_use":
            self = .toolUse(try ToolUseContent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type: \(type)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let content):
            try content.encode(to: encoder)
        case .toolUse(let content):
            try content.encode(to: encoder)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
    }
}

struct AnthropicUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

struct AnthropicStreamChunk: Codable {
    let type: String
    let index: Int?
    let delta: AnthropicStreamDelta?
}

enum AnthropicStreamDelta: Codable {
    case textDelta(String)
    case other
    
    enum CodingKeys: String, CodingKey {
        case type, text
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text_delta":
            let text = try container.decode(String.self, forKey: .text)
            self = .textDelta(text)
        default:
            self = .other
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .textDelta(let text):
            try container.encode("text_delta", forKey: .type)
            try container.encode(text, forKey: .text)
        case .other:
            try container.encode("other", forKey: .type)
        }
    }
}

struct AnthropicErrorResponse: Codable {
    let type: String
    let error: Error
    
    struct Error: Codable {
        let type: String
        let message: String
    }
}

// MARK: - Provider Factory

/// Factory for creating model providers from LanguageModel enum
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ProviderFactory {
    
    /// Create a provider for the specified language model
    public static func createProvider(for model: LanguageModel) throws -> any ModelProvider {
        switch model {
        case .openai(let openaiModel):
            return try OpenAIProvider(model: openaiModel)
            
        case .anthropic(let anthropicModel):
            return try AnthropicProvider(model: anthropicModel)
            
        case .google(let googleModel):
            return try GoogleProvider(model: googleModel)
            
        case .mistral(let mistralModel):
            return try MistralProvider(model: mistralModel)
            
        case .groq(let groqModel):
            return try GroqProvider(model: groqModel)
            
        case .grok(let grokModel):
            return try GrokProvider(model: grokModel)
            
        case .ollama(let ollamaModel):
            return try OllamaProvider(model: ollamaModel)
            
        case .openRouter(let modelId):
            return try OpenRouterProvider(modelId: modelId)
            
        case .together(let modelId):
            return try TogetherProvider(modelId: modelId)
            
        case .replicate(let modelId):
            return try ReplicateProvider(modelId: modelId)
            
        case .openaiCompatible(let modelId, let baseURL):
            return try OpenAICompatibleProvider(modelId: modelId, baseURL: baseURL)
            
        case .anthropicCompatible(let modelId, let baseURL):
            return try AnthropicCompatibleProvider(modelId: modelId, baseURL: baseURL)
            
        case .custom(let provider):
            return provider
        }
    }
}

// MARK: - Provider Base Classes

/// Base provider for OpenAI-compatible APIs
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class OpenAIProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    
    private let model: LanguageModel.OpenAI
    
    public init(model: LanguageModel.OpenAI) throws {
        self.model = model
        self.modelId = model.modelId
        self.baseURL = "https://api.openai.com/v1"
        
        // Get API key from configuration system (environment or credentials)
        if let key = TachikomaConfiguration.shared.getAPIKey(for: "openai") {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("OPENAI_API_KEY not found")
        }
        
        self.capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            contextLength: model.contextLength,
            maxOutputTokens: 4096
        )
    }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        let url = URL(string: "\(self.baseURL!)/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(self.apiKey!)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let orgId = ProcessInfo.processInfo.environment["OPENAI_ORG_ID"] {
            urlRequest.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        // Convert request to OpenAI format
        let openAIRequest = OpenAIChatRequest(
            model: self.modelId,
            messages: try convertMessages(request.messages),
            temperature: request.settings.temperature,
            maxTokens: request.settings.maxTokens,
            tools: try convertTools(request.tools),
            stream: nil
        )
        
        let jsonData = try JSONEncoder().encode(openAIRequest)
        urlRequest.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw TachikomaError.apiError("OpenAI API Error: \(errorData.error.message)")
            } else {
                throw TachikomaError.apiError("OpenAI API Error: HTTP \(httpResponse.statusCode)")
            }
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        
        // Convert response back to ProviderResponse format
        let choice = openAIResponse.choices.first ?? OpenAIChatResponse.Choice(
            index: 0, 
            message: OpenAIChatResponse.Message(role: "assistant", content: "No response", toolCalls: nil),
            finishReason: "error"
        )
        
        let usage = openAIResponse.usage.map { 
            Usage(
                inputTokens: $0.promptTokens,
                outputTokens: $0.completionTokens
            )
        }
        
        return ProviderResponse(
            text: choice.message.content ?? "",
            usage: usage,
            finishReason: convertFinishReason(choice.finishReason),
            toolCalls: choice.message.toolCalls?.map { convertToolCall($0) }
        )
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        let url = URL(string: "\(self.baseURL!)/chat/completions")!
        var urlRequestBuilder = URLRequest(url: url)
        urlRequestBuilder.httpMethod = "POST"
        urlRequestBuilder.setValue("Bearer \(self.apiKey!)", forHTTPHeaderField: "Authorization")  
        urlRequestBuilder.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let orgId = ProcessInfo.processInfo.environment["OPENAI_ORG_ID"] {
            urlRequestBuilder.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        // Convert request to OpenAI format with streaming enabled
        let openAIRequest = OpenAIChatRequest(
            model: self.modelId,
            messages: try convertMessages(request.messages),
            temperature: request.settings.temperature,
            maxTokens: request.settings.maxTokens,
            tools: try convertTools(request.tools),
            stream: true
        )
        
        let jsonData = try JSONEncoder().encode(openAIRequest)
        urlRequestBuilder.httpBody = jsonData
        
        let finalUrlRequest = urlRequestBuilder // Make it immutable
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: finalUrlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: TachikomaError.networkError(NSError(domain: "Invalid response", code: 0)))
                        return
                    }
                    
                    if httpResponse.statusCode != 200 {
                        continuation.finish(throwing: TachikomaError.apiError("HTTP \(httpResponse.statusCode)"))
                        return
                    }
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            
                            if data == "[DONE]" {
                                continuation.yield(TextStreamDelta(type: .done))
                                continuation.finish()
                                return
                            }
                            
                            if let chunkData = data.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: chunkData) {
                                if let choice = chunk.choices.first,
                                   let content = choice.delta.content {
                                    continuation.yield(TextStreamDelta(type: .textDelta, content: content))
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
    
    private func convertMessages(_ messages: [ModelMessage]) throws -> [OpenAIChatMessage] {
        return try messages.map { message -> OpenAIChatMessage in
            switch message.role {
            case .system:
                if let textContent = message.content.first,
                   case let .text(text) = textContent {
                    return OpenAIChatMessage(role: "system", content: text)
                }
                throw TachikomaError.invalidInput("System message must have text content")
                
            case .user:
                if let textContent = message.content.first,
                   case let .text(text) = textContent {
                    return OpenAIChatMessage(role: "user", content: text)
                } else if message.content.count > 1 {
                    // Multi-modal message
                    let content = try message.content.map { part -> OpenAIChatMessageContent in
                        switch part {
                        case let .text(text):
                            return .text(OpenAIChatMessageContent.TextContent(type: "text", text: text))
                        case let .image(imageContent):
                            return .imageUrl(OpenAIChatMessageContent.ImageUrlContent(
                                type: "image_url",
                                imageUrl: OpenAIChatMessageContent.ImageUrl(url: "data:\(imageContent.mimeType);base64,\(imageContent.data)")
                            ))
                        default:
                            throw TachikomaError.invalidInput("Unsupported content type")
                        }
                    }
                    return OpenAIChatMessage(role: "user", content: content)
                }
                throw TachikomaError.invalidInput("User message must have content")
                
            case .assistant:
                if let textContent = message.content.first,
                   case let .text(text) = textContent {
                    return OpenAIChatMessage(role: "assistant", content: text)
                }
                throw TachikomaError.invalidInput("Assistant message must have text content")
                
            case .tool:
                if let toolResult = message.content.first,
                   case let .toolResult(result) = toolResult {
                    // Convert ToolArgument to string
                    let resultString: String
                    switch result.result {
                    case .string(let str):
                        resultString = str
                    case .int(let int):
                        resultString = String(int)
                    case .double(let double):
                        resultString = String(double)
                    case .bool(let bool):
                        resultString = String(bool)
                    case .null:
                        resultString = "null"
                    case .array(let array):
                        resultString = array.description
                    case .object(let object):
                        resultString = object.description
                    }
                    return OpenAIChatMessage(role: "tool", content: resultString, toolCallId: result.toolCallId)
                }
                throw TachikomaError.invalidInput("Tool message must have tool result content")
            }
        }
    }
    
    private func convertTools(_ tools: [SimpleTool]?) throws -> [OpenAITool]? {
        return tools?.map { tool in
            OpenAITool(
                type: "function",
                function: OpenAITool.Function(
                    name: tool.name,
                    description: tool.description,
                    parameters: ["type": "object", "properties": [:]]  // Simplified for now
                )
            )
        }
    }
    
    private func convertFinishReason(_ reason: String?) -> FinishReason {
        switch reason {
        case "stop": return .stop
        case "length": return .length
        case "tool_calls": return .toolCalls
        case "content_filter": return .contentFilter
        default: return .other
        }
    }
    
    private func convertToolCall(_ toolCall: OpenAIChatResponse.ToolCall) -> ToolCall {
        // Parse arguments JSON string into ToolArgument dictionary
        var arguments: [String: ToolArgument] = [:]
        if let argsData = toolCall.function.arguments.data(using: .utf8),
           let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
            for (key, value) in argsDict {
                if let toolArg = try? ToolArgument.from(any: value) {
                    arguments[key] = toolArg
                }
            }
        }
        
        return ToolCall(
            id: toolCall.id,
            name: toolCall.function.name,
            arguments: arguments
        )
    }
}

/// Provider for Anthropic Claude models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class AnthropicProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    
    private let model: LanguageModel.Anthropic
    
    public init(model: LanguageModel.Anthropic) throws {
        self.model = model
        self.modelId = model.modelId
        self.baseURL = "https://api.anthropic.com"
        
        // Get API key from configuration system (environment or credentials)
        if let key = TachikomaConfiguration.shared.getAPIKey(for: "anthropic") {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("ANTHROPIC_API_KEY not found")
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
        let url = URL(string: "\(self.baseURL!)/v1/messages")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(self.apiKey!, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        // Convert request to Anthropic format
        let anthropicRequest = AnthropicMessageRequest(
            model: self.modelId,
            maxTokens: request.settings.maxTokens ?? 4096,
            temperature: request.settings.temperature,
            system: extractSystemMessage(request.messages),
            messages: try convertAnthropicMessages(request.messages),
            tools: try convertAnthropicTools(request.tools),
            stream: nil
        )
        
        let jsonData = try JSONEncoder().encode(anthropicRequest)
        urlRequest.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data) {
                throw TachikomaError.apiError("Anthropic API Error: \(errorData.error.message)")
            } else {
                throw TachikomaError.apiError("Anthropic API Error: HTTP \(httpResponse.statusCode)")
            }
        }
        
        let anthropicResponse = try JSONDecoder().decode(AnthropicMessageResponse.self, from: data)
        
        // Convert response back to ProviderResponse format
        let text = anthropicResponse.content.compactMap { content in
            if case let .text(textContent) = content {
                return textContent.text
            }
            return nil
        }.joined()
        
        let usage = Usage(
            inputTokens: anthropicResponse.usage.inputTokens,
            outputTokens: anthropicResponse.usage.outputTokens
        )
        
        return ProviderResponse(
            text: text,
            usage: usage,
            finishReason: convertAnthropicFinishReason(anthropicResponse.stopReason),
            toolCalls: extractAnthropicToolCalls(anthropicResponse.content)
        )
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        let url = URL(string: "\(self.baseURL!)/v1/messages")!
        var urlRequestBuilder = URLRequest(url: url)
        urlRequestBuilder.httpMethod = "POST"
        urlRequestBuilder.setValue(self.apiKey!, forHTTPHeaderField: "x-api-key")
        urlRequestBuilder.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequestBuilder.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        // Convert request to Anthropic format with streaming enabled
        let anthropicRequest = AnthropicMessageRequest(
            model: self.modelId,
            maxTokens: request.settings.maxTokens ?? 4096,
            temperature: request.settings.temperature,
            system: extractSystemMessage(request.messages),
            messages: try convertAnthropicMessages(request.messages),
            tools: try convertAnthropicTools(request.tools),
            stream: true
        )
        
        let jsonData = try JSONEncoder().encode(anthropicRequest)
        urlRequestBuilder.httpBody = jsonData
        
        let finalUrlRequest = urlRequestBuilder
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: finalUrlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: TachikomaError.networkError(NSError(domain: "Invalid response", code: 0)))
                        return
                    }
                    
                    if httpResponse.statusCode != 200 {
                        continuation.finish(throwing: TachikomaError.apiError("HTTP \(httpResponse.statusCode)"))
                        return
                    }
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            
                            if data == "[DONE]" {
                                continuation.yield(TextStreamDelta(type: .done))
                                continuation.finish()
                                return
                            }
                            
                            if let chunkData = data.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(AnthropicStreamChunk.self, from: chunkData) {
                                if chunk.type == "content_block_delta",
                                   let delta = chunk.delta,
                                   case let .textDelta(text) = delta {
                                    continuation.yield(TextStreamDelta(type: .textDelta, content: text))
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
    
    // MARK: - Anthropic Helper Methods
    
    private func extractSystemMessage(_ messages: [ModelMessage]) -> String? {
        return messages.first { $0.role == .system }?.content.compactMap { part in
            if case let .text(text) = part {
                return text
            }
            return nil
        }.joined()
    }
    
    private func convertAnthropicMessages(_ messages: [ModelMessage]) throws -> [AnthropicMessage] {
        return try messages.compactMap { message -> AnthropicMessage? in
            // Skip system messages as they're handled separately
            guard message.role != .system else { return nil }
            
            switch message.role {
            case .user:
                let content = try message.content.map { part -> AnthropicContent in
                    switch part {
                    case let .text(text):
                        return .text(AnthropicContent.TextContent(type: "text", text: text))
                    case let .image(imageContent):
                        return .image(AnthropicContent.ImageContent(
                            type: "image",
                            source: AnthropicContent.ImageSource(
                                type: "base64",
                                mediaType: imageContent.mimeType,
                                data: imageContent.data
                            )
                        ))
                    default:
                        throw TachikomaError.invalidInput("Unsupported user content type")
                    }
                }
                return AnthropicMessage(role: "user", content: content)
                
            case .assistant:
                let content = message.content.compactMap { part -> AnthropicContent? in
                    if case let .text(text) = part {
                        return .text(AnthropicContent.TextContent(type: "text", text: text))
                    }
                    return nil
                }
                return AnthropicMessage(role: "assistant", content: content)
                
            case .tool:
                // Handle tool results
                if let toolResult = message.content.first,
                   case let .toolResult(result) = toolResult {
                    let resultString: String
                    switch result.result {
                    case .string(let str): resultString = str
                    case .int(let int): resultString = String(int)
                    case .double(let double): resultString = String(double)
                    case .bool(let bool): resultString = String(bool)
                    case .null: resultString = "null"
                    case .array(let array): resultString = array.description
                    case .object(let object): resultString = object.description
                    }
                    
                    return AnthropicMessage(
                        role: "user",
                        content: [.text(AnthropicContent.TextContent(
                            type: "text",
                            text: "Tool result for \(result.toolCallId): \(resultString)"
                        ))]
                    )
                }
                return nil
                
            case .system:
                return nil // Already handled
            }
        }
    }
    
    private func convertAnthropicTools(_ tools: [SimpleTool]?) throws -> [AnthropicTool]? {
        return tools?.map { tool in
            AnthropicTool(
                name: tool.name,
                description: tool.description,
                inputSchema: AnthropicInputSchema(
                    type: "object",
                    properties: [:], // Simplified for now
                    required: []
                )
            )
        }
    }
    
    private func convertAnthropicFinishReason(_ reason: String?) -> FinishReason {
        switch reason {
        case "end_turn": return .stop
        case "max_tokens": return .length
        case "tool_use": return .toolCalls
        default: return .other
        }
    }
    
    private func extractAnthropicToolCalls(_ content: [AnthropicResponseContent]) -> [ToolCall]? {
        let toolCalls = content.compactMap { content -> ToolCall? in
            if case let .toolUse(toolUse) = content {
                // Convert input to ToolArgument dictionary
                var arguments: [String: ToolArgument] = [:]
                if let inputDict = toolUse.input as? [String: Any] {
                    for (key, value) in inputDict {
                        if let toolArg = try? ToolArgument.from(any: value) {
                            arguments[key] = toolArg
                        }
                    }
                }
                
                return ToolCall(
                    id: toolUse.id,
                    name: toolUse.name,
                    arguments: arguments
                )
            }
            return nil
        }
        
        return toolCalls.isEmpty ? nil : toolCalls
    }
}

/// Provider for Google Gemini models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class GoogleProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    
    private let model: LanguageModel.Google
    
    public init(model: LanguageModel.Google) throws {
        self.model = model
        self.modelId = model.rawValue
        self.baseURL = "https://generativelanguage.googleapis.com/v1beta"
        
        if let key = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] {
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
        throw TachikomaError.unsupportedOperation("Google provider not yet implemented")
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Google streaming not yet implemented")
    }
}

/// Provider for Mistral models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class MistralProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    
    private let model: LanguageModel.Mistral
    
    public init(model: LanguageModel.Mistral) throws {
        self.model = model
        self.modelId = model.rawValue
        self.baseURL = "https://api.mistral.ai/v1"
        
        if let key = ProcessInfo.processInfo.environment["MISTRAL_API_KEY"] {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("MISTRAL_API_KEY not found")
        }
        
        self.capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            contextLength: model.contextLength,
            maxOutputTokens: 4096
        )
    }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Mistral provider not yet implemented")
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Mistral streaming not yet implemented")
    }
}

/// Provider for Groq models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class GroqProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    
    private let model: LanguageModel.Groq
    
    public init(model: LanguageModel.Groq) throws {
        self.model = model
        self.modelId = model.rawValue
        self.baseURL = "https://api.groq.com/openai/v1"
        
        if let key = ProcessInfo.processInfo.environment["GROQ_API_KEY"] {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("GROQ_API_KEY not found")
        }
        
        self.capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            contextLength: model.contextLength,
            maxOutputTokens: 4096
        )
    }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Groq provider not yet implemented")
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Groq streaming not yet implemented")
    }
}

/// Provider for Grok (xAI) models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class GrokProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    
    private let model: LanguageModel.Grok
    
    public init(model: LanguageModel.Grok) throws {
        self.model = model
        self.modelId = model.modelId
        self.baseURL = "https://api.x.ai/v1"
        
        // Support both X_AI_API_KEY and XAI_API_KEY environment variables
        if let key = ProcessInfo.processInfo.environment["X_AI_API_KEY"] ?? 
                     ProcessInfo.processInfo.environment["XAI_API_KEY"] {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("X_AI_API_KEY or XAI_API_KEY not found")
        }
        
        self.capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            contextLength: model.contextLength,
            maxOutputTokens: 4096
        )
    }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Grok provider not yet implemented")
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Grok streaming not yet implemented")
    }
}

/// Provider for Ollama models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class OllamaProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    
    private let model: LanguageModel.Ollama
    
    public init(model: LanguageModel.Ollama) throws {
        self.model = model
        self.modelId = model.modelId
        self.baseURL = ProcessInfo.processInfo.environment["OLLAMA_BASE_URL"] ?? "http://localhost:11434"
        self.apiKey = nil // Ollama doesn't require API keys
        
        self.capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            contextLength: model.contextLength,
            maxOutputTokens: 4096
        )
    }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Ollama provider not yet implemented")
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Ollama streaming not yet implemented")
    }
}

// MARK: - Third-Party Aggregators

/// Provider for OpenRouter models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class OpenRouterProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    
    public init(modelId: String) throws {
        self.modelId = modelId
        self.baseURL = "https://openrouter.ai/api/v1"
        
        if let key = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("OPENROUTER_API_KEY not found")
        }
        
        self.capabilities = ModelCapabilities(
            supportsVision: false, // Unknown, assume no vision
            supportsTools: true,
            supportsStreaming: true,
            contextLength: 128_000,
            maxOutputTokens: 4096
        )
    }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("OpenRouter provider not yet implemented")
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("OpenRouter streaming not yet implemented")
    }
}

/// Provider for Together AI models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class TogetherProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    
    public init(modelId: String) throws {
        self.modelId = modelId
        self.baseURL = "https://api.together.xyz/v1"
        
        if let key = ProcessInfo.processInfo.environment["TOGETHER_API_KEY"] {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("TOGETHER_API_KEY not found")
        }
        
        self.capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTools: true,
            supportsStreaming: true,
            contextLength: 128_000,
            maxOutputTokens: 4096
        )
    }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Together provider not yet implemented")
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Together streaming not yet implemented")
    }
}

/// Provider for Replicate models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class ReplicateProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    
    public init(modelId: String) throws {
        self.modelId = modelId
        self.baseURL = "https://api.replicate.com/v1"
        
        if let key = ProcessInfo.processInfo.environment["REPLICATE_API_TOKEN"] {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("REPLICATE_API_TOKEN not found")
        }
        
        self.capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTools: false, // Most Replicate models don't support tools
            supportsStreaming: true,
            contextLength: 32_000,
            maxOutputTokens: 4096
        )
    }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Replicate provider not yet implemented")
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Replicate streaming not yet implemented")
    }
}

// MARK: - Compatible Providers

/// Provider for OpenAI-compatible APIs
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class OpenAICompatibleProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    
    public init(modelId: String, baseURL: String) throws {
        self.modelId = modelId
        self.baseURL = baseURL
        
        // Try common environment variable patterns
        if let key = ProcessInfo.processInfo.environment["OPENAI_COMPATIBLE_API_KEY"] ?? 
                     ProcessInfo.processInfo.environment["API_KEY"] {
            self.apiKey = key
        } else {
            self.apiKey = nil // Some compatible APIs don't require keys
        }
        
        self.capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTools: true,
            supportsStreaming: true,
            contextLength: 128_000,
            maxOutputTokens: 4096
        )
    }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("OpenAI-compatible provider not yet implemented")
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("OpenAI-compatible streaming not yet implemented")
    }
}

/// Provider for Anthropic-compatible APIs
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class AnthropicCompatibleProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    
    public init(modelId: String, baseURL: String) throws {
        self.modelId = modelId
        self.baseURL = baseURL
        
        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_COMPATIBLE_API_KEY"] ?? 
                     ProcessInfo.processInfo.environment["API_KEY"] {
            self.apiKey = key
        } else {
            self.apiKey = nil
        }
        
        self.capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTools: true,
            supportsStreaming: true,
            contextLength: 200_000,
            maxOutputTokens: 8192
        )
    }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Anthropic-compatible provider not yet implemented")
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Anthropic-compatible streaming not yet implemented")
    }
}