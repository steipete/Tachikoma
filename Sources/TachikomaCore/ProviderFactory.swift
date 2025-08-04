import Foundation

// MARK: - Helper Types

/// A coding key that can represent any string
struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

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
    let content: Either<String, [OpenAIChatMessageContent]>?
    let toolCallId: String?
    let toolCalls: [ToolCall]?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCallId = "tool_call_id"
        case toolCalls = "tool_calls"
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

    init(role: String, content: String, toolCallId: String? = nil) {
        self.role = role
        self.content = .left(content)
        self.toolCallId = toolCallId
        self.toolCalls = nil
    }

    init(role: String, content: [OpenAIChatMessageContent], toolCallId: String? = nil) {
        self.role = role
        self.content = .right(content)
        self.toolCallId = toolCallId
        self.toolCalls = nil
    }

    init(role: String, content: String? = nil, toolCalls: [ToolCall]?) {
        self.role = role
        self.content = content.map { .left($0) }
        self.toolCallId = nil
        self.toolCalls = toolCalls
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
            self.name = try container.decode(String.self, forKey: .name)
            self.description = try container.decode(String.self, forKey: .description)

            // Decode parameters as generic dictionary
            if
                let data = try? container.decode(Data.self, forKey: .parameters),
                let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                self.parameters = dict
            } else {
                self.parameters = [:]
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.name, forKey: .name)
            try container.encode(self.description, forKey: .description)

            // Encode parameters as a nested JSON structure
            var parametersContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .parameters)
            try encodeAnyValue(self.parameters, to: &parametersContainer)
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
        case let .left(value):
            try container.encode(value)
        case let .right(value):
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
            self = try .text(TextContent(from: decoder))
        case "image":
            self = try .image(ImageContent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .text(content):
            try content.encode(to: encoder)
        case let .image(content):
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
        self.type = try container.decode(String.self, forKey: .type)
        self.required = try container.decode([String].self, forKey: .required)

        if
            let data = try? container.decode(Data.self, forKey: .properties),
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            self.properties = dict
        } else {
            self.properties = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.required, forKey: .required)

        // Encode properties directly as JSON object, not as base64 data
        var propertiesContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .properties)
        try self.encodeAnyDictionary(self.properties, to: &propertiesContainer)
    }

    private func encodeAnyDictionary(
        _ dict: [String: Any],
        to container: inout KeyedEncodingContainer<AnyCodingKey>
    ) throws {
        for (key, value) in dict {
            let codingKey = AnyCodingKey(stringValue: key)!

            switch value {
            case let stringValue as String:
                try container.encode(stringValue, forKey: codingKey)
            case let intValue as Int:
                try container.encode(intValue, forKey: codingKey)
            case let doubleValue as Double:
                try container.encode(doubleValue, forKey: codingKey)
            case let boolValue as Bool:
                try container.encode(boolValue, forKey: codingKey)
            case let arrayValue as [Any]:
                // Encode arrays properly (this is complex, but for tool schemas we likely won't need complex arrays)
                let jsonData = try JSONSerialization.data(withJSONObject: arrayValue)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                try container.encode(jsonString, forKey: codingKey)
            case let dictValue as [String: Any]:
                // Encode nested objects properly as nested containers
                var nestedContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: codingKey)
                try self.encodeAnyDictionary(dictValue, to: &nestedContainer)
            default:
                // Fallback: convert to string
                try container.encode(String(describing: value), forKey: codingKey)
            }
        }
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
            self.type = try container.decode(String.self, forKey: .type)
            self.id = try container.decode(String.self, forKey: .id)
            self.name = try container.decode(String.self, forKey: .name)

            // Decode input as generic value
            // Try to decode directly as a JSON object first (standard Anthropic API format)
            if container.contains(.input) {
                // Use a nestedContainer to get the raw JSON value
                do {
                    let inputContainer = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .input)
                    // Convert the nested container to a dictionary
                    var inputDict: [String: Any] = [:]
                    for key in inputContainer.allKeys {
                        if let stringValue = try? inputContainer.decode(String.self, forKey: key) {
                            inputDict[key.stringValue] = stringValue
                        } else if let intValue = try? inputContainer.decode(Int.self, forKey: key) {
                            inputDict[key.stringValue] = intValue
                        } else if let doubleValue = try? inputContainer.decode(Double.self, forKey: key) {
                            inputDict[key.stringValue] = doubleValue
                        } else if let boolValue = try? inputContainer.decode(Bool.self, forKey: key) {
                            inputDict[key.stringValue] = boolValue
                        }
                        // Add more types as needed
                    }
                    self.input = inputDict
                } catch {
                    // Fallback to the old Data-based approach
                    if
                        let data = try? container.decode(Data.self, forKey: .input),
                        let obj = try? JSONSerialization.jsonObject(with: data)
                    {
                        self.input = obj
                    } else {
                        self.input = [:]
                    }
                }
            } else {
                self.input = [:]
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.type, forKey: .type)
            try container.encode(self.id, forKey: .id)
            try container.encode(self.name, forKey: .name)

            let data = try JSONSerialization.data(withJSONObject: self.input)
            try container.encode(data, forKey: .input)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            self = try .text(TextContent(from: decoder))
        case "tool_use":
            self = try .toolUse(ToolUseContent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .text(content):
            try content.encode(to: encoder)
        case let .toolUse(content):
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
        case let .textDelta(text):
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

// MARK: - Ollama API Types

struct OllamaChatRequest: Codable {
    let model: String
    let messages: [OllamaChatMessage]
    let tools: [OllamaTool]?
    let stream: Bool?
    let options: OllamaOptions?

    struct OllamaOptions: Codable {
        let temperature: Double?
        let numCtx: Int? // Context length
        let numPredict: Int? // Max tokens

        enum CodingKeys: String, CodingKey {
            case temperature
            case numCtx = "num_ctx"
            case numPredict = "num_predict"
        }
    }
}

struct OllamaChatMessage: Codable {
    let role: String
    let content: String
    let toolCalls: [OllamaToolCall]?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
    }

    init(role: String, content: String, toolCalls: [OllamaToolCall]? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
    }
}

