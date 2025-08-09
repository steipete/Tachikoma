//
//  OpenAIResponsesTypes.swift
//  Tachikoma
//

import Foundation

// MARK: - Responses API Types

/// Request structure for OpenAI Responses API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct OpenAIResponsesRequest: Codable {
    let model: String
    let input: [ResponsesMessage]
    let temperature: Double?
    let topP: Double?
    let maxOutputTokens: Int?
    
    // Response format and text configuration
    let text: TextConfig?  // GPT-5 text configuration with verbosity
    
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
    }
}

/// Text configuration for GPT-5 models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct TextConfig: Codable, Sendable {
    let verbosity: String?  // "low", "medium", "high"
}

/// Reasoning configuration for reasoning models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct ReasoningConfig: Codable, Sendable {
    let effort: String?  // "minimal", "low", "medium", "high"
    let summary: Bool?
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
            case .jsonSchema(let schema):
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
                    debugDescription: "Unknown response format type: \(type)")
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
    let schema: [String: Any]  // Can't be Sendable due to Any
    
    enum CodingKeys: String, CodingKey {
        case type
        case strict
        case name
        case description
        case schema
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(strict, forKey: .strict)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        
        // Encode schema as JSON data
        let schemaData = try JSONSerialization.data(withJSONObject: schema)
        let schemaJSON = try JSONSerialization.jsonObject(with: schemaData)
        try container.encode(AnyEncodable(schemaJSON), forKey: .schema)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        strict = try container.decode(Bool.self, forKey: .strict)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        
        // Decode schema as Any
        let anySchema = try container.decode(AnyDecodable.self, forKey: .schema)
        schema = anySchema.value as? [String: Any] ?? [:]
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
            case .text(let text):
                var container = encoder.singleValueContainer()
                try container.encode(text)
            case .parts(let parts):
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
    let imageUrl: ImageURL?
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }
    
    struct ImageURL: Codable, Sendable {
        let url: String
        let detail: String?
    }
}

/// Tool definition for Responses API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct ResponsesTool: Codable {
    let type: String
    let function: ToolFunction?
    
    struct ToolFunction: Codable {
        let name: String
        let description: String?
        let parameters: [String: Any]?  // Can't be Sendable due to Any
        
        init(name: String, description: String? = nil, parameters: [String: Any]? = nil) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
        
        enum CodingKeys: String, CodingKey {
            case name
            case description
            case parameters
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(description, forKey: .description)
            
            if let params = parameters {
                let paramsData = try JSONSerialization.data(withJSONObject: params)
                let paramsJSON = try JSONSerialization.jsonObject(with: paramsData)
                try container.encode(AnyEncodable(paramsJSON), forKey: .parameters)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            description = try container.decodeIfPresent(String.self, forKey: .description)
            
            if let anyParams = try container.decodeIfPresent(AnyDecodable.self, forKey: .parameters) {
                parameters = anyParams.value as? [String: Any]
            } else {
                parameters = nil
            }
        }
    }
}

// MARK: - Response Types

/// Response from OpenAI Responses API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct OpenAIResponsesResponse: Codable, Sendable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [ResponsesChoice]
    let usage: ResponsesUsage?
    let metadata: ResponsesMetadata?
    
    struct ResponsesChoice: Codable, Sendable {
        let index: Int
        let message: ResponsesOutputMessage
        let finishReason: String?
        let logprobs: String?  // null for now
        
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
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        let reasoningTokens: Int?
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
            case reasoningTokens = "reasoning_tokens"
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

/// Server-sent event for streaming responses
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

