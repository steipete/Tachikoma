//
//  RealtimeConversationEnhanced.swift
//  Tachikoma
//

import Foundation
@preconcurrency import AVFoundation

// MARK: - Enhanced Realtime Conversation

/// Enhanced conversation API with integrated audio pipeline
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@MainActor
public final class EnhancedRealtimeConversation: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var state: ConversationState = .idle
    @Published public private(set) var isRecording = false
    @Published public private(set) var isPlaying = false
    @Published public private(set) var audioLevel: Float = 0
    @Published public private(set) var transcript = ""
    @Published public private(set) var messages: [ConversationMessage] = []
    @Published public private(set) var connectionStatus: ConnectionStatus = .disconnected
    
    // MARK: - Private Properties
    
    private let conversation: RealtimeConversation
    private var audioPipeline: AudioStreamPipeline?
    private let configuration: ConversationConfiguration
    private var toolExecutor: ToolExecutor?
    
    // Session persistence
    private var sessionData: SessionData?
    private let sessionStore: SessionStore
    
    // Background tasks
    private var monitoringTask: Task<Void, Never>?
    
    // MARK: - Types
    
    public struct ConversationConfiguration {
        public var enableAudioPipeline: Bool = true
        public var enableVAD: Bool = true
        public var enableEchoCancellation: Bool = true
        public var enableNoiseSupression: Bool = true
        public var autoReconnect: Bool = true
        public var sessionPersistence: Bool = true
        public var voiceActivityThreshold: Float = 0.01
        public var silenceDuration: TimeInterval = 0.5
        
        public init() {}
    }
    
    public enum ConnectionStatus: String {
        case disconnected
        case connecting
        case connected
        case reconnecting
        case error
    }
    
    public struct ConversationMessage: Identifiable, Sendable, Codable {
        public let id = UUID()
        public let role: MessageRole
        public let content: String
        public let timestamp: Date
        public let audioData: Data?
        
        public enum MessageRole: String, Sendable, Codable {
            case user
            case assistant
            case system
            case tool
        }
    }
    
    // MARK: - Initialization
    
    public init(
        apiKey: String? = nil,
        configuration: ConversationConfiguration = ConversationConfiguration()
    ) throws {
        self.configuration = configuration
        self.sessionStore = SessionStore()
        
        // Create Tachikoma configuration
        let tachikomaConfig = TachikomaConfiguration()
        if let apiKey = apiKey {
            tachikomaConfig.setAPIKey(apiKey, for: .openai)
        }
        
        // Create base conversation
        self.conversation = try RealtimeConversation(configuration: tachikomaConfig)
        
        // Setup audio pipeline if enabled
        if configuration.enableAudioPipeline {
            setupAudioPipeline()
        }
        
        // Setup monitoring
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start a conversation with the specified parameters
    public func start(
        model: LanguageModel.OpenAI = .gpt4oRealtime,
        voice: RealtimeVoice = .nova,
        instructions: String? = nil,
        tools: [AgentTool]? = nil
    ) async throws {
        connectionStatus = .connecting
        
        // Setup tool executor if tools provided
        if let tools = tools {
            toolExecutor = ToolExecutor(tools: tools)
        }
        
        // Convert tools to RealtimeTools
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
        
        // Start audio pipeline
        if let pipeline = audioPipeline {
            try await pipeline.start()
        }
        
        // Restore session if available
        if configuration.sessionPersistence {
            await restoreSession()
        }
        
        connectionStatus = .connected
        state = .idle
    }
    
    /// End the conversation
    public func end() async {
        // Save session if persistence enabled
        if configuration.sessionPersistence {
            await saveSession()
        }
        
        // Stop audio pipeline
        if let pipeline = audioPipeline {
            await pipeline.stop()
        }
        
        // End conversation
        await conversation.end()
        
        // Cancel monitoring
        monitoringTask?.cancel()
        
        connectionStatus = .disconnected
        state = .idle
    }
    
    /// Send a text message
    public func sendMessage(_ text: String) async throws {
        // Add to messages
        let message = ConversationMessage(
            role: .user,
            content: text,
            timestamp: Date(),
            audioData: nil
        )
        messages.append(message)
        
        // Send to API
        try await conversation.sendText(text)
    }
    
    /// Toggle recording
    public func toggleRecording() async throws {
        if isRecording {
            await stopRecording()
        } else {
            try await startRecording()
        }
    }
    
    /// Start recording audio
    public func startRecording() async throws {
        guard !isRecording else { return }
        
        try await conversation.startListening()
        isRecording = true
        state = .listening
    }
    
    /// Stop recording audio
    public func stopRecording() async {
        guard isRecording else { return }
        
        await conversation.stopListening()
        isRecording = false
        state = .idle
    }
    
    /// Interrupt the current response
    public func interrupt() async throws {
        try await conversation.interrupt()
    }
    
    /// Clear conversation history
    public func clearHistory() {
        messages.removeAll()
        transcript = ""
    }
    
    // MARK: - Audio Pipeline Setup
    
    private func setupAudioPipeline() {
        do {
            var pipelineConfig = AudioStreamPipeline.PipelineConfiguration()
            pipelineConfig.voiceThreshold = configuration.voiceActivityThreshold
            pipelineConfig.silenceDuration = configuration.silenceDuration
            pipelineConfig.enableVAD = configuration.enableVAD
            pipelineConfig.enableEchoCancellation = configuration.enableEchoCancellation
            pipelineConfig.enableNoiseSupression = configuration.enableNoiseSupression
            
            let pipeline = try AudioStreamPipeline(configuration: pipelineConfig)
            pipeline.delegate = self
            self.audioPipeline = pipeline
        } catch {
            print("Failed to setup audio pipeline: \(error)")
        }
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        monitoringTask = Task {
            // Monitor transcript updates
            Task {
                for await text in conversation.transcriptUpdates {
                    await MainActor.run {
                        self.transcript += text + " "
                    }
                }
            }
            
            // Monitor audio level
            Task {
                for await level in conversation.audioLevelUpdates {
                    await MainActor.run {
                        self.audioLevel = level
                    }
                }
            }
            
            // Monitor state changes
            Task {
                for await state in conversation.stateChanges {
                    await MainActor.run {
                        self.state = state
                        
                        // Update playing state
                        self.isPlaying = (state == .speaking)
                    }
                }
            }
        }
    }
    
    // MARK: - Session Persistence
    
    private func saveSession() async {
        let session = SessionData(
            messages: messages,
            transcript: transcript,
            timestamp: Date()
        )
        
        await sessionStore.save(session)
    }
    
    private func restoreSession() async {
        if let session = await sessionStore.load() {
            self.messages = session.messages
            self.transcript = session.transcript
        }
    }
}

