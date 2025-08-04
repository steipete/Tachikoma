import Foundation

/// Modern AI agent integrated with the Tachikoma enum-based model system
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class Agent<Context>: @unchecked Sendable {
    /// Agent's unique identifier
    public let name: String

    /// System instructions for the agent
    public let instructions: String

    /// Available tools for the agent
    public private(set) var tools: [SimpleTool]

    /// Language model used by this agent
    public var model: LanguageModel

    /// Generation settings for the agent
    public var settings: GenerationSettings

    /// The context instance passed to tool executions
    private let context: Context

    /// Current conversation history
    public private(set) var conversation: Conversation

    public init(
        name: String,
        instructions: String,
        model: LanguageModel = .default,
        tools: [SimpleTool] = [],
        settings: GenerationSettings = .default,
        context: Context
    ) {
        self.name = name
        self.instructions = instructions
        self.model = model
        self.tools = tools
        self.settings = settings
        self.context = context
        self.conversation = Conversation()

        // Add system message with instructions
        self.conversation.addSystemMessage(instructions)
    }

    /// Add a tool to the agent
    public func addTool(_ tool: SimpleTool) {
        self.tools.append(tool)
    }

    /// Remove a tool from the agent
    public func removeTool(named name: String) {
        self.tools.removeAll { $0.name == name }
    }

    /// Execute a single message with the agent
    public func execute(_ message: String) async throws -> AgentResponse {
        // Add user message to conversation
        self.conversation.addUserMessage(message)

        // Generate response using the conversation
        let result = try await generateText(
            model: model,
            messages: conversation.getModelMessages(),
            tools: self.tools.isEmpty ? nil : self.tools,
            settings: self.settings,
            maxSteps: 5 // Allow multi-step tool execution
        )

        // Add assistant response to conversation
        self.conversation.addAssistantMessage(result.text)

        // Add any tool calls and results to conversation
        for step in result.steps {
            if !step.toolCalls.isEmpty {
                for _ in step.toolCalls {
                    // Tool calls are already added by generateText
                }
            }
            if !step.toolResults.isEmpty {
                for _ in step.toolResults {
                    // Tool results are already added by generateText
                }
            }
        }

        return AgentResponse(
            text: result.text,
            usage: result.usage,
            finishReason: result.finishReason,
            steps: result.steps,
            conversationLength: self.conversation.messages.count
        )
    }

    /// Stream a response from the agent
    public func stream(_ message: String) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        // Add user message to conversation
        self.conversation.addUserMessage(message)

        // Stream response
        let streamResult = try await streamText(
            model: model,
            messages: conversation.getModelMessages(),
            tools: self.tools.isEmpty ? nil : self.tools,
            settings: self.settings,
            maxSteps: 5
        )

        // Track final message in conversation (this is approximate for streaming)
        let trackedStream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                do {
                    var assistantText = ""

                    for try await delta in streamResult.textStream {
                        continuation.yield(delta)

                        // Collect assistant text
                        if case .textDelta = delta.type, let content = delta.content {
                            assistantText += content
                        }

                        if case .done = delta.type {
                            // Add final assistant message to conversation
                            if !assistantText.isEmpty {
                                self.conversation.addAssistantMessage(assistantText)
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }

        return trackedStream
    }

    /// Reset the agent's conversation history
    public func resetConversation() {
        self.conversation = Conversation()
        self.conversation.addSystemMessage(self.instructions)
    }

    /// Get the current conversation history
    public var messages: [ModelMessage] {
        self.conversation.getModelMessages()
    }

    /// Update the agent's instructions
    public func updateInstructions(_ newInstructions: String) {
        // Create new conversation with updated instructions
        let oldMessages = self.conversation.getModelMessages().filter { $0.role != .system }
        self.conversation = Conversation()
        self.conversation.addSystemMessage(newInstructions)

        // Re-add non-system messages
        for message in oldMessages {
            self.conversation.addModelMessage(message)
        }
    }
}

/// Response from an agent execution
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentResponse: Sendable {
    public let text: String
    public let usage: Usage?
    public let finishReason: FinishReason
    public let steps: [GenerationStep]
    public let conversationLength: Int

    public init(
        text: String,
        usage: Usage?,
        finishReason: FinishReason,
        steps: [GenerationStep],
        conversationLength: Int
    ) {
        self.text = text
        self.usage = usage
        self.finishReason = finishReason
        self.steps = steps
        self.conversationLength = conversationLength
    }
}

/// Session management for agents
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class AgentSessionManager: @unchecked Sendable {
    public static let shared = AgentSessionManager()

    private var sessions: [String: AgentSessionData] = [:]
    private let lock = NSLock()

    private init() {}

    /// Create a new agent session
    public func createSession(
        sessionId: String,
        agent: Agent<some Any>
    ) {
        self.lock.lock()
        defer { lock.unlock() }

        self.sessions[sessionId] = AgentSessionData(
            id: sessionId,
            modelName: agent.model.description,
            createdAt: Date(),
            lastAccessedAt: Date(),
            messageCount: agent.messages.count,
            status: .active
        )
    }

    /// Update session data
    public func updateSession(
        sessionId: String,
        agent: Agent<some Any>
    ) {
        self.lock.lock()
        defer { lock.unlock() }

        if var sessionData = sessions[sessionId] {
            sessionData.lastAccessedAt = Date()
            sessionData.messageCount = agent.messages.count
            self.sessions[sessionId] = sessionData
        }
    }

    /// Complete a session
    public func completeSession(sessionId: String) {
        self.lock.lock()
        defer { lock.unlock() }

        if var sessionData = sessions[sessionId] {
            sessionData.status = .completed
            sessionData.lastAccessedAt = Date()
            self.sessions[sessionId] = sessionData
        }
    }

    /// Get session summary
    public func getSessionSummary(sessionId: String) -> SessionSummary? {
        self.lock.lock()
        defer { lock.unlock() }

        guard let sessionData = sessions[sessionId] else { return nil }

        return SessionSummary(
            id: sessionData.id,
            modelName: sessionData.modelName,
            createdAt: sessionData.createdAt,
            lastAccessedAt: sessionData.lastAccessedAt,
            messageCount: sessionData.messageCount,
            status: sessionData.status,
            summary: nil // Could be enhanced to generate summaries
        )
    }

    /// List all sessions
    public func listSessions() -> [SessionSummary] {
        self.lock.lock()
        defer { lock.unlock() }

        return self.sessions.values.map { sessionData in
            SessionSummary(
                id: sessionData.id,
                modelName: sessionData.modelName,
                createdAt: sessionData.createdAt,
                lastAccessedAt: sessionData.lastAccessedAt,
                messageCount: sessionData.messageCount,
                status: sessionData.status,
                summary: nil
            )
        }.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
    }

    /// Remove a session
    public func removeSession(sessionId: String) {
        self.lock.lock()
        defer { lock.unlock() }

        self.sessions.removeValue(forKey: sessionId)
    }

    /// Clear old sessions (older than specified days)
    public func clearOldSessions(olderThanDays days: Int = 30) {
        self.lock.lock()
        defer { lock.unlock() }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        self.sessions = self.sessions.filter { _, sessionData in
            sessionData.lastAccessedAt >= cutoffDate
        }
    }
}

/// Internal session data structure
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
private struct AgentSessionData {
    let id: String
    let modelName: String
    let createdAt: Date
    var lastAccessedAt: Date
    var messageCount: Int
    var status: SessionStatus
}

/// Session summary information
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct SessionSummary: Sendable, Codable {
    /// Unique session identifier
    public let id: String

    /// Model name used in this session
    public let modelName: String

    /// When the session was created
    public let createdAt: Date

    /// When the session was last accessed
    public let lastAccessedAt: Date

    /// Number of messages in the session
    public let messageCount: Int

    /// Session status
    public let status: SessionStatus

    /// Brief description of the session
    public let summary: String?

    public init(
        id: String,
        modelName: String,
        createdAt: Date,
        lastAccessedAt: Date,
        messageCount: Int,
        status: SessionStatus,
        summary: String? = nil
    ) {
        self.id = id
        self.modelName = modelName
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.messageCount = messageCount
        self.status = status
        self.summary = summary
    }
}

/// Status of an agent session
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum SessionStatus: String, Codable, Sendable, CaseIterable {
    case active
    case completed
    case failed
    case cancelled
}
