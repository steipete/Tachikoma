//
//  RealtimeConversation.swift
//  Tachikoma
//

import Foundation
import Tachikoma
#if canImport(Combine)
import Combine
#endif

// MARK: - Conversation State

/// Current state of a real-time conversation
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum ConversationState: String, Sendable {
    case idle
    case listening
    case processing
    case speaking
    case error
}

// MARK: - Connection Status

/// Status of the realtime connection
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum ConnectionStatus: String, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error
}

// MARK: - Realtime Conversation

/// High-level API for managing real-time voice conversations
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@MainActor
public final class RealtimeConversation: ObservableObject {
    // MARK: - Nested Types
    
    /// Configuration for realtime conversation
    public struct ConversationConfiguration: Sendable {
        public var enableVAD: Bool
        public var enableEchoCancellation: Bool
        public var enableNoiseSupression: Bool
        public var autoReconnect: Bool
        public var sessionPersistence: Bool
        
        public init(
            enableVAD: Bool = true,
            enableEchoCancellation: Bool = true,
            enableNoiseSupression: Bool = true,
            autoReconnect: Bool = true,
            sessionPersistence: Bool = true
        ) {
            self.enableVAD = enableVAD
            self.enableEchoCancellation = enableEchoCancellation
            self.enableNoiseSupression = enableNoiseSupression
            self.autoReconnect = autoReconnect
            self.sessionPersistence = sessionPersistence
        }
    }
    
    /// Message in conversation
    public struct ConversationMessage: Identifiable, Sendable {
        public let id: String
        public let role: Tachikoma.ModelMessage.Role
        public let content: String
        public let timestamp: Date
        public let audioData: Data?
        
        public init(
            id: String = UUID().uuidString,
            role: Tachikoma.ModelMessage.Role,
            content: String,
            timestamp: Date = Date(),
            audioData: Data? = nil
        ) {
            self.id = id
            self.role = role
            self.content = content
            self.timestamp = timestamp
            self.audioData = audioData
        }
    }
    // MARK: - Properties
    
    /// The underlying session
    private let session: RealtimeSession
    
    /// Tool registry for function calling
    private let toolRegistry = RealtimeToolRegistry()
    
    /// Current conversation state
    @Published public private(set) var state: ConversationState = .idle
    
    /// Conversation items (messages)
    public private(set) var items: [ConversationItem] = []
    
    /// Conversation messages
    @Published public private(set) var messages: [ConversationMessage] = []
    
    /// Connection status
    @Published public private(set) var connectionStatus: ConnectionStatus = .disconnected
    
    /// Whether we're currently recording audio
    @Published public private(set) var isRecording: Bool = false
    
    /// Whether the assistant is currently speaking
    @Published public private(set) var isPlaying: Bool = false
    
    /// Audio level for visualization
    @Published public private(set) var audioLevel: Float = 0
    
    /// Current configuration
    public let configuration: TachikomaConfiguration
    
    /// Whether the conversation is ready
    public var isReady: Bool {
        connectionStatus == .connected
    }
    
    /// Duration of the current session
    public var duration: TimeInterval? {
        // TODO: Track session start time
        nil
    }
    
    // Event streams
    private var transcriptContinuation: AsyncStream<String>.Continuation?
    private var audioLevelContinuation: AsyncStream<Float>.Continuation?
    private var stateContinuation: AsyncStream<ConversationState>.Continuation?
    
    // Audio buffering
    private var audioBuffer = Data()
    private let audioChunkSize = 1024 * 4 // 4KB chunks
    
    // Background tasks
    private var eventProcessingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    public init(configuration: TachikomaConfiguration = TachikomaConfiguration()) throws {
        self.configuration = configuration
        
        // Get API key
        guard let apiKey = configuration.getAPIKey(for: .openai) else {
            throw TachikomaError.authenticationFailed("OpenAI API key not found")
        }
        
        // Create session with configuration
        let sessionConfig = SessionConfiguration(
            model: "gpt-4o-realtime-preview",
            voice: .alloy,
            instructions: nil,
            tools: nil,
            temperature: 0.8
        )
        
        self.session = RealtimeSession(
            apiKey: apiKey,
            configuration: sessionConfig
        )
    }
    
    // MARK: - Lifecycle
    
