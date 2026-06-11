import Foundation
import Tachikoma

// MARK: - Conversation Management

private actor ContinuationGate {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Bool, Never>
    }

    private var isLocked = false
    private var waiters: [Waiter] = []

    func acquire() async throws {
        try Task.checkCancellation()

        if !self.isLocked {
            self.isLocked = true
            return
        }

        let id = UUID()
        let acquired = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.waiters.append(Waiter(id: id, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }

        guard acquired else {
            throw CancellationError()
        }

        if Task.isCancelled {
            self.release()
            throw CancellationError()
        }
    }

    private func cancelWaiter(_ id: UUID) {
        guard let index = self.waiters.firstIndex(where: { $0.id == id }) else {
            return
        }

        let waiter = self.waiters.remove(at: index)
        waiter.continuation.resume(returning: false)
    }

    func release() {
        if self.waiters.isEmpty {
            self.isLocked = false
        } else {
            let waiter = self.waiters.removeFirst()
            waiter.continuation.resume(returning: true)
        }
    }
}

/// A conversation with an AI model
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class Conversation: @unchecked Sendable {
    private let lock = NSLock()
    private let continuationGate = ContinuationGate()
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

    /// Replace the conversation with lossless ModelMessage history.
    public func replaceModelMessages(_ modelMessages: [ModelMessage]) {
        self.lock.lock()
        self._messages = modelMessages.map { ConversationMessage.from($0) }
        self.lock.unlock()
    }

    /// Replace the conversation only if the original snapshot is still current.
    public func replaceModelMessages(
        _ modelMessages: [ModelMessage],
        validatingSnapshotIDs snapshotIDs: [String],
    )
        -> Bool
    {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard self._messages.count >= snapshotIDs.count else {
            return false
        }

        let currentPrefixIDs = self._messages.prefix(snapshotIDs.count).map(\.id)
        guard currentPrefixIDs == snapshotIDs else {
            return false
        }

        let laterMessages = self._messages.dropFirst(snapshotIDs.count)
        self._messages = modelMessages.map { ConversationMessage.from($0) } + laterMessages
        return true
    }

    /// Replace the original snapshot with generated history while preserving later appends.
    public func mergeGeneratedMessages(_ modelMessages: [ModelMessage], replacingPrefixCount prefixCount: Int) {
        self.lock.lock()
        let laterMessages = self._messages.dropFirst(min(prefixCount, self._messages.count))
        self._messages = modelMessages.map { ConversationMessage.from($0) } + laterMessages
        self.lock.unlock()
    }

    /// Insert generated response messages after the snapshot anchor while preserving concurrent appends.
    public func appendGeneratedMessages(_ modelMessages: [ModelMessage], afterMessageID messageID: String) {
        guard !modelMessages.isEmpty else { return }

        self.lock.lock()
        let conversationMessages = modelMessages.map { ConversationMessage.from($0) }
        if let index = self._messages.firstIndex(where: { $0.id == messageID }) {
            self._messages.insert(contentsOf: conversationMessages, at: self._messages.index(after: index))
        } else {
            self._messages.append(contentsOf: conversationMessages)
        }
        self.lock.unlock()
    }

    /// Insert generated response messages only if the snapshot prefix is still current.
    public func appendGeneratedMessages(
        _ modelMessages: [ModelMessage],
        afterMessageID messageID: String,
        validatingSnapshotIDs snapshotIDs: [String],
    )
        -> Bool
    {
        guard !modelMessages.isEmpty else { return true }

        self.lock.lock()
        defer { self.lock.unlock() }

        guard self._messages.count >= snapshotIDs.count else {
            return false
        }

        let currentPrefixIDs = self._messages.prefix(snapshotIDs.count).map(\.id)
        guard currentPrefixIDs == snapshotIDs else {
            return false
        }

        let conversationMessages = modelMessages.map { ConversationMessage.from($0) }
        if let index = self._messages.firstIndex(where: { $0.id == messageID }) {
            self._messages.insert(contentsOf: conversationMessages, at: self._messages.index(after: index))
        } else {
            self._messages.append(contentsOf: conversationMessages)
        }
        return true
    }

    /// Merge a refused generation without losing completed tool steps.
    public func mergeContentFilterResult(
        _ resultMessages: [ModelMessage],
        originalMessages: [ModelMessage],
        afterMessageID _: String?,
        validatingSnapshotIDs snapshotIDs: [String],
    )
        -> Bool
    {
        let generatedMessages = Array(resultMessages.dropFirst(originalMessages.count))
        if !generatedMessages.isEmpty {
            return self.replaceModelMessages(
                originalMessages + generatedMessages,
                validatingSnapshotIDs: snapshotIDs,
            )
        }

        return self.replaceModelMessages(
            originalMessages.droppingLastUserTurn(),
            validatingSnapshotIDs: snapshotIDs,
        )
    }

    public func removeMessage(id: String) {
        self.lock.lock()
        self._messages.removeAll { $0.id == id }
        self.lock.unlock()
    }

    public func withContinuationLock<T>(_ operation: () async throws -> T) async throws -> T {
        try await self.acquireContinuationLock()
        do {
            let result = try await operation()
            await self.releaseContinuationLock()
            return result
        } catch {
            await self.releaseContinuationLock()
            throw error
        }
    }

    public func acquireContinuationLock() async throws {
        try await self.continuationGate.acquire()
    }

    public func releaseContinuationLock() async {
        await self.continuationGate.release()
    }

    /// Continue the conversation with a model
    public func continueConversation(
        using model: Model? = nil,
        tools: [AgentTool]? = nil,
        maxSteps: Int = 5,
    ) async throws
        -> String
    {
        try await self.withContinuationLock {
            let conversationMessages = self.messages
            let modelMessages = conversationMessages.map { $0.toModelMessage() }
            let snapshotIDs = conversationMessages.map(\.id)
            let anchorID = conversationMessages.last?.id

            // Generate response using the core API
            let response = try await generateText(
                model: model ?? .default,
                messages: modelMessages,
                tools: tools,
                settings: .default,
                maxSteps: maxSteps,
                configuration: configuration,
            )

            let didMerge: Bool
            if response.finishReason == .contentFilter {
                didMerge = self.mergeContentFilterResult(
                    response.messages,
                    originalMessages: modelMessages,
                    afterMessageID: anchorID,
                    validatingSnapshotIDs: snapshotIDs,
                )
            } else if let anchorID {
                let generatedMessages = Array(response.messages.dropFirst(modelMessages.count))
                didMerge = self.appendGeneratedMessages(
                    generatedMessages,
                    afterMessageID: anchorID,
                    validatingSnapshotIDs: snapshotIDs,
                )
            } else if self.messages.isEmpty {
                self.replaceModelMessages(response.messages)
                didMerge = true
            } else {
                didMerge = false
            }

            guard didMerge else {
                throw TachikomaError.invalidConfiguration(
                    "Conversation changed during generation; refusing to merge response",
                )
            }

            return response.text
        }
    }

    /// Continue the conversation with a model, streaming the response
    public func continueConversationStreaming(
        using model: LanguageModel? = nil,
        tools: [AgentTool]? = nil,
    ) async throws
        -> AsyncThrowingStream<String, Error>
    {
        try await self.acquireContinuationLock()
        let gateRelease = AsyncReleaseOnce {
            await self.releaseContinuationLock()
        }
        let conversationMessages = self.messages
        let modelMessages = conversationMessages.map { $0.toModelMessage() }
        let snapshotIDs = conversationMessages.map(\.id)
        let resolvedModel = model ?? .defaultStreaming
        let streamSettings = GenerationSettings.default
        let buffersUntilDone = streamSettings.streamBuffering == .untilTerminal ||
            resolvedModel.requiresTerminalRefusalBuffering

        // Generate response using the core API
        let responseStream: StreamTextResult
        do {
            responseStream = try await streamText(
                model: resolvedModel,
                messages: modelMessages,
                tools: tools ?? [], // Use provided tools or empty array
                settings: streamSettings,
                configuration: self.configuration,
            )
        } catch {
            gateRelease.release()
            throw error
        }

        // Create a new stream to process the response and update the conversation
        return AsyncThrowingStream<String, Error> { continuation in
            let producer = Task {
                defer {
                    gateRelease.release()
                }
                var fullResponse = ""
                var isContentFiltered = false
                var bufferedText: [String] = []
                var didApproveBufferedResponse = !buffersUntilDone
                var didReceiveTerminal = false
                do {
                    for try await delta in responseStream.stream {
                        try Task.checkCancellation()
                        switch delta.type {
                        case .textDelta:
                            if let text = delta.content {
                                if buffersUntilDone {
                                    bufferedText.append(text)
                                } else {
                                    continuation.yield(text)
                                }
                                fullResponse += text
                            }
                        case .done where delta.finishReason == .contentFilter:
                            didReceiveTerminal = true
                            isContentFiltered = true
                            let didRollback = self.replaceModelMessages(
                                modelMessages.droppingLastUserTurn(),
                                validatingSnapshotIDs: snapshotIDs,
                            )
                            guard didRollback else {
                                throw TachikomaError.invalidConfiguration(
                                    "Conversation changed during streaming; refusing to merge response",
                                )
                            }
                            fullResponse = ""
                            bufferedText.removeAll()
                        case .done:
                            didReceiveTerminal = true
                            if buffersUntilDone {
                                for text in bufferedText {
                                    continuation.yield(text)
                                }
                                didApproveBufferedResponse = true
                                bufferedText.removeAll()
                            }
                        default:
                            break
                        }
                    }
                    if buffersUntilDone, !didReceiveTerminal, !bufferedText.isEmpty {
                        throw TachikomaError.apiError("Stream ended before provider completion status was received")
                    }
                    // Add the full response to the conversation
                    if !isContentFiltered, !fullResponse.isEmpty, didApproveBufferedResponse {
                        try Task.checkCancellation()
                        self.addAssistantMessage(fullResponse)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                producer.cancel()
            }
        }
    }
}

extension [ModelMessage] {
    func droppingLastUserTurn() -> [ModelMessage] {
        guard self.last?.role == .user else { return self }
        return Array(self.dropLast())
    }
}

/// A message in a conversation
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ConversationMessage: Sendable, Codable, Equatable {
    public let id: String
    public let role: Role
    public let content: String
    public let timestamp: Date
    public let contentParts: [ModelMessage.ContentPart]?
    public let channel: ResponseChannel?
    public let metadata: MessageMetadata?

    public enum Role: String, Sendable, Codable, CaseIterable {
        case system
        case user
        case assistant
        case tool
    }

    public init(
        id: String = UUID().uuidString,
        role: Role,
        content: String,
        timestamp: Date = Date(),
        contentParts: [ModelMessage.ContentPart]? = nil,
        channel: ResponseChannel? = nil,
        metadata: MessageMetadata? = nil,
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.contentParts = contentParts
        self.channel = channel
        self.metadata = metadata
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
            content: self.contentParts ?? [.text(self.content)],
            timestamp: self.timestamp,
            channel: self.channel,
            metadata: self.metadata,
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
            contentParts: modelMessage.content,
            channel: modelMessage.channel,
            metadata: modelMessage.metadata,
        )
    }
}
