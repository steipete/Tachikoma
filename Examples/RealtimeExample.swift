import Foundation
import Tachikoma
import TachikomaAudio

/// Example demonstrating the OpenAI Realtime API integration
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@MainActor
class RealtimeVoiceAssistant {
    private var conversation: RealtimeConversation?

    func start() async throws {
        print("🎙️ Starting Realtime Voice Assistant...")

        // Define tools the assistant can use
        let weatherTool = AgentTool(
            name: "getWeather",
            description: "Get the current weather for a location",
            parameters: AgentToolParameters(
                properties: [
                    "location": AgentToolParameterProperty(
                        type: .string,
                        description: "The city and state, e.g. San Francisco, CA",
                    ),
                ],
                required: ["location"],
            ),
        ) { args in
            let location = args["location"]?.stringValue ?? "Unknown"
            return .string("The weather in \(location) is sunny and 72°F")
        }

        let calculatorTool = AgentTool(
            name: "calculate",
            description: "Perform mathematical calculations",
            parameters: AgentToolParameters(
                properties: [
                    "expression": AgentToolParameterProperty(
                        type: .string,
                        description: "Mathematical expression to evaluate",
                    ),
                ],
                required: ["expression"],
            ),
        ) { args in
            let expression = args["expression"]?.stringValue ?? "0"
            // In a real implementation, you'd evaluate the expression
            return .double(42.0)
        }

        // Start the conversation
        self.conversation = try await startRealtimeConversation(
            model: .gpt4oRealtime,
            voice: .nova,
            instructions: """
            You are a helpful voice assistant. Keep responses concise and natural.
            Use the available tools when needed to help answer questions.
            """,
            tools: [weatherTool, calculatorTool],
        )

        print("✅ Voice assistant ready!")
        print("🎤 You can now start speaking...")

        // Set up event handlers
        await self.setupEventHandlers()

        // Simulate some interactions (in a real app, this would come from audio input)
        try await self.simulateConversation()
    }

    private func setupEventHandlers() async {
        guard let conversation else { return }

        // Listen for transcript updates
        Task {
            for await transcript in conversation.transcriptUpdates {
                print("📝 Transcript: \(transcript)")
            }
        }

        // Listen for audio level updates (for UI visualization)
        Task {
            for await level in conversation.audioLevelUpdates {
                // Update UI with audio level
                if level > 0.5 {
                    print("🔊 Speaking (level: \(level))")
                }
            }
        }

        // Listen for state changes
        Task {
            for await state in conversation.stateChanges {
                print("🔄 State: \(state)")
            }
        }
    }

    private func simulateConversation() async throws {
        guard let conversation else { return }

        // Example 1: Simple text interaction
        print("\n👤 User: What's the weather in San Francisco?")
        try await conversation.sendText("What's the weather in San Francisco?")

        // Wait for response
        try await Task.sleep(nanoseconds: 3_000_000_000)

        // Example 2: Another question
        print("\n👤 User: Calculate 15 times 28")
        try await conversation.sendText("Calculate 15 times 28")

        // Wait for response
        try await Task.sleep(nanoseconds: 3_000_000_000)

        // Example 3: Interrupt demonstration
        print("\n👤 User: Tell me a long story about...")
        try await conversation.sendText("Tell me a long story about the history of computers")

        // Interrupt after 1 second
        try await Task.sleep(nanoseconds: 1_000_000_000)
        print("🛑 Interrupting...")
        try await conversation.interrupt()

        // End the conversation
        print("\n👋 Ending conversation...")
        await conversation.end()
    }
}

// MARK: - Usage Example

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
func runRealtimeExample() async throws {
    // Set up configuration with API key
    var config = TachikomaConfiguration()

    // Note: In production, use environment variables or secure storage
    // config.setAPIKey("your-openai-api-key", for: .openai)

    let assistant = RealtimeVoiceAssistant()
    try await assistant.start()
}

// MARK: - Features Demo

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
class RealtimeDemo {
    func demonstrateServerVAD() async throws {
        print("🎯 Demonstrating Server Voice Activity Detection...")

        // Server VAD automatically detects when user starts/stops speaking
        let conversation = try await startRealtimeConversation(
            model: .gpt4oRealtime,
            voice: .alloy,
            instructions: "You are a voice assistant with server-side voice activity detection",
        )

        // The server will automatically:
        // 1. Detect when user starts speaking
        // 2. Buffer the audio
        // 3. Detect when user stops speaking
        // 4. Process the complete utterance
        // 5. Generate and stream response

        await conversation.end()
    }

