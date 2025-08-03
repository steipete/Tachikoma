import Foundation

// MARK: - Conversation Management

/// Manages multi-turn conversations with AI models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class Conversation: ObservableObject, @unchecked Sendable {
    @Published public private(set) var messages: [ConversationMessage] = []
    @Published public private(set) var id: String
    
    public init(id: String = UUID().uuidString) {
        self.id = id
    }
    
    /// Add a user message to the conversation
    public func addUserMessage(_ content: String) {
        let message = ConversationMessage(
            id: UUID().uuidString,
            role: .user,
            content: content,
            timestamp: Date()
        )
        messages.append(message)
    }
    
    /// Add an assistant message to the conversation
    public func addAssistantMessage(_ content: String) {
        let message = ConversationMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: content,
            timestamp: Date()
        )
        messages.append(message)
    }
    
    /// Clear all messages from the conversation
    public func clear() {
        messages.removeAll()
    }
    
    /// Get the last N messages
    public func lastMessages(_ count: Int) -> [ConversationMessage] {
        return Array(messages.suffix(count))
    }
}

/// A message in a conversation
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ConversationMessage: Identifiable, Sendable {
    public let id: String
    public let role: MessageRole
    public let content: String
    public let timestamp: Date
    
    public init(id: String = UUID().uuidString, role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

/// Role of a message in a conversation
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum MessageRole: String, CaseIterable, Sendable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

// MARK: - Conversation Extensions

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public extension Conversation {
    /// Convert conversation to a format suitable for API requests
    var apiMessages: [[String: Any]] {
        return messages.map { message in
            [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }
    }
    
    /// Get conversation summary (first and last messages)
    var summary: String {
        guard !messages.isEmpty else { return "Empty conversation" }
        
        if messages.count <= 2 {
            return messages.map { $0.content }.joined(separator: " → ")
        }
        
        let first = messages.first!
        let last = messages.last!
        return "\(first.content) ... \(last.content)"
    }
    
    /// Check if conversation has any messages
    var isEmpty: Bool {
        return messages.isEmpty
    }
    
    /// Get total character count of all messages
    var characterCount: Int {
        return messages.reduce(0) { $0 + $1.content.count }
    }
}