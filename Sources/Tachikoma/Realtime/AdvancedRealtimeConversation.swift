//
//  AdvancedRealtimeConversation.swift
//  Tachikoma
//

#if canImport(Combine)
import Foundation
import Combine

// MARK: - Advanced Realtime Conversation

/// Advanced conversation management with full feature support
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@MainActor
public final class AdvancedRealtimeConversation: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var state: ConversationState = .idle
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var audioLevel: Float = 0
    @Published public private(set) var isSpeaking: Bool = false
    @Published public private(set) var isListening: Bool = false
    @Published public private(set) var transcript: String = ""
    @Published public private(set) var items: [ConversationItem] = []
    @Published public private(set) var turnActive: Bool = false
    @Published public private(set) var modalities: ResponseModality = .all
    
    // MARK: - Private Properties
    
    private let session: EnhancedRealtimeSession
    private let configuration: EnhancedSessionConfiguration
    private let settings: ConversationSettings
    private let toolRegistry = RealtimeToolRegistry()
    
    private var audioManager: RealtimeAudioManager?
    private var audioProcessor: RealtimeAudioProcessor?
    private var pipeline: AudioStreamPipeline?
    
    private var eventProcessingTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // Turn management
    private var currentTurnId: String?
    private var turnStartTime: Date?
    
    // MARK: - Initialization
    
    public init(
        apiKey: String,
        configuration: EnhancedSessionConfiguration = .voiceConversation(),
        settings: ConversationSettings = .production
    ) throws {
        self.configuration = configuration
        self.settings = settings
        self.session = EnhancedRealtimeSession(
            apiKey: apiKey,
            configuration: configuration,
            settings: settings
        )
        
        // Initialize audio components if needed
        if configuration.modalities?.contains(.audio) ?? false {
            setupAudioPipeline()
        }
        
        // Set up event handlers
        setupEventHandlers()
    }
    
    // MARK: - Public Methods
    
    /// Start the conversation with advanced configuration
    public func start() async throws {
        guard state == .idle else { return }
        
        state = .connecting
        
        // Connect to API
        try await session.connect()
        isConnected = true
        
        // Register tools if configured
        if let tools = configuration.tools {
            await registerRealtimeTools(tools)
        }
        
        // Start event processing
        startEventProcessing()
        
        // Start audio pipeline if using audio
        if configuration.modalities?.contains(.audio) ?? false {
            try await pipeline?.start()
        }
        
        state = .ready
    }
    
    /// End the conversation
    public func end() async {
        state = .disconnecting
        
        // Stop audio pipeline
        await pipeline?.stop()
        
        // Cancel event processing
        eventProcessingTask?.cancel()
        
        // Disconnect session
        await session.disconnect()
        
        isConnected = false
        state = .idle
    }
    
    /// Update conversation modalities dynamically
    public func updateModalities(_ modalities: ResponseModality) async throws {
        self.modalities = modalities
        
        var updatedConfig = configuration
        updatedConfig.modalities = modalities
        
        try await session.updateConfiguration(updatedConfig)
        
        // Start or stop audio pipeline based on modalities
        if modalities.contains(.audio) && pipeline == nil {
            setupAudioPipeline()
            try await pipeline?.start()
        } else if !modalities.contains(.audio) && pipeline != nil {
            await pipeline?.stop()
            pipeline = nil
        }
    }
    
    /// Update turn detection settings
    public func updateTurnDetection(_ turnDetection: RealtimeTurnDetection) async throws {
        var updatedConfig = configuration
        updatedConfig.turnDetection = turnDetection
        
        try await session.updateConfiguration(updatedConfig)
    }
    
    /// Send text message
    public func sendText(_ text: String) async throws {
        let item = ConversationItem(
            type: "message",
            role: "user",
            content: [ConversationContent(type: "text", text: text)]
        )
        
        items.append(item)
        try await session.createItem(item)
        
        // Create response based on modalities
        try await session.createResponse(modalities: modalities)
        
        state = .processing
    }
    
    /// Start listening (manual turn control)
    public func startListening() async throws {
        guard !isListening else { return }
        
        isListening = true
        turnActive = true
        currentTurnId = UUID().uuidString
        turnStartTime = Date()
        
        // Start audio capture if available
        try? await audioManager?.startRecording()
        
        state = .listening
    }
    
    /// Stop listening (manual turn control)
    public func stopListening() async throws {
        guard isListening else { return }
        
        isListening = false
        turnActive = false
        
        // Stop audio capture
        audioManager?.stopRecording()
        
        // Commit audio buffer
        try await session.commitAudio()
        
        // Log turn duration
        if let startTime = turnStartTime {
            let duration = Date().timeIntervalSince(startTime)
            print("Turn duration: \(duration) seconds")
        }
        
        currentTurnId = nil
        turnStartTime = nil
        
        state = .processing
    }
    
    /// Interrupt current response
    public func interrupt() async throws {
        try await session.cancelResponse()
        
        // Stop audio playback if active
        audioManager?.stopPlayback()
        
        isSpeaking = false
        state = .ready
    }
    
    /// Clear conversation history
    public func clearConversation() async throws {
        items.removeAll()
        transcript = ""
        
        // Clear audio buffer
        try await session.clearAudioBuffer()
        
        state = .ready
    }
    
    /// Truncate conversation at specific item
    public func truncateAt(itemId: String) async throws {
        try await session.truncateConversation(itemId: itemId)
        
        // Remove items after truncation point
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items = Array(items.prefix(through: index))
        }
    }
    
    // MARK: - Tool Management
    
    /// Register tools for function calling
    public func registerTools(_ tools: [AgentTool]) async {
        for tool in tools {
            let wrapper = AgentToolWrapper(tool: tool)
            await toolRegistry.register(wrapper)
        }
    }
    
    /// Register built-in tools
    public func registerBuiltInTools() async {
        await toolRegistry.registerBuiltInTools()
    }
    
    private func registerRealtimeTools(_ tools: [RealtimeTool]) async {
        // Tools are already registered with the session
        // This is for local tracking if needed
    }
    
    // MARK: - Private Methods
    
    private func setupAudioPipeline() {
        do {
            audioManager = RealtimeAudioManager()
            audioProcessor = try RealtimeAudioProcessor()
            
            pipeline = try AudioStreamPipeline()
            
            // Set pipeline delegate
            pipeline?.delegate = self
        } catch {
            print("Failed to setup audio pipeline: \(error)")
        }
    }
    
    private func setupEventHandlers() {
        Task {
            // TODO: Setup event handlers when methods are available
            // Connection state and error handlers need to be implemented
        }
    }
    
    private func startEventProcessing() {
        eventProcessingTask = Task {
            do {
                for try await event in await session.eventStream() {
                    await handleServerEvent(event)
                }
            } catch {
                print("Event stream error: \(error)")
                state = .error
            }
        }
    }
    
    private func handleServerEvent(_ event: RealtimeServerEvent) async {
        switch event {
        // Session events
        case .sessionCreated(let event):
            print("Session created: \(event.session.id)")
            
        case .sessionUpdated(let event):
            print("Session updated: \(event.session.id)")
            
        // Conversation events
        case .conversationItemCreated(let event):
            items.append(event.item)
            
        case .conversationItemDeleted(let event):
            items.removeAll { $0.id == event.itemId }
            
        case .conversationItemTruncated(let event):
            if let index = items.firstIndex(where: { $0.id == event.itemId }) {
                items = Array(items.prefix(through: index))
            }
            
        // Input audio events
        case .inputAudioBufferCommitted:
            print("Audio buffer committed")
            
        case .inputAudioBufferSpeechStarted:
            turnActive = true
            isListening = true
            state = .listening
            
        case .inputAudioBufferSpeechStopped:
            turnActive = false
            isListening = false
            state = .processing
            
        // Response events
        case .responseCreated(let event):
            state = .processing
            
        case .responseTextDelta(let event):
            transcript += event.delta
            
        case .responseTextDone(let event):
            transcript = event.text
            
        case .responseAudioDelta(let event):
            if !isSpeaking {
                isSpeaking = true
                state = .speaking
            }
            
            // Decode and play audio
            if let audioData = Data(base64Encoded: event.delta) {
                // TODO: Implement audio playback
                // audioManager?.playAudioData(audioData)
            }
            
        case .responseAudioDone(let event):
            isSpeaking = false
            state = .ready
            
        case .responseAudioTranscriptDelta(let event):
            // Handle audio transcript if transcription is enabled
            transcript += event.delta
            
        case .responseFunctionCallArgumentsDone(let event):
            // Execute function call
            await handleFunctionCall(event)
            
        // Rate limit events
        case .rateLimitsUpdated(let event):
            print("Rate limits updated")
            
        // Error events
        case .error(let event):
            print("API Error: \(event.error.message)")
            state = .error
            
        default:
            // Handle other events as needed
            break
        }
    }
    
    private func handleFunctionCall(_ event: ResponseFunctionCallArgumentsDoneEvent) async {
        let result = await toolRegistry.execute(
            toolName: event.name,
            arguments: event.arguments
        )
        
        // Create result item
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
        try? await session.createResponse(modalities: modalities)
    }
}

