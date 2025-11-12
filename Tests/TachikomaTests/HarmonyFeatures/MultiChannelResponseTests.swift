import Testing
@testable import Tachikoma

@Suite("Multi-Channel Response System")
struct MultiChannelResponseTests {
    @Test("ResponseChannel enum has all expected cases")
    func responseChannelCases() {
        let allCases = ResponseChannel.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.thinking))
        #expect(allCases.contains(.analysis))
        #expect(allCases.contains(.commentary))
        #expect(allCases.contains(.final))
    }

    @Test("ResponseChannel raw values are correct")
    func responseChannelRawValues() {
        #expect(ResponseChannel.thinking.rawValue == "thinking")
        #expect(ResponseChannel.analysis.rawValue == "analysis")
        #expect(ResponseChannel.commentary.rawValue == "commentary")
        #expect(ResponseChannel.final.rawValue == "final")
    }

    @Test("ModelMessage supports channel property")
    func modelMessageChannel() {
        let message = ModelMessage(
            role: .assistant,
            content: [.text("This is my reasoning")],
            channel: .thinking,
        )

        #expect(message.channel == .thinking)
        #expect(message.role == .assistant)
        #expect(message.content.first == .text("This is my reasoning"))
    }

    @Test("ModelMessage supports metadata property")
    func modelMessageMetadata() {
        let metadata = MessageMetadata(
            conversationId: "conv-123",
            turnId: "turn-456",
            customData: ["key": "value"],
        )

        let message = ModelMessage(
            role: .user,
            content: [.text("Hello")],
            metadata: metadata,
        )

        #expect(message.metadata?.conversationId == "conv-123")
        #expect(message.metadata?.turnId == "turn-456")
        #expect(message.metadata?.customData?["key"] == "value")
    }

    @Test("TextStreamDelta supports channel events")
    func textStreamDeltaChannelEvents() {
        // Channel information is now passed via the channel property, not event types
        let reasoningDelta = TextStreamDelta(
            type: .reasoning,
            content: "Analyzing the problem...",
            channel: .thinking,
        )

        let doneDelta = TextStreamDelta(
            type: .done,
            channel: .final,
        )

        let textDelta = TextStreamDelta(
            type: .textDelta,
            content: "Reasoning about the problem",
            channel: .thinking,
        )

        // Verify the event types and channels
        #expect(reasoningDelta.type == .reasoning)
        #expect(reasoningDelta.channel == .thinking)

        #expect(doneDelta.type == .done)
        #expect(doneDelta.channel == .final)

        #expect(textDelta.channel == .thinking)
        #expect(textDelta.content == "Reasoning about the problem")
    }

    @Test("MessageMetadata equality")
    func messageMetadataEquality() {
        let metadata1 = MessageMetadata(
            conversationId: "123",
            turnId: "456",
            customData: ["key": "value"],
        )

        let metadata2 = MessageMetadata(
            conversationId: "123",
            turnId: "456",
            customData: ["key": "value"],
        )

        let metadata3 = MessageMetadata(
            conversationId: "789",
            turnId: "456",
            customData: ["key": "value"],
        )

        #expect(metadata1 == metadata2)
        #expect(metadata1 != metadata3)
    }

    @Test("Legacy messages work without channel")
    func legacyMessageCompatibility() {
        // Old API still works
        let message = ModelMessage.user("Hello")

        #expect(message.channel == nil)
        #expect(message.metadata == nil)
        #expect(message.role == .user)
        #expect(message.content.first == .text("Hello"))
    }

    @Test("Convenience initializers preserve nil channel")
    func convenienceInitializers() {
        let systemMessage = ModelMessage.system("You are helpful")
        let userMessage = ModelMessage.user("Hello")
        let assistantMessage = ModelMessage.assistant("Hi there")

        #expect(systemMessage.channel == nil)
        #expect(userMessage.channel == nil)
        #expect(assistantMessage.channel == nil)
    }

    @Test("Channel-aware message creation")
    func channelAwareMessageCreation() {
        let thinkingMessage = ModelMessage(
            role: .assistant,
            content: [.text("Let me think about this...")],
            channel: .thinking,
        )

        let analysisMessage = ModelMessage(
            role: .assistant,
            content: [.text("Analyzing the components...")],
            channel: .analysis,
        )

        let finalMessage = ModelMessage(
            role: .assistant,
            content: [.text("The answer is 42")],
            channel: .final,
        )

        #expect(thinkingMessage.channel == .thinking)
        #expect(analysisMessage.channel == .analysis)
        #expect(finalMessage.channel == .final)
    }

    @Test("Codable conformance for ResponseChannel")
    func responseChannelCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = ResponseChannel.thinking
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ResponseChannel.self, from: data)

        #expect(decoded == original)

        // Check JSON string representation
        let jsonString = String(data: data, encoding: .utf8)
        #expect(jsonString == "\"thinking\"")
    }

    @Test("Codable conformance for MessageMetadata")
    func messageMetadataCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = MessageMetadata(
            conversationId: "conv-123",
            turnId: "turn-456",
            customData: ["foo": "bar", "baz": "qux"],
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MessageMetadata.self, from: data)

        #expect(decoded == original)
        #expect(decoded.conversationId == "conv-123")
        #expect(decoded.turnId == "turn-456")
        #expect(decoded.customData?["foo"] == "bar")
    }
}
