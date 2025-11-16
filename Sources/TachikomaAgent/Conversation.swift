import Foundation
import Tachikoma

// MARK: - Conversation Management

/// A conversation with an AI model
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class Conversation: @unchecked Sendable {
    private let lock = NSLock()
    private var _messages: [ConversationMessage] = []

    /// The configuration used by this conversation
    public let configuration: TachikomaConfiguration

    public var messages: [ConversationMessage] {
        self.lock.lock()
        defer { lock.unlock() }
        return self._messages
    }

    public init(configuration: TachikomaConfiguration = .current) {
        self.configuration = configuration
    }

    /// Add a user message to the conversation
    public func addUserMessage(_ content: String) {
        // Add a user message to the conversation
        let message = ConversationMessage(role: .user, content: content)
        self.lock.lock()
        self._messages.append(message)
        self.lock.unlock()
    }

    /// Add an assistant message to the conversation
    public func addAssistantMessage(_ content: String) {
        // Add an assistant message to the conversation
        let message = ConversationMessage(role: .assistant, content: content)
        self.lock.lock()
        self._messages.append(message)
        self.lock.unlock()
    }

    /// Add a system message to the conversation
    public func addSystemMessage(_ content: String) {
        // Add a system message to the conversation
        let message = ConversationMessage(role: .system, content: content)
        self.lock.lock()
        self._messages.append(message)
        self.lock.unlock()
    }

    /// Clear all messages from the conversation
    public func clear() {
        // Clear all messages from the conversation
        self.lock.lock()
        self._messages.removeAll()
        self.lock.unlock()
    }

    /// Get messages as ModelMessage array for API compatibility
    public func getModelMessages() -> [ModelMessage] {
        // Get messages as ModelMessage array for API compatibility
        self.messages.map { $0.toModelMessage() }
    }

    /// Add a ModelMessage to the conversation
    public func addModelMessage(_ modelMessage: ModelMessage) {
        // Add a ModelMessage to the conversation
        let conversationMessage = ConversationMessage.from(modelMessage)
        self.lock.lock()
        self._messages.append(conversationMessage)
        self.lock.unlock()
    }

    /// Continue the conversation with a model
    public func continueConversation(using model: Model? = nil, tools _: [AgentTool]? = nil) async throws -> String {
        // Convert conversation messages to model messages
        let modelMessages = self.messages.map { conversationMessage in
            ModelMessage(
                id: conversationMessage.id,
                role: ModelMessage.Role(rawValue: conversationMessage.role.rawValue) ?? .user,
                content: [.text(conversationMessage.content)],
                timestamp: conversationMessage.timestamp,
            )
        }

        // Generate response using the core API
        let response = try await generateText(
            model: model ?? .default,
            messages: modelMessages,
            tools: [],
            settings: .default,
            configuration: configuration,
        )

        // Add the response to the conversation
        self.addAssistantMessage(response.text)

        return response.text
    }

    /// Continue the conversation with a model, streaming the response
    public func continueConversationStreaming(
        using model: LanguageModel? = nil,
        tools: [AgentTool]? = nil,
    ) async throws
        -> AsyncThrowingStream<String, Error>
    {
        // Convert conversation messages to model messages
        let modelMessages = self.messages.map { conversationMessage in
            ModelMessage(
                id: conversationMessage.id,
                role: ModelMessage.Role(rawValue: conversationMessage.role.rawValue) ?? .user,
                content: [.text(conversationMessage.content)],
                timestamp: conversationMessage.timestamp,
            )
        }

        // Generate response using the core API
        let responseStream = try await streamText(
            model: model ?? .default,
            messages: modelMessages,
            tools: tools ?? [], // Use provided tools or empty array
            settings: .default,
            configuration: configuration,
        )

        // Create a new stream to process the response and update the conversation
        let processedStream = AsyncThrowingStream<String, Error> { continuation in
            Task {
                var fullResponse = ""
                do {
                    for try await delta in responseStream.stream {
                        switch delta.type {
                        case .textDelta:
                            if let text = delta.content {
                                continuation.yield(text)
                                fullResponse += text
                            }
                        default:
                            break
                        }
                    }
                    // Add the full response to the conversation
                    if !fullResponse.isEmpty {
                        self.addAssistantMessage(fullResponse)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }

        return processedStream
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
        // Convert to ModelMessage for API compatibility
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
            timestamp: self.timestamp,
        )
    }

    /// Create from ModelMessage
    public static func from(_ modelMessage: ModelMessage) -> ConversationMessage {
        // Create from ModelMessage
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
            timestamp: modelMessage.timestamp,
        )
    }
}
