import Foundation

// MARK: - AI SDK Core Functions (Following Vercel AI SDK Patterns)

/// Generate text using AI models following the Vercel AI SDK generateText pattern
///
/// This function provides a clean, type-safe API for text generation with support for
/// tools, multi-step execution, and rich result types.
///
/// - Parameters:
///   - model: The language model to use
///   - messages: Array of conversation messages
///   - tools: Optional tools the model can call
///   - settings: Generation settings (temperature, maxTokens, etc.)
///   - maxSteps: Maximum number of tool calling steps (default: 1)
/// - Returns: Complete generation result with text, usage, and execution steps
/// - Throws: TachikomaError for any failures
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func generateText(
    model: LanguageModel,
    messages: [ModelMessage],
    tools: [AgentTool]? = nil,
    settings: GenerationSettings = .default,
    maxSteps: Int = 1,
    configuration: TachikomaConfiguration = .current
) async throws
-> GenerateTextResult {
    let provider = try ProviderFactory.createProvider(for: model, configuration: configuration)

    var currentMessages = messages
    var allSteps: [GenerationStep] = []
    var totalUsage = Usage(inputTokens: 0, outputTokens: 0)

    for stepIndex in 0..<maxSteps {
        let request = ProviderRequest(
            messages: currentMessages,
            tools: tools,
            settings: settings
        )

        let response = try await provider.generateText(request: request)

        // Track usage if we have a current session
        if let usage = response.usage {
            // For now, create a temporary session for tracking
            // In a full implementation, this would use an existing session context
            let sessionId = "generation-\(UUID().uuidString)"
            _ = UsageTracker.shared.startSession(sessionId)

            let operationType: OperationType = tools?.isEmpty == false ? .toolCall : .textGeneration
            UsageTracker.shared.recordUsage(
                sessionId: sessionId,
                model: model,
                usage: usage,
                operation: operationType
            )
            _ = UsageTracker.shared.endSession(sessionId)
        }

        // Update total usage
        if let usage = response.usage {
            totalUsage = Usage(
                inputTokens: totalUsage.inputTokens + usage.inputTokens,
                outputTokens: totalUsage.outputTokens + usage.outputTokens,
                cost: usage.cost // Could combine costs here
            )
        }

        // Create step record
        let step = GenerationStep(
            stepIndex: stepIndex,
            text: response.text,
            toolCalls: response.toolCalls ?? [],
            toolResults: [],
            usage: response.usage,
            finishReason: response.finishReason
        )

        allSteps.append(step)

        // Add assistant message
        var assistantContent: [ModelMessage.ContentPart] = [.text(response.text)]

        // Handle tool calls
        if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
            // Add tool calls to assistant message
            assistantContent.append(contentsOf: toolCalls.map { .toolCall($0) })
            currentMessages.append(ModelMessage(role: .assistant, content: assistantContent))

            // Execute tools
            var toolResults: [AgentToolResult] = []
            for toolCall in toolCalls {
                if let tool = tools?.first(where: { $0.name == toolCall.name }) {
                    do {
                        // Debug: Log tool call details in verbose mode
                        if
                            ProcessInfo.processInfo.arguments.contains("--verbose") ||
                                ProcessInfo.processInfo.arguments.contains("-v")
                        {
                            print(
                                "DEBUG Generation.swift: Executing tool '\(toolCall.name)' with \(toolCall.arguments.count) arguments:"
                            )
                            for (key, value) in toolCall.arguments {
                                print("DEBUG   \(key): \(value)")
                            }
                        }

                        let result = try await tool.execute(AgentToolArguments(toolCall.arguments))
                        let toolResult = AgentToolResult.success(toolCallId: toolCall.id, result: result)
                        toolResults.append(toolResult)

                        // Add tool result message
                        currentMessages.append(ModelMessage(
                            role: .tool,
                            content: [.toolResult(toolResult)]
                        ))
                    } catch {
                        let errorResult = AgentToolResult.error(toolCallId: toolCall.id, error: error.localizedDescription)
                        toolResults.append(errorResult)

                        currentMessages.append(ModelMessage(
                            role: .tool,
                            content: [.toolResult(errorResult)]
                        ))
                    }
                }
            }

            // Update step with tool results
            allSteps[stepIndex] = GenerationStep(
                stepIndex: stepIndex,
                text: response.text,
                toolCalls: toolCalls,
                toolResults: toolResults,
                usage: response.usage,
                finishReason: response.finishReason
            )

            // Continue to next step if not done
            if response.finishReason != .toolCalls, response.finishReason != .stop {
                break
            }
        } else {
            // No tool calls, we're done
            currentMessages.append(ModelMessage(role: .assistant, content: assistantContent))
            break
        }
    }

    // Extract final text from last step
    let finalText = allSteps.last?.text ?? ""
    let finalFinishReason = allSteps.last?.finishReason ?? .other

    return GenerateTextResult(
        text: finalText,
        usage: totalUsage,
        finishReason: finalFinishReason,
        steps: allSteps,
        messages: currentMessages
    )
}

