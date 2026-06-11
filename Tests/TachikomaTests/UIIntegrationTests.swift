import Foundation
import Testing
@testable import Tachikoma

struct UIIntegrationTests {
    @Test
    func `Convert UIMessage to ModelMessage`() throws {
        // Create a UIMessage with various content
        let uiMessage = try UIMessage(
            role: .user,
            content: "Hello, world!",
            attachments: [
                UIAttachment(
                    type: .image,
                    data: Data("test".utf8),
                    mimeType: "image/png",
                ),
            ],
            toolCalls: [
                AgentToolCall(
                    id: "test-1",
                    name: "calculator",
                    arguments: ["expression": "2+2"],
                ),
            ],
        )

        // Convert to model messages
        let modelMessages = [uiMessage].toModelMessages()

        #expect(modelMessages.count == 1)
        #expect(modelMessages[0].role == .user)

        // Check content parts
        let parts = modelMessages[0].content
        #expect(parts.count >= 2) // Text + image + tool call

        // Verify text content
        if case let .text(text) = parts[0] {
            #expect(text == "Hello, world!")
        } else {
            Issue.record("First content part should be text")
        }

        // Verify image content
        if parts.count > 1, case let .image(imageContent) = parts[1] {
            #expect(imageContent.mimeType == "image/png")
        } else {
            Issue.record("Second content part should be image")
        }
    }

    @Test
    func `Convert ModelMessage to UIMessage`() throws {
        // Create a ModelMessage with various content
        let modelMessage = try ModelMessage(
            role: .assistant,
            content: [
                .text("Here's the result:"),
                .image(ModelMessage.ContentPart.ImageContent(
                    data: "https://example.com/image.jpg",
                    mimeType: "image/jpeg",
                )),
                .toolCall(AgentToolCall(
                    id: "calc-1",
                    name: "calculator",
                    arguments: ["result": 42],
                )),
            ],
        )

        // Convert to UI messages
        let uiMessages = [modelMessage].toUIMessages()

        #expect(uiMessages.count == 1)
        #expect(uiMessages[0].role == .assistant)
        #expect(uiMessages[0].content == "Here's the result:")
        #expect(uiMessages[0].attachments.count == 1)
        #expect(uiMessages[0].toolCalls?.count == 1)
    }

