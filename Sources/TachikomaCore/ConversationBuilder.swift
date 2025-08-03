import Foundation

// MARK: - Conversation Builder

/// Fluent API for building conversations with AI models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public class ConversationBuilder {
    private var messages: [ModelMessage] = []
    private var tools: [Tool] = []
    private var settings: GenerationSettings = .default
    private var maxSteps: Int = 1
    
    public init() {}
    
    // MARK: - Message Building
    
    @discardableResult
    public func system(_ text: String) -> ConversationBuilder {
        messages.append(.system(text))
        return self
    }
    
    @discardableResult
    public func user(_ text: String) -> ConversationBuilder {
        messages.append(.user(text))
        return self
    }
    
    @discardableResult
    public func user(text: String, images: [ModelMessage.ContentPart.ImageContent]) -> ConversationBuilder {
        messages.append(.user(text: text, images: images))
        return self
    }
    
    @discardableResult
    public func assistant(_ text: String) -> ConversationBuilder {
        messages.append(.assistant(text))
        return self
    }
    
    @discardableResult
    public func message(_ message: ModelMessage) -> ConversationBuilder {
        messages.append(message)
        return self
    }
    
    @discardableResult
    public func messages(_ newMessages: [ModelMessage]) -> ConversationBuilder {
        messages.append(contentsOf: newMessages)
        return self
    }
    
    // MARK: - Tool Configuration
    
    @discardableResult
    public func tool(_ tool: Tool) -> ConversationBuilder {
        tools.append(tool)
        return self
    }
    
    @discardableResult
    public func tools(_ newTools: [Tool]) -> ConversationBuilder {
        tools.append(contentsOf: newTools)
        return self
    }
    
    @discardableResult
    public func commonTools() -> ConversationBuilder {
        do {
            tools.append(try CommonTools.calculator())
            tools.append(try CommonTools.getCurrentDateTime())
        } catch {
            // Silently fail for common tools - they're optional
        }
        return self
    }
    
    // MARK: - Generation Settings
    
    @discardableResult
    public func temperature(_ temperature: Double) -> ConversationBuilder {
        settings = GenerationSettings(
            maxTokens: settings.maxTokens,
            temperature: temperature,
            topP: settings.topP,
            topK: settings.topK,
            frequencyPenalty: settings.frequencyPenalty,
            presencePenalty: settings.presencePenalty,
            stopSequences: settings.stopSequences
        )
        return self
    }
    
    @discardableResult
    public func maxTokens(_ maxTokens: Int) -> ConversationBuilder {
        settings = GenerationSettings(
            maxTokens: maxTokens,
            temperature: settings.temperature,
            topP: settings.topP,
            topK: settings.topK,
            frequencyPenalty: settings.frequencyPenalty,
            presencePenalty: settings.presencePenalty,
            stopSequences: settings.stopSequences
        )
        return self
    }
    
    @discardableResult
    public func topP(_ topP: Double) -> ConversationBuilder {
        settings = GenerationSettings(
            maxTokens: settings.maxTokens,
            temperature: settings.temperature,
            topP: topP,
            topK: settings.topK,
            frequencyPenalty: settings.frequencyPenalty,
            presencePenalty: settings.presencePenalty,
            stopSequences: settings.stopSequences
        )
        return self
    }
    
    @discardableResult
    public func topK(_ topK: Int) -> ConversationBuilder {
        settings = GenerationSettings(
            maxTokens: settings.maxTokens,
            temperature: settings.temperature,
            topP: settings.topP,
            topK: topK,
            frequencyPenalty: settings.frequencyPenalty,
            presencePenalty: settings.presencePenalty,
            stopSequences: settings.stopSequences
        )
        return self
    }
    
    @discardableResult
    public func frequencyPenalty(_ penalty: Double) -> ConversationBuilder {
        settings = GenerationSettings(
            maxTokens: settings.maxTokens,
            temperature: settings.temperature,
            topP: settings.topP,
            topK: settings.topK,
            frequencyPenalty: penalty,
            presencePenalty: settings.presencePenalty,
            stopSequences: settings.stopSequences
        )
        return self
    }
    
    @discardableResult
    public func presencePenalty(_ penalty: Double) -> ConversationBuilder {
        settings = GenerationSettings(
            maxTokens: settings.maxTokens,
            temperature: settings.temperature,
            topP: settings.topP,
            topK: settings.topK,
            frequencyPenalty: settings.frequencyPenalty,
            presencePenalty: penalty,
            stopSequences: settings.stopSequences
        )
        return self
    }
    
    @discardableResult
    public func stopSequences(_ sequences: [String]) -> ConversationBuilder {
        settings = GenerationSettings(
            maxTokens: settings.maxTokens,
            temperature: settings.temperature,
            topP: settings.topP,
            topK: settings.topK,
            frequencyPenalty: settings.frequencyPenalty,
            presencePenalty: settings.presencePenalty,
            stopSequences: sequences
        )
        return self
    }
    
    @discardableResult
    public func settings(_ newSettings: GenerationSettings) -> ConversationBuilder {
        settings = newSettings
        return self
    }
    
    // MARK: - Multi-step Configuration
    
    @discardableResult
    public func maxSteps(_ steps: Int) -> ConversationBuilder {
        maxSteps = steps
        return self
    }
    
    // MARK: - Generation Methods
    
    public func generateText(using model: LanguageModel = .default) async throws -> GenerateTextResult {
        return try await TachikomaCore.generateText(
            model: model,
            messages: messages,
            tools: tools.isEmpty ? nil : tools,
            settings: settings,
            maxSteps: maxSteps
        )
    }
    
    public func streamText(using model: LanguageModel = .default) async throws -> StreamTextResult {
        return try await TachikomaCore.streamText(
            model: model,
            messages: messages,
            tools: tools.isEmpty ? nil : tools,
            settings: settings,
            maxSteps: maxSteps
        )
    }
    
    public func generateObject<T: Codable>(
        _ type: T.Type,
        using model: LanguageModel = .default
    ) async throws -> GenerateObjectResult<T> {
        return try await TachikomaCore.generateObject(
            model: model,
            messages: messages,
            schema: type,
            settings: settings
        )
    }
    
    // MARK: - Convenience Methods
    
    public func generate(using model: LanguageModel = .default) async throws -> String {
        let result = try await generateText(using: model)
        return result.text
    }
    
    public func stream(using model: LanguageModel = .default) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        let result = try await streamText(using: model)
        return result.textStream
    }
    
    // MARK: - Build Methods
    
    public func build() -> ConversationContext {
        return ConversationContext(
            messages: messages,
            tools: tools,
            settings: settings,
            maxSteps: maxSteps
        )
    }
    
    public var builtMessages: [ModelMessage] {
        return messages
    }
    
    public var builtTools: [Tool] {
        return tools
    }
    
    public var builtSettings: GenerationSettings {
        return settings
    }
}