/// Stream text generation following the Vercel AI SDK streamText pattern
///
/// Provides real-time streaming of AI responses with support for tool calling
/// and multi-step execution within the stream.
///
/// - Parameters:
///   - model: The language model to use
///   - messages: Array of conversation messages
///   - tools: Optional tools the model can call
///   - settings: Generation settings (temperature, maxTokens, etc.)
///   - maxSteps: Maximum number of tool calling steps (default: 1)
/// - Returns: StreamTextResult with async sequence and metadata
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func streamText(
    model: LanguageModel,
    messages: [ModelMessage],
    tools: [AgentTool]? = nil,
    settings: GenerationSettings = .default,
    maxSteps: Int = 1,
    configuration: TachikomaConfiguration = .current
) async throws
-> StreamTextResult {
    let provider = try ProviderFactory.createProvider(for: model, configuration: configuration)

    let request = ProviderRequest(
        messages: messages,
        tools: tools,
        settings: settings
    )

    let stream = try await provider.streamText(request: request)

    // Create a session for tracking streaming usage
    let sessionId = "streaming-\(UUID().uuidString)"
    _ = UsageTracker.shared.startSession(sessionId)

    // Wrap the stream to track usage when it completes
    let trackedStream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
        Task {
            do {
                let totalInputTokens = 0
                var totalOutputTokens = 0

                for try await delta in stream {
                    continuation.yield(delta)

                    // Track tokens as they come in (approximate)
                    if case .textDelta = delta.type, let content = delta.content {
                        // Rough approximation: ~4 characters per token
                        totalOutputTokens += max(1, content.count / 4)
                    }

                    if case .done = delta.type {
                        // Record final usage (this is approximate for streaming)
                        let usage = Usage(
                            inputTokens: totalInputTokens,
                            outputTokens: totalOutputTokens
                        )

                        UsageTracker.shared.recordUsage(
                            sessionId: sessionId,
                            model: model,
                            usage: usage,
                            operation: .textStreaming
                        )
                        _ = UsageTracker.shared.endSession(sessionId)
                    }
                }

                continuation.finish()
            } catch {
                _ = UsageTracker.shared.endSession(sessionId)
                continuation.finish(throwing: error)
            }
        }
    }

    return StreamTextResult(
        stream: trackedStream,
        model: model,
        settings: settings
    )
}

/// Generate structured objects using AI following the generateObject pattern
///
/// This function constrains the AI output to a specific schema, ensuring type-safe
/// structured data generation.
///
/// - Parameters:
///   - model: The language model to use
///   - messages: Array of conversation messages
///   - schema: The expected output schema (Codable type)
///   - settings: Generation settings
/// - Returns: GenerateObjectResult with parsed object
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func generateObject<T: Codable & Sendable>(
    model: LanguageModel,
    messages: [ModelMessage],
    schema: T.Type,
    settings: GenerationSettings = .default,
    configuration: TachikomaConfiguration = .current
) async throws
-> GenerateObjectResult<T> {
    let provider = try ProviderFactory.createProvider(for: model, configuration: configuration)

    let request = ProviderRequest(
        messages: messages,
        tools: nil,
        settings: settings,
        outputFormat: .json
    )

    let response = try await provider.generateText(request: request)

    // Parse the JSON response into the expected type
    guard let jsonData = response.text.data(using: .utf8) else {
        throw TachikomaError.invalidInput("Response text is not valid UTF-8")
    }

    do {
        let object = try JSONDecoder().decode(T.self, from: jsonData)
        return GenerateObjectResult(
            object: object,
            usage: response.usage,
            finishReason: response.finishReason ?? .other,
            rawText: response.text
        )
    } catch {
        throw TachikomaError.invalidInput("Failed to parse response as \(T.self): \(error.localizedDescription)")
    }
}