// MARK: - Audio Pipeline Delegate

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension EnhancedRealtimeConversation: AudioStreamPipelineDelegate {
    public func audioStreamPipeline(didCaptureAudio data: Data) async {
        // Send audio to conversation
        try? await conversation.sendAudio(data)
    }
    
    public func audioStreamPipeline(didDetectVoice hasVoice: Bool) async {
        if hasVoice && !isRecording {
            // Auto-start recording on voice detection
            try? await startRecording()
        } else if !hasVoice && isRecording && configuration.enableVAD {
            // Auto-stop on silence
            await stopRecording()
        }
    }
    
    public func audioStreamPipeline(didUpdateInputLevel level: Float) {
        audioLevel = level
    }
    
    public func audioStreamPipeline(didEncounterError error: Error) async {
        print("Audio pipeline error: \(error)")
        connectionStatus = .error
    }
}

// MARK: - Tool Executor

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
private final class ToolExecutor {
    private let tools: [AgentTool]
    
    init(tools: [AgentTool]) {
        self.tools = tools
    }
    
    func execute(name: String, arguments: String) async -> String {
        guard let tool = tools.first(where: { $0.name == name }) else {
            return "Tool '\(name)' not found"
        }
        
        // Parse arguments JSON and execute
        // For now, return a placeholder
        // In a real implementation, you'd parse the JSON and call tool.execute
        return "Tool executed successfully"
    }
}

// MARK: - Session Store

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
private actor SessionStore {
    private let fileURL: URL
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = documentsPath.appendingPathComponent("realtime_session.json")
    }
    
    func save(_ session: SessionData) async {
        do {
            let data = try JSONEncoder().encode(session)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save session: \(error)")
        }
    }
    
    func load() async -> SessionData? {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(SessionData.self, from: data)
        } catch {
            return nil
        }
    }
}

// MARK: - Session Data

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
private struct SessionData: Codable {
    let messages: [EnhancedRealtimeConversation.ConversationMessage]
    let transcript: String
    let timestamp: Date
}

// MARK: - Convenience Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension EnhancedRealtimeConversation {
    /// Quick start with default settings
    func quickStart() async throws {
        try await start(
            model: .gpt4oRealtime,
            voice: .nova,
            instructions: "You are a helpful assistant. Keep responses concise and natural."
        )
    }
    
    /// Start with custom voice
    func startWithVoice(_ voice: RealtimeVoice) async throws {
        try await start(voice: voice)
    }
    
    /// Check if ready for interaction
    var isReady: Bool {
        connectionStatus == .connected && state != .error
    }
    
    /// Get conversation duration
    var duration: TimeInterval? {
        guard let firstMessage = messages.first else { return nil }
        return Date().timeIntervalSince(firstMessage.timestamp)
    }
    
    /// Export conversation as text
    func exportAsText() -> String {
        messages.map { message in
            "[\(message.role.rawValue.uppercased())] \(message.content)"
        }.joined(separator: "\n\n")
    }
}
