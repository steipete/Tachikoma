//
//  UIIntegration.swift
//  Tachikoma
//

import Foundation

// MARK: - UI Message Types

/// Message format optimized for UI display
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct UIMessage: Sendable, Codable {
    public let id: String
    public let role: ModelMessage.Role
    public let content: String
    public let attachments: [UIAttachment]
    public let toolCalls: [AgentToolCall]?
    public let metadata: [String: String]
    public let timestamp: Date
    
    public init(
        id: String = UUID().uuidString,
        role: ModelMessage.Role,
        content: String,
        attachments: [UIAttachment] = [],
        toolCalls: [AgentToolCall]? = nil,
        metadata: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.attachments = attachments
        self.toolCalls = toolCalls
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

/// Attachment in UI messages
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct UIAttachment: Sendable, Codable {
    public let id: String
    public let type: AttachmentType
    public let url: URL?
    public let data: Data?
    public let mimeType: String
    public let name: String?
    
    public enum AttachmentType: String, Sendable, Codable {
        case image
        case document
        case audio
        case video
        case file
    }
    
    public init(
        id: String = UUID().uuidString,
        type: AttachmentType,
        url: URL? = nil,
        data: Data? = nil,
        mimeType: String,
        name: String? = nil
    ) {
        self.id = id
        self.type = type
        self.url = url
        self.data = data
        self.mimeType = mimeType
        self.name = name
    }
}

/// Streaming chunk for UI updates
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum UIMessageChunk: Sendable {
    case text(String)
    case toolCallStart(id: String, name: String)
    case toolCallArgument(id: String, argument: String)
    case toolCallEnd(id: String)
    case attachment(UIAttachment)
    case metadata([String: String])
    case error(Error)
    case done
}

// MARK: - Message Conversion

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension Array where Element == UIMessage {
    /// Convert UI messages to model messages for API calls
    func toModelMessages() -> [ModelMessage] {
        self.map { uiMessage in
            var contentParts: [ModelMessage.ContentPart] = [.text(uiMessage.content)]
            
            // Add attachments as content parts
            for attachment in uiMessage.attachments {
                if attachment.type == .image {
                    if let data = attachment.data {
                        let base64 = data.base64EncodedString()
                        let dataUrl = "data:\(attachment.mimeType);base64,\(base64)"
                        contentParts.append(.image(dataUrl))
                    } else if let url = attachment.url {
                        contentParts.append(.image(url.absoluteString))
                    }
                }
            }
            
            // Add tool calls
            if let toolCalls = uiMessage.toolCalls {
                for toolCall in toolCalls {
                    contentParts.append(.toolCall(toolCall))
                }
            }
            
            return ModelMessage(
                role: uiMessage.role,
                content: contentParts
            )
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension Array where Element == ModelMessage {
    /// Convert model messages to UI messages for display
    func toUIMessages() -> [UIMessage] {
        self.map { modelMessage in
            var content = ""
            var attachments: [UIAttachment] = []
            var toolCalls: [AgentToolCall] = []
            
            for part in modelMessage.content {
                switch part {
                case .text(let text):
                    content += text
                case .image(let url):
                    if url.starts(with: "data:") {
                        // Parse data URL
                        let components = url.split(separator: ",", maxSplits: 1)
                        if components.count == 2 {
                            let metadata = String(components[0])
                            let base64Data = String(components[1])
                            
                            if let data = Data(base64Encoded: base64Data) {
                                let mimeType = metadata
                                    .replacingOccurrences(of: "data:", with: "")
                                    .replacingOccurrences(of: ";base64", with: "")
                                
                                attachments.append(UIAttachment(
                                    type: .image,
                                    data: data,
                                    mimeType: mimeType
                                ))
                            }
                        }
                    } else if let imageUrl = URL(string: url) {
                        attachments.append(UIAttachment(
                            type: .image,
                            url: imageUrl,
                            mimeType: "image/jpeg"
                        ))
                    }
                case .toolCall(let call):
                    toolCalls.append(call)
                case .toolResult(let result):
                    content += "\n[Tool Result: \(result.result)]"
                }
            }
            
            return UIMessage(
                role: modelMessage.role,
                content: content,
                attachments: attachments,
                toolCalls: toolCalls.isEmpty ? nil : toolCalls
            )
        }
    }
}

// MARK: - Streaming Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension StreamTextResult {
    /// Convert streaming result to UI message chunks for real-time updates
    func toUIMessageStream() -> AsyncStream<UIMessageChunk> {
        AsyncStream { continuation in
            Task {
                do {
                    for try await event in self.stream {
                        switch event {
                        case .text(let text):
                            continuation.yield(.text(text))
                        case .toolCallStart(let id, let name):
                            continuation.yield(.toolCallStart(id: id, name: name))
                        case .toolCallArgument(let id, let argument):
                            continuation.yield(.toolCallArgument(id: id, argument: argument))
                        case .toolCallEnd(let id):
                            continuation.yield(.toolCallEnd(id: id))
                        case .finish:
                            continuation.yield(.done)
                            continuation.finish()
                        case .error(let error):
                            continuation.yield(.error(error))
                            continuation.finish()
                        }
                    }
                } catch {
                    continuation.yield(.error(error))
                    continuation.finish()
                }
            }
        }
    }
    
    /// Convert streaming result to simple text stream
    func toTextStream() -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                do {
                    for try await event in self.stream {
                        if case .text(let text) = event {
                            continuation.yield(text)
                        } else if case .finish = event {
                            continuation.finish()
                        }
                    }
                } catch {
                    continuation.finish()
                }
            }
        }
    }
    
    /// Collect all text from stream into a single string
    func collectText() async throws -> String {
        var result = ""
        for try await event in self.stream {
            if case .text(let text) = event {
                result += text
            }
        }
        return result
    }
}

// MARK: - Response Helpers

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct UIStreamResponse: Sendable {
    public let stream: AsyncStream<UIMessageChunk>
    public let messageId: String
    public let role: ModelMessage.Role
    
    public init(
        stream: AsyncStream<UIMessageChunk>,
        messageId: String = UUID().uuidString,
        role: ModelMessage.Role = .assistant
    ) {
        self.stream = stream
        self.messageId = messageId
        self.role = role
    }
    
    /// Collect complete message from stream
    public func collectMessage() async -> UIMessage {
        var content = ""
        var toolCalls: [AgentToolCall] = []
        var currentToolCall: (id: String, name: String, arguments: String)?
        
        for await chunk in stream {
            switch chunk {
            case .text(let text):
                content += text
            case .toolCallStart(let id, let name):
                currentToolCall = (id, name, "")
            case .toolCallArgument(let id, let argument):
                if currentToolCall?.id == id {
                    currentToolCall?.arguments += argument
                }
            case .toolCallEnd(let id):
                if let tool = currentToolCall, tool.id == id {
                    toolCalls.append(AgentToolCall(
                        id: tool.id,
                        name: tool.name,
                        arguments: try? JSONSerialization.jsonObject(
                            with: tool.arguments.data(using: .utf8) ?? Data()
                        ) as? [String: Any] ?? [:]
                    ))
                    currentToolCall = nil
                }
            case .done, .error:
                break
            default:
                break
            }
        }
        
        return UIMessage(
            id: messageId,
            role: role,
            content: content,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls
        )
    }
}

// MARK: - Convenience Functions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func convertToModelMessages(_ uiMessages: [UIMessage]) -> [ModelMessage] {
    uiMessages.toModelMessages()
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func convertToUIMessages(_ modelMessages: [ModelMessage]) -> [UIMessage] {
    modelMessages.toUIMessages()
}