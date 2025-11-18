import Foundation

// MARK: - OpenAI API Types

struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double?
    let maxTokens: Int?
    let tools: [OpenAITool]?
    let stream: Bool?
    let stop: [String]? // Native stop sequences support

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, tools, stream, stop
        case maxTokens = "max_tokens"
        case maxCompletionTokens = "max_completion_tokens"
    }

    init(
        model: String,
        messages: [OpenAIChatMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        tools: [OpenAITool]? = nil,
        stream: Bool? = nil,
        stop: [String]? = nil,
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.tools = tools
        self.stream = stream
        self.stop = stop
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.model = try container.decode(String.self, forKey: .model)
        self.messages = try container.decode([OpenAIChatMessage].self, forKey: .messages)
        self.temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)

        // Try both max_tokens and max_completion_tokens
        if let maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens) {
            self.maxTokens = maxTokens
        } else {
            maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxCompletionTokens)
        }

        self.tools = try container.decodeIfPresent([OpenAITool].self, forKey: .tools)
        self.stream = try container.decodeIfPresent(Bool.self, forKey: .stream)
        self.stop = try container.decodeIfPresent([String].self, forKey: .stop)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.model, forKey: .model)
        try container.encode(self.messages, forKey: .messages)
        try container.encodeIfPresent(self.temperature, forKey: .temperature)

        // Use max_completion_tokens for GPT-5 models, max_tokens for others
        if self.model.hasPrefix("gpt-5") {
            try container.encodeIfPresent(self.maxTokens, forKey: .maxCompletionTokens)
        } else {
            try container.encodeIfPresent(self.maxTokens, forKey: .maxTokens)
        }

        try container.encodeIfPresent(self.tools, forKey: .tools)
        try container.encodeIfPresent(self.stream, forKey: .stream)
        try container.encodeIfPresent(self.stop, forKey: .stop)
    }
}

struct OpenAIChatMessage: Codable {
    let role: String
    let content: Either<String, [OpenAIChatMessageContent]>?
    let toolCallId: String?
    let toolCalls: [AgentToolCall]?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCallId = "tool_call_id"
        case toolCalls = "tool_calls"
    }

    struct AgentToolCall: Codable {
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

    init(role: String, content: String? = nil, toolCalls: [AgentToolCall]?) {
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

    // Provide custom Codable to match OpenAI schema (flattened objects with type field)
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(TextContent(type: type, text: text))
        case "image_url":
            let imageUrl = try container.decode(ImageUrl.self, forKey: .imageUrl)
            self = .imageUrl(ImageUrlContent(type: type, imageUrl: imageUrl))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported content type: \(type)",
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(content):
            try container.encode(content.type, forKey: .type)
            try container.encode(content.text, forKey: .text)
        case let .imageUrl(content):
            try container.encode(content.type, forKey: .type)
            try container.encode(content.imageUrl, forKey: .imageUrl)
        }
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
    let choices: [Choice]?
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
        let toolCalls: [AgentToolCall]?

        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCalls = "tool_calls"
        }
    }

    struct AgentToolCall: Codable {
        let id: String
        let type: String
        let function: Function

        struct Function: Codable {
            let name: String
            let arguments: String
        }
    }

    struct Usage: Codable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?

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
        let toolCalls: [ToolCall]?

        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCalls = "tool_calls"
        }

        struct ToolCall: Codable {
            let index: Int?
            let id: String?
            let type: String?
            let function: Function?

            struct Function: Codable {
                let name: String?
                let arguments: String?
            }
        }
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
                debugDescription: "Could not decode Either<\(Left.self), \(Right.self)>",
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
