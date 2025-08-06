//
//  RealtimeConversationViewModel.swift
//  Tachikoma
//

#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI
import Combine

// MARK: - Realtime Conversation View Model

/// View model for realtime conversation UI
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@MainActor
public final class RealtimeConversationViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var state: ConversationState = .idle
    @Published public var isRecording = false
    @Published public var isPlaying = false
    @Published public var audioLevel: Float = 0
    @Published public var messages: [EnhancedRealtimeConversation.ConversationMessage] = []
    @Published public var connectionStatus: EnhancedRealtimeConversation.ConnectionStatus = .disconnected
    
    // Settings
    @Published public var selectedVoice: RealtimeVoice = .nova
    @Published public var enableVAD = true
    @Published public var enableEchoCancellation = true
    @Published public var enableNoiseSupression = true
    @Published public var autoReconnect = true
    @Published public var sessionPersistence = true
    
    // MARK: - Private Properties
    
    private var conversation: EnhancedRealtimeConversation?
    private let apiKey: String?
    private let configuration: EnhancedRealtimeConversation.ConversationConfiguration
    private var cancellables = Set<AnyCancellable>()
    private var initializationTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    public var isReady: Bool {
        conversation?.isReady ?? false
    }
    
    public var sessionDuration: TimeInterval? {
        conversation?.duration
    }
    
    // MARK: - Initialization
    
    public init(
        apiKey: String? = nil,
        configuration: EnhancedRealtimeConversation.ConversationConfiguration = .init()
    ) {
        self.apiKey = apiKey
        self.configuration = configuration
        
        // Load settings from configuration
        self.enableVAD = configuration.enableVAD
        self.enableEchoCancellation = configuration.enableEchoCancellation
        self.enableNoiseSupression = configuration.enableNoiseSupression
        self.autoReconnect = configuration.autoReconnect
        self.sessionPersistence = configuration.sessionPersistence
    }
    
    deinit {
        initializationTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Initialize the conversation
    public func initialize() async {
        do {
            // Create conversation with current settings
            var config = configuration
            config.enableVAD = enableVAD
            config.enableEchoCancellation = enableEchoCancellation
            config.enableNoiseSupression = enableNoiseSupression
            config.autoReconnect = autoReconnect
            config.sessionPersistence = sessionPersistence
            
            let conversation = try EnhancedRealtimeConversation(
                apiKey: apiKey,
                configuration: config
            )
            
            self.conversation = conversation
            
            // Observe conversation state
            setupObservers()
            
            // Start conversation
            try await conversation.start(
                voice: selectedVoice,
                instructions: "You are a helpful voice assistant. Keep responses concise and natural."
            )
        } catch {
            print("Failed to initialize conversation: \(error)")
            connectionStatus = .error
        }
    }
    
    /// Send a text message
    public func sendMessage(_ text: String) async {
        guard let conversation = conversation else { return }
        
        do {
            try await conversation.sendMessage(text)
        } catch {
            print("Failed to send message: \(error)")
        }
    }
    
    /// Toggle recording
    public func toggleRecording() async {
        guard let conversation = conversation else { return }
        
        do {
            try await conversation.toggleRecording()
        } catch {
            print("Failed to toggle recording: \(error)")
        }
    }
    
    /// Interrupt the current response
    public func interrupt() async {
        guard let conversation = conversation else { return }
        
        do {
            try await conversation.interrupt()
        } catch {
            print("Failed to interrupt: \(error)")
        }
    }
    
    /// Clear conversation history
    public func clearHistory() {
        conversation?.clearHistory()
        messages.removeAll()
    }
    
    /// Reconnect to the service
    public func reconnect() async {
        guard let conversation = conversation else { return }
        
        connectionStatus = .reconnecting
        
        do {
            // End current session
            await conversation.end()
            
            // Start new session
            try await conversation.start(
                voice: selectedVoice,
                instructions: "You are a helpful voice assistant. Keep responses concise and natural."
            )
        } catch {
            print("Failed to reconnect: \(error)")
            connectionStatus = .error
        }
    }
    
    /// Export conversation
    public func exportConversation() -> String {
        conversation?.exportAsText() ?? ""
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        guard let conversation = conversation else { return }
        
        // Observe state changes
        conversation.$state
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)
        
        // Observe recording state
        conversation.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
        
        // Observe playing state
        conversation.$isPlaying
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPlaying)
        
        // Observe audio level
        conversation.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
        
        // Observe messages
        conversation.$messages
            .receive(on: DispatchQueue.main)
            .assign(to: &$messages)
        
        // Observe connection status
        conversation.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionStatus)
        
        // Handle settings changes
        $selectedVoice
            .dropFirst()
            .sink { [weak self] voice in
                Task {
                    await self?.updateVoice(voice)
                }
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest4(
            $enableVAD,
            $enableEchoCancellation,
            $enableNoiseSupression,
            $autoReconnect
        )
        .dropFirst()
        .sink { [weak self] _ in
            Task {
                await self?.updateConfiguration()
            }
        }
        .store(in: &cancellables)
    }
    
    private func updateVoice(_ voice: RealtimeVoice) async {
        // Reconnect with new voice
        await reconnect()
    }
    
    private func updateConfiguration() async {
        // Would need to recreate conversation with new configuration
        // For now, these will take effect on next reconnect
    }
}

// MARK: - Preview Support

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public extension RealtimeConversationViewModel {
    /// Create a mock view model for previews
    static func mock() -> RealtimeConversationViewModel {
        let viewModel = RealtimeConversationViewModel()
        
        // Add mock messages
        viewModel.messages = [
            .init(
                role: .user,
                content: "Hello, how are you?",
                timestamp: Date().addingTimeInterval(-60),
                audioData: nil
            ),
            .init(
                role: .assistant,
                content: "I'm doing well, thank you! How can I help you today?",
                timestamp: Date().addingTimeInterval(-30),
                audioData: nil
            ),
            .init(
                role: .user,
                content: "What's the weather like?",
                timestamp: Date().addingTimeInterval(-15),
                audioData: nil
            ),
            .init(
                role: .assistant,
                content: "I'd be happy to help with weather information, but I'd need to know your location first. Where are you located?",
                timestamp: Date(),
                audioData: nil
            )
        ]
        
        viewModel.connectionStatus = .connected
        viewModel.state = .idle
        
        return viewModel
    }
}

#endif