struct OllamaToolCall: Codable {
    let function: Function

    struct Function: Codable {
        let name: String
        let arguments: [String: Any]

        init(name: String, arguments: [String: Any]) {
            self.name = name
            self.arguments = arguments
        }

        enum CodingKeys: String, CodingKey {
            case name, arguments
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)

            // Decode arguments as generic dictionary
            if
                let data = try? container.decode(Data.self, forKey: .arguments),
                let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                self.arguments = dict
            } else {
                self.arguments = [:]
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.name, forKey: .name)

            let data = try JSONSerialization.data(withJSONObject: self.arguments)
            try container.encode(data, forKey: .arguments)
        }
    }
}

struct OllamaTool: Codable {
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
            self.name = try container.decode(String.self, forKey: .name)
            self.description = try container.decode(String.self, forKey: .description)

            // Decode parameters as generic dictionary
            if
                let data = try? container.decode(Data.self, forKey: .parameters),
                let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                self.parameters = dict
            } else {
                self.parameters = [:]
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.name, forKey: .name)
            try container.encode(self.description, forKey: .description)

            // Encode parameters directly as JSON object, not as base64 data
            var parametersContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .parameters)
            try self.encodeAnyDictionary(self.parameters, to: &parametersContainer)
        }

        private func encodeAnyDictionary(
            _ dict: [String: Any],
            to container: inout KeyedEncodingContainer<AnyCodingKey>
        ) throws {
            for (key, value) in dict {
                guard let codingKey = AnyCodingKey(stringValue: key) else { continue }
                switch value {
                case let stringValue as String:
                    try container.encode(stringValue, forKey: codingKey)
                case let intValue as Int:
                    try container.encode(intValue, forKey: codingKey)
                case let doubleValue as Double:
                    try container.encode(doubleValue, forKey: codingKey)
                case let boolValue as Bool:
                    try container.encode(boolValue, forKey: codingKey)
                case let arrayValue as [Any]:
                    try container.encode(arrayValue.map { String(describing: $0) }, forKey: codingKey)
                case let dictValue as [String: Any]:
                    // Encode nested objects properly as nested containers
                    var nestedContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: codingKey)
                    try self.encodeAnyDictionary(dictValue, to: &nestedContainer)
                default:
                    // Fallback: convert to string
                    try container.encode(String(describing: value), forKey: codingKey)
                }
            }
        }
    }
}

struct OllamaChatResponse: Codable {
    let model: String
    let message: Message
    let done: Bool
    let totalDuration: Int?
    let loadDuration: Int?
    let promptEvalCount: Int?
    let promptEvalDuration: Int?
    let evalCount: Int?
    let evalDuration: Int?

    enum CodingKeys: String, CodingKey {
        case model, message, done
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case promptEvalCount = "prompt_eval_count"
        case promptEvalDuration = "prompt_eval_duration"
        case evalCount = "eval_count"
        case evalDuration = "eval_duration"
    }

    struct Message: Codable {
        let role: String
        let content: String
        let toolCalls: [OllamaToolCall]?

        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCalls = "tool_calls"
        }
    }
}

struct OllamaStreamChunk: Codable {
    let model: String
    let message: Delta
    let done: Bool

    struct Delta: Codable {
        let role: String?
        let content: String?
    }
}

struct OllamaErrorResponse: Codable {
    let error: String
}

// MARK: - Provider Factory

