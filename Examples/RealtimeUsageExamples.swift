import Foundation
import SwiftUI
import Tachikoma
import TachikomaAudio

// MARK: - Basic Voice Assistant

/// Simple voice assistant example
@available(macOS 14.0, iOS 17.0, *)
@MainActor
class BasicVoiceAssistant: ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var response = ""

    private var conversation: RealtimeConversation?

    func start() async throws {
        // Initialize with API key
        let config = TachikomaConfiguration()
            .withAPIKey("your-api-key", for: .openai)

        self.conversation = try RealtimeConversation(configuration: config)

        // Start conversation with voice
        try await self.conversation?.start(
            model: .gpt4oRealtime,
            voice: .nova,
            instructions: "You are a helpful voice assistant. Keep responses concise.",
        )

        // Listen for transcripts
        Task {
            guard let conversation else { return }
            for await update in conversation.transcriptUpdates {
                await MainActor.run {
                    self.transcript = update
                }
            }
        }

        // Listen for state changes
        Task {
            guard let conversation else { return }
            for await state in conversation.stateChanges {
                await MainActor.run {
                    self.isListening = (state == .listening)
                }
            }
        }
    }

    func startListening() async throws {
        try await self.conversation?.startListening()
    }

    func stopListening() async throws {
        try await self.conversation?.stopListening()
    }

    func stop() async {
        await self.conversation?.end()
    }
}

// MARK: - Advanced Conversation with Tools

/// Advanced conversation with function calling
@available(macOS 14.0, iOS 17.0, *)
@MainActor
class SmartAssistant: ObservableObject {
    @Published var messages: [String] = []
    @Published var isProcessing = false

    private var conversation: RealtimeConversation?

    func initialize(apiKey: String) async throws {
        // Configure with tools
        var config = SessionConfiguration.withTools(
            voice: .alloy,
            tools: self.createTools(),
        )

        // Enable server VAD for automatic turn detection
        config.turnDetection = .serverVAD
        config.modalities = .all

        // Production settings with auto-reconnect
        let settings = ConversationSettings.production

        self.conversation = try RealtimeConversation(
            apiKey: apiKey,
            configuration: config,
            settings: settings,
        )

        // Register built-in tools
        await self.conversation?.registerBuiltInTools()

        // Register custom tools
        await self.conversation?.registerTools(self.createCustomTools())

        // Start the conversation
        try await self.conversation?.start()

        // Monitor state
        self.setupStateMonitoring()
    }

    private func createTools() -> [RealtimeTool] {
        [
            RealtimeTool(
                name: "getCurrentTime",
                description: "Get the current time",
                parameters: AgentToolParameters(properties: [:], required: []),
            ),
            RealtimeTool(
                name: "setReminder",
                description: "Set a reminder",
                parameters: AgentToolParameters(
                    properties: [
                        "text": AgentToolParameterProperty(
                            name: "text",
                            type: .string,
                            description: "Reminder text",
                        ),
                        "time": AgentToolParameterProperty(
                            name: "time",
                            type: .string,
                            description: "Time for reminder",
                        ),
                    ],
                    required: ["text", "time"],
                ),
            ),
        ]
    }

    private func createCustomTools() -> [AgentTool] {
        [
            AgentTool(
                name: "getCurrentTime",
                description: "Get the current time",
                parameters: AgentToolParameters(properties: [:], required: []),
            ) { _ in
                let formatter = DateFormatter()
                formatter.timeStyle = .medium
                return .string(formatter.string(from: Date()))
            },
            AgentTool(
                name: "setReminder",
                description: "Set a reminder",
                parameters: AgentToolParameters(
                    properties: [
                        "text": AgentToolParameterProperty(
                            name: "text",
                            type: .string,
                            description: "Reminder text",
                        ),
                        "time": AgentToolParameterProperty(
                            name: "time",
                            type: .string,
                            description: "Time for reminder",
                        ),
                    ],
                    required: ["text", "time"],
                ),
            ) { args in
                let text = try args.stringValue("text")
                let time = try args.stringValue("time")
                // In real app, would schedule notification
                return .string("Reminder set: '\(text)' at \(time)")
            },
        ]
    }

    private func setupStateMonitoring() {
        // Monitor conversation items
        Task {
            guard let conversation else { return }
            await conversation.$items
                .sink { [weak self] items in
                    self?.messages = items.compactMap { item in
                        item.content?.first?.text
                    }
                }
                .store(in: &self.cancellables)
        }

        // Monitor processing state
        Task {
            guard let conversation else { return }
            await conversation.$state
                .map { $0 == .processing }
                .assign(to: &self.$isProcessing)
        }
    }