    @Test
    func `Thinking ModelMessages are hidden from UI messages`() {
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("private reasoning")],
            channel: .thinking,
            metadata: .init(customData: ["anthropic.thinking.signature": "sig"]),
        )
        let visible = ModelMessage(role: .assistant, content: [.text("Visible answer")])

        let uiMessages = [thinking, visible].toUIMessages()

        #expect(uiMessages.count == 1)
        #expect(uiMessages[0].content == "Visible answer")
    }

    @Test
    func `Provider-neutral thinking ModelMessages remain visible in UI messages`() {
        let thinking = ModelMessage(
            role: .assistant,
            content: [.text("visible reasoning")],
            channel: .thinking,
        )

        let uiMessages = [thinking].toUIMessages()

        #expect(uiMessages.count == 1)
        #expect(uiMessages[0].content == "visible reasoning")
    }

    @Test
    func `Provider-native reasoning ModelMessages are hidden from UI messages`() {
        let reasoning = ModelMessage(
            role: .assistant,
            content: [.text("openrouter reasoning")],
            channel: .thinking,
            metadata: .init(customData: [
                "tachikoma.reasoning.provider": "openrouter",
                "tachikoma.reasoning.model": "anthropic/claude-fable-5",
            ]),
        )
        let visible = ModelMessage(role: .assistant, content: [.text("Visible answer")])

        let uiMessages = [reasoning, visible].toUIMessages()

        #expect(uiMessages.count == 1)
        #expect(uiMessages[0].content == "Visible answer")
    }

    @Test
    func `Synthetic reasoning boundaries are hidden from UI messages`() {
        let boundary = ModelMessage(
            role: .assistant,
            content: [.text("")],
            metadata: .init(customData: ["tachikoma.internal.boundary": "reasoning_only"]),
        )
        let visible = ModelMessage(role: .assistant, content: [.text("Visible answer")])

        let uiMessages = [boundary, visible].toUIMessages()

        #expect(uiMessages.count == 1)
        #expect(uiMessages[0].content == "Visible answer")
    }

    @Test
    func `StreamTextResult to UI Message Stream`() async {
        // Create a mock stream
        let textStream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                continuation.yield(TextStreamDelta(
                    type: .textDelta,
                    content: "Hello",
                ))
                continuation.yield(TextStreamDelta(
                    type: .textDelta,
                    content: " world",
                ))
                continuation.yield(TextStreamDelta(
                    type: .done,
                    content: nil,
                ))
                continuation.finish()
            }
        }

        let streamResult = StreamTextResult(
            stream: textStream,
            model: .openai(.gpt55),
            settings: .default,
        )

        // Convert to UI stream
        let uiStream = streamResult.toUIMessageStream()

        var chunks: [UIMessageChunk] = []
        for await chunk in uiStream {
            chunks.append(chunk)
        }

        #expect(chunks.count >= 3)

        // Verify chunks
        if case let .text(text) = chunks[0] {
            #expect(text == "Hello")
        } else {
            Issue.record("First chunk should be text")
        }

        if case let .text(text) = chunks[1] {
            #expect(text == " world")
        } else {
            Issue.record("Second chunk should be text")
        }

        if case .done = chunks[2] {
            // Expected
        } else {
            Issue.record("Last chunk should be done")
        }
    }

    @Test
    func `Collect text from stream`() async throws {
        // Create a mock stream
        let textStream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                continuation.yield(TextStreamDelta(
                    type: .textDelta,
                    content: "The quick ",
                ))
                continuation.yield(TextStreamDelta(
                    type: .textDelta,
                    content: "brown fox",
                ))
                continuation.yield(TextStreamDelta(
                    type: .done,
                    content: nil,
                ))
                continuation.finish()
            }
        }

        let streamResult = StreamTextResult(
            stream: textStream,
            model: .openai(.gpt55),
            settings: .default,
        )

        let collectedText = try await streamResult.collectText()
        #expect(collectedText == "The quick brown fox")
    }

    @Test
    func `UIStreamResponse collect message`() async {
        let stream = AsyncStream<UIMessageChunk> { continuation in
            continuation.yield(.text("Hello"))
            continuation.yield(.text(" world"))
            continuation.yield(.toolCallStart(id: "t1", name: "test"))
            continuation.yield(.toolCallArgument(id: "t1", argument: "{\"x\":1}"))
            continuation.yield(.toolCallEnd(id: "t1"))
            continuation.yield(.done)
            continuation.finish()
        }

        let response = UIStreamResponse(
            stream: stream,
            messageId: "msg-1",
            role: .assistant,
        )

        let message = await response.collectMessage()

        #expect(message.id == "msg-1")
        #expect(message.role == .assistant)
        #expect(message.content == "Hello world")
        #expect(message.toolCalls?.count == 1)
        #expect(message.toolCalls?[0].name == "test")
    }

    @Test
    func `UIAttachment with data URL`() {
        let imageData = Data("test image".utf8)
        let attachment = UIAttachment(
            type: .image,
            data: imageData,
            mimeType: "image/png",
            name: "test.png",
        )

        #expect(attachment.type == .image)
        #expect(attachment.data == imageData)
        #expect(attachment.mimeType == "image/png")
        #expect(attachment.name == "test.png")
    }

    @Test
    func `Bidirectional conversion preserves content`() {
        let original = UIMessage(
            role: .user,
            content: "Test message",
            attachments: [],
            toolCalls: nil,
        )

        // Convert UIMessage -> ModelMessage -> UIMessage
        let modelMessages = [original].toModelMessages()
        let converted = modelMessages.toUIMessages()

        #expect(converted.count == 1)
        #expect(converted[0].role == original.role)
        #expect(converted[0].content == original.content)
    }
}
