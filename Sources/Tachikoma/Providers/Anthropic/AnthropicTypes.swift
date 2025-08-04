import Foundation

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

