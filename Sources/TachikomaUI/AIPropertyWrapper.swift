import Foundation
import SwiftUI
import TachikomaCore
import Combine

// MARK: - @AI Property Wrapper for SwiftUI

/// Property wrapper that provides reactive AI model integration for SwiftUI
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@propertyWrapper
@MainActor
public struct AI: DynamicProperty {
    @StateObject private var manager: AIManager
    
    public var wrappedValue: AIManager {
        manager
    }
    
    public var projectedValue: Binding<AIManager> {
        Binding(
            get: { manager },
            set: { _ in }
        )
    }
    
    public init(
        model: LanguageModel = .default,
        system: String? = nil,
        settings: GenerationSettings = .default,
        tools: [SimpleTool] = []
    ) {
        // Create AIManager on main actor since it's @MainActor
        let aiManager = AIManager(
            model: model,
            system: system,
            settings: settings,
            tools: tools
        )
        self._manager = StateObject(wrappedValue: aiManager)
    }
}

// MARK: - AI Manager

/// Observable object that manages AI conversations in SwiftUI
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@MainActor
public class AIManager: ObservableObject {
    @Published public var messages: [ModelMessage] = []
    @Published public var isGenerating: Bool = false
    @Published public var error: TachikomaError?
    @Published public var lastResult: GenerateTextResult?
    @Published public var streamingText: String = ""
    
    public let model: LanguageModel
    public let system: String?
    public let settings: GenerationSettings
    public let tools: [SimpleTool]
    
    private var streamingTask: Task<Void, Never>?
    
    public init(
        model: LanguageModel = .default,
        system: String? = nil,
        settings: GenerationSettings = .default,
        tools: [SimpleTool] = []
    ) {
        self.model = model
        self.system = system
        self.settings = settings
        self.tools = tools
        
        if let system = system {
            self.messages = [.system(system)]
        }
    }
    
    // MARK: - Conversation Management
    
    public func send(_ message: String) async {
        guard !isGenerating else { return }
        
        let userMessage = ModelMessage.user(message)
        messages.append(userMessage)
        
        await generate()
    }
    
    public func send(text: String, images: [ModelMessage.ContentPart.ImageContent]) async {
        guard !isGenerating else { return }
        
        let userMessage = ModelMessage.user(text: text, images: images)
        messages.append(userMessage)
        
        await generate()
    }
    
    public func generate() async {
        guard !isGenerating else { return }
        
        isGenerating = true
        error = nil
        lastResult = nil
        
        do {
            let result = try await generateText(
                model: model,
                messages: messages,
                tools: tools.isEmpty ? nil : tools,
                settings: settings,
                maxSteps: 5
            )
            
            lastResult = result
            messages.append(.assistant(result.text))
            
        } catch let tachikomaError as TachikomaError {
            error = tachikomaError
        } catch {
            self.error = .apiError(error.localizedDescription)
        }
        
        isGenerating = false
    }
    
    public func stream() async {
        guard !isGenerating else { return }
        
        isGenerating = true
        error = nil
        streamingText = ""
        
        streamingTask = Task {
            do {
                let result = try await streamText(
                    model: model,
                    messages: messages,
                    tools: tools.isEmpty ? nil : tools,
                    settings: settings,
                    maxSteps: 1
                )
                
                var fullText = ""
                for try await delta in result.textStream {
                    if !Task.isCancelled {
                        switch delta.type {
                        case .textDelta:
                            if let content = delta.content {
                                fullText += content
                                await MainActor.run {
                                    streamingText = fullText
                                }
                            }
                        case .done:
                            await MainActor.run {
                                messages.append(.assistant(fullText))
                                streamingText = ""
                            }
                        case .error:
                            if let content = delta.content {
                                await MainActor.run {
                                    error = .apiError(content)
                                }
                            }
                        default:
                            break
                        }
                    }
                }
                
            } catch let tachikomaError as TachikomaError {
                await MainActor.run {
                    error = tachikomaError
                }
            } catch {
                await MainActor.run {
                    self.error = .apiError(error.localizedDescription)
                }
            }
            
            await MainActor.run {
                isGenerating = false
            }
        }
    }
    
    public func clear() {
        messages.removeAll()
        if let system = system {
            messages.append(.system(system))
        }
        error = nil
        lastResult = nil
        streamingText = ""
        streamingTask?.cancel()
    }
    
    public func cancelGeneration() {
        streamingTask?.cancel()
        isGenerating = false
    }
    
    // MARK: - Convenience Properties
    
    public var userMessages: [ModelMessage] {
        messages.filter { $0.role == .user }
    }
    
    public var assistantMessages: [ModelMessage] {
        messages.filter { $0.role == .assistant }
    }
    
