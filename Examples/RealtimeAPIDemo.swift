import Foundation
import Tachikoma
import TachikomaAudio

/// Demonstrates Realtime API usage with Tachikoma
@available(macOS 14.0, iOS 17.0, *)
public struct RealtimeAPIDemo {
    /// Run a simple demo of the Realtime API
    public static func runDemo() async throws {
        print("""
        ╔════════════════════════════════════════════════╗
        ║   Tachikoma Realtime API Demo                 ║
        ╚════════════════════════════════════════════════╝
        """)

        // 1. Create configuration
        print("\n1️⃣ Creating Configuration...")
        let config = SessionConfiguration(
            model: "gpt-4o-realtime-preview",
            voice: .nova,
            instructions: "You are a helpful voice assistant",
            inputAudioFormat: .pcm16,
            outputAudioFormat: .pcm16,
            inputAudioTranscription: .whisper,
            turnDetection: RealtimeTurnDetection.serverVAD,
            tools: nil,
            toolChoice: nil,
            temperature: 0.8,
            maxResponseOutputTokens: 4096,
            modalities: .all,
        )

        print("   ✅ Model: \(config.model)")
        print("   ✅ Voice: \(config.voice)")
        print("   ✅ Turn Detection: \(config.turnDetection?.type.rawValue ?? "none")")

        // 2. Create conversation settings
        print("\n2️⃣ Creating Conversation Settings...")
        let settings = ConversationSettings.production
        print("   ✅ Auto-reconnect: \(settings.autoReconnect)")
        print("   ✅ Max attempts: \(settings.maxReconnectAttempts)")
        print("   ✅ Buffer audio: \(settings.bufferWhileDisconnected)")

        // 3. Show modality options
        print("\n3️⃣ Response Modalities...")
        let modalities = ResponseModality.all
        print("   ✅ Text: \(modalities.contains(.text))")
        print("   ✅ Audio: \(modalities.contains(.audio))")
        print("   ✅ Array: \(modalities.toArray.joined(separator: ", "))")

        // 4. Create tools
        print("\n4️⃣ Creating Tools...")
        let weatherTool = RealtimeTool(
            name: "get_weather",
            description: "Get weather information",
            parameters: AgentToolParameters(
                properties: [
                    "location": AgentToolParameterProperty(
                        name: "location",
                        type: .string,
                        description: "City and state/country",
                    ),
                ],
                required: ["location"],
            ),
        )
        print("   ✅ Tool: \(weatherTool.name)")
        print("   ✅ Description: \(weatherTool.description)")

        // 5. Show event types
        print("\n5️⃣ Event Types...")
        print("   Client Events:")
        print("     • sessionUpdate")
        print("     • inputAudioBufferAppend")
        print("     • responseCreate")
        print("   Server Events:")
        print("     • sessionCreated")
        print("     • responseAudioDelta")
        print("     • error")

        // 6. Create conversation items
        print("\n6️⃣ Conversation Items...")
        let messageItem = ConversationItem(
            id: "msg-001",
            type: "message",
            role: "user",
            content: [ConversationContent(type: "text", text: "Hello!")],
        )
        print("   ✅ Created message: \(messageItem.content?.first?.text ?? "")")

        // 7. Show audio formats
        print("\n7️⃣ Audio Formats...")
        let formats: [RealtimeAudioFormat] = [.pcm16, .g711Ulaw, .g711Alaw]
        for format in formats {
            print("   • \(format.rawValue)")
        }

        print("""

        ════════════════════════════════════════════════
        ✅ Demo Complete!

        To use with a real API key:
        1. Set OPENAI_API_KEY environment variable
        2. Create a RealtimeConversation instance
        3. Start the conversation with your configuration

        Example:
        let conversation = try RealtimeConversation(configuration: config)
        try await conversation.start(
            model: .gpt4oRealtime,
            voice: .nova
        )
        ════════════════════════════════════════════════
        """)
    }

    /// Create a sample configuration for testing
    public static func createSampleConfiguration() -> SessionConfiguration {
        SessionConfiguration.voiceConversation(
            model: "gpt-4o-realtime-preview",
            voice: .nova,
        )
    }

    /// Validate that all types are properly configured
    public static func validateTypes() -> Bool {
        // Test configuration creation
        let config = self.createSampleConfiguration()
        guard config.model == "gpt-4o-realtime-preview" else { return false }

        // Test VAD configuration
        let vad = RealtimeTurnDetection.serverVAD
        guard vad.type == .serverVad else { return false }

        // Test modalities
        let modalities = ResponseModality.all
        guard modalities.contains(.text), modalities.contains(.audio) else { return false }

        // Test settings
        let settings = ConversationSettings.production
        guard settings.autoReconnect == true else { return false }

        return true
    }
}