    func demonstrateMultiModalResponse() async throws {
        print("🎨 Demonstrating Multi-Modal Responses...")

        // Configure for both text and audio responses
        let conversation = try await startRealtimeConversation(
            model: .gpt4oRealtime,
            voice: .shimmer,
        )

        // Responses will include both:
        // - Text transcription (for display)
        // - Audio output (for playback)

        try await conversation.sendText("Explain quantum computing in simple terms")

        // Both text and audio will be streamed back
        Task {
            for await transcript in conversation.transcriptUpdates {
                print("Text: \(transcript)")
            }
        }

        await conversation.end()
    }

    func demonstrateFunctionCalling() async throws {
        print("🔧 Demonstrating Voice-Triggered Function Calling...")

        let smartHomeTool = AgentTool(
            name: "controlDevice",
            description: "Control smart home devices",
            parameters: AgentToolParameters(
                properties: [
                    "device": AgentToolParameterProperty(
                        type: .string,
                        description: "Device name (lights, thermostat, door)",
                    ),
                    "action": AgentToolParameterProperty(
                        type: .string,
                        description: "Action to perform (on, off, set)",
                    ),
                    "value": AgentToolParameterProperty(
                        type: .number,
                        description: "Optional value for the action",
                    ),
                ],
                required: ["device", "action"],
            ),
        ) { args in
            let device = args["device"]?.stringValue ?? ""
            let action = args["action"]?.stringValue ?? ""
            print("🏠 Executing: \(action) on \(device)")
            return .string("Done! \(device) is now \(action)")
        }

        let conversation = try await startRealtimeConversation(
            model: .gpt4oRealtime,
            voice: .echo,
            instructions: "You are a smart home assistant. Use the available tools to control devices.",
            tools: [smartHomeTool],
        )

        // Voice commands will trigger function calls
        try await conversation.sendText("Turn on the living room lights")
        try await Task.sleep(nanoseconds: 2_000_000_000)

        try await conversation.sendText("Set the thermostat to 72 degrees")
        try await Task.sleep(nanoseconds: 2_000_000_000)

        await conversation.end()
    }
}

// MARK: - SwiftUI Integration Example

#if canImport(SwiftUI)
import SwiftUI

@available(macOS 14.0, iOS 17.0, *)
struct RealtimeVoiceView: View {
    @State private var isListening = false
    @State private var transcript = ""
    @State private var audioLevel: Float = 0
    @State private var conversation: RealtimeConversation?

    var body: some View {
        VStack(spacing: 20) {
            // Audio level indicator
            HStack {
                ForEach(0..<10) { i in
                    Rectangle()
                        .fill(Color.blue.opacity(Double(i) / 10 <= Double(self.audioLevel) ? 1 : 0.3))
                        .frame(width: 10, height: 30)
                }
            }
            .frame(height: 50)

            // Transcript display
            ScrollView {
                Text(self.transcript)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .border(Color.gray, width: 1)

            // Control buttons
            HStack(spacing: 20) {
                Button(action: self.toggleListening) {
                    Image(systemName: self.isListening ? "mic.fill" : "mic.slash.fill")
                        .font(.system(size: 30))
                        .foregroundColor(self.isListening ? .red : .gray)
                }
                .buttonStyle(.plain)

                Button("Send Text") {
                    Task {
                        try? await self.conversation?.sendText("Hello, how are you?")
                    }
                }

                Button("End") {
                    Task {
                        await self.conversation?.end()
                        self.conversation = nil
                    }
                }
            }
        }
        .padding()
        .task {
            await self.setupConversation()
        }
    }

    private func toggleListening() {
        Task {
            if self.isListening {
                await self.conversation?.stopListening()
            } else {
                try? await self.conversation?.startListening()
            }
            self.isListening.toggle()
        }
    }

    private func setupConversation() async {
        do {
            conversation = try await startRealtimeConversation(
                model: .gpt4oRealtime,
                voice: .nova,
            )

            // Listen for updates
            if let conversation {
                Task {
                    for await text in conversation.transcriptUpdates {
                        self.transcript += text + " "
                    }
                }

                Task {
                    for await level in conversation.audioLevelUpdates {
                        self.audioLevel = level
                    }
                }
            }
        } catch {
            print("Failed to start conversation: \(error)")
        }
    }
}
#endif