    private var cancellables = Set<AnyCancellable>()

    func sendMessage(_ text: String) async throws {
        try await self.conversation?.sendText(text)
    }

    func switchToTextOnly() async throws {
        try await self.conversation?.updateModalities(.text)
    }

    func switchToVoiceOnly() async throws {
        try await self.conversation?.updateModalities(.audio)
    }

    func cleanup() async {
        await self.conversation?.end()
    }
}

// MARK: - SwiftUI Integration Example

@available(macOS 14.0, iOS 17.0, *)
struct VoiceAssistantView: View {
    @StateObject private var viewModel = RealtimeConversationViewModel()
    @State private var apiKey = ""
    @State private var isConfigured = false

    var body: some View {
        VStack(spacing: 20) {
            if !self.isConfigured {
                // API Key Configuration
                VStack {
                    Text("OpenAI API Key")
                        .font(.headline)
                    SecureField("sk-...", text: self.$apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Start Assistant") {
                        Task {
                            await self.configureAssistant()
                        }
                    }
                    .disabled(self.apiKey.isEmpty)
                }
                .padding()
            } else {
                // Conversation Interface
                RealtimeConversationView(
                    apiKey: self.apiKey,
                    configuration: .voiceConversation(),
                ) { error in
                    print("Error: \(error)")
                }

                // Custom Controls
                HStack {
                    Button("Text Only") {
                        Task {
                            try await self.viewModel.updateModalities(.text)
                        }
                    }

                    Button("Voice Only") {
                        Task {
                            try await self.viewModel.updateModalities(.audio)
                        }
                    }

                    Button("Both") {
                        Task {
                            try await self.viewModel.updateModalities(.all)
                        }
                    }
                }

                // Transcript Display
                ScrollView {
                    Text(self.viewModel.transcript)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
    }

    private func configureAssistant() async {
        do {
            try await self.viewModel.initialize(
                apiKey: self.apiKey,
                configuration: .voiceConversation(),
            )
            self.isConfigured = true
        } catch {
            print("Configuration failed: \(error)")
        }
    }
}

// MARK: - Streaming Audio Example

@available(macOS 14.0, iOS 17.0, *)
class AudioStreamingExample {
    private var conversation: RealtimeConversation?
    private var audioManager: RealtimeAudioManager?
    private var audioProcessor: RealtimeAudioProcessor?

    func setupAudioStreaming(apiKey: String) async throws {
        // Configure for audio streaming
        var config = EnhancedSessionConfiguration(
            model: "gpt-4o-realtime-preview",
            voice: .echo,
            inputAudioFormat: .pcm16,
            outputAudioFormat: .pcm16,
            turnDetection: .serverVAD,
            modalities: .audio, // Audio only for streaming
        )

        // Audio-optimized settings
        let settings = ConversationSettings(
            autoReconnect: true,
            bufferWhileDisconnected: true,
            maxAudioBufferSize: 1024 * 1024 * 5, // 5MB buffer
            enableEchoCancellation: true,
            enableNoiseSuppression: true,
            localVADThreshold: 0.3,
        )

        self.conversation = try RealtimeConversation(
            apiKey: apiKey,
            configuration: config,
            settings: settings,
        )

        // Setup audio pipeline
        self.audioManager = try RealtimeAudioManager()
        self.audioProcessor = try RealtimeAudioProcessor()

        // Start conversation
        try await self.conversation?.start()

        // Start audio capture
        await self.audioManager?.startCapture()

        // Process audio stream
        Task {
            await self.processAudioStream()
        }
    }

    private func processAudioStream() async {
        // In real implementation, this would:
        // 1. Capture audio from microphone
        // 2. Process through VAD
        // 3. Convert format if needed
        // 4. Send to API
        // 5. Receive and play response audio
    }

    func stopStreaming() async {
        await self.audioManager?.stopCapture()
        await self.conversation?.end()
    }
}

// MARK: - Multi-turn Conversation Example

@available(macOS 14.0, iOS 17.0, *)
class MultiTurnConversation {
    private var conversation: RealtimeConversation?

    func runConversation(apiKey: String) async throws {
        // Configure for multi-turn dialogue
        let config = EnhancedSessionConfiguration(
            model: "gpt-4o-realtime-preview",
            voice: .fable,
            instructions: """
            You are a knowledgeable assistant engaged in a multi-turn conversation.
            Remember context from previous messages.
            Ask clarifying questions when needed.
            """,
            turnDetection: .serverVAD,
            temperature: 0.7,
            maxResponseOutputTokens: 500,
        )

        self.conversation = try RealtimeConversation(
            apiKey: apiKey,
            configuration: config,
        )

        try await self.conversation?.start()

        // First turn
        try await self.conversation?.sendText("I want to learn about quantum computing")
        await self.waitForResponse()

        // Second turn - follows up on previous
        try await self.conversation?.sendText("What are qubits exactly?")
        await self.waitForResponse()

        // Third turn - asks for clarification
        try await self.conversation?.sendText("Can you give me a simple analogy?")
        await self.waitForResponse()

        // Truncate conversation at a specific point if needed
        if let items = conversation?.items, items.count > 10 {
            try await self.conversation?.truncateAt(itemId: items[5].id)
        }

        await self.conversation?.end()
    }

    private func waitForResponse() async {
        // Wait for processing to complete
        while self.conversation?.state == .processing {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
}

// MARK: - Error Recovery Example

@available(macOS 14.0, iOS 17.0, *)
class RobustConversation {
    private var conversation: RealtimeConversation?
    private var retryCount = 0
    private let maxRetries = 3

    func startWithErrorHandling(apiKey: String) async throws {
        let config = EnhancedSessionConfiguration.voiceConversation()
        let settings = ConversationSettings(
            autoReconnect: true,
            maxReconnectAttempts: 5,
            reconnectDelay: 2.0,
            bufferWhileDisconnected: true,
        )

        do {
            self.conversation = try RealtimeConversation(
                apiKey: apiKey,
                configuration: config,
                settings: settings,
            )

            try await self.conversation?.start()

            // Monitor connection state
            Task {
                await self.monitorConnectionState()
            }
        } catch TachikomaError.authenticationFailed {
            print("Invalid API key")
            throw TachikomaError.authenticationFailed("Please check your API key")
        } catch let TachikomaError.networkError(error) {
            print("Network error: \(error)")
            if retryCount < maxRetries {
                retryCount += 1
                try await Task.sleep(nanoseconds: 2_000_000_000)
                try await startWithErrorHandling(apiKey: apiKey)
            }
        } catch {
            print("Unexpected error: \(error)")
            throw error
        }
    }

    private func monitorConnectionState() async {
        guard let conversation else { return }

        for await isConnected in conversation.$isConnected.values {
            if !isConnected {
                print("Connection lost - auto-reconnect enabled")
                // Could trigger UI updates, notifications, etc.
            } else {
                print("Connected successfully")
                self.retryCount = 0 // Reset retry count on successful connection
            }
        }
    }

    func sendWithRetry(_ message: String) async throws {
        do {
            try await self.conversation?.sendText(message)
        } catch {
            print("Send failed, retrying...")
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try await self.conversation?.sendText(message)
        }
    }
}

// MARK: - Usage in UIKit

#if os(iOS)
import UIKit

@available(iOS 17.0, *)
class VoiceAssistantViewController: UIViewController {
    private var conversation: RealtimeConversation?
    private var transcriptLabel: UILabel!
    private var recordButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        self.setupConversation()
    }

    private func setupUI() {
        // Transcript label
        self.transcriptLabel = UILabel()
        self.transcriptLabel.numberOfLines = 0
        self.transcriptLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self.transcriptLabel)

        // Record button
        self.recordButton = UIButton(type: .system)
        self.recordButton.setTitle("Hold to Talk", for: .normal)
        self.recordButton.translatesAutoresizingMaskIntoConstraints = false
        self.recordButton.addTarget(self, action: #selector(self.recordButtonPressed), for: .touchDown)
        self.recordButton.addTarget(
            self,
            action: #selector(self.recordButtonReleased),
            for: [.touchUpInside, .touchUpOutside],
        )
        view.addSubview(self.recordButton)

        // Layout
        NSLayoutConstraint.activate([
            self.transcriptLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            self.transcriptLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            self.transcriptLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            self.recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            self.recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            self.recordButton.widthAnchor.constraint(equalToConstant: 200),
            self.recordButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func setupConversation() {
        Task {
            do {
                let config = TachikomaConfiguration()
                    .withAPIKey("your-api-key", for: .openai)

                self.conversation = try RealtimeConversation(configuration: config)

                try await self.conversation?.start(
                    model: .gpt4oRealtime,
                    voice: .shimmer,
                )

                // Listen for updates
                Task {
                    guard let conversation else { return }
                    for await transcript in conversation.transcriptUpdates {
                        await MainActor.run {
                            self.transcriptLabel.text = transcript
                        }
                    }
                }
            } catch {
                print("Setup failed: \(error)")
            }
        }
    }

    @objc
    private func recordButtonPressed() {
        Task {
            try await self.conversation?.startListening()
        }
    }

    @objc
    private func recordButtonReleased() {
        Task {
            try await self.conversation?.stopListening()
        }
    }
}
#endif
