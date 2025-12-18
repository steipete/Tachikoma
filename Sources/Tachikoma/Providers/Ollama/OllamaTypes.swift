import Foundation

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
    let images: [String]?
    let toolCalls: [OllamaToolCall]?

    enum CodingKeys: String, CodingKey {
        case role, content, images
        case toolCalls = "tool_calls"
    }

    init(role: String, content: String, images: [String]? = nil, toolCalls: [OllamaToolCall]? = nil) {
        self.role = role
        self.content = content
        self.images = images
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

            // Try to decode arguments as direct JSON object using a nested container (GPT-OSS format)
            if let nestedContainer = try? container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .arguments) {
                self.arguments = try Self.decodeAnyDictionary(from: nestedContainer)
            }
            // Fallback: decode arguments as Data then parse (legacy format)
            else if
                let data = try? container.decode(Data.self, forKey: .arguments),
                let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                self.arguments = dict
            } else {
                self.arguments = [:]
            }
        }

        private static func decodeAnyDictionary(from container: KeyedDecodingContainer<AnyCodingKey>) throws
            -> [String: Any]
        {
            var result: [String: Any] = [:]
            for key in container.allKeys {
                if let stringValue = try? container.decode(String.self, forKey: key) {
                    result[key.stringValue] = stringValue
                } else if let intValue = try? container.decode(Int.self, forKey: key) {
                    result[key.stringValue] = intValue
                } else if let doubleValue = try? container.decode(Double.self, forKey: key) {
                    result[key.stringValue] = doubleValue
                } else if let boolValue = try? container.decode(Bool.self, forKey: key) {
                    result[key.stringValue] = boolValue
                }
            }
            return result
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.name, forKey: .name)

            // Encode arguments as a JSON object (not base64 Data)
            var argsContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .arguments)
            try Self.encodeAnyDictionary(self.arguments, to: &argsContainer)
        }

        private static func encodeAnyDictionary(
            _ dict: [String: Any],
            to container: inout KeyedEncodingContainer<AnyCodingKey>,
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
                    var nestedContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: codingKey)
                    try Self.encodeAnyDictionary(dictValue, to: &nestedContainer)
                default:
                    try container.encode(String(describing: value), forKey: codingKey)
                }
            }
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
            to container: inout KeyedEncodingContainer<AnyCodingKey>,
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
