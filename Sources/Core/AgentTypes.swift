<<<<<<< HEAD
import Foundation

// MARK: - Agent Execution Result

/// The result of an agent execution containing output and metadata
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentExecutionResult: Sendable {
    /// The final text output
    public let content: String
    
    /// All messages in the conversation
    public let messages: [Message]
    
    /// The session ID for resuming
    public let sessionId: String
    
    /// Token usage information
    public let usage: Usage?
    
    /// Tool calls made during execution
    public let toolCalls: [ToolCallItem]
    
    /// Execution metadata
    public let metadata: AgentMetadata
    
    public init(
        content: String,
        messages: [Message],
        sessionId: String,
        usage: Usage?,
        toolCalls: [ToolCallItem],
        metadata: AgentMetadata
    ) {
        self.content = content
        self.messages = messages
        self.sessionId = sessionId
        self.usage = usage
        self.toolCalls = toolCalls
        self.metadata = metadata
    }
}

// MARK: - Agent Metadata

/// Metadata about agent execution
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentMetadata: Sendable {
    /// When the execution started
    public let startTime: Date
    
    /// When the execution completed
    public let endTime: Date
    
    /// Total execution duration
    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    /// Number of tool calls made
    public let toolCallCount: Int
    
    /// Name of the model used
    public let modelName: String
    
    /// Whether this was a resumed session
    public let isResumed: Bool
    
    /// Masked API key for security
    public let maskedApiKey: String?
    
    public init(
        startTime: Date,
        endTime: Date,
        toolCallCount: Int,
        modelName: String,
        isResumed: Bool,
        maskedApiKey: String?
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.toolCallCount = toolCallCount
        self.modelName = modelName
        self.isResumed = isResumed
        self.maskedApiKey = maskedApiKey
    }
}

// Note: Usage and ToolCallItem types are already defined in StreamingTypes.swift and MessageTypes.swift

// MARK: - Agent Events

/// Events emitted during agent execution
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum AgentEvent: Sendable {
    case textDelta(String)
    case toolCallStarted(name: String, arguments: String)
    case toolCallCompleted(name: String, result: String)
    case error(message: String)
    case completed(summary: String, usage: Usage?)
}

// MARK: - Agent Event Delegate

/// Protocol for receiving real-time agent events
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public protocol AgentEventDelegate: Sendable {
    func didReceiveEvent(_ event: AgentEvent) async
}

// MARK: - Tool Execution Event

/// Events related to tool execution during agent runs
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ToolExecutionEvent: Sendable {
    case toolStarted(name: String, arguments: String)
    case toolProgress(name: String, progress: String)
    case toolCompleted(name: String, result: String)
    case toolFailed(name: String, error: String)
}
||||||| parent of 69989a9 (fix: Update test suite to match current API)
=======
import Foundation

/// Result of agent task execution containing response content, metadata, and tool usage information
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentExecutionResult: Sendable {
    /// The generated response content from the AI model
    public let content: String

    /// Complete conversation messages including tool calls and responses
    public let messages: [Message]

    /// Session identifier for tracking conversation state
    public let sessionId: String?

    /// Token usage statistics from the AI provider
    public let usage: Usage?

    /// List of tool calls executed during the task
    public let toolCalls: [ToolCallItem]

    /// Additional metadata about the execution
    public let metadata: AgentMetadata

    public init(
        content: String,
        messages: [Message] = [],
        sessionId: String? = nil,
        usage: Usage? = nil,
        toolCalls: [ToolCallItem] = [],
        metadata: AgentMetadata
    ) {
        self.content = content
        self.messages = messages
        self.sessionId = sessionId
        self.usage = usage
        self.toolCalls = toolCalls
        self.metadata = metadata
    }
}

/// Metadata about agent execution including performance metrics and model information
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentMetadata: Sendable {
    /// Total execution time in seconds
    public let executionTime: TimeInterval

    /// Number of tool calls made during execution
    public let toolCallCount: Int

    /// Model name used for generation
    public let modelName: String

    /// Timestamp when execution started
    public let startTime: Date

    /// Timestamp when execution completed
    public let endTime: Date

    /// Additional context-specific metadata
    public let context: [String: String]

    public init(
        executionTime: TimeInterval,
        toolCallCount: Int,
        modelName: String,
        startTime: Date,
        endTime: Date,
        context: [String: String] = [:]
    ) {
        self.executionTime = executionTime
        self.toolCallCount = toolCallCount
        self.modelName = modelName
        self.startTime = startTime
        self.endTime = endTime
        self.context = context
    }
}

/// Real-time event from agent execution for streaming updates
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum AgentEvent: Sendable {
    /// Agent started processing the task
    case taskStarted(task: String)

    /// Agent is thinking/planning the next step
    case thinking(message: String)

    /// Agent is about to execute a tool
    case toolCallStarted(toolName: String, parameters: [String: String])

    /// Tool execution completed successfully
    case toolCallCompleted(toolName: String, result: String)

    /// Tool execution failed
    case toolCallFailed(toolName: String, error: String)

    /// Agent generated partial response content
    case responseChunk(content: String)

    /// Agent completed the entire task
    case taskCompleted(result: AgentExecutionResult)

    /// Agent encountered an error
    case error(message: String)
}

/// Delegate protocol for receiving real-time agent execution events
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public protocol AgentEventDelegate: Sendable {
    /// Called when an agent event occurs during execution
    func agentDidEmitEvent(_ event: AgentEvent) async
}
>>>>>>> 69989a9 (fix: Update test suite to match current API)
