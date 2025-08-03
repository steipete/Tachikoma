import Foundation
import SwiftUI
import TachikomaCore
import TachikomaBuilders

// MARK: - @AI Property Wrapper

/// Property wrapper for AI assistants in SwiftUI applications
/// Automatically manages conversation state and provides easy access to AI capabilities
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@propertyWrapper
public struct AI: DynamicProperty {
    private let model: Model
    private let systemPrompt: String?
    private let tools: (any ToolKit)?
    private let maxTokens: Int?
    private let temperature: Double?
    
    @StateObject private var assistant: AIAssistant
    
    public init(
        _ model: Model,
        systemPrompt: String? = nil,
        tools: (any ToolKit)? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) {
        self.model = model
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.maxTokens = maxTokens
        self.temperature = temperature
        
        self._assistant = StateObject(wrappedValue: AIAssistant(
            model: model,
            systemPrompt: systemPrompt,
            tools: tools,
            maxTokens: maxTokens,
            temperature: temperature
        ))
    }
    
    public var wrappedValue: AIAssistant {
        assistant
    }
    
    public var projectedValue: AIAssistant {
        assistant
    }
}

// MARK: - AIAssistant

/// Observable AI assistant that manages conversation state for SwiftUI
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@MainActor
public final class AIAssistant: ObservableObject {
    private let model: Model
    private let systemPrompt: String?
    private let tools: (any ToolKit)?
    private let maxTokens: Int?
    private let temperature: Double?
    
    @Published public private(set) var conversation: Conversation
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: Error?
    
    /// All messages in the conversation
    public var messages: [Message] {
        conversation.messages
    }
    
    /// Whether the conversation has any messages
    public var isEmpty: Bool {
        conversation.isEmpty
    }
    
    /// The last user message content
    public var lastUserMessage: String? {
        conversation.lastUserMessage
    }
    
    /// The last assistant message content
    public var lastAssistantMessage: String? {
        conversation.lastAssistantMessage
    }
    
    public init(
        model: Model,
        systemPrompt: String? = nil,
        tools: (any ToolKit)? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) {
        self.model = model
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.maxTokens = maxTokens
        self.temperature = temperature
        
        self.conversation = Conversation()
        
        // Add system prompt if provided
        if let systemPrompt = systemPrompt {
            self.conversation.system(systemPrompt)
        }
    }
    
    // MARK: - Core Interaction Methods
    