// MARK: - Conversation Context

/// Immutable conversation context built from ConversationBuilder
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ConversationContext: Sendable {
    public let messages: [ModelMessage]
    public let tools: [Tool]
    public let settings: GenerationSettings
    public let maxSteps: Int
    
    public init(
        messages: [ModelMessage],
        tools: [Tool] = [],
        settings: GenerationSettings = .default,
        maxSteps: Int = 1
    ) {
        self.messages = messages
        self.tools = tools
        self.settings = settings
        self.maxSteps = maxSteps
    }
    
    public func generateText(using model: LanguageModel = .default) async throws -> GenerateTextResult {
        return try await TachikomaCore.generateText(
            model: model,
            messages: messages,
            tools: tools.isEmpty ? nil : tools,
            settings: settings,
            maxSteps: maxSteps
        )
    }
    
    public func streamText(using model: LanguageModel = .default) async throws -> StreamTextResult {
        return try await TachikomaCore.streamText(
            model: model,
            messages: messages,
            tools: tools.isEmpty ? nil : tools,
            settings: settings,
            maxSteps: maxSteps
        )
    }
    
    public func generateObject<T: Codable>(
        _ type: T.Type,
        using model: LanguageModel = .default
    ) async throws -> GenerateObjectResult<T> {
        return try await TachikomaCore.generateObject(
            model: model,
            messages: messages,
            schema: type,
            settings: settings
        )
    }
}

