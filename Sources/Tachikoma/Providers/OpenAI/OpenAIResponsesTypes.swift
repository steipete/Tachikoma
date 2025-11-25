import Foundation

// MARK: - Responses API Types

/// Request structure for OpenAI Responses API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct OpenAIResponsesRequest: Encodable {
    let model: String
    let input: [ResponsesInputItem]
    let temperature: Double?
    let topP: Double?
    let maxOutputTokens: Int?

    // Response format and text configuration
    let text: TextConfig? // GPT-5 text configuration with verbosity

    // Tool configuration
    let tools: [ResponsesTool]?
    let toolChoice: String?

    // Provider-specific options
    let metadata: [String: String]?
    let parallelToolCalls: Bool?
    let previousResponseId: String?
    let store: Bool?
    let user: String?
    let instructions: String?
    let serviceTier: String?
    let include: [String]?

    // Reasoning configuration (for o3/o4/GPT-5)
    let reasoning: ReasoningConfig?

    // Truncation for long inputs
    let truncation: String?

    // Streaming support
    let stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case temperature
        case topP = "top_p"
        case maxOutputTokens = "max_output_tokens"
        case text
        case tools
        case toolChoice = "tool_choice"
        case metadata
        case parallelToolCalls = "parallel_tool_calls"
        case previousResponseId = "previous_response_id"
        case store
        case user
        case instructions
        case serviceTier = "service_tier"
        case include
        case reasoning
        case truncation
        case stream
    }
}

/// Text verbosity levels for GPT-5
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
enum TextVerbosity: String, Codable, Sendable {
    case low
    case medium
    case high
}

/// Internal reasoning effort levels for OpenAI responses provider
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
enum OpenAIReasoningEffort: String, Codable, Sendable {
    case minimal
    case low
    case medium
    case high
}

/// Reasoning summary modes for reasoning models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
enum ReasoningSummary: String, Codable, Sendable {
    case concise
    case detailed
    case auto
}

/// Text configuration for GPT-5 models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct TextConfig: Codable, Sendable {
    let verbosity: TextVerbosity?
}

/// Reasoning configuration for reasoning models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct ReasoningConfig: Codable, Sendable {
    let effort: OpenAIReasoningEffort?
    let summary: ReasoningSummary?
}

/// Response format configuration
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct ResponseFormat: Codable {
    let format: ResponseFormatType

    enum ResponseFormatType: Codable {
        case jsonObject
        case jsonSchema(JSONSchemaFormat)

        private enum CodingKeys: String, CodingKey {
            case type
        }

        func encode(to encoder: Encoder) throws {
            switch self {
            case .jsonObject:
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("json_object", forKey: .type)
            case let .jsonSchema(schema):
                try schema.encode(to: encoder)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "json_object":
                self = .jsonObject
            case "json_schema":
                let schema = try JSONSchemaFormat(from: decoder)
                self = .jsonSchema(schema)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown response format type: \(type)",
                )
            }
        }
    }
}

/// JSON Schema format for structured outputs
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct JSONSchemaFormat: Codable {
    let type: String = "json_schema"
    let strict: Bool
    let name: String
    let description: String?
    let schema: [String: Any] // Can't be Sendable due to Any

    enum CodingKeys: String, CodingKey {
        case type
        case strict
        case name
        case description
        case schema
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.strict, forKey: .strict)
        try container.encode(self.name, forKey: .name)
        try container.encodeIfPresent(self.description, forKey: .description)

        // Encode schema as JSON data
        let schemaData = try JSONSerialization.data(withJSONObject: self.schema)
        let schemaJSON = try JSONSerialization.jsonObject(with: schemaData)
        try container.encode(AnyEncodable(schemaJSON), forKey: .schema)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.strict = try container.decode(Bool.self, forKey: .strict)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)

        // Decode schema as Any
        let anySchema = try container.decode(AnyDecodable.self, forKey: .schema)
        self.schema = anySchema.value as? [String: Any] ?? [:]
    }
}

/// Message format for Responses API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct ResponsesMessage: Codable, Sendable {
    let role: String
    let content: ResponsesContent

    enum ResponsesContent: Codable, Sendable {
        case text(String)
        case parts([ResponsesContentPart])

        func encode(to encoder: Encoder) throws {
            switch self {
            case let .text(text):
                var container = encoder.singleValueContainer()
                try container.encode(text)
            case let .parts(parts):
                var container = encoder.singleValueContainer()
                try container.encode(parts)
            }
        }

        init(from decoder: Decoder) throws {
            if let text = try? decoder.singleValueContainer().decode(String.self) {
                self = .text(text)
            } else {
                let parts = try decoder.singleValueContainer().decode([ResponsesContentPart].self)
                self = .parts(parts)
            }
        }
    }
}

