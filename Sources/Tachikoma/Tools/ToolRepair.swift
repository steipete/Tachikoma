//
//  ToolRepair.swift
//  Tachikoma
//

import Foundation

// MARK: - Tool Repair & Retry System

/// Strategy for repairing failed tool calls
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol ToolRepairStrategy: Sendable {
    /// Attempt to repair a failed tool call
    func repair(
        toolCall: AgentToolCall,
        error: Error,
        attempt: Int
    ) async throws -> AgentToolCall?
}

/// Repairs tool calls by fixing common parameter issues
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ParameterRepairStrategy: ToolRepairStrategy {
    public init() {}
    
    public func repair(
        toolCall: AgentToolCall,
        error: Error,
        attempt: Int
    ) async throws -> AgentToolCall? {
        // Analyze error message to determine repair strategy
        let errorMessage = error.localizedDescription.lowercased()
        
        var repairedArguments = toolCall.arguments
        
        // Fix missing required parameters
        if errorMessage.contains("required") || errorMessage.contains("missing") {
            // Add default values for common parameter types
            for (key, value) in repairedArguments {
                if case .null = value {
                    // Try to infer a sensible default
                    repairedArguments[key] = inferDefault(for: key)
                }
            }
        }
        
        // Fix type mismatches
        if errorMessage.contains("type") || errorMessage.contains("invalid") {
            for (key, value) in repairedArguments {
                repairedArguments[key] = coerceType(value, for: key)
            }
        }
        
        // Fix out of range values
        if errorMessage.contains("range") || errorMessage.contains("maximum") || errorMessage.contains("minimum") {
            for (key, value) in repairedArguments {
                repairedArguments[key] = clampValue(value, for: key)
            }
        }
        
        // Return repaired tool call if changes were made
        if repairedArguments != toolCall.arguments {
            return AgentToolCall(
                id: toolCall.id,
                name: toolCall.name,
                arguments: repairedArguments,
                namespace: toolCall.namespace,
                recipient: toolCall.recipient
            )
        }
        
        return nil
    }
    
    private func inferDefault(for key: String) -> AgentToolArgument {
        // Common parameter name patterns
        switch key.lowercased() {
        case let k where k.contains("count") || k.contains("limit") || k.contains("max"):
            return .int(10)
        case let k where k.contains("page") || k.contains("offset"):
            return .int(0)
        case let k where k.contains("query") || k.contains("search"):
            return .string("")
        case let k where k.contains("enabled") || k.contains("active"):
            return .bool(true)
        case let k where k.contains("temperature"):
            return .double(0.7)
        default:
            return .string("")
        }
    }
    
    private func coerceType(_ value: AgentToolArgument, for key: String) -> AgentToolArgument {
        // Try to convert between common type mismatches
        switch value {
        case .string(let str):
            // Try to parse string as number
            if let intValue = Int(str) {
                return .int(intValue)
            } else if let doubleValue = Double(str) {
                return .double(doubleValue)
            } else if str.lowercased() == "true" || str.lowercased() == "false" {
                return .bool(str.lowercased() == "true")
            }
        case .double(let num):
            // Convert float to int if needed
            if key.lowercased().contains("count") || key.lowercased().contains("index") {
                return .int(Int(num))
            }
        case .int(let int):
            // Convert int to float if needed
            if key.lowercased().contains("rate") || key.lowercased().contains("ratio") {
                return .double(Double(int))
            }
        default:
            break
        }
        return value
    }
    
    private func clampValue(_ value: AgentToolArgument, for key: String) -> AgentToolArgument {
        // Apply common range constraints
        switch value {
        case .double(let num):
            if key.lowercased().contains("temperature") {
                return .double(max(0, min(2, num)))
            } else if key.lowercased().contains("probability") {
                return .double(max(0, min(1, num)))
            }
        case .int(let int):
            if key.lowercased().contains("limit") || key.lowercased().contains("max") {
                return .int(max(1, min(100, int)))
            } else if key.lowercased().contains("page") {
                return .int(max(0, int))
            }
        default:
            break
        }
        return value
    }
}

/// Repairs tool calls by prompting the model to fix issues
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ModelAssistedRepairStrategy: ToolRepairStrategy {
    private let model: LanguageModel
    private let configuration: TachikomaConfiguration
    
    public init(model: LanguageModel, configuration: TachikomaConfiguration = .current) {
        self.model = model
        self.configuration = configuration
    }
    
    public func repair(
        toolCall: AgentToolCall,
        error: Error,
        attempt: Int
    ) async throws -> AgentToolCall? {
        let prompt = """
        The following tool call failed with an error:
        
        Tool: \(toolCall.name)
        Arguments: \(toolCall.arguments)
        Error: \(error.localizedDescription)
        
        Please provide corrected arguments for this tool call.
        Return only the corrected arguments as a JSON object.
        """
        
        let messages = [
            ModelMessage.system("You are a helpful assistant that fixes tool call parameters."),
            ModelMessage.user(prompt)
        ]
        
        // Use generateObject to get structured response
        let result = try await generateObject(
            model: model,
            messages: messages,
            schema: [String: AgentToolArgument].self,
            configuration: configuration
        )
        
        // Create repaired tool call with new arguments
        return AgentToolCall(
            id: toolCall.id,
            name: toolCall.name,
            arguments: result.object,
            namespace: toolCall.namespace,
            recipient: toolCall.recipient
        )
    }
}

