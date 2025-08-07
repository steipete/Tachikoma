//
//  RealtimeUsageExamples.swift
//  Tachikoma
//

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
        
        conversation = try RealtimeConversation(configuration: config)
        
        // Start conversation with voice
        try await conversation?.start(
            model: .gpt4oRealtime,
            voice: .nova,
            instructions: "You are a helpful voice assistant. Keep responses concise."
        )
        
        // Listen for transcripts
        Task {
            guard let conversation = conversation else { return }
            for await update in conversation.transcriptUpdates {
                await MainActor.run {
                    self.transcript = update
                }
            }
        }
        
        // Listen for state changes
        Task {
            guard let conversation = conversation else { return }
            for await state in conversation.stateChanges {
                await MainActor.run {
                    self.isListening = (state == .listening)
                }
            }
        }
    }
    
    func startListening() async throws {
        try await conversation?.startListening()
    }
    
    func stopListening() async throws {
        try await conversation?.stopListening()
    }
    
    func stop() async {
        await conversation?.end()
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
            tools: createTools()
        )
        
        // Enable server VAD for automatic turn detection
        config.turnDetection = .serverVAD
        config.modalities = .all
        
        // Production settings with auto-reconnect
        let settings = ConversationSettings.production
        
        conversation = try RealtimeConversation(
            apiKey: apiKey,
            configuration: config,
            settings: settings
        )
        
        // Register built-in tools
        await conversation?.registerBuiltInTools()
        
        // Register custom tools
        await conversation?.registerTools(createCustomTools())
        
        // Start the conversation
        try await conversation?.start()
        
        // Monitor state
        setupStateMonitoring()
    }
    
    private func createTools() -> [RealtimeTool] {
        [
            RealtimeTool(
                name: "getCurrentTime",
                description: "Get the current time",
                parameters: AgentToolParameters(properties: [:], required: [])
            ),
            RealtimeTool(
                name: "setReminder",
                description: "Set a reminder",
                parameters: AgentToolParameters(
                    properties: [
                        "text": AgentToolParameterProperty(
                            name: "text",
                            type: .string,
                            description: "Reminder text"
                        ),
                        "time": AgentToolParameterProperty(
                            name: "time",
                            type: .string,
                            description: "Time for reminder"
                        )
                    ],
                    required: ["text", "time"]
                )
            )
        ]
    }
    
    private func createCustomTools() -> [AgentTool] {
        [
            AgentTool(
                name: "getCurrentTime",
                description: "Get the current time",
                parameters: AgentToolParameters(properties: [:], required: []),
                execute: { _ in
                    let formatter = DateFormatter()
                    formatter.timeStyle = .medium
                    return .string(formatter.string(from: Date()))
                }
            ),
            AgentTool(
                name: "setReminder",
                description: "Set a reminder",
                parameters: AgentToolParameters(
                    properties: [
                        "text": AgentToolParameterProperty(
                            name: "text",
                            type: .string,
                            description: "Reminder text"
                        ),
                        "time": AgentToolParameterProperty(
                            name: "time",
                            type: .string,
                            description: "Time for reminder"
                        )
                    ],
                    required: ["text", "time"]
                ),
                execute: { args in
                    let text = try args.stringValue("text")
                    let time = try args.stringValue("time")
                    // In real app, would schedule notification
                    return .string("Reminder set: '\(text)' at \(time)")
                }
            )
        ]
    }
    
    private func setupStateMonitoring() {
        // Monitor conversation items
        Task {
            guard let conversation = conversation else { return }
            await conversation.$items
                .sink { [weak self] items in
                    self?.messages = items.compactMap { item in
                        item.content?.first?.text
                    }
                }
                .store(in: &cancellables)
        }
        
        // Monitor processing state
        Task {
            guard let conversation = conversation else { return }
            await conversation.$state
                .map { $0 == .processing }
                .assign(to: &$isProcessing)
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func sendMessage(_ text: String) async throws {
        try await conversation?.sendText(text)
    }
    
    func switchToTextOnly() async throws {
        try await conversation?.updateModalities(.text)
    }
    
    func switchToVoiceOnly() async throws {
        try await conversation?.updateModalities(.audio)
    }
    
    func cleanup() async {
        await conversation?.end()
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
            if !isConfigured {
                // API Key Configuration
                VStack {
                    Text("OpenAI API Key")
                        .font(.headline)
                    SecureField("sk-...", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Start Assistant") {
                        Task {
                            await configureAssistant()
                        }
                    }
                    .disabled(apiKey.isEmpty)
                }
                .padding()
            } else {
                // Conversation Interface
                RealtimeConversationView(
                    apiKey: apiKey,
                    configuration: .voiceConversation(),
                    onError: { error in
                        print("Error: \(error)")
                    }
                )
                
                // Custom Controls
                HStack {
                    Button("Text Only") {
                        Task {
                            try await viewModel.updateModalities(.text)
                        }
                    }
                    
                    Button("Voice Only") {
                        Task {
                            try await viewModel.updateModalities(.audio)
                        }
                    }
                    
                    Button("Both") {
                        Task {
                            try await viewModel.updateModalities(.all)
                        }
                    }
                }
                
                // Transcript Display
                ScrollView {
                    Text(viewModel.transcript)
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
            try await viewModel.initialize(
                apiKey: apiKey,
                configuration: .voiceConversation()
            )
            isConfigured = true
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
            modalities: .audio // Audio only for streaming
        )
        
        // Audio-optimized settings
        let settings = ConversationSettings(
            autoReconnect: true,
            bufferWhileDisconnected: true,
            maxAudioBufferSize: 1024 * 1024 * 5, // 5MB buffer
            enableEchoCancellation: true,
            enableNoiseSuppression: true,
            localVADThreshold: 0.3
        )
        
        conversation = try RealtimeConversation(
            apiKey: apiKey,
            configuration: config,
            settings: settings
        )
        
        // Setup audio pipeline
        audioManager = try RealtimeAudioManager()
        audioProcessor = try RealtimeAudioProcessor()
        
        // Start conversation
        try await conversation?.start()
        
        // Start audio capture
        await audioManager?.startCapture()
        
        // Process audio stream
        Task {
            await processAudioStream()
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
        await audioManager?.stopCapture()
        await conversation?.end()
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
            maxResponseOutputTokens: 500
        )
        
        conversation = try RealtimeConversation(
            apiKey: apiKey,
            configuration: config
        )
        
        try await conversation?.start()
        
        // First turn
        try await conversation?.sendText("I want to learn about quantum computing")
        await waitForResponse()
        
        // Second turn - follows up on previous
        try await conversation?.sendText("What are qubits exactly?")
        await waitForResponse()
        
        // Third turn - asks for clarification
        try await conversation?.sendText("Can you give me a simple analogy?")
        await waitForResponse()
        
        // Truncate conversation at a specific point if needed
        if let items = conversation?.items, items.count > 10 {
            try await conversation?.truncateAt(itemId: items[5].id)
        }
        
        await conversation?.end()
    }
    
    private func waitForResponse() async {
        // Wait for processing to complete
        while conversation?.state == .processing {
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
            bufferWhileDisconnected: true
        )
        
        do {
            conversation = try RealtimeConversation(
                apiKey: apiKey,
                configuration: config,
                settings: settings
            )
            
            try await conversation?.start()
            
            // Monitor connection state
            Task {
                await monitorConnectionState()
            }
            
        } catch TachikomaError.authenticationFailed {
            print("Invalid API key")
            throw TachikomaError.authenticationFailed("Please check your API key")
        } catch TachikomaError.networkError(let error) {
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
        guard let conversation = conversation else { return }
        
        for await isConnected in conversation.$isConnected.values {
            if !isConnected {
                print("Connection lost - auto-reconnect enabled")
                // Could trigger UI updates, notifications, etc.
            } else {
                print("Connected successfully")
                retryCount = 0 // Reset retry count on successful connection
            }
        }
    }
    
    func sendWithRetry(_ message: String) async throws {
        do {
            try await conversation?.sendText(message)
        } catch {
            print("Send failed, retrying...")
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try await conversation?.sendText(message)
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
        setupUI()
        setupConversation()
    }
    
    private func setupUI() {
        // Transcript label
        transcriptLabel = UILabel()
        transcriptLabel.numberOfLines = 0
        transcriptLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(transcriptLabel)
        
        // Record button
        recordButton = UIButton(type: .system)
        recordButton.setTitle("Hold to Talk", for: .normal)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(recordButtonPressed), for: .touchDown)
        recordButton.addTarget(self, action: #selector(recordButtonReleased), for: [.touchUpInside, .touchUpOutside])
        view.addSubview(recordButton)
        
        // Layout
        NSLayoutConstraint.activate([
            transcriptLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            transcriptLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            transcriptLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.widthAnchor.constraint(equalToConstant: 200),
            recordButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupConversation() {
        Task {
            do {
                let config = TachikomaConfiguration()
                    .withAPIKey("your-api-key", for: .openai)
                
                conversation = try RealtimeConversation(configuration: config)
                
                try await conversation?.start(
                    model: .gpt4oRealtime,
                    voice: .shimmer
                )
                
                // Listen for updates
                Task {
                    guard let conversation = conversation else { return }
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
    
    @objc private func recordButtonPressed() {
        Task {
            try await conversation?.startListening()
        }
    }
    
    @objc private func recordButtonReleased() {
        Task {
            try await conversation?.stopListening()
        }
    }
}
#endif