// MARK: - Namespace for Global Functions

/// Main namespace for Tachikoma AI SDK functions
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum Tachikoma {
    
    /// Start building a conversation
    public static func conversation() -> ConversationBuilder {
        return ConversationBuilder()
    }
    
    /// Quick conversation from prompt
    public static func conversation(_ prompt: String) -> ConversationBuilder {
        return ConversationBuilder().user(prompt)
    }
    
    /// Quick conversation with system message
    public static func conversation(system: String, user: String) -> ConversationBuilder {
        return ConversationBuilder()
            .system(system)
            .user(user)
    }
    
    /// Direct access to generation functions (forward to global functions)
    public static func generateText(
        model: LanguageModel,
        messages: [ModelMessage],
        tools: [Tool]? = nil,
        settings: GenerationSettings = .default,
        maxSteps: Int = 1
    ) async throws -> GenerateTextResult {
        return try await TachikomaCore.generateText(
            model: model,
            messages: messages,
            tools: tools,
            settings: settings,
            maxSteps: maxSteps
        )
    }
    
    public static func streamText(
        model: LanguageModel,
        messages: [ModelMessage],
        tools: [Tool]? = nil,
        settings: GenerationSettings = .default,
        maxSteps: Int = 1
    ) async throws -> StreamTextResult {
        return try await TachikomaCore.streamText(
            model: model,
            messages: messages,
            tools: tools,
            settings: settings,
            maxSteps: maxSteps
        )
    }
    
    public static func generateObject<T: Codable>(
        model: LanguageModel,
        messages: [ModelMessage],
        schema: T.Type,
        settings: GenerationSettings = .default
    ) async throws -> GenerateObjectResult<T> {
        return try await TachikomaCore.generateObject(
            model: model,
            messages: messages,
            schema: schema,
            settings: settings
        )
    }
    
    /// Convenience functions (forward to global functions)
    public static func generate(
        _ prompt: String,
        using model: LanguageModel = .default,
        system: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) async throws -> String {
        return try await TachikomaCore.generate(
            prompt,
            using: model,
            system: system,
            maxTokens: maxTokens,
            temperature: temperature
        )
    }
    
    public static func stream(
        _ prompt: String,
        using model: LanguageModel = .default,
        system: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        return try await TachikomaCore.stream(
            prompt,
            using: model,
            system: system,
            maxTokens: maxTokens,
            temperature: temperature
        )
    }
}

// MARK: - Example Usage Extensions

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension ConversationBuilder {
    
    /// Add a few-shot example to the conversation
    @discardableResult
    public func example(user: String, assistant: String) -> ConversationBuilder {
        return self
            .user(user)
            .assistant(assistant)
    }
    
    /// Add multiple few-shot examples
    @discardableResult
    public func examples(_ examples: [(user: String, assistant: String)]) -> ConversationBuilder {
        for example in examples {
            _ = self.example(user: example.user, assistant: example.assistant)
        }
        return self
    }
    
    /// Configure for creative writing (high temperature, tools disabled)
    @discardableResult
    public func creative() -> ConversationBuilder {
        return self
            .temperature(0.9)
            .topP(0.95)
    }
    
    /// Configure for analytical tasks (low temperature, tools enabled)
    @discardableResult
    public func analytical() -> ConversationBuilder {
        return self
            .temperature(0.1)
            .topP(0.95)
            .commonTools()
    }
    
    /// Configure for coding tasks
    @discardableResult
    public func coding() -> ConversationBuilder {
        return self
            .temperature(0.2)
            .maxTokens(8192)
    }
}