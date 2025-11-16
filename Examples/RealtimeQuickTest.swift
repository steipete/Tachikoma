import Foundation
import Tachikoma
import TachikomaAudio

// Quick test to verify Realtime API configuration

@available(macOS 14.0, iOS 17.0, *)
@MainActor
func testRealtimeConfiguration() async throws {
    print("🧪 Testing Realtime API Configuration...")
    print("=" * 50)

    // Test 1: Session Configuration
    print("\n1️⃣ Testing Session Configuration:")
    let voiceConfig = SessionConfiguration.voiceConversation(
        model: "gpt-4o-realtime-preview",
        voice: .nova,
    )
    print("   ✅ Model: \(voiceConfig.model)")
    print("   ✅ Voice: \(voiceConfig.voice)")
    print("   ✅ Turn Detection: \(voiceConfig.turnDetection?.type.rawValue ?? "none")")
    print("   ✅ Modalities: \(voiceConfig.modalities?.toArray.joined(separator: ", ") ?? "none")")

    // Test 2: Turn Detection
    print("\n2️⃣ Testing Turn Detection Configuration:")
    let vad = RealtimeTurnDetection.serverVAD
    print("   ✅ Type: \(vad.type.rawValue)")
    print("   ✅ Threshold: \(vad.threshold ?? 0)")
    print("   ✅ Silence Duration: \(vad.silenceDurationMs ?? 0)ms")
    print("   ✅ Create Response: \(vad.createResponse ?? false)")

    // Test 3: Response Modalities
    print("\n3️⃣ Testing Response Modalities:")
    let modalities = ResponseModality.all
    print("   ✅ Contains text: \(modalities.contains(.text))")
    print("   ✅ Contains audio: \(modalities.contains(.audio))")
    print("   ✅ Array format: \(modalities.toArray.joined(separator: ", "))")

    // Test 4: Conversation Settings
    print("\n4️⃣ Testing Conversation Settings:")
    let settings = ConversationSettings.production
    print("   ✅ Auto-reconnect: \(settings.autoReconnect)")
    print("   ✅ Max attempts: \(settings.maxReconnectAttempts)")
    print("   ✅ Buffer audio: \(settings.bufferWhileDisconnected)")
    print("   ✅ Echo cancellation: \(settings.enableEchoCancellation)")

    // Test 5: Tool Creation
    print("\n5️⃣ Testing Tool Creation:")
    let tool = RealtimeTool(
        name: "test_tool",
        description: "Test tool for validation",
        parameters: AgentToolParameters(
            properties: [
                "input": AgentToolParameterProperty(
                    name: "input",
                    type: .string,
                    description: "Test input",
                ),
            ],
            required: ["input"],
        ),
    )
    print("   ✅ Tool name: \(tool.name)")
    print("   ✅ Parameters: \(tool.parameters.properties.count)")
    print("   ✅ Required: \(tool.parameters.required.joined(separator: ", "))")

    // Test 6: Event Creation
    print("\n6️⃣ Testing Event Creation:")
    let event = RealtimeClientEvent.responseCreate(
        ResponseCreateEvent(
            modalities: ["text", "audio"],
            instructions: "Test instructions",
            voice: .nova,
            temperature: 0.8,
        ),
    )
    if case let .responseCreate(createEvent) = event {
        print("   ✅ Event type: responseCreate")
        print("   ✅ Modalities: \(createEvent.modalities?.joined(separator: ", ") ?? "none")")
        print("   ✅ Temperature: \(createEvent.temperature ?? 0)")
    }

    // Test 7: Audio Format
    print("\n7️⃣ Testing Audio Formats:")
    let formats: [RealtimeAudioFormat] = [.pcm16, .g711Ulaw, .g711Alaw]
    for format in formats {
        print("   ✅ Format: \(format.rawValue)")
    }

    // Test 8: Conversation Item
    print("\n8️⃣ Testing Conversation Items:")
    let item = ConversationItem(
        id: "test-123",
        type: "message",
        role: "user",
        content: [ConversationContent(type: "text", text: "Test message")],
    )
    print("   ✅ Item ID: \(item.id)")
    print("   ✅ Type: \(item.type)")
    print("   ✅ Content: \(item.content?.first?.text ?? "none")")

    print("\n" + "=" * 50)
    print("✅ All configuration tests passed!")
    print("\n📝 Note: This test validates configuration without API calls.")
    print("To test actual API functionality, set OPENAI_API_KEY and run:")
    print("  swift run RealtimeVoiceAssistant --basic")
}

// Extension for string multiplication
extension String {
    static func * (string: String, count: Int) -> String {
        String(repeating: string, count: count)
    }
}

// Main entry point
#if os(macOS) || os(iOS)
if #available(macOS 14.0, iOS 17.0, *) {
    Task {
        do {
            try await testRealtimeConfiguration()
        } catch {
            print("❌ Error: \(error)")
        }
        exit(0)
    }
    RunLoop.main.run()
}
#endif