/// Content part for multimodal messages
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct ResponsesContentPart: Codable, Sendable {
    let type: String
    let text: String?
    /// OpenAI Responses API (GPT‑5.x) accepts `image_url` only as a string (URL or data URL).
    /// We still parse legacy `{ url, detail }` objects, but always encode back to a string to
    /// avoid 400s ("expected an image URL, but got an object instead").
    let imageUrl: ImageURL?

    struct ImageURL: Codable, Sendable {
        let url: String
        let detail: String?
    }

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }

    init(type: String, text: String?, imageUrl: ImageURL?) {
        self.type = type
        self.text = text
        self.imageUrl = imageUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)

        // Accept either the current string form or the legacy object form.
        if let urlString = try? container.decode(String.self, forKey: .imageUrl) {
            self.imageUrl = ImageURL(url: urlString, detail: nil)
        } else if let object = try? container.decode(ImageURL.self, forKey: .imageUrl) {
            self.imageUrl = object
        } else {
            self.imageUrl = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.type, forKey: .type)
        try container.encodeIfPresent(self.text, forKey: .text)
        if let imageUrl {
            // Force the string form per Responses API schema, drop legacy detail.
            try container.encode(imageUrl.url, forKey: .imageUrl)
        }
    }
}

/// Heterogeneous input entries supported by the Responses API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
enum ResponsesInputItem: Encodable, Sendable {
    case message(ResponsesMessage)
    case functionCall(FunctionCall)
    case functionCallOutput(FunctionCallOutput)

    struct FunctionCall: Encodable, Sendable {
        let type: String = "function_call"
        let callId: String
        let name: String
        let arguments: String

        enum CodingKeys: String, CodingKey {
            case type
            case callId = "call_id"
            case name
            case arguments
        }
    }

    struct FunctionCallOutput: Encodable, Sendable {
        let type: String = "function_call_output"
        let callId: String
        let output: String
        let status: String?

        init(callId: String, output: String, status: String? = nil) {
            self.callId = callId
            self.output = output
            self.status = status
        }

        enum CodingKeys: String, CodingKey {
            case type
            case callId = "call_id"
            case output
            case status
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .message(message):
            try container.encode(message)
        case let .functionCall(functionCall):
            try container.encode(functionCall)
        case let .functionCallOutput(output):
            try container.encode(output)
        }
    }
}

/// Tool definition for Responses API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct ResponsesTool: Codable {
    let name: String // Required at root level for GPT-5 compatibility
    let type: String
    let description: String?
    let parameters: [String: Any]?
    let inputSchema: [String: Any]?
    let strict: Bool?
    let function: ToolFunction?

    init(
        name: String,
        type: String,
        description: String? = nil,
        parameters: [String: Any]? = nil,
        inputSchema: [String: Any]? = nil,
        strict: Bool? = nil,
        function: ToolFunction? = nil,
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.parameters = parameters
        self.inputSchema = inputSchema
        self.strict = strict
        self.function = function
    }

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case description
        case parameters
        case inputSchema = "input_schema"
        case strict
        case function
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.type, forKey: .type)
        try container.encodeIfPresent(self.description, forKey: .description)

        if let params = parameters {
            let paramsData = try JSONSerialization.data(withJSONObject: params)
            let paramsJSON = try JSONSerialization.jsonObject(with: paramsData)
            try container.encode(AnyEncodable(paramsJSON), forKey: .parameters)
        }

        if let schema = inputSchema {
            let schemaData = try JSONSerialization.data(withJSONObject: schema)
            let schemaJSON = try JSONSerialization.jsonObject(with: schemaData)
            try container.encode(AnyEncodable(schemaJSON), forKey: .inputSchema)
        }

        try container.encodeIfPresent(self.strict, forKey: .strict)
        try container.encodeIfPresent(self.function, forKey: .function)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(String.self, forKey: .type)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)

        if let anyParams = try container.decodeIfPresent(AnyDecodable.self, forKey: .parameters) {
            self.parameters = anyParams.value as? [String: Any]
        } else {
            self.parameters = nil
        }

        if let schema = try container.decodeIfPresent(AnyDecodable.self, forKey: .inputSchema) {
            self.inputSchema = schema.value as? [String: Any]
        } else {
            self.inputSchema = nil
        }

        self.strict = try container.decodeIfPresent(Bool.self, forKey: .strict)
        self.function = try container.decodeIfPresent(ToolFunction.self, forKey: .function)
    }

    struct ToolFunction: Codable {
        let name: String
        let description: String?
        let parameters: [String: Any]? // Legacy parameters field
        let inputSchema: [String: Any]? // Preferred for Responses API

        init(
            name: String,
            description: String? = nil,
            parameters: [String: Any]? = nil,
            inputSchema: [String: Any]? = nil,
        ) {
            self.name = name
            self.description = description
            self.parameters = parameters
            self.inputSchema = inputSchema
        }

        enum CodingKeys: String, CodingKey {
            case name
            case description
            case parameters
            case inputSchema = "input_schema"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.name, forKey: .name)
            try container.encodeIfPresent(self.description, forKey: .description)

            if let params = parameters {
                let paramsData = try JSONSerialization.data(withJSONObject: params)
                let paramsJSON = try JSONSerialization.jsonObject(with: paramsData)
                try container.encode(AnyEncodable(paramsJSON), forKey: .parameters)
            }

            if let schema = inputSchema {
                let schemaData = try JSONSerialization.data(withJSONObject: schema)
                let schemaJSON = try JSONSerialization.jsonObject(with: schemaData)
                try container.encode(AnyEncodable(schemaJSON), forKey: .inputSchema)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.description = try container.decodeIfPresent(String.self, forKey: .description)

            if let anyParams = try container.decodeIfPresent(AnyDecodable.self, forKey: .parameters) {
                self.parameters = anyParams.value as? [String: Any]
            } else {
                self.parameters = nil
            }

            if let schema = try container.decodeIfPresent(AnyDecodable.self, forKey: .inputSchema) {
                self.inputSchema = schema.value as? [String: Any]
            } else {
                self.inputSchema = nil
            }
        }
    }
}