/// Stream structured objects using AI following the streamObject pattern
///
/// This function streams partial object updates as the AI generates structured data,
/// allowing for real-time UI updates and progressive rendering.
///
/// - Parameters:
///   - model: The language model to use
///   - messages: Array of conversation messages
///   - schema: The expected output schema (Codable type)
///   - settings: Generation settings
///   - configuration: Tachikoma configuration
/// - Returns: StreamObjectResult with partial object stream
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func streamObject<T: Codable & Sendable>(
    model: LanguageModel,
    messages: [ModelMessage],
    schema: T.Type,
    settings: GenerationSettings = .default,
    configuration: TachikomaConfiguration = .current
) async throws
-> StreamObjectResult<T> {
    let provider = try ProviderFactory.createProvider(for: model, configuration: configuration)
    
    // Create request with JSON output format
    let request = ProviderRequest(
        messages: messages,
        tools: nil,
        settings: settings,
        outputFormat: .json
    )
    
    // Get the text stream from the provider
    let stream = try await provider.streamText(request: request)
    
    // Create a new stream that attempts to parse partial JSON objects
    let objectStream = AsyncThrowingStream<ObjectStreamDelta<T>, Error> { continuation in
        Task {
            do {
                var accumulatedText = ""
                var lastValidObject: T?
                var hasStarted = false
                
                for try await delta in stream {
                    if case .textDelta = delta.type, let content = delta.content {
                        accumulatedText += content
                        
                        // Signal stream start
                        if !hasStarted {
                            hasStarted = true
                            continuation.yield(ObjectStreamDelta(type: .start))
                        }
                        
                        // Attempt to parse the accumulated JSON
                        if let jsonData = accumulatedText.data(using: .utf8) {
                            // Try to parse as complete object
                            if let object = try? JSONDecoder().decode(T.self, from: jsonData) {
                                lastValidObject = object
                                continuation.yield(ObjectStreamDelta(
                                    type: .partial,
                                    object: object,
                                    rawText: accumulatedText
                                ))
                            } else if let partialObject = attemptPartialParse(T.self, from: accumulatedText) {
                                // Attempt to parse as partial object
                                lastValidObject = partialObject
                                continuation.yield(ObjectStreamDelta(
                                    type: .partial,
                                    object: partialObject,
                                    rawText: accumulatedText
                                ))
                            }
                        }
                    } else if case .done = delta.type {
                        // Final parse attempt
                        if let jsonData = accumulatedText.data(using: .utf8),
                           let finalObject = try? JSONDecoder().decode(T.self, from: jsonData) {
                            continuation.yield(ObjectStreamDelta(
                                type: .complete,
                                object: finalObject,
                                rawText: accumulatedText
                            ))
                        } else if let lastValidObject {
                            // If we have a last valid object, use it as complete
                            continuation.yield(ObjectStreamDelta(
                                type: .complete,
                                object: lastValidObject,
                                rawText: accumulatedText
                            ))
                        } else {
                            throw TachikomaError.invalidInput(
                                "Failed to parse complete object from stream"
                            )
                        }
                        continuation.yield(ObjectStreamDelta(type: .done))
                    }
                }
                
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
    
    return StreamObjectResult(
        objectStream: objectStream,
        model: model,
        settings: settings,
        schema: schema
    )
}

/// Attempt to parse a partial JSON object by fixing common issues
private func attemptPartialParse<T: Codable>(_ type: T.Type, from json: String) -> T? {
    // Try various strategies to parse partial JSON
    let strategies = [
        json,                                    // Original
        json + "}",                             // Missing closing brace
        json + "\"}",                           // Missing quote and brace
        json + "]",                             // Missing closing bracket
        json + "]}",                            // Missing bracket and brace
        fixPartialJSON(json)                    // Custom fix attempt
    ]
    
    for strategy in strategies {
        if let data = strategy.data(using: .utf8),
           let object = try? JSONDecoder().decode(T.self, from: data) {
            return object
        }
    }
    
    return nil
}

/// Fix common issues in partial JSON
private func fixPartialJSON(_ json: String) -> String {
    var fixed = json.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Count brackets and braces
    let openBraces = fixed.filter { $0 == "{" }.count
    let closeBraces = fixed.filter { $0 == "}" }.count
    let openBrackets = fixed.filter { $0 == "[" }.count
    let closeBrackets = fixed.filter { $0 == "]" }.count
    
    // Add missing closing characters
    if openBrackets > closeBrackets {
        fixed += String(repeating: "]", count: openBrackets - closeBrackets)
    }
    if openBraces > closeBraces {
        fixed += String(repeating: "}", count: openBraces - closeBraces)
    }
    
    // Fix trailing comma
    if fixed.hasSuffix(",") {
        fixed.removeLast()
    }
    
    // Ensure quotes are balanced for the last property
    if let lastQuoteIndex = fixed.lastIndex(of: "\"") {
        let afterQuote = String(fixed[fixed.index(after: lastQuoteIndex)...])
        if afterQuote.contains(":") && !afterQuote.contains("\"") {
            // Likely missing closing quote for string value
            fixed += "\""
        }
    }
    
    return fixed
}

// MARK: - Convenience Functions

/// Simple text generation from a prompt (convenience wrapper) - with Model enum
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func generate(
    _ prompt: String,
    using model: Model? = nil,
    system: String? = nil,
    tools: [AgentTool]? = nil
) async throws
-> String {
    // For now, just return a mock response since we don't have provider implementations
    "Mock response for prompt: \(prompt)"
}

/// Simple text generation from a prompt (convenience wrapper) - with LanguageModel enum
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func generate(
    _ prompt: String,
    using model: LanguageModel = .default,
    system: String? = nil,
    maxTokens: Int? = nil,
    temperature: Double? = nil,
    configuration: TachikomaConfiguration = .current
) async throws
-> String {
    var messages: [ModelMessage] = []

    if let system {
        messages.append(.system(system))
    }

    messages.append(.user(prompt))

    let settings = GenerationSettings(
        maxTokens: maxTokens,
        temperature: temperature
    )

    let result = try await generateText(
        model: model,
        messages: messages,
        settings: settings,
        configuration: configuration
    )

    return result.text
}

/// Analyze an image using an AI model
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func analyze(
    image: ImageInput,
    prompt: String,
    using model: Model? = nil,
    configuration: TachikomaConfiguration = .current
) async throws
-> String {
    // Determine the model to use
    let selectedModel: LanguageModel = if let model {
        model
    } else {
        // Use a vision-capable model by default
        .openai(.gpt4o)
    }

    // Ensure the model supports vision
    guard selectedModel.supportsVision else {
        throw TachikomaError.unsupportedOperation("Model \(selectedModel.description) does not support vision")
    }

    // Convert ImageInput to base64 string
    let base64Data: String
    let mimeType: String

    switch image {
    case let .base64(data):
        base64Data = data
        mimeType = "image/png" // Default assumption
    case .url:
        throw TachikomaError.unsupportedOperation("URL-based images not yet supported")
    case let .filePath(path):
        let url = URL(fileURLWithPath: path)
        let imageData = try Data(contentsOf: url)
        base64Data = imageData.base64EncodedString()

        // Determine MIME type from file extension
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "png":
            mimeType = "image/png"
        case "jpg", "jpeg":
            mimeType = "image/jpeg"
        case "gif":
            mimeType = "image/gif"
        case "webp":
            mimeType = "image/webp"
        default:
            mimeType = "image/png" // Default fallback
        }
    }

    // Create image content
    let imageContent = ModelMessage.ContentPart.ImageContent(data: base64Data, mimeType: mimeType)

    // Create messages with both text and image
    let messages = [
        ModelMessage.user(text: prompt, images: [imageContent]),
    ]

    // Generate text using the multimodal capabilities
    let result = try await generateText(
        model: selectedModel,
        messages: messages,
        settings: .default,
        configuration: configuration
    )

    // Additional tracking for image analysis (the generateText call above already tracks usage)
    // This could be enhanced to track image-specific metrics
    if let usage = result.usage {
        let sessionId = "image-analysis-\(UUID().uuidString)"
        _ = UsageTracker.shared.startSession(sessionId)
        UsageTracker.shared.recordUsage(
            sessionId: sessionId,
            model: selectedModel,
            usage: usage,
            operation: .imageAnalysis
        )
        _ = UsageTracker.shared.endSession(sessionId)
    }

    return result.text
}

/// Simple streaming from a prompt (convenience wrapper)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func stream(
    _ prompt: String,
    using model: LanguageModel = .default,
    system: String? = nil,
    maxTokens: Int? = nil,
    temperature: Double? = nil,
    configuration: TachikomaConfiguration = .current
) async throws
-> AsyncThrowingStream<TextStreamDelta, Error> {
    var messages: [ModelMessage] = []

    if let system {
        messages.append(.system(system))
    }

    messages.append(.user(prompt))

    let settings = GenerationSettings(
        maxTokens: maxTokens,
        temperature: temperature
    )

    let result = try await streamText(
        model: model,
        messages: messages,
        settings: settings,
        configuration: configuration
    )

    return result.textStream
}

// MARK: - Result Types

/// Result from generateText function
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct GenerateTextResult: Sendable {
    public let text: String
    public let usage: Usage?
    public let finishReason: FinishReason
    public let steps: [GenerationStep]
    public let messages: [ModelMessage]

    public init(
        text: String,
        usage: Usage?,
        finishReason: FinishReason,
        steps: [GenerationStep],
        messages: [ModelMessage]
    ) {
        self.text = text
        self.usage = usage
        self.finishReason = finishReason
        self.steps = steps
        self.messages = messages
    }
}

/// Result from streamText function
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct StreamTextResult: Sendable {
    public let textStream: AsyncThrowingStream<TextStreamDelta, Error>
    public let model: LanguageModel
    public let settings: GenerationSettings

    public init(
        stream: AsyncThrowingStream<TextStreamDelta, Error>,
        model: LanguageModel,
        settings: GenerationSettings
    ) {
        self.textStream = stream
        self.model = model
        self.settings = settings
    }
}

// MARK: - AsyncSequence Conformance
extension StreamTextResult: AsyncSequence {
    public typealias Element = TextStreamDelta
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: AsyncThrowingStream<TextStreamDelta, Error>.AsyncIterator
        
        public mutating func next() async throws -> TextStreamDelta? {
            try await iterator.next()
        }
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: textStream.makeAsyncIterator())
    }
}

