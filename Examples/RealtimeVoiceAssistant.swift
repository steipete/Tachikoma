//
//  RealtimeVoiceAssistant.swift
//  Tachikoma
//

import Foundation
import Tachikoma
import TachikomaAudio

// MARK: - Complete Realtime API Example

/// Comprehensive example demonstrating all Realtime API features
@available(macOS 14.0, iOS 17.0, *)
@MainActor
class RealtimeVoiceAssistant {
    
    private let apiKey: String
    private var conversation: RealtimeConversation?
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Basic Voice Conversation
    
    func basicVoiceConversation() async throws {
        print("🎙️ Starting Basic Voice Conversation...")
        
        // Simple configuration for voice conversation
        let config = TachikomaConfiguration()
        config.setAPIKey(apiKey, for: .openai)
        
        // Create basic conversation
        let conversation = try RealtimeConversation(configuration: config)
        
        // Start with voice configuration
        try await conversation.start(
            model: .gpt4oRealtime,
            voice: .nova,
            instructions: "You are a helpful, witty, and friendly AI assistant. Keep responses concise."
        )
        
        print("✅ Connected to Realtime API")
        print("🎤 Starting to listen...")
        
        // Manual turn control
        try await conversation.startListening()
        
        // Simulate user speaking for 3 seconds
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        try await conversation.stopListening()
        print("🛑 Stopped listening, processing response...")
        
        // Handle transcript updates
        Task {
            for await transcript in conversation.transcriptUpdates {
                print("📝 Transcript: \(transcript)")
            }
        }
        
        // Monitor audio levels
        Task {
            for await level in conversation.audioLevelUpdates {
                if level > 0.5 {
                    print("🔊 Audio Level: \(String(format: "%.2f", level))")
                }
            }
        }
        
        // Let conversation run for 10 seconds
        try await Task.sleep(nanoseconds: 10_000_000_000)
        
        // End conversation
        await conversation.end()
        print("👋 Conversation ended")
    }
    
    // MARK: - Advanced Configuration with VAD
    
    func advancedVoiceWithVAD() async throws {
        print("\n🎯 Starting Advanced Voice Conversation with Server VAD...")
        
        // Advanced configuration with all features
        let config = SessionConfiguration(
            model: "gpt-4o-realtime-preview",
            voice: .nova,
            instructions: """
                You are an expert AI assistant with deep knowledge across many domains.
                Provide helpful, accurate, and engaging responses.
                Use a conversational tone while maintaining professionalism.
                """,
            inputAudioFormat: .pcm16,
            outputAudioFormat: .pcm16,
            inputAudioTranscription: .whisper,  // Enable transcription
            turnDetection: RealtimeTurnDetection(
                type: .serverVad,
                threshold: 0.5,
                silenceDurationMs: 200,      // 200ms silence to end turn
                prefixPaddingMs: 300,         // Include 300ms before speech
                createResponse: true          // Auto-respond after turn
            ),
            tools: nil,
            toolChoice: nil,
            temperature: 0.8,
            maxResponseOutputTokens: 4096,
            modalities: .all  // Both text and audio
        )
        
        // Production settings with auto-reconnect
        let settings = ConversationSettings(
            autoReconnect: true,
            maxReconnectAttempts: 3,
            reconnectDelay: 2.0,
            bufferWhileDisconnected: true,
            maxAudioBufferSize: 1024 * 1024,  // 1MB buffer
            enableEchoCancellation: true,
            enableNoiseSuppression: true,
            localVADThreshold: 0.3,
            showAudioLevels: true,
            persistConversation: false
        )
        
        // Create advanced conversation
        conversation = try RealtimeConversation(
            apiKey: apiKey,
            configuration: config,
            settings: settings
        )
        
        // Start conversation
        try await conversation!.start()
        print("✅ Connected with Server VAD enabled")
        
        // Monitor conversation state
        observeConversationState()
        
        // Server VAD will automatically detect speech start/stop
        print("🎤 Server VAD is listening for speech...")
        print("💡 Speak naturally - the server will detect when you start and stop talking")
        
        // Run for 30 seconds
        try await Task.sleep(nanoseconds: 30_000_000_000)
        
        await conversation!.end()
        print("👋 Advanced conversation ended")
    }
    
