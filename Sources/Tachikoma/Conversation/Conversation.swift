import Foundation

// MARK: - Conversation Management

/// A conversation with an AI model
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class Conversation: @unchecked Sendable {
    private let lock = NSLock()
    private var _messages: [ConversationMessage] = []

    public var messages: [ConversationMessage] {
        self.lock.lock()
        defer { lock.unlock() }
        return self._messages
    }

    public init() {}

    /// Add a user message to the conversation
    public func addUserMessage(_ content: String) {
        let message = ConversationMessage(role: .user, content: content)
        self.lock.lock()
        self._messages.append(message)
        self.lock.unlock()
    }

    /// Add an assistant message to the conversation
    public func addAssistantMessage(_ content: String) {
        let message = ConversationMessage(role: .assistant, content: content)
        self.lock.lock()
        self._messages.append(message)
        self.lock.unlock()
    }

    /// Add a system message to the conversation
    public func addSystemMessage(_ content: String) {
        let message = ConversationMessage(role: .system, content: content)
        self.lock.lock()
        self._messages.append(message)
        self.lock.unlock()
    }

    /// Clear all messages from the conversation
    public func clear() {
        self.lock.lock()
        self._messages.removeAll()
        self.lock.unlock()
    }

    /// Get messages as ModelMessage array for API compatibility
    public func getModelMessages() -> [ModelMessage] {
        self.messages.map { $0.toModelMessage() }
    }

    /// Add a ModelMessage to the conversation
    public func addModelMessage(_ modelMessage: ModelMessage) {
        let conversationMessage = ConversationMessage.from(modelMessage)
        self.lock.lock()
        self._messages.append(conversationMessage)
        self.lock.unlock()
    }

    /// Continue the conversation with a model
    public func continueConversation(using model: Model? = nil, tools: (any ToolKit)? = nil) async throws -> String {
        // Convert conversation messages to model messages
        let modelMessages = self.messages.map { conversationMessage in
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
        self.addAssistantMessage(response.text)

        return response.text
    }
}

/// A message in a conversation
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
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

    /// Convert to ModelMessage for API compatibility
    public func toModelMessage() -> ModelMessage {
        let modelRole: ModelMessage.Role = switch self.role {
        case .system: .system
        case .user: .user
        case .assistant: .assistant
        case .tool: .tool
        }

        return ModelMessage(
            id: self.id,
            role: modelRole,
            content: [.text(self.content)],
            timestamp: self.timestamp
        )
    }

    /// Create from ModelMessage
    public static func from(_ modelMessage: ModelMessage) -> ConversationMessage {
        let role: Role = switch modelMessage.role {
        case .system: .system
        case .user: .user
        case .assistant: .assistant
        case .tool: .tool
        }

        // Extract text content from ModelMessage content parts
        let textContent = modelMessage.content
            .compactMap { part in
                if case let .text(text) = part {
                    return text
                }
                return nil
            }
            .joined(separator: "\n")

        return ConversationMessage(
            id: modelMessage.id,
            role: role,
            content: textContent,
            timestamp: modelMessage.timestamp
        )
    }
}
