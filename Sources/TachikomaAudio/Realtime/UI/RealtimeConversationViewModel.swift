#if canImport(SwiftUI) && canImport(Combine)
import Combine
import SwiftUI
import Tachikoma

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
    @Published public var messages: [RealtimeConversation.ConversationMessage] = []
    @Published public var connectionStatus: ConnectionStatus = .disconnected

    // Settings
    @Published public var selectedVoice: RealtimeVoice = .nova
    @Published public var enableVAD = true
    @Published public var enableEchoCancellation = true
    @Published public var enableNoiseSupression = true
    @Published public var autoReconnect = true
    @Published public var sessionPersistence = true

    // MARK: - Private Properties

    private var conversation: RealtimeConversation?
    private let apiKey: String?
    private let configuration: RealtimeConversation.ConversationConfiguration
    private var cancellables = Set<AnyCancellable>()
    private var initializationTask: Task<Void, Never>?

    // MARK: - Computed Properties

    public var isReady: Bool {
        self.conversation?.isReady ?? false
    }

    public var sessionDuration: TimeInterval? {
        self.conversation?.duration
    }

    // MARK: - Initialization

    public init(
        apiKey: String? = nil,
        configuration: RealtimeConversation.ConversationConfiguration = .init(),
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
        // Initialize the conversation
        do {
            // Create TachikomaConfiguration
            let tachikomaConfig = TachikomaConfiguration()
            if let apiKey {
                tachikomaConfig.setAPIKey(apiKey, for: .openai)
            }

            let conversation = try RealtimeConversation(
                configuration: tachikomaConfig,
            )

            self.conversation = conversation

            // Observe conversation state
            self.setupObservers()

            // Start conversation
            try await conversation.start(
                voice: self.selectedVoice,
                instructions: "You are a helpful voice assistant. Keep responses concise and natural.",
            )
        } catch {
            print("Failed to initialize conversation: \(error)")
            self.connectionStatus = ConnectionStatus.error
        }
    }

    /// Send a text message
    public func sendMessage(_ text: String) async {
        // Send a text message
        guard let conversation else { return }

        do {
            try await conversation.sendMessage(text)
        } catch {
            print("Failed to send message: \(error)")
        }
    }

    /// Toggle recording
    public func toggleRecording() async {
        // Toggle recording
        guard let conversation else { return }

        do {
            try await conversation.toggleRecording()
        } catch {
            print("Failed to toggle recording: \(error)")
        }
    }

    /// Interrupt the current response
    public func interrupt() async {
        // Interrupt the current response
        guard let conversation else { return }

        do {
            try await conversation.interrupt()
        } catch {
            print("Failed to interrupt: \(error)")
        }
    }

    /// Clear conversation history
    public func clearHistory() {
        // Clear conversation history
        self.conversation?.clearHistory()
        self.messages.removeAll()
    }

    /// Reconnect to the service
    public func reconnect() async {
        // Reconnect to the service
        guard let conversation else { return }

        self.connectionStatus = ConnectionStatus.reconnecting

        do {
            // End current session
            await conversation.end()

            // Start new session
            try await conversation.start(
                voice: self.selectedVoice,
                instructions: "You are a helpful voice assistant. Keep responses concise and natural.",
            )
        } catch {
            print("Failed to reconnect: \(error)")
            self.connectionStatus = ConnectionStatus.error
        }
    }

    /// Export conversation
    public func exportConversation() -> String {
        // Export conversation
        self.conversation?.exportAsText() ?? ""
    }

    // MARK: - Private Methods

    private func setupObservers() {
        guard let conversation else { return }

        // Observe state changes
        conversation.$state
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$state)

        // Observe recording state
        conversation.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$isRecording)

        // Observe playing state
        conversation.$isPlaying
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$isPlaying)

        // Observe audio level
        conversation.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$audioLevel)

        // Observe messages
        conversation.$messages
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$messages)

        // Observe connection status
        conversation.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$connectionStatus)

        // Handle settings changes
        self.$selectedVoice
            .dropFirst()
            .sink { [weak self] voice in
                Task {
                    await self?.updateVoice(voice)
                }
            }
            .store(in: &self.cancellables)

        Publishers.CombineLatest4(
            self.$enableVAD,
            self.$enableEchoCancellation,
            self.$enableNoiseSupression,
            self.$autoReconnect,
        )
        .dropFirst()
        .sink { [weak self] _ in
            Task {
                await self?.updateConfiguration()
            }
        }
        .store(in: &self.cancellables)
    }

    private func updateVoice(_: RealtimeVoice) async {
        // Reconnect with new voice
        await self.reconnect()
    }

    private func updateConfiguration() async {
        // Would need to recreate conversation with new configuration
        // For now, these will take effect on next reconnect
    }
}

// MARK: - Preview Support

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension RealtimeConversationViewModel {
    /// Create a mock view model for previews
    public static func mock() -> RealtimeConversationViewModel {
        // Create a mock view model for previews
        let viewModel = RealtimeConversationViewModel()

        // Add mock messages
        viewModel.messages = [
            RealtimeConversation.ConversationMessage(
                role: Tachikoma.ModelMessage.Role.user,
                content: "Hello, how are you?",
                timestamp: Date().addingTimeInterval(-60),
                audioData: nil as Data?,
            ),
            RealtimeConversation.ConversationMessage(
                role: Tachikoma.ModelMessage.Role.assistant,
                content: "I'm doing well, thank you! How can I help you today?",
                timestamp: Date().addingTimeInterval(-30),
                audioData: nil as Data?,
            ),
            RealtimeConversation.ConversationMessage(
                role: Tachikoma.ModelMessage.Role.user,
                content: "What's the weather like?",
                timestamp: Date().addingTimeInterval(-15),
                audioData: nil as Data?,
            ),
            RealtimeConversation.ConversationMessage(
                role: Tachikoma.ModelMessage.Role.assistant,
                content: "I'd be happy to help with weather information, but I'd need to know your location first. Where are you located?",
                timestamp: Date(),
                audioData: nil as Data?,
            ),
        ]

        viewModel.connectionStatus = ConnectionStatus.connected
        viewModel.state = .idle

        return viewModel
    }
}

#endif