// MARK: - Response Types

/// Response from OpenAI Responses API (GPT-5 format)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct OpenAIResponsesResponse: Codable, Sendable {
    let id: String
    let object: String?
    let createdAt: Int? // GPT-5 uses created_at
    let created: Int? // O3 uses created
    let status: String?
    let model: String
    let output: [ResponsesOutput]? // GPT-5 uses output array
    let choices: [ResponsesChoice]? // O3 uses choices array
    let usage: ResponsesUsage?
    let metadata: ResponsesMetadata?

    enum CodingKeys: String, CodingKey {
        case id, object, status, model, output, choices, usage, metadata
        case createdAt = "created_at"
        case created
    }

    // GPT-5 output format
    struct ResponsesOutput: Codable, Sendable {
        let id: String
        let type: String
        let status: String?
        let content: [OutputContent]?
        let role: String?
        let toolCall: ResponsesToolCall?
        // Summary can be array, which we'll decode but not use for now

        enum CodingKeys: String, CodingKey {
            case id
            case type
            case status
            case content
            case role
            case toolCall = "tool_call"
        }

        struct OutputContent: Codable, Sendable {
            let type: String
            let text: String?
            let toolCall: ResponsesToolCall?

            enum CodingKeys: String, CodingKey {
                case type
                case text
                case toolCall = "tool_call"
            }
        }
    }

    // O3 choices format (kept for compatibility)
    struct ResponsesChoice: Codable, Sendable {
        let index: Int
        let message: ResponsesOutputMessage
        let finishReason: String?
        let logprobs: String? // null for now

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
            case logprobs
        }
    }

    struct ResponsesOutputMessage: Codable, Sendable {
        let role: String
        let content: String?
        let toolCalls: [ResponsesToolCall]?
        let refusal: String?

        enum CodingKeys: String, CodingKey {
            case role
            case content
            case toolCalls = "tool_calls"
            case refusal
        }
    }

    struct ResponsesToolCall: Codable, Sendable {
        let id: String
        let type: String
        let function: ResponsesToolFunction

        struct ResponsesToolFunction: Codable, Sendable {
            let name: String
            let arguments: String
        }
    }

    struct ResponsesUsage: Codable, Sendable {
        let inputTokens: Int?
        let outputTokens: Int?
        let totalTokens: Int?
        let promptTokens: Int?
        let completionTokens: Int?
        let reasoningTokens: Int?
        let inputTokensDetails: TokenDetails?
        let outputTokensDetails: OutputTokenDetails?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case totalTokens = "total_tokens"
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case reasoningTokens = "reasoning_tokens"
            case inputTokensDetails = "input_tokens_details"
            case outputTokensDetails = "output_tokens_details"
        }

        struct TokenDetails: Codable, Sendable {
            let cachedTokens: Int?

            enum CodingKeys: String, CodingKey {
                case cachedTokens = "cached_tokens"
            }
        }

        struct OutputTokenDetails: Codable, Sendable {
            let reasoningTokens: Int?

            enum CodingKeys: String, CodingKey {
                case reasoningTokens = "reasoning_tokens"
            }
        }
    }

    struct ResponsesMetadata: Codable, Sendable {
        let responseId: String?
        let reasoningItemIds: [String]?

        enum CodingKeys: String, CodingKey {
            case responseId = "response_id"
            case reasoningItemIds = "reasoning_item_ids"
        }
    }
}

// MARK: - Streaming Response Types

/// Server-sent event for streaming responses (O3 and older models)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct OpenAIResponsesStreamChunk: Codable, Sendable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [StreamChoice]

    struct StreamChoice: Codable, Sendable {
        let index: Int
        let delta: StreamDelta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct StreamDelta: Codable, Sendable {
        let role: String?
        let content: String?
        let toolCalls: [StreamToolCall]?

        enum CodingKeys: String, CodingKey {
            case role
            case content
            case toolCalls = "tool_calls"
        }
    }

    struct StreamToolCall: Codable, Sendable {
        let index: Int
        let id: String?
        let type: String?
        let function: StreamToolFunction?

        struct StreamToolFunction: Codable, Sendable {
            let name: String?
            let arguments: String?
        }
    }
}