/// Combines multiple repair strategies
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct CompositeRepairStrategy: ToolRepairStrategy {
    private let strategies: [ToolRepairStrategy]
    
    public init(strategies: [ToolRepairStrategy]) {
        self.strategies = strategies
    }
    
    public func repair(
        toolCall: AgentToolCall,
        error: Error,
        attempt: Int
    ) async throws -> AgentToolCall? {
        var currentCall = toolCall
        
        for strategy in strategies {
            if let repaired = try await strategy.repair(
                toolCall: currentCall,
                error: error,
                attempt: attempt
            ) {
                currentCall = repaired
            }
        }
        
        return currentCall != toolCall ? currentCall : nil
    }
}

// MARK: - Tool Executor with Retry

/// Executes tools with automatic retry and repair
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ResilientToolExecutor: Sendable {
    private let maxRetries: Int
    private let repairStrategy: ToolRepairStrategy?
    private let retryDelay: TimeInterval
    
    public init(
        maxRetries: Int = 3,
        repairStrategy: ToolRepairStrategy? = ParameterRepairStrategy(),
        retryDelay: TimeInterval = 1.0
    ) {
        self.maxRetries = maxRetries
        self.repairStrategy = repairStrategy
        self.retryDelay = retryDelay
    }
    
    /// Execute a tool with automatic retry and repair
    public func execute(
        tool: AgentTool,
        call: AgentToolCall
    ) async throws -> AgentToolResult {
        var currentCall = call
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                // Try to execute the tool
                let result = try await tool.execute(AgentToolArguments(currentCall.arguments))
                return AgentToolResult(
                    toolCallId: currentCall.id,
                    result: result,
                    isError: false
                )
            } catch {
                lastError = error
                
                // If this isn't the last attempt, try to repair
                if attempt < maxRetries - 1 {
                    // Wait before retry
                    if retryDelay > 0 {
                        try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    }
                    
                    // Attempt repair if strategy is available
                    if let repairStrategy {
                        if let repairedCall = try await repairStrategy.repair(
                            toolCall: currentCall,
                            error: error,
                            attempt: attempt
                        ) {
                            currentCall = repairedCall
                            continue
                        }
                    }
                }
            }
        }
        
        // All retries failed, return error result
        return AgentToolResult(
            toolCallId: call.id,
            result: .string("Tool execution failed after \(maxRetries) attempts: \(lastError?.localizedDescription ?? "Unknown error")"),
            isError: true
        )
    }
    
    /// Execute multiple tools in parallel with retry
    public func executeAll(
        tools: [AgentTool],
        calls: [AgentToolCall]
    ) async throws -> [AgentToolResult] {
        try await withThrowingTaskGroup(of: AgentToolResult.self) { group in
            for call in calls {
                guard let tool = tools.first(where: { $0.name == call.name }) else {
                    continue
                }
                
                let executor = self
                group.addTask {
                    try await executor.execute(tool: tool, call: call)
                }
            }
            
            var results: [AgentToolResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
}

// MARK: - Enhanced Generation with Tool Repair

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func generateTextWithRepair(
    model: LanguageModel,
    messages: [ModelMessage],
    tools: [AgentTool]? = nil,
    settings: GenerationSettings = .default,
    maxSteps: Int = 5,
    repairStrategy: ToolRepairStrategy? = ParameterRepairStrategy(),
    configuration: TachikomaConfiguration = .current
) async throws -> GenerateTextResult {
    let executor = ResilientToolExecutor(
        maxRetries: 3,
        repairStrategy: repairStrategy
    )
    
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
        
        // Track usage
        if let usage = response.usage {
            totalUsage = Usage(
                inputTokens: totalUsage.inputTokens + usage.inputTokens,
                outputTokens: totalUsage.outputTokens + usage.outputTokens,
                cost: usage.cost
            )
        }
        
        // Process tool calls with repair
        var stepToolResults: [AgentToolResult] = []
        if let toolCalls = response.toolCalls, !toolCalls.isEmpty, let tools {
            stepToolResults = try await executor.executeAll(
                tools: tools,
                calls: toolCalls
            )
            
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
        
        // Stop if no more tool calls
        if response.toolCalls?.isEmpty ?? true {
            break
        }
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