    public var conversationMessages: [ModelMessage] {
        messages.filter { $0.role == .user || $0.role == .assistant }
    }
    
    public var hasMessages: Bool {
        !conversationMessages.isEmpty
    }
    
    public var canGenerate: Bool {
        !isGenerating && hasMessages
    }
}

// MARK: - SwiftUI View Extensions

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension View {
    
    /// Configure AI model for child views
    public func aiModel(_ model: LanguageModel) -> some View {
        environment(\.aiModel, model)
    }
    
    /// Configure AI settings for child views
    public func aiSettings(_ settings: GenerationSettings) -> some View {
        environment(\.aiSettings, settings)
    }
    
    /// Configure AI tools for child views
    public func aiTools(_ tools: [SimpleTool]) -> some View {
        environment(\.aiTools, tools)
    }
}

// MARK: - Environment Values

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension EnvironmentValues {
    public var aiModel: LanguageModel {
        get { self[AIModelKey.self] }
        set { self[AIModelKey.self] = newValue }
    }
    
    public var aiSettings: GenerationSettings {
        get { self[AISettingsKey.self] }
        set { self[AISettingsKey.self] = newValue }
    }
    
    public var aiTools: [SimpleTool] {
        get { self[AIToolsKey.self] }
        set { self[AIToolsKey.self] = newValue }
    }
}

private struct AIModelKey: EnvironmentKey {
    static let defaultValue: LanguageModel = .default
}

private struct AISettingsKey: EnvironmentKey {
    static let defaultValue: GenerationSettings = .default
}

private struct AIToolsKey: EnvironmentKey {
    static let defaultValue: [SimpleTool] = []
}

// MARK: - Convenience Views

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ChatView: View {
    @AI private var ai
    @State private var inputText: String = ""
    
    public init(
        model: LanguageModel = .default,
        system: String? = nil,
        settings: GenerationSettings = .default,
        tools: [SimpleTool] = []
    ) {
        self._ai = AI(
            model: model,
            system: system,
            settings: settings,
            tools: tools
        )
    }
    
    public var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(ai.conversationMessages, id: \.id) { message in
                        MessageBubble(message: message)
                    }
                    
                    if ai.isGenerating && !ai.streamingText.isEmpty {
                        MessageBubble(
                            message: .assistant(ai.streamingText),
                            isStreaming: true
                        )
                    }
                }
                .padding()
            }
            
            HStack {
                TextField("Type a message...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        sendMessage()
                    }
                
                Button("Send") {
                    sendMessage()
                }
                .disabled(inputText.isEmpty || ai.isGenerating)
            }
            .padding()
        }
        .alert("Error", isPresented: .constant(ai.error != nil)) {
            Button("OK") {
                ai.error = nil
            }
        } message: {
            Text(ai.error?.localizedDescription ?? "Unknown error")
        }
    }
    
    private func sendMessage() {
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        inputText = ""
        
        Task {
            await ai.send(message)
        }
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct MessageBubble: View {
    let message: ModelMessage
    let isStreaming: Bool
    
    public init(message: ModelMessage, isStreaming: Bool = false) {
        self.message = message
        self.isStreaming = isStreaming
    }
    
    public var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contentText)
                    .padding(12)
                    .background(
                        message.role == .user ? Color.blue : Color.gray.opacity(0.2)
                    )
                    .foregroundColor(
                        message.role == .user ? .white : .primary
                    )
                    .cornerRadius(16)
                
                if isStreaming {
                    HStack {
                        Text("•")
                            .foregroundColor(.secondary)
                            .animation(.easeInOut(duration: 0.6).repeatForever(), value: isStreaming)
                        Text("AI is typing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
    
    private var contentText: String {
        // Extract text from content parts
        return message.content
            .compactMap { part in
                if case .text(let text) = part {
                    return text
                }
                return nil
            }
            .joined(separator: "\n")
    }
}

// MARK: - Example Usage

/*
 Usage examples:
 
 // Simple chat interface
 struct ContentView: View {
     var body: some View {
         ChatView(
             model: .anthropic(.opus4),
             system: "You are a helpful assistant.",
             tools: [try! CommonTools.calculator()]
         )
     }
 }
 
 // Custom AI integration
 struct CustomView: View {
     @AI private var ai = AI(
         model: .openai(.gpt4o),
         system: "You are a creative writer."
     )
     
     var body: some View {
         VStack {
             Button("Generate Story") {
                 Task {
                     await ai.send("Write a short story about a robot.")
                 }
             }
             .disabled(ai.isGenerating)
             
             if let result = ai.lastResult {
                 Text(result.text)
                     .padding()
             }
         }
     }
 }
 */