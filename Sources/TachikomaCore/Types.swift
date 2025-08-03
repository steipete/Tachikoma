import Foundation

// MARK: - AI SDK Core Types

/// Error types for the modern Tachikoma API
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum TachikomaError: Error, LocalizedError, Sendable {
    case modelNotFound(String)
    case invalidConfiguration(String)
    case unsupportedOperation(String)
    case apiError(String)
    case networkError(Error)
    case toolCallFailed(String)
    case invalidInput(String)
    case rateLimited(retryAfter: TimeInterval?)
    case authenticationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .unsupportedOperation(let operation):
            return "Unsupported operation: \(operation)"
        case .apiError(let message):
            return "API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .toolCallFailed(let message):
            return "Tool call failed: \(message)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited. Retry after \(retryAfter) seconds"
            } else {
                return "Rate limited"
            }
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        }
    }
}

// MARK: - Message Types

/// A message in a conversation with an AI model
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModelMessage: Sendable, Codable, Equatable {
    public let id: String
    public let role: Role
    public let content: [ContentPart]
    public let timestamp: Date
    
    public enum Role: String, Sendable, Codable, CaseIterable {
        case system
        case user
        case assistant
        case tool
    }
    
    public enum ContentPart: Sendable, Codable, Equatable {
        case text(String)
        case image(ImageContent)
        case toolCall(ToolCall)
        case toolResult(ToolResult)
        
        public struct ImageContent: Sendable, Codable, Equatable {
            public let data: String // base64 encoded
            public let mimeType: String
            
            public init(data: String, mimeType: String = "image/png") {
                self.data = data
                self.mimeType = mimeType
            }
        }
    }
    
    public init(id: String = UUID().uuidString, role: Role, content: [ContentPart], timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
    
    // Convenience initializers
    public static func system(_ text: String) -> ModelMessage {
        ModelMessage(role: .system, content: [.text(text)])
    }
    
    public static func user(_ text: String) -> ModelMessage {
        ModelMessage(role: .user, content: [.text(text)])
    }
    
    public static func assistant(_ text: String) -> ModelMessage {
        ModelMessage(role: .assistant, content: [.text(text)])
    }
    
    public static func user(text: String, images: [ContentPart.ImageContent]) -> ModelMessage {
        var content: [ContentPart] = [.text(text)]
        content.append(contentsOf: images.map { .image($0) })
        return ModelMessage(role: .user, content: content)
    }
}

// MARK: - Tool Types

/// A tool call made by the AI model
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ToolCall: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let arguments: [String: ToolArgument]
    
    public init(id: String = UUID().uuidString, name: String, arguments: [String: ToolArgument]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// Result of executing a tool
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ToolResult: Sendable, Codable, Equatable {
    public let toolCallId: String
    public let result: ToolArgument
    public let isError: Bool
    
    public init(toolCallId: String, result: ToolArgument, isError: Bool = false) {
        self.toolCallId = toolCallId
        self.result = result
        self.isError = isError
    }
    
    public static func success(toolCallId: String, result: ToolArgument) -> ToolResult {
        ToolResult(toolCallId: toolCallId, result: result, isError: false)
    }
    
    public static func error(toolCallId: String, error: String) -> ToolResult {
        ToolResult(toolCallId: toolCallId, result: .string(error), isError: true)
    }
}

/// Type-safe tool argument handling
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ToolArgument: Sendable, Codable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([ToolArgument])
    case object([String: ToolArgument])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([ToolArgument].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: ToolArgument].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ToolArgument")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
    
    /// Create ToolArgument from any JSON-compatible value
    public static func from(any value: Any) throws -> ToolArgument {
        if value is NSNull {
            return .null
        } else if let bool = value as? Bool {
            return .bool(bool)
        } else if let int = value as? Int {
            return .int(int)
        } else if let double = value as? Double {
            return .double(double)
        } else if let string = value as? String {
            return .string(string)
        } else if let array = value as? [Any] {
            let toolArgs = try array.map { try ToolArgument.from(any: $0) }
            return .array(toolArgs)
        } else if let dict = value as? [String: Any] {
            var toolDict: [String: ToolArgument] = [:]
            for (key, val) in dict {
                toolDict[key] = try ToolArgument.from(any: val)
            }
            return .object(toolDict)
        } else {
            throw ToolError.invalidInput("Unsupported value type: \(type(of: value))")
        }
    }
}

// MARK: - Usage Statistics

/// Token usage statistics for a generation
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct Usage: Sendable, Codable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int
    public let cost: Cost?
    
    public struct Cost: Sendable, Codable, Equatable {
        public let input: Double
        public let output: Double
        public let total: Double
        
        public init(input: Double, output: Double) {
            self.input = input
            self.output = output
            self.total = input + output
        }
    }
    
    public init(inputTokens: Int, outputTokens: Int, cost: Cost? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = inputTokens + outputTokens
        self.cost = cost
    }
}

// MARK: - Finish Reason

/// Reason why generation finished
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum FinishReason: String, Sendable, Codable, CaseIterable {
    case stop = "stop"
    case length = "length"
    case toolCalls = "tool_calls"
    case contentFilter = "content_filter"
    case error = "error"
    case cancelled = "cancelled"
    case other = "other"
}

// MARK: - Image Input

/// Input type for image analysis
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ImageInput: Sendable {
    case base64(String)
    case url(String)
    case filePath(String)
}

// MARK: - Generation Settings

/// Settings for text generation
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct GenerationSettings: Sendable, Codable {
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let frequencyPenalty: Double?
    public let presencePenalty: Double?
    public let stopSequences: [String]?
    
    public init(
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        stopSequences: [String]? = nil
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.stopSequences = stopSequences
    }
    
    public static let `default` = GenerationSettings()
}