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
@discardableResult
public func generateText(
    model: LanguageModel,
    messages: [ModelMessage],
    tools: [AgentTool]? = nil,
    settings: GenerationSettings = .default,
    maxSteps: Int = 1,
    timeout: TimeInterval? = nil,
    configuration: TachikomaConfiguration = .current,
    sessionId: String? = nil,
) async throws
    -> GenerateTextResult
{
    let resolvedConfiguration = TachikomaConfiguration.resolve(configuration)
    let provider = try resolvedConfiguration.makeProvider(for: model)

    var currentMessages = messages
    var allSteps: [GenerationStep] = []
    var totalUsage = Usage(inputTokens: 0, outputTokens: 0)

    for stepIndex in 0..<maxSteps {
        let request = ProviderRequest(
            messages: currentMessages,
            tools: tools,
            settings: settings,
        )

        let response: ProviderResponse = if let timeout {
            try await withTimeout(timeout) {
                try await provider.generateText(request: request)
            }
        } else {
            try await provider.generateText(request: request)
        }

        // Track usage with proper session management
        if let usage = response.usage {
            let actualSessionId = sessionId ?? "generation-\(UUID().uuidString)"

            // Start session if not already started
            if sessionId == nil {
                _ = UsageTracker.shared.startSession(actualSessionId)
            }

            let operationType: OperationType = tools?.isEmpty == false ? .toolCall : .textGeneration
            UsageTracker.shared.recordUsage(
                sessionId: actualSessionId,
                model: model,
                usage: usage,
                operation: operationType,
            )

            // Only end session if we created it
            if sessionId == nil {
                _ = UsageTracker.shared.endSession(actualSessionId)
            }
        }

        // Update total usage
        if let usage = response.usage {
            totalUsage = Usage(
                inputTokens: totalUsage.inputTokens + usage.inputTokens,
                outputTokens: totalUsage.outputTokens + usage.outputTokens,
                cost: usage.cost, // Could combine costs here
            )
        }

        // Create step record
        let step = GenerationStep(
            stepIndex: stepIndex,
            text: response.text,
            toolCalls: response.toolCalls ?? [],
            toolResults: [],
            usage: response.usage,
            finishReason: response.finishReason,
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
                                "DEBUG Generation.swift: Executing tool '\(toolCall.name)' with \(toolCall.arguments.count) arguments:",
                            )
                            for (key, value) in toolCall.arguments {
                                print("DEBUG   \(key): \(value)")
                            }
                        }

                        // Create execution context with full conversation and model info
                        let context = ToolExecutionContext(
                            messages: currentMessages,
                            model: model,
                            settings: settings,
                            sessionId: sessionId ?? "generation-\(UUID().uuidString)",
                            stepIndex: stepIndex,
                            metadata: ["toolCallId": toolCall.id],
                        )

                        // Convert arguments to AgentToolArguments
                        let toolArguments = AgentToolArguments(toolCall.arguments)
                        let result = try await tool.execute(toolArguments, context: context)
                        let toolResult = AgentToolResult.success(toolCallId: toolCall.id, result: result)
                        toolResults.append(toolResult)

                        // Add tool result message
                        currentMessages.append(ModelMessage(
                            role: .tool,
                            content: [.toolResult(toolResult)],
                        ))
                    } catch {
                        let errorResult = AgentToolResult.error(
                            toolCallId: toolCall.id,
                            error: error.localizedDescription,
                        )
                        toolResults.append(errorResult)

                        currentMessages.append(ModelMessage(
                            role: .tool,
                            content: [.toolResult(errorResult)],
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
                finishReason: response.finishReason,
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
    var finalText = allSteps.last?.text ?? ""
    var finalFinishReason = allSteps.last?.finishReason ?? .other

    // Apply stop conditions if configured
    if let stopCondition = settings.stopConditions {
        // Check if we should stop and truncate the text
        if await stopCondition.shouldStop(text: finalText, delta: nil) {
            // Truncate text based on the type of stop condition
            if let stringStop = stopCondition as? StringStopCondition {
                // For string stop conditions, truncate at the stop string
                if
                    let range = finalText.range(
                        of: stringStop.stopString,
                        options: stringStop.caseSensitive ? [] : .caseInsensitive,
                    )
                {
                    finalText = String(finalText[..<range.lowerBound])
                }
                finalFinishReason = .stop
            } else if
                stopCondition is TokenCountStopCondition ||
                stopCondition is TimeoutStopCondition
            {
                // For token/time limits, the text is already at the right length
                finalFinishReason = .length
            } else if let regexStop = stopCondition as? RegexStopCondition {
                // For regex conditions, truncate at the first match
                if let matchRange = regexStop.matchLocation(in: finalText) {
                    finalText = String(finalText[..<matchRange.lowerBound])
                }
                finalFinishReason = .stop
            } else {
                // For other conditions, just mark as stopped
                finalFinishReason = .stop
            }
        }
    }

    return GenerateTextResult(
        text: finalText,
        usage: totalUsage,
        finishReason: finalFinishReason,
        steps: allSteps,
        messages: currentMessages,
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
    maxSteps _: Int = 1,
    timeout: TimeInterval? = nil,
    configuration: TachikomaConfiguration = .current,
    sessionId: String? = nil,
) async throws
    -> StreamTextResult
{
    // Debug logging only when explicitly enabled via environment variable or verbose flag
    let resolvedConfiguration = TachikomaConfiguration.resolve(configuration)
    let debugEnabled = ProcessInfo.processInfo.environment["DEBUG_TACHIKOMA"] != nil ||
        resolvedConfiguration.verbose
    if debugEnabled {
        print("\n🔵 DEBUG streamText: Creating provider for model: \(model)")
        print("🔵 DEBUG streamText: Model details: \(model.description)")
        if case let .openai(openaiModel) = model {
            print("🔵 DEBUG streamText: OpenAI model enum case: \(openaiModel)")
            print("🔵 DEBUG streamText: OpenAI model modelId: \(openaiModel.modelId)")
        }
    }
    let provider = try resolvedConfiguration.makeProvider(for: model)
    if debugEnabled {
        print("🔵 DEBUG streamText: Provider created: \(type(of: provider))")
        print(
            "🔵 DEBUG streamText: Provider modelId: \((provider as? AnthropicProvider)?.modelId ?? (provider as? OpenAIProvider)?.modelId ?? (provider as? OpenAIResponsesProvider)?.modelId ?? "unknown")",
        )
    }

    let request = ProviderRequest(
        messages: messages,
        tools: tools,
        settings: settings,
    )

    var stream: AsyncThrowingStream<TextStreamDelta, Error>
    if let timeout {
        // Wrap stream with timeout for initial connection
        if debugEnabled {
            print("🔵 DEBUG streamText: Calling provider.streamText with timeout and \(request.tools?.count ?? 0) tools")
        }
        stream = try await withTimeout(timeout) {
            try await provider.streamText(request: request)
        }
    } else {
        if debugEnabled {
            print("🔵 DEBUG streamText: Calling provider.streamText with \(request.tools?.count ?? 0) tools")
        }
        stream = try await provider.streamText(request: request)
    }

    // Apply stop conditions if configured
    if let stopCondition = settings.stopConditions {
        // Wrap the stream with stop condition checking
        stream = stream.stopWhen(stopCondition)
    }

    // Use provided session or create a new one for tracking streaming usage
    let actualSessionId = sessionId ?? "streaming-\(UUID().uuidString)"
    if sessionId == nil {
        _ = UsageTracker.shared.startSession(actualSessionId)
    }

    // Wrap the stream to track usage when it completes
    let capturedModel = model
    let capturedSessionId = actualSessionId
    let capturedStream = stream
    let shouldEndSession = sessionId == nil

    let trackedStream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
        Task {
            do {
                let totalInputTokens = 0
                var totalOutputTokens = 0

                for try await delta in capturedStream {
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
                            outputTokens: totalOutputTokens,
                        )

                        UsageTracker.shared.recordUsage(
                            sessionId: capturedSessionId,
                            model: capturedModel,
                            usage: usage,
                            operation: .textStreaming,
                        )
                        if shouldEndSession {
                            _ = UsageTracker.shared.endSession(capturedSessionId)
                        }
                    }
                }

                continuation.finish()
            } catch {
                if shouldEndSession {
                    _ = UsageTracker.shared.endSession(capturedSessionId)
                }
                continuation.finish(throwing: error)
            }
        }
    }

    return StreamTextResult(
        stream: trackedStream,
        model: model,
        settings: settings,
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
@discardableResult
public func generateObject<T: Codable & Sendable>(
    model: LanguageModel,
    messages: [ModelMessage],
    schema _: T.Type,
    settings: GenerationSettings = .default,
    timeout: TimeInterval? = nil,
    configuration: TachikomaConfiguration = .current,
) async throws
    -> GenerateObjectResult<T>
{
    let resolvedConfiguration = TachikomaConfiguration.resolve(configuration)
    let provider = try resolvedConfiguration.makeProvider(for: model)

    let request = ProviderRequest(
        messages: messages,
        tools: nil,
        settings: settings,
        outputFormat: .json,
    )

    let response: ProviderResponse = if let timeout {
        try await withTimeout(timeout) {
            try await provider.generateText(request: request)
        }
    } else {
        try await provider.generateText(request: request)
    }

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
    configuration: TachikomaConfiguration = .current,
) async throws
    -> StreamObjectResult<T>
{
    let resolvedConfiguration = TachikomaConfiguration.resolve(configuration)
    let provider = try resolvedConfiguration.makeProvider(for: model)

    // Create request with JSON output format
    let request = ProviderRequest(
        messages: messages,
        tools: nil,
        settings: settings,
        outputFormat: .json,
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
                                    rawText: accumulatedText,
                                ))
                            } else if let partialObject = attemptPartialParse(T.self, from: accumulatedText) {
                                // Attempt to parse as partial object
                                lastValidObject = partialObject
                                continuation.yield(ObjectStreamDelta(
                                    type: .partial,
                                    object: partialObject,
                                    rawText: accumulatedText,
                                ))
                            }
                        }
                    } else if case .done = delta.type {
                        // Final parse attempt
                        if
                            let jsonData = accumulatedText.data(using: .utf8),
                            let finalObject = try? JSONDecoder().decode(T.self, from: jsonData)
                        {
                            continuation.yield(ObjectStreamDelta(
                                type: .complete,
                                object: finalObject,
                                rawText: accumulatedText,
                            ))
                        } else if let lastValidObject {
                            // If we have a last valid object, use it as complete
                            continuation.yield(ObjectStreamDelta(
                                type: .complete,
                                object: lastValidObject,
                                rawText: accumulatedText,
                            ))
                        } else {
                            throw TachikomaError.invalidInput(
                                "Failed to parse complete object from stream",
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
        schema: schema,
    )
}

/// Attempt to parse a partial JSON object by fixing common issues
private func attemptPartialParse<T: Codable>(_: T.Type, from json: String) -> T? {
    // Try various strategies to parse partial JSON
    let strategies = [
        json, // Original
        json + "}", // Missing closing brace
        json + "\"}", // Missing quote and brace
        json + "]", // Missing closing bracket
        json + "]}", // Missing bracket and brace
        fixPartialJSON(json), // Custom fix attempt
    ]

    for strategy in strategies {
        if
            let data = strategy.data(using: .utf8),
            let object = try? JSONDecoder().decode(T.self, from: data)
        {
            return object
        }
    }

    return nil
}

/// Fix common issues in partial JSON
private func fixPartialJSON(_ json: String) -> String {
    // Fix common issues in partial JSON
    var fixed = json.trimmingCharacters(in: .whitespacesAndNewlines)

    // Count brackets and braces
    let openBraces = fixed.count { $0 == "{" }
    let closeBraces = fixed.count { $0 == "}" }
    let openBrackets = fixed.count { $0 == "[" }
    let closeBrackets = fixed.count { $0 == "]" }

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
        if afterQuote.contains(":"), !afterQuote.contains("\"") {
            // Likely missing closing quote for string value
            fixed += "\""
        }
    }

    return fixed
}

