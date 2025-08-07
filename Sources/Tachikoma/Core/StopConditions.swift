//
//  StopConditions.swift
//  Tachikoma
//

import Foundation

// MARK: - Stop Conditions for Multi-Step Tool Execution

/// Protocol for defining when to stop multi-step tool execution
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol StopCondition: Sendable {
    /// Check if execution should stop based on current state
    func shouldStop(step: Int, toolCalls: [AgentToolCall], results: [AgentToolResult]) async -> Bool
}

// MARK: - Built-in Stop Conditions

/// Stop after a specific number of steps
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct StepCountCondition: StopCondition {
    public let maxSteps: Int
    
    public init(maxSteps: Int) {
        self.maxSteps = maxSteps
    }
    
    public func shouldStop(step: Int, toolCalls: [AgentToolCall], results: [AgentToolResult]) async -> Bool {
        step >= maxSteps
    }
}

/// Stop when a specific tool is called
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ToolCalledCondition: StopCondition {
    public let toolName: String
    
    public init(toolName: String) {
        self.toolName = toolName
    }
    
    public func shouldStop(step: Int, toolCalls: [AgentToolCall], results: [AgentToolResult]) async -> Bool {
        toolCalls.contains { $0.name == toolName }
    }
}

/// Stop when a tool returns a specific result type
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ResultTypeCondition: StopCondition {
    public let checker: @Sendable (AgentToolResult) -> Bool
    
    public init(checker: @escaping @Sendable (AgentToolResult) -> Bool) {
        self.checker = checker
    }
    
    public func shouldStop(step: Int, toolCalls: [AgentToolCall], results: [AgentToolResult]) async -> Bool {
        results.contains(where: checker)
    }
}

/// Stop when an error occurs
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ErrorCondition: StopCondition {
    public init() {}
    
    public func shouldStop(step: Int, toolCalls: [AgentToolCall], results: [AgentToolResult]) async -> Bool {
        results.contains { $0.isError }
    }
}

/// Combine multiple conditions with AND logic
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AndCondition: StopCondition {
    public let conditions: [StopCondition]
    
    public init(_ conditions: StopCondition...) {
        self.conditions = conditions
    }
    
    public init(conditions: [StopCondition]) {
        self.conditions = conditions
    }
    
    public func shouldStop(step: Int, toolCalls: [AgentToolCall], results: [AgentToolResult]) async -> Bool {
        for condition in conditions {
            if !(await condition.shouldStop(step: step, toolCalls: toolCalls, results: results)) {
                return false
            }
        }
        return true
    }
}

/// Combine multiple conditions with OR logic
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct OrCondition: StopCondition {
    public let conditions: [StopCondition]
    
    public init(_ conditions: StopCondition...) {
        self.conditions = conditions
    }
    
    public init(conditions: [StopCondition]) {
        self.conditions = conditions
    }
    
    public func shouldStop(step: Int, toolCalls: [AgentToolCall], results: [AgentToolResult]) async -> Bool {
        for condition in conditions {
            if await condition.shouldStop(step: step, toolCalls: toolCalls, results: results) {
                return true
            }
        }
        return false
    }
}

/// Custom condition with a closure
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct CustomCondition: StopCondition {
    public let evaluator: @Sendable (Int, [AgentToolCall], [AgentToolResult]) async -> Bool
    
    public init(evaluator: @escaping @Sendable (Int, [AgentToolCall], [AgentToolResult]) async -> Bool) {
        self.evaluator = evaluator
    }
    
    public func shouldStop(step: Int, toolCalls: [AgentToolCall], results: [AgentToolResult]) async -> Bool {
        await evaluator(step, toolCalls, results)
    }
}

// MARK: - Stop When Builder

/// Fluent builder for creating stop conditions
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct StopWhen {
    /// Stop after a specific number of steps
    public static func stepCountIs(_ count: Int) -> StopCondition {
        StepCountCondition(maxSteps: count)
    }
    
    /// Stop when a specific tool is called
    public static func toolCalled(_ name: String) -> StopCondition {
        ToolCalledCondition(toolName: name)
    }
    
    /// Stop when any error occurs
    public static func errorOccurs() -> StopCondition {
        ErrorCondition()
    }
    
    /// Stop when a custom condition is met
    public static func custom(
        _ evaluator: @escaping @Sendable (Int, [AgentToolCall], [AgentToolResult]) async -> Bool
    ) -> StopCondition {
        CustomCondition(evaluator: evaluator)
    }
    
    /// Stop when all conditions are met
    public static func all(_ conditions: StopCondition...) -> StopCondition {
        AndCondition(conditions: conditions)
    }
    
    /// Stop when any condition is met
    public static func any(_ conditions: StopCondition...) -> StopCondition {
        OrCondition(conditions: conditions)
    }
    
    /// Stop when a result contains a specific value
    public static func resultContains(_ checker: @escaping @Sendable (AgentToolResult) -> Bool) -> StopCondition {
        ResultTypeCondition(checker: checker)
    }
    
    /// Stop when a result contains a string matching a pattern
    public static func resultMatches(_ pattern: String) -> StopCondition {
        ResultTypeCondition { result in
            switch result.result {
            case .string(let str):
                return str.contains(pattern)
            case .object(let dict):
                // Check if any value in the object contains the pattern
                for value in dict.values {
                    if case .string(let str) = value, str.contains(pattern) {
                        return true
                    }
                }
                return false
            default:
                return false
            }
        }
    }
    
    /// Never stop (only limited by max steps if provided)
    public static func never() -> StopCondition {
        CustomCondition { _, _, _ in false }
    }
}

