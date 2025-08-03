import Foundation

// MARK: - Conversation Management

/// A conversation with an AI model
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class Conversation: @unchecked Sendable {
    private let lock = NSLock()
    private var _messages: [ConversationMessage] = []
    
    public var messages: [ConversationMessage] {
        lock.lock()
        defer { lock.unlock() }
        return _messages
    }
    
    public init() {}
    
    /// Add a user message to the conversation
    public func addUserMessage(_ content: String) {
        let message = ConversationMessage(role: .user, content: content)
        lock.lock()
        _messages.append(message)
        lock.unlock()
    }
    
    /// Add an assistant message to the conversation
    public func addAssistantMessage(_ content: String) {
        let message = ConversationMessage(role: .assistant, content: content)
        lock.lock()
        _messages.append(message)
        lock.unlock()
    }
    
    /// Add a system message to the conversation
    public func addSystemMessage(_ content: String) {
        let message = ConversationMessage(role: .system, content: content)
        lock.lock()
        _messages.append(message)
        lock.unlock()
    }
    
    /// Clear all messages from the conversation
    public func clear() {
        lock.lock()
        _messages.removeAll()
        lock.unlock()
    }
    
    /// Continue the conversation with a model
    public func continueConversation(using model: Model? = nil, tools: (any ToolKit)? = nil) async throws -> String {
        // Convert conversation messages to model messages
        let modelMessages = messages.map { conversationMessage in
            ModelMessage(
                id: conversationMessage.id,
                role: ModelMessage.Role(rawValue: conversationMessage.role.rawValue) ?? .user,
                content: [.text(conversationMessage.content)],
                timestamp: conversationMessage.timestamp
            )
        }
        
        // Generate response using the core API
        let response = try await generateText(
            model: model ?? .default,
            messages: modelMessages,
            tools: [],
            settings: .default
        )
        
        // Add the response to the conversation
        addAssistantMessage(response.text)
        
        return response.text
    }
}

/// A message in a conversation
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ConversationMessage: Sendable, Codable, Equatable {
    public let id: String
    public let role: Role
    public let content: String
    public let timestamp: Date
    
    public enum Role: String, Sendable, Codable, CaseIterable {
        case system
        case user
        case assistant
        case tool
    }
    
    public init(id: String = UUID().uuidString, role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}