/// Result from generateObject function
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct GenerateObjectResult<T: Codable & Sendable>: Sendable {
    public let object: T
    public let usage: Usage?
    public let finishReason: FinishReason
    public let rawText: String

    public init(object: T, usage: Usage?, finishReason: FinishReason, rawText: String) {
        self.object = object
        self.usage = usage
        self.finishReason = finishReason
        self.rawText = rawText
    }
}

/// Result type for streaming object generation with partial updates
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct StreamObjectResult<T: Codable & Sendable>: Sendable {
    public let objectStream: AsyncThrowingStream<ObjectStreamDelta<T>, Error>
    public let model: LanguageModel
    public let settings: GenerationSettings
    public let schema: T.Type
    
    public init(
        objectStream: AsyncThrowingStream<ObjectStreamDelta<T>, Error>,
        model: LanguageModel,
        settings: GenerationSettings,
        schema: T.Type
    ) {
        self.objectStream = objectStream
        self.model = model
        self.settings = settings
        self.schema = schema
    }
}

// MARK: - AsyncSequence Conformance for StreamObjectResult
extension StreamObjectResult: AsyncSequence {
    public typealias Element = ObjectStreamDelta<T>
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: AsyncThrowingStream<ObjectStreamDelta<T>, Error>.AsyncIterator
        
