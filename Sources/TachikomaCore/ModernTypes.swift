import Foundation

// MARK: - Modern API Types

// This file contains the modern API types that are self-contained and don't depend on legacy code

// MARK: - Basic Error Types

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ModernTachikomaError: Error, LocalizedError {
    case modelNotFound(String)
    case invalidConfiguration(String)
    case unsupportedOperation(String)
    case apiError(String)
    case networkError(Error)
    
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
        }
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ModernToolError: Error, LocalizedError {
    case invalidInput(String)
    case executionFailed(String)
    case toolNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid tool input: \(message)"
        case .executionFailed(let message):
            return "Tool execution failed: \(message)"
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        }
    }
}

// MARK: - Simple Modern Configuration

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModernAIConfiguration {
    public static func fromEnvironment() throws -> ModernAIModelProvider {
        // For now, return a simple provider
        return ModernAIModelProvider()
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModernAIModelProvider {
    public func getModel(_ modelId: String) throws -> any ModernModelInterface {
        // For now, return a mock model
        return MockModel(modelId: modelId)
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public protocol ModernModelInterface: Sendable {
    func getResponse(request: ModernModelRequest) async throws -> ModernModelResponse
    func getStreamedResponse(request: ModernModelRequest) async throws -> AsyncThrowingStream<ModernStreamEvent, any Error>
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModernModelRequest: Sendable {
    public let messages: [ModernMessage]
    public let tools: [ModernToolDefinition]?
    public let settings: ModernModelSettings
    
    public init(messages: [ModernMessage], tools: [ModernToolDefinition]? = nil, settings: ModernModelSettings) {
        self.messages = messages
        self.tools = tools
        self.settings = settings
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModernModelResponse: Sendable {
    public let content: [ModernAssistantContent]
    
    public init(content: [ModernAssistantContent]) {
        self.content = content
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModernModelSettings: Sendable {
    public let modelName: String
    public let temperature: Double?
    public let maxTokens: Int?
    
    public init(modelName: String, temperature: Double? = nil, maxTokens: Int? = nil) {
        self.modelName = modelName
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ModernMessage: Sendable {
    case system(content: String)
    case user(content: ModernMessageContent)
    case assistant(content: [ModernAssistantContent])
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ModernMessageContent: Sendable {
    case text(String)
    case multimodal([ModernMessageContentPart])
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModernMessageContentPart: Sendable {
    public let type: String
    public let text: String?
    public let imageUrl: ModernImageContent?
    
    public init(type: String, text: String? = nil, imageUrl: ModernImageContent? = nil) {
        self.type = type
        self.text = text
        self.imageUrl = imageUrl
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModernImageContent: Sendable {
    public let url: String?
    public let base64: String?
    
    public init(url: String? = nil, base64: String? = nil) {
        self.url = url
        self.base64 = base64
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ModernAssistantContent: Sendable {
    case outputText(String)
    case toolCall(ModernToolCallItem)
    
    public var textContent: String? {
        switch self {
        case .outputText(let text):
            return text
        case .toolCall:
            return nil
        }
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModernToolCallItem: Sendable {
    public let id: String
    public let function: ModernFunctionCall
    
    public init(id: String, function: ModernFunctionCall) {
        self.id = id
        self.function = function
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModernFunctionCall: Sendable {
    public let name: String
    public let arguments: String
    
    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModernToolDefinition: Sendable {
    public let name: String
    public let description: String
    
    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModernStreamEvent: Sendable {
    public let type: StreamEventType
    public let delta: String?
    
    public enum StreamEventType: Sendable {
        case textDelta
        case complete
        case error
    }
    
    public init(type: StreamEventType, delta: String? = nil) {
        self.type = type
        self.delta = delta
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModernToolInput: Sendable {
    private let jsonString: String
    
    public init(jsonString: String) throws {
        self.jsonString = jsonString.isEmpty ? "{}" : jsonString
        
        // Validate JSON format
        if !jsonString.isEmpty {
            guard let jsonData = jsonString.data(using: .utf8),
                  let _ = try? JSONSerialization.jsonObject(with: jsonData) else {
                throw ModernToolError.invalidInput("Invalid JSON string")
            }
        }
    }
    
    private var parsedData: [String: Any] {
        guard let data = jsonString.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return parsed
    }
    
    public func stringValue(_ key: String) throws -> String {
        guard let value = parsedData[key] as? String else {
            throw ModernToolError.invalidInput("Missing or invalid string value for key: \(key)")
        }
        return value
    }
    
    public func stringValue(_ key: String, default defaultValue: String?) -> String? {
        return (parsedData[key] as? String) ?? defaultValue
    }
    
    public func intValue(_ key: String) throws -> Int {
        if let intValue = parsedData[key] as? Int {
            return intValue
        }
        if let doubleValue = parsedData[key] as? Double {
            return Int(doubleValue)
        }
        throw ModernToolError.invalidInput("Missing or invalid integer value for key: \(key)")
    }
    
    public func intValue(_ key: String, default defaultValue: Int?) -> Int? {
        if let intValue = parsedData[key] as? Int {
            return intValue
        }
        if let doubleValue = parsedData[key] as? Double {
            return Int(doubleValue)
        }
        return defaultValue
    }
    
    public func boolValue(_ key: String, default defaultValue: Bool) -> Bool {
        return (parsedData[key] as? Bool) ?? defaultValue
    }
    
    public func doubleValue(_ key: String) throws -> Double {
        if let doubleValue = parsedData[key] as? Double {
            return doubleValue
        }
        if let intValue = parsedData[key] as? Int {
            return Double(intValue)
        }
        throw ModernToolError.invalidInput("Missing or invalid double value for key: \(key)")
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ModernToolOutput: Sendable {
    case string(String)
    case error(message: String)
    
    public func toJSONString() throws -> String {
        switch self {
        case .string(let str):
            return str
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModernTool<Context>: Sendable {
    public let name: String
    public let description: String
    public let execute: @Sendable (ModernToolInput, Context) async throws -> ModernToolOutput
    
    public init(
        name: String,
        description: String,
        execute: @escaping @Sendable (ModernToolInput, Context) async throws -> ModernToolOutput
    ) {
        self.name = name
        self.description = description
        self.execute = execute
    }
    
    public func toToolDefinition() -> ModernToolDefinition {
        ModernToolDefinition(name: name, description: description)
    }
}

// MARK: - Mock Implementation

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
private struct MockModel: ModernModelInterface {
    let modelId: String
    
    func getResponse(request: ModernModelRequest) async throws -> ModernModelResponse {
        // Simple mock response
        let content = ModernAssistantContent.outputText("Mock response from \(modelId)")
        return ModernModelResponse(content: [content])
    }
    
    func getStreamedResponse(request: ModernModelRequest) async throws -> AsyncThrowingStream<ModernStreamEvent, any Error> {
        return AsyncThrowingStream { continuation in
            Task {
                continuation.yield(ModernStreamEvent(type: .textDelta, delta: "Mock "))
                try await Task.sleep(nanoseconds: 100_000_000)
                continuation.yield(ModernStreamEvent(type: .textDelta, delta: "response "))
                try await Task.sleep(nanoseconds: 100_000_000)
                continuation.yield(ModernStreamEvent(type: .textDelta, delta: "from \(modelId)"))
                continuation.yield(ModernStreamEvent(type: .complete))
                continuation.finish()
            }
        }
    }
}

// MARK: - Modern API Types Export

// The modern types are available with their Modern* prefixes
// to avoid conflicts with legacy types during the transition.
// Once the refactor is complete, these can be re-exported
// without the Modern prefix.