// MARK: - Convenience Functions

/// Simple text generation from a prompt (convenience wrapper) - with Model enum
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@discardableResult
public func generate(
    _ prompt: String,
    using _: Model? = nil,
    system _: String? = nil,
    tools _: [AgentTool]? = nil,
    timeout _: TimeInterval? = nil,
) async throws
    -> String
{
    // For now, just return a mock response since we don't have provider implementations
    "Mock response for prompt: \(prompt)"
}

/// Simple text generation from a prompt (convenience wrapper) - with LanguageModel enum
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@discardableResult
public func generate(
    _ prompt: String,
    using model: LanguageModel = .default,
    system: String? = nil,
    maxTokens: Int? = nil,
    temperature: Double? = nil,
    timeout: TimeInterval? = nil,
    configuration: TachikomaConfiguration = .current,
) async throws
    -> String
{
    var messages: [ModelMessage] = []

    if let system {
        messages.append(.system(system))
    }

    messages.append(.user(prompt))

    let settings = GenerationSettings(
        maxTokens: maxTokens,
        temperature: temperature,
    )

    let result = try await generateText(
        model: model,
        messages: messages,
        settings: settings,
        timeout: timeout,
        configuration: configuration,
    )

    return result.text
}

/// Analyze an image using an AI model
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func analyze(
    image: ImageInput,
    prompt: String,
    using model: Model? = nil,
    configuration: TachikomaConfiguration = .current,
) async throws
    -> String
{
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
        configuration: configuration,
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
            operation: .imageAnalysis,
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
    configuration: TachikomaConfiguration = .current,
) async throws
    -> AsyncThrowingStream<TextStreamDelta, Error>
{
    var messages: [ModelMessage] = []

    if let system {
        messages.append(.system(system))
    }

    messages.append(.user(prompt))

    let settings = GenerationSettings(
        maxTokens: maxTokens,
        temperature: temperature,
    )

    let result = try await streamText(
        model: model,
        messages: messages,
        settings: settings,
        configuration: configuration,
    )

    return result.stream
}

// MARK: - Result Types

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
        schema: T.Type,
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
            try await self.iterator.next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: self.objectStream.makeAsyncIterator())
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
        case start // Stream has started
        case partial // Partial object update
        case complete // Complete object received
        case done // Stream has finished
        case error // An error occurred
    }

    public init(
        type: DeltaType,
        object: T? = nil,
        rawText: String? = nil,
        error: Error? = nil,
    ) {
        self.type = type
        self.object = object
        self.rawText = rawText
        self.error = error
    }
}