        public mutating func next() async throws -> ObjectStreamDelta<T>? {
            try await iterator.next()
        }
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: objectStream.makeAsyncIterator())
    }
}

/// A delta in streaming object generation
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ObjectStreamDelta<T: Codable & Sendable>: Sendable {
    public let type: DeltaType
    public let object: T?
    public let rawText: String?
    public let error: Error?
    
    public enum DeltaType: Sendable, Equatable {
        case start          // Stream has started
        case partial        // Partial object update
        case complete       // Complete object received
        case done          // Stream has finished
        case error         // An error occurred
    }
    
    public init(
        type: DeltaType,
        object: T? = nil,
        rawText: String? = nil,
        error: Error? = nil
    ) {
        self.type = type
        self.object = object
        self.rawText = rawText
        self.error = error
    }
}

/// A single step in multi-step generation
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct GenerationStep: Sendable {
    public let stepIndex: Int
    public let text: String
    public let toolCalls: [AgentToolCall]
    public let toolResults: [AgentToolResult]
    public let usage: Usage?
    public let finishReason: FinishReason?

    public init(
        stepIndex: Int,
        text: String,
        toolCalls: [AgentToolCall],
        toolResults: [AgentToolResult],
        usage: Usage?,
        finishReason: FinishReason?
    ) {
        self.stepIndex = stepIndex
        self.text = text
        self.toolCalls = toolCalls
        self.toolResults = toolResults
        self.usage = usage
        self.finishReason = finishReason
    }
}

/// A delta in streaming text generation
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct TextStreamDelta: Sendable {
    public let type: DeltaType
    public let content: String?
    public let channel: ResponseChannel?
    public let toolCall: AgentToolCall?
    public let toolResult: AgentToolResult?

    public enum DeltaType: Sendable, Equatable {
        case textDelta
        case channelStart(ResponseChannel)
        case channelEnd(ResponseChannel)
        case toolCallStart
        case toolCallDelta
        case toolCallEnd
        case toolResult
        case stepStart
        case stepEnd
        case done
        case error
    }

    public init(
        type: DeltaType,
        content: String? = nil,
        channel: ResponseChannel? = nil,
        toolCall: AgentToolCall? = nil,
        toolResult: AgentToolResult? = nil
    ) {
        self.type = type
        self.content = content
        self.channel = channel
        self.toolCall = toolCall
        self.toolResult = toolResult
    }
}