    /// Start the conversation
    public func start(
        model: LanguageModel.OpenAI = .gpt4oRealtime,
        voice: RealtimeVoice = .alloy,
        instructions: String? = nil,
        tools: [RealtimeTool]? = nil
    ) async throws {
        // Update session configuration
        var config = session.configuration
        config.model = model.modelId
        config.voice = voice
        config.instructions = instructions
        config.tools = tools
        
        // Update connection status
        connectionStatus = .connecting
        
        // Connect to the API
        try await session.connect()
        connectionStatus = .connected
        
        // Update configuration if needed
        if instructions != nil || tools != nil {
            try await session.update(config)
        }
        
        // Start processing events
        startEventProcessing()
        
        // Update state
        state = .idle
        stateContinuation?.yield(.idle)
    }
    
    /// End the conversation
    public func end() async {
        // Stop recording if active
        if isRecording {
            await stopListening()
        }
        
        // Cancel event processing
        eventProcessingTask?.cancel()
        
        // Disconnect session
        await session.disconnect()
        
        // Update state
        state = .idle
        stateContinuation?.yield(.idle)
        connectionStatus = .disconnected
        
        // Complete all streams
        transcriptContinuation?.finish()
        audioLevelContinuation?.finish()
        stateContinuation?.finish()
    }
    
    // MARK: - Audio Control
    
    /// Start listening for user input
    public func startListening() async throws {
        guard !isRecording else { return }
        
        isRecording = true
        state = .listening
        stateContinuation?.yield(.listening)
        
        // Note: In a real implementation, we'd start audio capture here
        // For now, this is a placeholder
    }
    
    /// Stop listening for user input
    public func stopListening() async {
        guard isRecording else { return }
        
        isRecording = false
        
        // Commit any buffered audio
        if !audioBuffer.isEmpty {
            try? await session.commitAudio()
            audioBuffer = Data()
        }
        
        state = .processing
        stateContinuation?.yield(.processing)
    }
    
    /// Send audio data
    public func sendAudio(_ data: Data) async throws {
        guard isRecording else { return }
        
        // Add to buffer
        audioBuffer.append(data)
        
        // Send in chunks
        while audioBuffer.count >= audioChunkSize {
            let chunk = audioBuffer.prefix(audioChunkSize)
            try await session.appendAudio(Data(chunk))
            audioBuffer.removeFirst(audioChunkSize)
            
            // Simulate audio level for UI feedback
            let level = Float.random(in: 0.1...0.8)
            audioLevelContinuation?.yield(level)
            audioLevel = level
        }
    }
    
    // MARK: - Text Interaction
    
    /// Send a text message
    public func sendText(_ text: String) async throws {
        // Create a user message item
        let item = ConversationItem(
            type: "message",
            role: "user",
            content: [ConversationContent(type: "text", text: text)]
        )
        
        // Add to local items
        items.append(item)
        
        // Send to API
        try await session.createItem(item)
        
        // Trigger response
        try await session.createResponse()
        
        // Update state
        state = .processing
        stateContinuation?.yield(.processing)
    }
    
    /// Interrupt the current response
    public func interrupt() async throws {
        try await session.cancelResponse()
        
        state = .idle
        stateContinuation?.yield(.idle)
        isPlaying = false
    }
    
    /// Send a message (alias for sendText)
    public func sendMessage(_ text: String) async throws {
        try await sendText(text)
        
        // Add to messages
        let message = ConversationMessage(
            role: Tachikoma.ModelMessage.Role.user,
            content: text
        )
        messages.append(message)
    }
    
    /// Toggle recording
    public func toggleRecording() async throws {
        if isRecording {
            await stopListening()
        } else {
            try await startListening()
        }
    }
    
    /// Clear conversation history
    public func clearHistory() {
        messages.removeAll()
        items.removeAll()
    }
    
    /// Export conversation as text
    public func exportAsText() -> String {
        messages.map { message in
            "\(message.role): \(message.content)"
        }.joined(separator: "\n")
    }
    
    /// Register tools for function calling
    public func registerTools(_ tools: [AgentTool]) async {
        // Convert AgentTool to RealtimeExecutableTool wrapper
        for tool in tools {
            let wrapper = AgentToolWrapper(tool: tool)
            await toolRegistry.register(wrapper)
        }
    }
    
    /// Register built-in tools
    public func registerBuiltInTools() async {
        await toolRegistry.registerBuiltInTools()
    }
    