    /// Send a message and get a response
    public func respond(to input: String) async throws -> String {
        guard !isLoading else {
            throw AIAssistantError.alreadyProcessing
        }
        
        isLoading = true
        lastError = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Add user message
            conversation.user(input)
            
            // Get response from AI
            let response = try await conversation.continue(
                using: model,
                tools: tools,
                maxTokens: maxTokens,
                temperature: temperature
            )
            
            return response
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// Send a message with image and get a response
    public func respond(to input: String, image: ImageInput) async throws -> String {
        guard !isLoading else {
            throw AIAssistantError.alreadyProcessing
        }
        
        guard model.supportsVision else {
            throw AIAssistantError.visionNotSupported
        }
        
        isLoading = true
        lastError = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Add user message with image
            conversation.userWithImage(input, image: image)
            
            // Get response from AI
            let response = try await conversation.continue(
                using: model,
                tools: tools,
                maxTokens: maxTokens,
                temperature: temperature
            )
            
            return response
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// Start a streaming conversation
    public func stream(input: String) -> AsyncThrowingStream<StreamToken, Error> {
        // Add user message immediately
        conversation.user(input)
        
        // Set loading state
        isLoading = true
        lastError = nil
        
        return AsyncThrowingStream { continuation in
            Task { @MainActor in
                defer {
                    self.isLoading = false
                }
                
                do {
                    let stream = conversation.stream(using: model, tools: tools)
                    
                    for try await token in stream {
                        continuation.yield(token)
                    }
                    
                    continuation.finish()
                } catch {
                    self.lastError = error
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Conversation Management
    
    /// Clear the entire conversation
    public func clear() {
        conversation.clear()
        
        // Re-add system prompt if it was provided
        if let systemPrompt = systemPrompt {
            conversation.system(systemPrompt)
        }
        
        lastError = nil
    }
    
    /// Remove the last message
    public func removeLast() {
        conversation.removeLast()
    }
    
    /// Create a copy of this assistant
    public func copy() -> AIAssistant {
        let copy = AIAssistant(
            model: model,
            systemPrompt: systemPrompt,
            tools: tools,
            maxTokens: maxTokens,
            temperature: temperature
        )
        copy.conversation = conversation.copy()
        return copy
    }
    
    /// Branch the conversation from a specific point
    public func branch(fromIndex index: Int) -> AIAssistant {
        let branch = AIAssistant(
            model: model,
            systemPrompt: systemPrompt,
            tools: tools,
            maxTokens: maxTokens,
            temperature: temperature
        )
        branch.conversation = conversation.branch(fromIndex: index)
        return branch
    }
}

// MARK: - AIAssistant Errors

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum AIAssistantError: Error, LocalizedError {
    case alreadyProcessing
    case visionNotSupported
    case invalidInput(String)
    
    public var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "AI assistant is already processing a request"
        case .visionNotSupported:
            return "Selected model does not support vision inputs"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        }
    }
}

// MARK: - SwiftUI View Modifiers

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public extension View {
    /// Add an AI chat interface to any view
    func aiChat<T: ToolKit>(
        model: Model = .default,
        systemPrompt: String? = nil,
        tools: T? = nil,
        isPresented: Binding<Bool>
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            AIChatView(
                model: model,
                systemPrompt: systemPrompt,
                tools: tools
            )
        }
    }
    
    /// Add an AI chat interface with a specific assistant
    func aiChat(
        with assistant: AIAssistant,
        isPresented: Binding<Bool>
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            AIChatView(assistant: assistant)
        }
    }
}

// MARK: - AI Chat View

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AIChatView<T: ToolKit>: View {
    @AI private var assistant: AIAssistant
    @State private var messageText = ""
    @State private var isStreaming = false
    @Environment(\.dismiss) private var dismiss
    
    public init(
        model: Model = .default,
        systemPrompt: String? = nil,
        tools: T? = nil
    ) {
        self._assistant = AI(
            model,
            systemPrompt: systemPrompt,
            tools: tools
        )
    }
    
    public init(assistant: AIAssistant) {
        // For now, create a new AI wrapper - in real implementation this would be more sophisticated
        self._assistant = AI(
            assistant.model,
            systemPrompt: assistant.systemPrompt,
            tools: assistant.tools
        )
    }
    
    public var body: some View {
        NavigationView {
            VStack {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(assistant.messages.enumerated()), id: \.offset) { index, message in
                                MessageBubble(message: message)
                                    .id(index)
                            }
                            
                            if assistant.isLoading || isStreaming {
                                TypingIndicator()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: assistant.messages.count) { _ in
                        if let lastIndex = assistant.messages.indices.last {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
                
                // Input area
                HStack {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            sendMessage()
                        }
                        .disabled(assistant.isLoading || isStreaming)
                    
                    Button("Send") {
                        sendMessage()
                    }
                    .disabled(messageText.isEmpty || assistant.isLoading || isStreaming)
                }
                .padding()
            }
            .navigationTitle("AI Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        assistant.clear()
                    }
                    .disabled(assistant.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        let text = messageText
        messageText = ""
        
        Task {
            do {
                _ = try await assistant.respond(to: text)
            } catch {
                // Error handling would go here
                print("Error: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct MessageBubble: View {
    let message: Message
    
    public var body: some View {
        HStack {
            if message.type == .user {
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(messageContent)
                    .padding()
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .cornerRadius(12)
                
                HStack {
                    Text(message.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            if message.type != .user {
                Spacer()
            }
        }
    }
    
    private var messageContent: String {
        switch message {
        case .system(_, let content):
            return content
        case .user(_, let content):
            switch content {
            case .text(let text):
                return text
            case .multimodal(let parts):
                return parts.compactMap { $0.text }.joined(separator: " ")
            default:
                return "[Media content]"
            }
        case .assistant(_, let content, _):
            return content.compactMap { $0.textContent }.joined(separator: "\n")
        case .tool(_, _, let content):
            return content
        case .reasoning(_, let content):
            return content
        }
    }
    
    private var backgroundColor: Color {
        switch message.type {
        case .user:
            return .blue
        case .assistant:
            return .gray.opacity(0.2)
        case .system:
            return .orange.opacity(0.2)
        case .tool:
            return .green.opacity(0.2)
        case .reasoning:
            return .purple.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch message.type {
        case .user:
            return .white
        default:
            return .primary
        }
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct TypingIndicator: View {
    @State private var isAnimating = false
    
    public var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
            
            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview Helpers

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
#if DEBUG
struct AIChatView_Previews: PreviewProvider {
    static var previews: some View {
        AIChatView<EmptyToolKit>(
            model: .claude,
            systemPrompt: "You are a helpful assistant."
        )
    }
}
#endif