// MARK: - AudioStreamPipelineDelegate

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension AdvancedRealtimeConversation: AudioStreamPipelineDelegate {
    public func audioStreamPipeline(_ pipeline: AudioStreamPipeline, didCaptureAudio data: Data) {
        Task {
            try? await session.appendAudio(data)
        }
    }
    
    public func audioStreamPipeline(_ pipeline: AudioStreamPipeline, didUpdateAudioLevel level: Float) {
        audioLevel = level
    }
    
    public func audioStreamPipeline(_ pipeline: AudioStreamPipeline, didDetectSpeechStart: Bool) {
        if didDetectSpeechStart && configuration.turnDetection?.type == .serverVad {
            Task {
                try? await startListening()
            }
        }
    }
    
    public func audioStreamPipeline(_ pipeline: AudioStreamPipeline, didDetectSpeechEnd: Bool) {
        if didDetectSpeechEnd && configuration.turnDetection?.type == .serverVad {
            Task {
                try? await stopListening()
            }
        }
    }
    
    public func audioStreamPipeline(_ pipeline: AudioStreamPipeline, didEncounterError error: Error) {
        print("Audio pipeline error: \(error)")
    }
}

// MARK: - Conversation State Extension

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension ConversationState {
    static let connecting = ConversationState(rawValue: "connecting")!
    static let ready = ConversationState(rawValue: "ready")!
    static let reconnecting = ConversationState(rawValue: "reconnecting")!
    static let disconnecting = ConversationState(rawValue: "disconnecting")!
}

#endif // canImport(Combine)