// MARK: - Enhanced Generation Functions with Stop Conditions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func generateTextWithConditions(
    model: LanguageModel,
    messages: [ModelMessage],
    tools: [AgentTool]? = nil,
    settings: GenerationSettings = .default,
    stopWhen: StopCondition = StopWhen.stepCountIs(1),
    maxSteps: Int = 10, // Safety limit
    configuration: TachikomaConfiguration = .current
) async throws -> GenerateTextResult {
    let provider = try ProviderFactory.createProvider(for: model, configuration: configuration)
    
    var currentMessages = messages
    var allSteps: [GenerationStep] = []
    var totalUsage = Usage(inputTokens: 0, outputTokens: 0)
    var allToolCalls: [AgentToolCall] = []
    var allToolResults: [AgentToolResult] = []
    
    for stepIndex in 0..<maxSteps {
        // Check stop condition before executing
        if await stopWhen.shouldStop(step: stepIndex, toolCalls: allToolCalls, results: allToolResults) {
            break
        }
        
        let request = ProviderRequest(
            messages: currentMessages,
            tools: tools,
            settings: settings
        )
        
        let response = try await provider.generateText(request: request)
        
        // Track usage
        if let usage = response.usage {
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
            
            totalUsage = Usage(
                inputTokens: totalUsage.inputTokens + usage.inputTokens,
                outputTokens: totalUsage.outputTokens + usage.outputTokens,
                cost: usage.cost
            )
        }
        
        // Process tool calls
        var stepToolResults: [AgentToolResult] = []
        if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
            allToolCalls.append(contentsOf: toolCalls)
            
            // Execute tools
            for toolCall in toolCalls {
                if let tool = tools?.first(where: { $0.name == toolCall.name }) {
                    do {
                        let resultValue = try await tool.execute(AgentToolArguments(toolCall.arguments))
                        let result = AgentToolResult(
                            toolCallId: toolCall.id,
                            result: resultValue,
                            isError: false
                        )
                        stepToolResults.append(result)
                        allToolResults.append(result)
                    } catch {
                        let errorResult = AgentToolResult(
                            toolCallId: toolCall.id,
                            result: .string("Error: \(error.localizedDescription)"),
                            isError: true
                        )
                        stepToolResults.append(errorResult)
                        allToolResults.append(errorResult)
                    }
                }
            }
            
            // Add tool results to messages
            currentMessages.append(contentsOf: stepToolResults.map { result in
                ModelMessage(role: .tool, content: [.toolResult(result)])
            })
        }
        
        // Create step record
        let step = GenerationStep(
            stepIndex: stepIndex,
            text: response.text,
            toolCalls: response.toolCalls ?? [],
            toolResults: stepToolResults,
            usage: response.usage,
            finishReason: response.finishReason
        )
        
        allSteps.append(step)
        
        // Add assistant message
        var assistantContent: [ModelMessage.ContentPart] = [.text(response.text)]
        if let toolCalls = response.toolCalls {
            assistantContent.append(contentsOf: toolCalls.map { .toolCall($0) })
        }
        currentMessages.append(ModelMessage(role: .assistant, content: assistantContent))
    }
    
    // Return the complete result
    let finalText = allSteps.map { $0.text }.joined()
    return GenerateTextResult(
        text: finalText,
        usage: totalUsage,
        finishReason: allSteps.last?.finishReason ?? .other,
        steps: allSteps,
        messages: currentMessages
    )
}

// MARK: - Convenience Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension StopCondition {
    /// Combine with another condition using OR logic
    func or(_ other: StopCondition) -> StopCondition {
        OrCondition(conditions: [self, other])
    }
    
    /// Combine with another condition using AND logic
    func and(_ other: StopCondition) -> StopCondition {
        AndCondition(conditions: [self, other])
    }
    
    /// Negate the condition
    func not() -> StopCondition {
        CustomCondition { step, toolCalls, results in
            !(await self.shouldStop(step: step, toolCalls: toolCalls, results: results))
        }
    }
}