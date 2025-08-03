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
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func generateText(
    model: LanguageModel,
    messages: [ModelMessage],
    tools: [Tool]? = nil,
    settings: GenerationSettings = .default,
    maxSteps: Int = 1
) async throws -> GenerateTextResult {
    let provider = try ProviderFactory.createProvider(for: model)
    
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
            var toolResults: [ToolResult] = []
            for toolCall in toolCalls {
                if let tool = tools?.first(where: { $0.name == toolCall.name }) {
                    do {
                        let result = try await tool.execute(ToolArguments(toolCall.arguments))
                        let toolResult = ToolResult.success(toolCallId: toolCall.id, result: result)
                        toolResults.append(toolResult)
                        
                        // Add tool result message
                        currentMessages.append(ModelMessage(
                            role: .tool,
                            content: [.toolResult(toolResult)]
                        ))
                    } catch {
                        let errorResult = ToolResult.error(toolCallId: toolCall.id, error: error.localizedDescription)
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
            if response.finishReason != .toolCalls && response.finishReason != .stop {
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
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func streamText(
    model: LanguageModel,
    messages: [ModelMessage],
    tools: [Tool]? = nil,
    settings: GenerationSettings = .default,
    maxSteps: Int = 1
) async throws -> StreamTextResult {
    let provider = try ProviderFactory.createProvider(for: model)
    
    let request = ProviderRequest(
        messages: messages,
        tools: tools,
        settings: settings
    )
    
    let stream = try await provider.streamText(request: request)
    
    return StreamTextResult(
        stream: stream,
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
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func generateObject<T: Codable & Sendable>(
    model: LanguageModel,
    messages: [ModelMessage],
    schema: T.Type,
    settings: GenerationSettings = .default
) async throws -> GenerateObjectResult<T> {
    let provider = try ProviderFactory.createProvider(for: model)
    
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

// MARK: - Convenience Functions

/// Simple text generation from a prompt (convenience wrapper)
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func generate(
    _ prompt: String,
    using model: LanguageModel = .default,
    system: String? = nil,
    maxTokens: Int? = nil,
    temperature: Double? = nil
) async throws -> String {
    var messages: [ModelMessage] = []
    
    if let system = system {
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
        settings: settings
    )
    
    return result.text
}

/// Simple streaming from a prompt (convenience wrapper)
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func stream(
    _ prompt: String,
    using model: LanguageModel = .default,
    system: String? = nil,
    maxTokens: Int? = nil,
    temperature: Double? = nil
) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
    var messages: [ModelMessage] = []
    
    if let system = system {
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
        settings: settings
    )
    
    return result.textStream
}

// MARK: - Result Types

/// Result from generateText function
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

/// Result from generateObject function
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

/// A single step in multi-step generation
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct GenerationStep: Sendable {
    public let stepIndex: Int
    public let text: String
    public let toolCalls: [ToolCall]
    public let toolResults: [ToolResult]
    public let usage: Usage?
    public let finishReason: FinishReason?
    
    public init(
        stepIndex: Int,
        text: String,
        toolCalls: [ToolCall],
        toolResults: [ToolResult],
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
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct TextStreamDelta: Sendable {
    public let type: DeltaType
    public let content: String?
    public let toolCall: ToolCall?
    public let toolResult: ToolResult?
    
    public enum DeltaType: Sendable {
        case textDelta
        case toolCallStart
        case toolCallDelta
        case toolCallEnd
        case toolResult
        case stepStart
        case stepEnd
        case done
        case error
    }
    
    public init(type: DeltaType, content: String? = nil, toolCall: ToolCall? = nil, toolResult: ToolResult? = nil) {
        self.type = type
        self.content = content
        self.toolCall = toolCall
        self.toolResult = toolResult
    }
}