    // MARK: - Event Streams
    
    /// Stream of transcript updates
    public var transcriptUpdates: AsyncStream<String> {
        AsyncStream { continuation in
            self.transcriptContinuation = continuation
        }
    }
    
    /// Stream of audio level updates
    public var audioLevelUpdates: AsyncStream<Float> {
        AsyncStream { continuation in
            self.audioLevelContinuation = continuation
        }
    }
    
    /// Stream of state changes
    public var stateChanges: AsyncStream<ConversationState> {
        AsyncStream { continuation in
            self.stateContinuation = continuation
        }
    }
    
    // MARK: - Private Methods
    
    private func startEventProcessing() {
        eventProcessingTask = Task {
            let eventStream = session.eventStream()
            
            do {
                for try await event in eventStream {
                    await handleServerEvent(event)
                }
            } catch {
                print("RealtimeConversation: Event stream error: \(error)")
                state = .error
                stateContinuation?.yield(.error)
            }
        }
    }
    
    private func handleServerEvent(_ event: RealtimeServerEvent) async {
        switch event {
        case .conversationItemCreated(let event):
            // Add item to conversation
            items.append(event.item)
            
        case .responseTextDelta(let event):
            // Stream text updates
            transcriptContinuation?.yield(event.delta)
            
        case .responseTextDone(let event):
            // Final text received
            transcriptContinuation?.yield(event.text)
            
            // Add assistant message
            let message = ConversationMessage(
                role: Tachikoma.ModelMessage.Role.assistant,
                content: event.text
            )
            messages.append(message)
            
        case .responseAudioDelta(_):
            // Handle audio streaming (would play audio here)
            state = .speaking
            stateContinuation?.yield(.speaking)
            
        case .responseAudioDone:
            // Audio playback complete
            state = .idle
            stateContinuation?.yield(.idle)
            isPlaying = false
            
        case .inputAudioBufferSpeechStarted:
            // User started speaking
            state = .listening
            stateContinuation?.yield(.listening)
            
        case .inputAudioBufferSpeechStopped:
            // User stopped speaking
            state = .processing
            stateContinuation?.yield(.processing)
            
        case .responseFunctionCallArgumentsDone(let event):
            // Handle function call
            await handleFunctionCall(event)
            
        case .error(let event):
            print("RealtimeConversation: API error: \(event.error.message)")
            state = .error
            stateContinuation?.yield(.error)
            
        default:
            // Handle other events as needed
            break
        }
    }
    
    private func handleFunctionCall(_ event: ResponseFunctionCallArgumentsDoneEvent) async {
        // Execute the tool
        let result = await toolRegistry.execute(
            toolName: event.name,
            arguments: event.arguments
        )
        
        print("Function call: \(event.name) executed with result: \(result)")
        
        // Create result item with actual result
        let resultItem = ConversationItem(
            id: UUID().uuidString,
            type: "function_call_output",
            role: nil,
            content: nil,
            callId: event.callId,
            name: nil,
            arguments: nil,
            output: result
        )
        
        // Send result
        try? await session.createItem(resultItem)
        
        // Continue conversation
        try? await session.createResponse()
    }
}

// MARK: - Integration with Generation API

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func startRealtimeConversation(
    model: LanguageModel.OpenAI = .gpt4oRealtime,
    voice: RealtimeVoice = .alloy,
    instructions: String? = nil,
    tools: [AgentTool]? = nil,
    configuration: TachikomaConfiguration = TachikomaConfiguration()
) async throws -> RealtimeConversation {
    // Verify model supports realtime
    guard model.supportsRealtime else {
        throw TachikomaError.unsupportedOperation("Model \(model.modelId) doesn't support Realtime API")
    }
    
    // Create conversation
    let conversation = try await MainActor.run {
        try RealtimeConversation(configuration: configuration)
    }
    
    // Register tools with the conversation
    if let tools = tools {
        await conversation.registerTools(tools)
    }
    
    // Convert AgentTool to RealtimeTool
    let realtimeTools = tools?.map { tool in
        RealtimeTool(
            name: tool.name,
            description: tool.description,
            parameters: tool.parameters
        )
    }
    
    // Start conversation
    try await conversation.start(
        model: model,
        voice: voice,
        instructions: instructions,
        tools: realtimeTools
    )
    
    return conversation
}


