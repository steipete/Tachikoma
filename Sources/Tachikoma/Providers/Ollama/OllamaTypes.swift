import Foundation

// MARK: - Ollama API Types

struct OllamaChatRequest: Codable {
    let model: String
    let messages: [OllamaChatMessage]
    let tools: [OllamaTool]?
    let stream: Bool?
    let think: OllamaThink?
    let options: OllamaOptions?

    enum OllamaThink: Codable, Equatable {
        case enabled(Bool)
        case level(String)

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let enabled = try? container.decode(Bool.self) {
                self = .enabled(enabled)
                return
            }
            self = try .level(container.decode(String.self))
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .enabled(enabled):
                try container.encode(enabled)
            case let .level(level):
                try container.encode(level)
            }
        }
    }

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
    let thinking: String?
    let images: [String]?
    let toolCalls: [OllamaToolCall]?
    let toolName: String?

    enum CodingKeys: String, CodingKey {
        case role, content, thinking, images
        case toolCalls = "tool_calls"
        case toolName = "tool_name"
    }

    init(
        role: String,
        content: String,
        thinking: String? = nil,
        images: [String]? = nil,
        toolCalls: [OllamaToolCall]? = nil,
        toolName: String? = nil,
    ) {
        self.role = role
        self.content = content
        self.thinking = thinking
        self.images = images
        self.toolCalls = toolCalls
        self.toolName = toolName
    }
}

struct OllamaToolCall: Codable {
    let type: String?
    let function: Function

    struct Function: Codable {
        let index: Int?
        let name: String
        let arguments: [String: AnyAgentToolValue]

        enum CodingKeys: String, CodingKey {
            case index, name, arguments
        }

        init(index: Int? = nil, name: String, arguments: [String: AnyAgentToolValue]) {
            self.index = index
            self.name = name
            self.arguments = arguments
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.index = try container.decodeIfPresent(Int.self, forKey: .index)
            self.name = try container.decode(String.self, forKey: .name)
            self.arguments = try container.decodeIfPresent(
                [String: AnyAgentToolValue].self,
                forKey: .arguments,
            ) ?? [:]
        }
    }

    init(type: String? = "function", function: Function) {
        self.type = type
        self.function = function
    }
}

struct OllamaTool: Codable {
    let type: String
    let function: Function

    struct Function: Codable {
        let name: String
        let description: String
        let parameters: [String: AnyAgentToolValue]
    }
}

struct OllamaChatResponse: Codable {
    let model: String
    let message: Message
    let done: Bool
    let doneReason: String?
    let totalDuration: Int?
    let loadDuration: Int?
    let promptEvalCount: Int?
    let promptEvalDuration: Int?
    let evalCount: Int?
    let evalDuration: Int?

    enum CodingKeys: String, CodingKey {
        case model, message, done
        case doneReason = "done_reason"
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
        let thinking: String?
        let toolCalls: [OllamaToolCall]?

        enum CodingKeys: String, CodingKey {
            case role, content, thinking
            case toolCalls = "tool_calls"
        }
    }
}

struct OllamaStreamChunk: Codable {
    let model: String
    let message: Delta
    let done: Bool
    let doneReason: String?

    enum CodingKeys: String, CodingKey {
        case model, message, done
        case doneReason = "done_reason"
    }

    struct Delta: Codable {
        let role: String?
        let content: String?
        let thinking: String?
        /// Ollama emits native tool calls on the streaming `/api/chat` response
        /// (`{"message":{"content":"","tool_calls":[…]},"done":false}`). Without
        /// this the caller sees zero tool calls and models fall back to printing
        /// tool-call JSON as plain text.
        let toolCalls: [OllamaToolCall]?

        enum CodingKeys: String, CodingKey {
            case role, content, thinking
            case toolCalls = "tool_calls"
        }
    }
}

struct OllamaErrorResponse: Codable {
    let error: String
}