/// Factory for creating model providers from LanguageModel enum
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ProviderFactory {
    /// Create a provider for the specified language model
    public static func createProvider(for model: LanguageModel) throws -> any ModelProvider {
        // Check if we're in test mode or if API tests are disabled
        if TachikomaConfiguration.shared.isTestMode || 
           ProcessInfo.processInfo.environment["TACHIKOMA_DISABLE_API_TESTS"] == "true" ||
           ProcessInfo.processInfo.environment["TACHIKOMA_TEST_MODE"] == "mock" {
            return MockProvider(model: model)
        }
        
        switch model {
        case let .openai(openaiModel):
            return try OpenAIProvider(model: openaiModel)

        case let .anthropic(anthropicModel):
            return try AnthropicProvider(model: anthropicModel)

        case let .google(googleModel):
            return try GoogleProvider(model: googleModel)

        case let .mistral(mistralModel):
            return try MistralProvider(model: mistralModel)

        case let .groq(groqModel):
            return try GroqProvider(model: groqModel)

        case let .grok(grokModel):
            return try GrokProvider(model: grokModel)

        case let .ollama(ollamaModel):
            return try OllamaProvider(model: ollamaModel)

        case let .openRouter(modelId):
            return try OpenRouterProvider(modelId: modelId)

        case let .together(modelId):
            return try TogetherProvider(modelId: modelId)

        case let .replicate(modelId):
            return try ReplicateProvider(modelId: modelId)

        case let .openaiCompatible(modelId, baseURL):
            return try OpenAICompatibleProvider(modelId: modelId, baseURL: baseURL)

        case let .anthropicCompatible(modelId, baseURL):
            return try AnthropicCompatibleProvider(modelId: modelId, baseURL: baseURL)

        case let .custom(provider):
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
        let openAIRequest = try OpenAIChatRequest(
            model: self.modelId,
            messages: self.convertMessages(request.messages),
            temperature: request.settings.temperature,
            maxTokens: request.settings.maxTokens,
            tools: self.convertTools(request.tools),
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
            finishReason: self.convertFinishReason(choice.finishReason),
            toolCalls: choice.message.toolCalls?.map { self.convertToolCall($0) }
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
        let openAIRequest = try OpenAIChatRequest(
            model: self.modelId,
            messages: self.convertMessages(request.messages),
            temperature: request.settings.temperature,
            maxTokens: request.settings.maxTokens,
            tools: self.convertTools(request.tools),
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
                        continuation.finish(throwing: TachikomaError.networkError(NSError(
                            domain: "Invalid response",
                            code: 0
                        )))
                        return
                    }

                    if httpResponse.statusCode != 200 {
                        continuation.finish(throwing: TachikomaError.apiError("HTTP \(httpResponse.statusCode)"))
                        return
                    }

                    for try await line in bytes.lines where line.hasPrefix("data: ") {
                        let data = String(line.dropFirst(6))

                        if data == "[DONE]" {
                            continuation.yield(TextStreamDelta(type: .done))
                            continuation.finish()
                            return
                        }

                        if
                            let chunkData = data.data(using: .utf8),
                            let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: chunkData)
                        {
                            if
                                let choice = chunk.choices.first,
                                let content = choice.delta.content
                            {
                                continuation.yield(TextStreamDelta(type: .textDelta, content: content))
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

    private func convertToolArgumentsToSerializable(_ arguments: [String: ToolArgument]) throws -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in arguments {
            result[key] = try self.convertToolArgumentToSerializable(value)
        }
        return result
    }

    private func convertToolArgumentToSerializable(_ argument: ToolArgument) throws -> Any {
        switch argument {
        case let .string(str):
            return str
        case let .int(int):
            return int
        case let .double(double):
            return double
        case let .bool(bool):
            return bool
        case .null:
            return NSNull()
        case let .array(array):
            return try array.map { try self.convertToolArgumentToSerializable($0) }
        case let .object(object):
            return try self.convertToolArgumentsToSerializable(object)
        }
    }

    private func convertMessages(_ messages: [ModelMessage]) throws -> [OpenAIChatMessage] {
        try messages.map { message -> OpenAIChatMessage in
            switch message.role {
            case .system:
                if
                    let textContent = message.content.first,
                    case let .text(text) = textContent
                {
                    return OpenAIChatMessage(role: "system", content: text)
                }
                throw TachikomaError.invalidInput("System message must have text content")

            case .user:
                if
                    let textContent = message.content.first,
                    case let .text(text) = textContent
                {
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
                                imageUrl: OpenAIChatMessageContent
                                    .ImageUrl(url: "data:\(imageContent.mimeType);base64,\(imageContent.data)")
                            ))
                        default:
                            throw TachikomaError.invalidInput("Unsupported content type")
                        }
                    }
                    return OpenAIChatMessage(role: "user", content: content)
                }
                throw TachikomaError.invalidInput("User message must have content")

            case .assistant:
                // Extract text content
                var textContent: String? = nil
                var toolCalls: [OpenAIChatMessage.ToolCall] = []
                
                for part in message.content {
                    switch part {
                    case let .text(text):
                        textContent = text
                    case let .toolCall(toolCall):
                        // Convert ToolArgument dictionary to JSON-serializable dictionary
                        let serializableArgs = try self.convertToolArgumentsToSerializable(toolCall.arguments)
                        let argumentsData = try JSONSerialization.data(withJSONObject: serializableArgs)
                        let argumentsString = String(data: argumentsData, encoding: .utf8) ?? "{}"
                        let openAIToolCall = OpenAIChatMessage.ToolCall(
                            id: toolCall.id,
                            type: "function",
                            function: OpenAIChatMessage.ToolCall.Function(
                                name: toolCall.name,
                                arguments: argumentsString
                            )
                        )
                        toolCalls.append(openAIToolCall)
                    default:
                        throw TachikomaError.invalidInput("Unsupported assistant message content type")
                    }
                }
                
                if !toolCalls.isEmpty {
                    // Assistant message with tool calls
                    return OpenAIChatMessage(role: "assistant", content: textContent, toolCalls: toolCalls)
                } else if let text = textContent {
                    // Regular assistant message
                    return OpenAIChatMessage(role: "assistant", content: text)
                } else {
                    throw TachikomaError.invalidInput("Assistant message must have text or tool call content")
                }

            case .tool:
                if
                    let toolResult = message.content.first,
                    case let .toolResult(result) = toolResult
                {
                    // Convert ToolArgument to string
                    let resultString: String = switch result.result {
                    case let .string(str):
                        str
                    case let .int(int):
                        String(int)
                    case let .double(double):
                        String(double)
                    case let .bool(bool):
                        String(bool)
                    case .null:
                        "null"
                    case let .array(array):
                        array.description
                    case let .object(object):
                        object.description
                    }
                    return OpenAIChatMessage(role: "tool", content: resultString, toolCallId: result.toolCallId)
                }
                throw TachikomaError.invalidInput("Tool message must have tool result content")
            }
        }
    }

    private func convertTools(_ tools: [SimpleTool]?) throws -> [OpenAITool]? {
        if let tools = tools {
            print("DEBUG: OpenAI convertTools called with \(tools.count) tools")
        }
        return tools?.map { tool in
            print("DEBUG: Converting tool '\(tool.name)' with \(tool.parameters.properties.count) parameters")
            // Convert ToolParameters to OpenAI format
            var properties: [String: Any] = [:]

            for (paramName, paramProp) in tool.parameters.properties {
                var propDict: [String: Any] = [:]

                // Map parameter type
                switch paramProp.type {
                case .string:
                    propDict["type"] = "string"
                case .integer:
                    propDict["type"] = "integer"
                case .number:
                    propDict["type"] = "number"
                case .boolean:
                    propDict["type"] = "boolean"
                case .array:
                    propDict["type"] = "array"
                case .object:
                    propDict["type"] = "object"
                case .null:
                    propDict["type"] = "null"
                }

                // Add description if available
                if let description = paramProp.description {
                    propDict["description"] = description
                }

                // Add enum values if available
                if let enumValues = paramProp.enumValues {
                    propDict["enum"] = enumValues
                }

                properties[paramName] = propDict
            }

            let parametersObj = [
                "type": "object",
                "properties": properties,
                "required": tool.parameters.required,
            ]
            print("DEBUG: Tool '\(tool.name)' final parameters: \(parametersObj)")
            return OpenAITool(
                type: "function",
                function: OpenAITool.Function(
                    name: tool.name,
                    description: tool.description,
                    parameters: parametersObj
                )
            )
        }
    }

    private func convertFinishReason(_ reason: String?) -> FinishReason {
        switch reason {
        case "stop": .stop
        case "length": .length
        case "tool_calls": .toolCalls
        case "content_filter": .contentFilter
        default: .other
        }
    }

    private func convertToolCall(_ toolCall: OpenAIChatResponse.ToolCall) -> ToolCall {
        // Parse arguments JSON string into ToolArgument dictionary
        var arguments: [String: ToolArgument] = [:]
        if
            let argsData = toolCall.function.arguments.data(using: .utf8),
            let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any]
        {
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
        let anthropicRequest = try AnthropicMessageRequest(
            model: self.modelId,
            maxTokens: request.settings.maxTokens ?? 4096,
            temperature: request.settings.temperature,
            system: self.extractSystemMessage(request.messages),
            messages: self.convertAnthropicMessages(request.messages),
            tools: self.convertAnthropicTools(request.tools),
            stream: nil
        )

        let jsonData = try JSONEncoder().encode(anthropicRequest)
        urlRequest.httpBody = jsonData

        // Debug: Print the JSON being sent to Anthropic (only in verbose mode)
        if
            let jsonString = String(data: jsonData, encoding: .utf8),
            ProcessInfo.processInfo.arguments.contains("--verbose") ||
                ProcessInfo.processInfo.arguments.contains("-v")
        {
            print("DEBUG: Anthropic API Request JSON:")
            print(jsonString)
        }

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

        // Debug: Log raw API response in verbose mode
        if
            ProcessInfo.processInfo.arguments.contains("--verbose") ||
                ProcessInfo.processInfo.arguments.contains("-v")
        {
            if let responseString = String(data: data, encoding: .utf8) {
                print("DEBUG ProviderFactory: Raw Anthropic API Response:")
                print(responseString)
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
            finishReason: self.convertAnthropicFinishReason(anthropicResponse.stopReason),
            toolCalls: self.extractAnthropicToolCalls(anthropicResponse.content)
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
        let anthropicRequest = try AnthropicMessageRequest(
            model: self.modelId,
            maxTokens: request.settings.maxTokens ?? 4096,
            temperature: request.settings.temperature,
            system: self.extractSystemMessage(request.messages),
            messages: self.convertAnthropicMessages(request.messages),
            tools: self.convertAnthropicTools(request.tools),
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
                        continuation.finish(throwing: TachikomaError.networkError(NSError(
                            domain: "Invalid response",
                            code: 0
                        )))
                        return
                    }

                    if httpResponse.statusCode != 200 {
                        continuation.finish(throwing: TachikomaError.apiError("HTTP \(httpResponse.statusCode)"))
                        return
                    }

                    for try await line in bytes.lines where line.hasPrefix("data: ") {
                        let data = String(line.dropFirst(6))

                        if data == "[DONE]" {
                            continuation.yield(TextStreamDelta(type: .done))
                            continuation.finish()
                            return
                        }

                        if
                            let chunkData = data.data(using: .utf8),
                            let chunk = try? JSONDecoder().decode(AnthropicStreamChunk.self, from: chunkData)
                        {
                            if
                                chunk.type == "content_block_delta",
                                let delta = chunk.delta,
                                case let .textDelta(text) = delta
                            {
                                continuation.yield(TextStreamDelta(type: .textDelta, content: text))
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
        messages.first { $0.role == .system }?.content.compactMap { part in
            if case let .text(text) = part {
                return text
            }
            return nil
        }.joined()
    }

    private func convertAnthropicMessages(_ messages: [ModelMessage]) throws -> [AnthropicMessage] {
        try messages.compactMap { message -> AnthropicMessage? in
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
                if
                    let toolResult = message.content.first,
                    case let .toolResult(result) = toolResult
                {
                    let resultString: String = switch result.result {
                    case let .string(str): str
                    case let .int(int): String(int)
                    case let .double(double): String(double)
                    case let .bool(bool): String(bool)
                    case .null: "null"
                    case let .array(array): array.description
                    case let .object(object): object.description
                    }

                    return AnthropicMessage(
                        role: "user",
                        content: [.text(AnthropicContent.TextContent(
                            type: "text",
                            text: "Tool result for \(result.toolCallId): \(resultString)"
                        )),]
                    )
                }
                return nil

            case .system:
                return nil // Already handled
            }
        }
    }

    private func convertAnthropicTools(_ tools: [SimpleTool]?) throws -> [AnthropicTool]? {
        tools?.map { tool in
            // Convert ToolParameters to Anthropic format
            var properties: [String: Any] = [:]

            for (paramName, paramProp) in tool.parameters.properties {
                var propDict: [String: Any] = [:]

                // Map parameter type
                switch paramProp.type {
                case .string:
                    propDict["type"] = "string"
                case .integer:
                    propDict["type"] = "integer"
                case .number:
                    propDict["type"] = "number"
                case .boolean:
                    propDict["type"] = "boolean"
                case .array:
                    propDict["type"] = "array"
                case .object:
                    propDict["type"] = "object"
                case .null:
                    propDict["type"] = "null"
                }

                // Add description if available
                if let description = paramProp.description {
                    propDict["description"] = description
                }

                // Add enum values if available
                if let enumValues = paramProp.enumValues {
                    propDict["enum"] = enumValues
                }

                properties[paramName] = propDict
            }

            return AnthropicTool(
                name: tool.name,
                description: tool.description,
                inputSchema: AnthropicInputSchema(
                    type: "object",
                    properties: properties,
                    required: tool.parameters.required
                )
            )
        }
    }

    private func convertAnthropicFinishReason(_ reason: String?) -> FinishReason {
        switch reason {
        case "end_turn": .stop
        case "max_tokens": .length
        case "tool_use": .toolCalls
        default: .other
        }
    }

    private func extractAnthropicToolCalls(_ content: [AnthropicResponseContent]) -> [ToolCall]? {
        let toolCalls = content.compactMap { content -> ToolCall? in
            if case let .toolUse(toolUse) = content {
                // Debug: Log raw tool use content in verbose mode
                if
                    ProcessInfo.processInfo.arguments.contains("--verbose") ||
                        ProcessInfo.processInfo.arguments.contains("-v")
                {
                    print("DEBUG ProviderFactory: Raw tool use:")
                    print("  name: \(toolUse.name)")
                    print("  id: \(toolUse.id)")
                    print("  input type: \(type(of: toolUse.input))")
                    print("  input: \(toolUse.input)")
                }

                // Convert input to ToolArgument dictionary
                var arguments: [String: ToolArgument] = [:]
                if let inputDict = toolUse.input as? [String: Any] {
                    if
                        ProcessInfo.processInfo.arguments.contains("--verbose") ||
                            ProcessInfo.processInfo.arguments.contains("-v")
                    {
                        print("DEBUG ProviderFactory: Input dictionary has \(inputDict.count) keys:")
                        for (key, value) in inputDict {
                            print("  \(key): \(value) (type: \(type(of: value)))")
                        }
                    }

                    for (key, value) in inputDict {
                        if let toolArg = try? ToolArgument.from(any: value) {
                            arguments[key] = toolArg
                        } else {
                            if
                                ProcessInfo.processInfo.arguments.contains("--verbose") ||
                                    ProcessInfo.processInfo.arguments.contains("-v")
                            {
                                print("DEBUG ProviderFactory: Failed to convert \(key): \(value) to ToolArgument")
                            }
                        }
                    }
                } else {
                    if
                        ProcessInfo.processInfo.arguments.contains("--verbose") ||
                            ProcessInfo.processInfo.arguments.contains("-v")
                    {
                        print("DEBUG ProviderFactory: Input is not a dictionary or is nil")
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
        if
            let key = ProcessInfo.processInfo.environment["X_AI_API_KEY"] ??
                ProcessInfo.processInfo.environment["XAI_API_KEY"]
        {
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
        let url = URL(string: "\(self.baseURL!)/api/chat")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 300 // 5 minutes for Ollama model loading

        // Convert request to Ollama format
        let ollamaRequest = try OllamaChatRequest(
            model: self.modelId,
            messages: self.convertMessages(request.messages),
            tools: self.convertTools(request.tools),
            stream: false,
            options: OllamaChatRequest.OllamaOptions(
                temperature: request.settings.temperature,
                numCtx: nil, // Use default context
                numPredict: request.settings.maxTokens
            )
        )

        let jsonData = try JSONEncoder().encode(ollamaRequest)
        urlRequest.httpBody = jsonData

        // Debug: Print the JSON being sent to Ollama (only in verbose mode)
        if
            let jsonString = String(data: jsonData, encoding: .utf8),
            ProcessInfo.processInfo.arguments.contains("--verbose") ||
                ProcessInfo.processInfo.arguments.contains("-v")
        {
            print("DEBUG: Ollama API Request JSON:")
            print(jsonString)
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONDecoder().decode(OllamaErrorResponse.self, from: data) {
                throw TachikomaError.apiError("Ollama API Error: \(errorData.error)")
            } else {
                let responseBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw TachikomaError.apiError("Ollama API Error: HTTP \(httpResponse.statusCode) - \(responseBody)")
            }
        }

        // Debug: Log raw API response in verbose mode
        if
            ProcessInfo.processInfo.arguments.contains("--verbose") ||
                ProcessInfo.processInfo.arguments.contains("-v")
        {
            if let responseString = String(data: data, encoding: .utf8) {
                print("DEBUG ProviderFactory: Raw Ollama API Response:")
                print(responseString)
            }
        }

        let ollamaResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)

        // Calculate usage information from Ollama's detailed metrics
        let usage = Usage(
            inputTokens: ollamaResponse.promptEvalCount ?? 0,
            outputTokens: ollamaResponse.evalCount ?? 0
        )

        // Try to extract tool calls from both standard format and text content
        let toolCalls = self.extractOllamaToolCalls(ollamaResponse.message.toolCalls) ??
            self.parseToolCallsFromText(ollamaResponse.message.content)

        return ProviderResponse(
            text: ollamaResponse.message.content,
            usage: usage,
            finishReason: .stop,
            toolCalls: toolCalls
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        let url = URL(string: "\(self.baseURL!)/api/chat")!
        var urlRequestBuilder = URLRequest(url: url)
        urlRequestBuilder.httpMethod = "POST"
        urlRequestBuilder.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequestBuilder.timeoutInterval = 300 // 5 minutes for Ollama model loading

        // Convert request to Ollama format with streaming enabled
        let ollamaRequest = try OllamaChatRequest(
            model: self.modelId,
            messages: self.convertMessages(request.messages),
            tools: self.convertTools(request.tools),
            stream: true,
            options: OllamaChatRequest.OllamaOptions(
                temperature: request.settings.temperature,
                numCtx: nil, // Use default context
                numPredict: request.settings.maxTokens
            )
        )

        let jsonData = try JSONEncoder().encode(ollamaRequest)
        urlRequestBuilder.httpBody = jsonData

        let finalUrlRequest = urlRequestBuilder

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: finalUrlRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: TachikomaError.networkError(NSError(
                            domain: "Invalid response",
                            code: 0
                        )))
                        return
                    }

                    if httpResponse.statusCode != 200 {
                        continuation.finish(throwing: TachikomaError.apiError("HTTP \(httpResponse.statusCode)"))
                        return
                    }

                    for try await line in bytes.lines where !line.isEmpty {
                        if
                            let chunkData = line.data(using: .utf8),
                            let chunk = try? JSONDecoder().decode(OllamaStreamChunk.self, from: chunkData)
                        {
                            if let content = chunk.message.content, !content.isEmpty {
                                continuation.yield(TextStreamDelta(type: .textDelta, content: content))
                            }

                            if chunk.done {
                                continuation.yield(TextStreamDelta(type: .done))
                                continuation.finish()
                                return
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

    // MARK: - Ollama Helper Methods

    private func convertMessages(_ messages: [ModelMessage]) throws -> [OllamaChatMessage] {
        try messages.map { message -> OllamaChatMessage in
            switch message.role {
            case .system:
                if
                    let textContent = message.content.first,
                    case let .text(text) = textContent
                {
                    return OllamaChatMessage(role: "system", content: text)
                }
                throw TachikomaError.invalidInput("System message must have text content")

            case .user:
                if
                    let textContent = message.content.first,
                    case let .text(text) = textContent
                {
                    return OllamaChatMessage(role: "user", content: text)
                }
                throw TachikomaError.invalidInput("User message must have text content")

            case .assistant:
                if
                    let textContent = message.content.first,
                    case let .text(text) = textContent
                {
                    return OllamaChatMessage(role: "assistant", content: text)
                }
                throw TachikomaError.invalidInput("Assistant message must have text content")

            case .tool:
                if
                    let toolResult = message.content.first,
                    case let .toolResult(result) = toolResult
                {
                    // Convert ToolArgument to string
                    let resultString: String = switch result.result {
                    case let .string(str):
                        str
                    case let .int(int):
                        String(int)
                    case let .double(double):
                        String(double)
                    case let .bool(bool):
                        String(bool)
                    case .null:
                        "null"
                    case let .array(array):
                        array.description
                    case let .object(object):
                        object.description
                    }
                    return OllamaChatMessage(role: "tool", content: "Tool result: \(resultString)")
                }
                throw TachikomaError.invalidInput("Tool message must have tool result content")
            }
        }
    }

    private func convertTools(_ tools: [SimpleTool]?) throws -> [OllamaTool]? {
        tools?.map { tool in
            // Convert ToolParameters to Ollama format
            var properties: [String: Any] = [:]

            for (paramName, paramProp) in tool.parameters.properties {
                var propDict: [String: Any] = [:]

                // Map parameter type
                switch paramProp.type {
                case .string:
                    propDict["type"] = "string"
                case .integer:
                    propDict["type"] = "integer"
                case .number:
                    propDict["type"] = "number"
                case .boolean:
                    propDict["type"] = "boolean"
                case .array:
                    propDict["type"] = "array"
                case .object:
                    propDict["type"] = "object"
                case .null:
                    propDict["type"] = "null"
                }

                // Add description if available
                if let description = paramProp.description {
                    propDict["description"] = description
                }

                // Add enum values if available
                if let enumValues = paramProp.enumValues {
                    propDict["enum"] = enumValues
                }

                properties[paramName] = propDict
            }

            return OllamaTool(
                type: "function",
                function: OllamaTool.Function(
                    name: tool.name,
                    description: tool.description,
                    parameters: [
                        "type": "object",
                        "properties": properties,
                        "required": tool.parameters.required,
                    ]
                )
            )
        }
    }

    private func extractOllamaToolCalls(_ toolCalls: [OllamaToolCall]?) -> [ToolCall]? {
        guard let toolCalls, !toolCalls.isEmpty else { return nil }

        return toolCalls.map { ollamaToolCall in
            // Convert arguments to ToolArgument dictionary
            var arguments: [String: ToolArgument] = [:]
            for (key, value) in ollamaToolCall.function.arguments {
                if let toolArg = try? ToolArgument.from(any: value) {
                    arguments[key] = toolArg
                }
            }

            return ToolCall(
                id: UUID().uuidString, // Generate ID for Ollama (which doesn't provide IDs)
                name: ollamaToolCall.function.name,
                arguments: arguments
            )
        }
    }

    /// Parse tool calls from text content (for models that output tool calls as JSON text)
    private func parseToolCallsFromText(_ text: String) -> [ToolCall]? {
        var toolCalls: [ToolCall] = []

        // Look for JSON-like patterns in the text
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines or non-JSON looking lines
            guard trimmedLine.hasPrefix("{"), trimmedLine.hasSuffix("}") else {
                continue
            }

            // Try to parse as JSON
            guard let data = trimmedLine.data(using: .utf8) else { continue }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Look for tool call patterns - try both "arguments" and "parameters"
                    if let name = json["name"] as? String {
                        let arguments = (json["arguments"] as? [String: Any]) ?? (json["parameters"] as? [String: Any]) ?? [:]
                        
                        // Convert arguments to ToolArgument format
                        var toolArguments: [String: ToolArgument] = [:]
                        for (key, value) in arguments {
                            if let toolArg = try? ToolArgument.from(any: value) {
                                toolArguments[key] = toolArg
                            }
                        }

                        let toolCall = ToolCall(
                            id: UUID().uuidString,
                            name: name,
                            arguments: toolArguments
                        )
                        toolCalls.append(toolCall)
                    }
                }
            } catch {
                // Skip lines that aren't valid JSON
                continue
            }
        }

        return toolCalls.isEmpty ? nil : toolCalls
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
        if
            let key = ProcessInfo.processInfo.environment["OPENAI_COMPATIBLE_API_KEY"] ??
                ProcessInfo.processInfo.environment["API_KEY"]
        {
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

        if
            let key = ProcessInfo.processInfo.environment["ANTHROPIC_COMPATIBLE_API_KEY"] ??
                ProcessInfo.processInfo.environment["API_KEY"]
        {
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

// MARK: - JSON Encoding Helpers

/// Dynamic coding key for encoding arbitrary dictionaries
struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Encode Any values into a keyed container without using AnyCodable
func encodeAnyValue<Container: KeyedEncodingContainerProtocol>(_ value: Any, to container: inout Container, forKey key: Container.Key) throws {
    if let string = value as? String {
        try container.encode(string, forKey: key)
    } else if let int = value as? Int {
        try container.encode(int, forKey: key)
    } else if let double = value as? Double {
        try container.encode(double, forKey: key)
    } else if let bool = value as? Bool {
        try container.encode(bool, forKey: key)
    } else if let array = value as? [Any] {
        var arrayContainer = container.nestedUnkeyedContainer(forKey: key)
        for item in array {
            try encodeAnyValueToUnkeyed(item, to: &arrayContainer)
        }
    } else if let dict = value as? [String: Any] {
        var dictContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: key)
        try encodeAnyValue(dict, to: &dictContainer)
    } else {
        try container.encodeNil(forKey: key)
    }
}

/// Encode a dictionary of Any values into a keyed container
func encodeAnyValue<Container: KeyedEncodingContainerProtocol>(_ dict: [String: Any], to container: inout Container) throws where Container.Key == DynamicCodingKey {
    for (key, value) in dict {
        guard let codingKey = DynamicCodingKey(stringValue: key) else {
            continue
        }
        try encodeAnyValue(value, to: &container, forKey: codingKey)
    }
}

/// Encode Any values into an unkeyed container
func encodeAnyValueToUnkeyed<Container: UnkeyedEncodingContainer>(_ value: Any, to container: inout Container) throws {
    if let string = value as? String {
        try container.encode(string)
    } else if let int = value as? Int {
        try container.encode(int)
    } else if let double = value as? Double {
        try container.encode(double)
    } else if let bool = value as? Bool {
        try container.encode(bool)
    } else if let array = value as? [Any] {
        var arrayContainer = container.nestedUnkeyedContainer()
        for item in array {
            try encodeAnyValueToUnkeyed(item, to: &arrayContainer)
        }
    } else if let dict = value as? [String: Any] {
        var dictContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self)
        try encodeAnyValue(dict, to: &dictContainer)
    } else {
        try container.encodeNil()
    }
}

// MARK: - Mock Provider for Testing

/// Mock provider that returns predictable responses for testing
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class MockProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities
    
    private let model: LanguageModel
    
    public init(model: LanguageModel) {
        self.model = model
        self.modelId = model.modelId
        self.baseURL = "https://mock.api.example.com"
        self.apiKey = "mock-api-key"
        
        self.capabilities = ModelCapabilities(
            supportsVision: true,
            supportsTools: true,
            supportsStreaming: true,
            contextLength: 128_000,
            maxOutputTokens: 4096
        )
    }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        // Simulate network delay
        try await Task.sleep(for: .milliseconds(100))
        
        // Extract prompt text from messages
        let promptText = request.messages.compactMap { message in
            message.content.compactMap { part in
                if case let .text(text) = part {
                    return text
                }
                return nil
            }.joined()
        }.joined(separator: " ")
        
        // Generate mock response based on provider type
        let mockResponse = generateMockResponse(for: model, prompt: promptText, hasTools: request.tools?.isEmpty == false)
        
        // Handle tool calls if requested
        var toolCalls: [ToolCall]? = nil
        if let tools = request.tools, !tools.isEmpty, mockResponse.contains("tool_call") {
            toolCalls = [ToolCall(
                id: "mock_tool_call_123",
                name: tools.first?.name ?? "mock_tool",
                arguments: ["query": .string("mock query")]
            )]
        }
        
        return ProviderResponse(
            text: mockResponse,
            usage: Usage(inputTokens: 50, outputTokens: 100, cost: Usage.Cost(input: 0.0005, output: 0.0005)),
            finishReason: toolCalls != nil ? .toolCalls : .stop,
            toolCalls: toolCalls
        )
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await generateText(request: request)
                    let words = response.text.split(separator: " ")
                    
                    for word in words {
                        continuation.yield(TextStreamDelta(type: .textDelta, content: String(word) + " "))
                        try await Task.sleep(for: .milliseconds(50))
                    }
                    
                    continuation.yield(TextStreamDelta(type: .done))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func generateMockResponse(for model: LanguageModel, prompt: String, hasTools: Bool) -> String {
        switch model {
        case .openai:
            if hasTools {
                return "OpenAI response for '\(prompt)' with model \(model.modelId). Using tool_call to help answer."
            } else {
                return "OpenAI response for '\(prompt)' with model \(model.modelId)."
            }
            
        case .anthropic:
            if prompt.contains("quantum physics") {
                return "Quantum physics is a fundamental theory in physics that describes the behavior of matter and energy at the atomic and subatomic level."
            } else if prompt.contains("2+2") {
                return "2+2 equals 4."
            } else if prompt.contains("Hello world") {
                return "Hello! How can I help you today?"
            } else {
                return "I'm Claude, an AI assistant created by Anthropic. I'm here to help with a variety of tasks."
            }
            
        case .google:
            return "Google Gemini response for '\(prompt)' with model \(model.modelId)."
            
        case .mistral:
            return "Mistral response for '\(prompt)' with model \(model.modelId)."
            
        case .groq:
            return "Groq response for '\(prompt)' with model \(model.modelId)."
            
        case .grok:
            return "Grok response for '\(prompt)' with model \(model.modelId)."
            
        case .ollama:
            return "Ollama response for '\(prompt)' with model \(model.modelId)."
            
        default:
            return "Mock response for '\(prompt)' with model \(model.modelId)."
        }
    }
}