    // MARK: - Function Calling Example
    
    func voiceWithFunctionCalling() async throws {
        print("\n🛠️ Starting Voice Conversation with Function Calling...")
        
        // Configuration with tools
        let config = SessionConfiguration.withTools(
            model: "gpt-4o-realtime-preview",
            voice: .nova,
            tools: [
                // Weather tool
                RealtimeTool(
                    name: "get_weather",
                    description: "Get current weather for any location",
                    parameters: AgentToolParameters(
                        properties: [
                            "location": AgentToolParameterProperty(
                                name: "location",
                                type: .string,
                                description: "City and state/country, e.g., 'Tokyo, Japan'"
                            ),
                            "units": AgentToolParameterProperty(
                                name: "units",
                                type: .string,
                                description: "Temperature units: 'celsius' or 'fahrenheit'",
                                enumValues: ["celsius", "fahrenheit"]
                            )
                        ],
                        required: ["location"]
                    )
                ),
                
                // Calculator tool
                RealtimeTool(
                    name: "calculate",
                    description: "Perform mathematical calculations",
                    parameters: AgentToolParameters(
                        properties: [
                            "expression": AgentToolParameterProperty(
                                name: "expression",
                                type: .string,
                                description: "Mathematical expression to evaluate"
                            )
                        ],
                        required: ["expression"]
                    )
                ),
                
                // Time tool
                RealtimeTool(
                    name: "get_time",
                    description: "Get current time in any timezone",
                    parameters: AgentToolParameters(
                        properties: [
                            "timezone": AgentToolParameterProperty(
                                name: "timezone",
                                type: .string,
                                description: "Timezone name, e.g., 'America/New_York', 'Asia/Tokyo'"
                            )
                        ],
                        required: ["timezone"]
                    )
                )
            ]
        )
        
        conversation = try RealtimeConversation(
            apiKey: apiKey,
            configuration: config,
            settings: .production
        )
        
        // Register tool executors
        await conversation!.registerTools([
            createTool(
                name: "get_weather",
                parameters: [
                    AgentToolParameterProperty(name: "location", type: .string, description: "Location"),
                    AgentToolParameterProperty(name: "units", type: .string, description: "Units")
                ]
            ) { args in
                let location = try args.stringValue("location")
                let units = args.optionalStringValue("units") ?? "celsius"
                
                // Simulate weather API call
                let temp = Int.random(in: 15...30)
                let conditions = ["sunny", "cloudy", "partly cloudy", "rainy"].randomElement()!
                
                return .string("""
                    Weather in \(location):
                    Temperature: \(temp)°\(units == "celsius" ? "C" : "F")
                    Conditions: \(conditions)
                    Humidity: \(Int.random(in: 40...80))%
                    Wind: \(Int.random(in: 5...20)) km/h
                    """)
            },
            
            createTool(
                name: "calculate",
                parameters: [
                    AgentToolParameterProperty(name: "expression", type: .string, description: "Math expression")
                ]
            ) { args in
                let expression = try args.stringValue("expression")
                
                // Simple calculator (in production, use proper expression parser)
                let result = NSExpression(format: expression).expressionValue(with: nil, context: nil) as? NSNumber
                
                if let result = result {
                    return .string("Result: \(result.doubleValue)")
                } else {
                    return .string("Error: Invalid expression")
                }
            },
            
            createTool(
                name: "get_time",
                parameters: [
                    AgentToolParameterProperty(name: "timezone", type: .string, description: "Timezone")
                ]
            ) { args in
                let timezone = try args.stringValue("timezone")
                
                let formatter = DateFormatter()
                formatter.timeZone = TimeZone(identifier: timezone) ?? TimeZone.current
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss z"
                
                return .string("Current time in \(timezone): \(formatter.string(from: Date()))")
            }
        ])
        
        try await conversation!.start()
        print("✅ Connected with function calling enabled")
        
        print("\n📢 Try these voice commands:")
        print("   - 'What's the weather in Tokyo?'")
        print("   - 'Calculate 25 times 4 plus 10'")
        print("   - 'What time is it in New York?'")
        print("   - 'What's the weather in Paris in fahrenheit?'")
        
        // Monitor function calls
        Task {
            while conversation != nil {
                if let items = conversation?.items {
                    for item in items {
                        if item.type == "function_call" {
                            print("🔧 Function called: \(item.name ?? "unknown")")
                            if let output = item.output {
                                print("   Result: \(output)")
                            }
                        }
                    }
                }
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        
        // Run for 30 seconds
        try await Task.sleep(nanoseconds: 30_000_000_000)
        
        await conversation!.end()
        print("👋 Function calling conversation ended")
    }
    
    // MARK: - Dynamic Modality Switching
    
    func dynamicModalitySwitching() async throws {
        print("\n🔄 Starting Dynamic Modality Switching Example...")
        
        let config = SessionConfiguration.voiceConversation()
        conversation = try RealtimeConversation(
            apiKey: apiKey,
            configuration: config,
            settings: .production
        )
        
        try await conversation!.start()
        print("✅ Connected with all modalities")
        
        // Start with both text and audio
        print("🎙️ Mode: Text + Audio")
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        // Switch to text-only
        print("📝 Switching to text-only mode...")
        try await conversation!.updateModalities(.text)
        
        // Send text message
        try await conversation!.sendText("Hello! Can you explain what modalities are?")
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        // Switch to audio-only
        print("🎤 Switching to audio-only mode...")
        try await conversation!.updateModalities(.audio)
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        // Switch back to both
        print("🎙️📝 Switching back to text + audio mode...")
        try await conversation!.updateModalities(.all)
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        await conversation!.end()
        print("👋 Modality switching example ended")
    }
    
    // MARK: - Conversation Management
    
    func conversationManagement() async throws {
        print("\n📚 Starting Conversation Management Example...")
        
        let config = SessionConfiguration.voiceConversation()
        conversation = try RealtimeConversation(
            apiKey: apiKey,
            configuration: config,
            settings: .production
        )
        
        try await conversation!.start()
        
        // Send initial messages
        try await conversation!.sendText("Remember this number: 42")
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        try await conversation!.sendText("Also remember this word: Tachikoma")
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Check conversation history
        print("📜 Conversation items: \(conversation!.items.count)")
        for item in conversation!.items {
            if let content = item.content?.first {
                switch content.type {
                case "text":
                    print("   [\(item.role ?? "unknown")]: \(content.text ?? "")")
                default:
                    break
                }
            }
        }
        
        // Test memory
        try await conversation!.sendText("What number and word did I ask you to remember?")
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        // Clear conversation
        print("🗑️ Clearing conversation history...")
        try await conversation!.clearConversation()
        
        // Test memory after clear
        try await conversation!.sendText("What number and word did I mention earlier?")
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        await conversation!.end()
        print("👋 Conversation management example ended")
    }
    
    // MARK: - Error Handling and Reconnection
    
    func errorHandlingExample() async throws {
        print("\n⚠️ Starting Error Handling and Reconnection Example...")
        
        let config = SessionConfiguration.voiceConversation()
        
        // Settings with aggressive reconnection
        let settings = ConversationSettings(
            autoReconnect: true,
            maxReconnectAttempts: 5,
            reconnectDelay: 1.0,
            bufferWhileDisconnected: true,
            maxAudioBufferSize: 2 * 1024 * 1024  // 2MB buffer
        )
        
        conversation = try RealtimeConversation(
            apiKey: apiKey,
            configuration: config,
            settings: settings
        )
        
        // Monitor connection state
        Task {
            while conversation != nil {
                let state = conversation!.state
                let connected = conversation!.isConnected
                print("📡 State: \(state.rawValue), Connected: \(connected)")
                
                if state == .reconnecting {
                    print("🔄 Attempting to reconnect...")
                } else if state == .error {
                    print("❌ Error state detected")
                }
                
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        
        try await conversation!.start()
        print("✅ Connected with auto-reconnect enabled")
        
        // Simulate conversation
        try await conversation!.sendText("Testing connection stability")
        
        // Note: In a real scenario, you could test disconnection by:
        // - Disabling network
        // - Killing the connection
        // - Server-side timeout
        
        print("💡 Auto-reconnect will handle network interruptions")
        print("💾 Audio is buffered during disconnection")
        
        // Run for 10 seconds
        try await Task.sleep(nanoseconds: 10_000_000_000)
        
        await conversation!.end()
        print("👋 Error handling example ended")
    }
    
    // MARK: - Helper Methods
    
    private func observeConversationState() {
        guard let conversation = conversation else { return }
        
        Task {
            while self.conversation != nil {
                print("""
                    📊 Status:
                       State: \(conversation.state.rawValue)
                       Connected: \(conversation.isConnected)
                       Listening: \(conversation.isListening)
                       Speaking: \(conversation.isSpeaking)
                       Turn Active: \(conversation.turnActive)
                       Audio Level: \(String(format: "%.2f", conversation.audioLevel))
                       Items: \(conversation.items.count)
                    """)
                
                try await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }
}

// MARK: - Main Example Runner

@available(macOS 14.0, iOS 17.0, *)
@MainActor
func runRealtimeExamples() async throws {
    guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
        print("❌ Error: OPENAI_API_KEY environment variable not set")
        return
    }
    
    let assistant = RealtimeVoiceAssistant(apiKey: apiKey)
    
    print("""
    ╔════════════════════════════════════════════╗
    ║     OpenAI Realtime API Examples           ║
    ║     Tachikoma Swift SDK                    ║
    ╚════════════════════════════════════════════╝
    """)
    
    // Run examples based on command line argument
    if CommandLine.arguments.contains("--basic") {
        try await assistant.basicVoiceConversation()
    } else if CommandLine.arguments.contains("--vad") {
        try await assistant.advancedVoiceWithVAD()
    } else if CommandLine.arguments.contains("--tools") {
        try await assistant.voiceWithFunctionCalling()
    } else if CommandLine.arguments.contains("--modality") {
        try await assistant.dynamicModalitySwitching()
    } else if CommandLine.arguments.contains("--conversation") {
        try await assistant.conversationManagement()
    } else if CommandLine.arguments.contains("--error") {
        try await assistant.errorHandlingExample()
    } else if CommandLine.arguments.contains("--all") {
        // Run all examples
        try await assistant.basicVoiceConversation()
        try await assistant.advancedVoiceWithVAD()
        try await assistant.voiceWithFunctionCalling()
        try await assistant.dynamicModalitySwitching()
        try await assistant.conversationManagement()
        try await assistant.errorHandlingExample()
    } else {
        print("""
        
        Usage: swift run RealtimeVoiceAssistant [option]
        
        Options:
          --basic       Basic voice conversation
          --vad         Advanced with Server VAD
          --tools       Function calling example
          --modality    Dynamic modality switching
          --conversation Conversation management
          --error       Error handling and reconnection
          --all         Run all examples
        
        Make sure OPENAI_API_KEY is set in your environment.
        """)
    }
}

// Entry point for standalone execution
#if os(macOS) || os(iOS)
if #available(macOS 14.0, iOS 17.0, *) {
    Task {
        do {
            try await runRealtimeExamples()
        } catch {
            print("❌ Error: \(error)")
        }
    }
}
#endif