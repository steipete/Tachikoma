import Foundation
import Tachikoma
import TachikomaAgent

/// Configuration for the agent
struct AgentConfiguration {
    let model: LanguageModel
    let systemPrompt: String
    let tools: [AgentTool]
    let maxIterations: Int
    let temperature: Double
    let showThinking: Bool
}

/// Result from agent execution
struct AgentExecutionResult {
    let content: String
    let toolCalls: [String]
    let usage: Usage?
    let duration: TimeInterval
}

/// Main agent that orchestrates conversations and tool calls
final class Agent {
    private let configuration: AgentConfiguration
    private weak var eventDelegate: AgentEventDelegate?
    private let tachikomaConfig: TachikomaConfiguration

    init(configuration: AgentConfiguration, eventDelegate: AgentEventDelegate? = nil) {
        self.configuration = configuration
        self.eventDelegate = eventDelegate
        self.tachikomaConfig = TachikomaConfiguration.current
    }

    /// Execute the agent with the given messages
    func execute(messages: [ModelMessage], maxTurns: Int? = nil) async throws -> AgentExecutionResult {
        let startTime = Date()
        let turns = maxTurns ?? self.configuration.maxIterations

        // Notify start
        self.eventDelegate?.agentDidEmitEvent(.started("Processing request..."))

        // Build messages with system prompt
        var allMessages = messages
        if !self.configuration.systemPrompt.isEmpty {
            allMessages.insert(.system(self.configuration.systemPrompt), at: 0)
        }

        // Track tool calls
        var toolCallHistory: [String] = []
        var totalUsage: Usage?
        var finalContent = ""

        // Main execution loop
        for turn in 0..<turns {
            self.eventDelegate?.agentDidEmitEvent(.statusUpdate("Turn \(turn + 1)/\(turns)"))

            // Check if we should show thinking for this model
            let shouldShowThinking = self.configuration.showThinking && self.isReasoningModel(self.configuration.model)

            // Generate response
            let response: GenerateTextResult

            if self.configuration.tools.isEmpty {
                // No tools - simple generation
                response = try await generateText(
                    model: self.configuration.model,
                    messages: allMessages,
                    settings: GenerationSettings(
                        maxTokens: 2000,
                        temperature: self.configuration.temperature,
                    ),
                    configuration: self.tachikomaConfig,
                )
            } else {
                // With tools - use generateText with tools
                response = try await generateText(
                    model: self.configuration.model,
                    messages: allMessages,
                    tools: self.configuration.tools,
                    settings: GenerationSettings(
                        maxTokens: 2000,
                        temperature: self.configuration.temperature,
                    ),
                    configuration: self.tachikomaConfig,
                )

                // Track tool calls from response steps
                for step in response.steps {
                    // Process tool calls in this step
                    for toolCall in step.toolCalls {
                        toolCallHistory.append(toolCall.name)
                        // Notify UI about tool call
                        let argsData = try? JSONEncoder().encode(toolCall.arguments)
                        let argsString = String(data: argsData ?? Data(), encoding: .utf8) ?? "{}"
                        self.eventDelegate?.agentDidEmitEvent(.toolCallStarted(
                            name: toolCall.name,
                            arguments: argsString,
                        ))
                    }

                    // Process tool results in this step
                    for toolResult in step.toolResults {
                        // Notify UI about tool result
                        let resultData = try? JSONEncoder().encode(toolResult.result)
                        let resultString = String(data: resultData ?? Data(), encoding: .utf8) ?? "{}"
                        self.eventDelegate?.agentDidEmitEvent(.toolCallCompleted(
                            name: toolResult.toolCallId,
                            result: resultString,
                        ))
                    }
                }
            }

            // Handle thinking display
            if shouldShowThinking, response.text.contains("thinking:") {
                let parts = response.text.components(separatedBy: "thinking:")
                if parts.count > 1 {
                    self.eventDelegate?
                        .agentDidEmitEvent(.thinking(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }

            // Update content and usage
            finalContent = response.text
            if let usage = response.usage {
                if let existing = totalUsage {
                    totalUsage = Usage(
                        inputTokens: existing.inputTokens + usage.inputTokens,
                        outputTokens: existing.outputTokens + usage.outputTokens,
                    )
                } else {
                    totalUsage = usage
                }
            }

            // Add response to messages
            allMessages.append(.assistant(response.text))

            // Check if we're done (no tool calls in response)
            let hasToolCalls = response.steps.contains { !$0.toolCalls.isEmpty }
            if !hasToolCalls {
                break
            }
        }

        // Notify completion
        self.eventDelegate?.agentDidEmitEvent(.completed(finalContent.prefix(100).description))

        let duration = Date().timeIntervalSince(startTime)

        return AgentExecutionResult(
            content: finalContent,
            toolCalls: toolCallHistory,
            usage: totalUsage,
            duration: duration,
        )
    }

    // MARK: - Private Helpers

    private func isReasoningModel(_ model: LanguageModel) -> Bool {
        switch model {
        case let .openai(openaiModel):
            switch openaiModel {
            case .o4Mini,
                 .gpt5,
                 .gpt5Pro,
                 .gpt5Mini,
                 .gpt5Nano,
                 .gpt5Thinking,
                 .gpt5ThinkingMini,
                 .gpt5ThinkingNano,
                 .gpt5ChatLatest:
                true
            default:
                false
            }
        case let .anthropic(anthropicModel):
            switch anthropicModel {
            case .opus4Thinking, .sonnet4Thinking:
                true
            default:
                false
            }
        case let .google(googleModel):
            switch googleModel {
            case .gemini25Pro:
                true
            default:
                false
            }
        default:
            false
        }
    }

    private func extractToolCalls(from text: String) -> [ToolCall]? {
        // Simple extraction - in real implementation, parse properly
        var toolCalls: [ToolCall] = []

        // Look for tool call patterns in the text
        let pattern = #"<tool_call>\s*(\{[^}]+\})\s*</tool_call>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
        let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []

        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                let json = String(text[range])
                if
                    let data = json.data(using: .utf8),
                    let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let name = parsed["name"] as? String
                {
                    let args = parsed["arguments"] as? [String: Any] ?? [:]
                    let toolCall = ToolCall(
                        id: UUID().uuidString,
                        name: name,
                        arguments: self.convertToAgentArguments(args),
                    )
                    toolCalls.append(toolCall)
                }
            }
        }

        return toolCalls.isEmpty ? nil : toolCalls
    }

    private func executeToolCall(_ toolCall: ToolCall) async throws -> String {
        // Find the tool
        guard let tool = configuration.tools.first(where: { $0.name == toolCall.name }) else {
            throw AgentError.toolNotFound(toolCall.name)
        }

        // Execute the tool
        let context = ToolExecutionContext()
        let result = try await tool.execute(toolCall.arguments, context: context)

        // Convert result to string
        if let string = result.stringValue {
            return string
        } else {
            let data = try JSONEncoder().encode(result)
            return String(data: data, encoding: .utf8) ?? "null"
        }
    }

    private func convertToAgentArguments(_ dict: [String: Any]) -> AgentToolArguments {
        var args: [String: AnyAgentToolValue] = [:]
        for (key, value) in dict {
            args[key] = self.convertToAgentValue(value)
        }
        return AgentToolArguments(args)
    }

    private func convertToAgentValue(_ value: Any) -> AnyAgentToolValue {
        if let string = value as? String {
            return AnyAgentToolValue(string: string)
        } else if let int = value as? Int {
            return AnyAgentToolValue(int: int)
        } else if let double = value as? Double {
            return AnyAgentToolValue(double: double)
        } else if let bool = value as? Bool {
            return AnyAgentToolValue(bool: bool)
        } else if let array = value as? [Any] {
            let converted = array.map { self.convertToAgentValue($0) }
            return AnyAgentToolValue(array: converted)
        } else if let dict = value as? [String: Any] {
            var converted: [String: AnyAgentToolValue] = [:]
            for (key, val) in dict {
                converted[key] = self.convertToAgentValue(val)
            }
            return AnyAgentToolValue(object: converted)
        } else {
            return AnyAgentToolValue(null: ())
        }
    }
}

// MARK: - Supporting Types

struct ToolCall {
    let id: String
    let name: String
    let arguments: AgentToolArguments
}

enum AgentError: LocalizedError {
    case toolNotFound(String)
    case toolExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case let .toolNotFound(name):
            "Tool not found: \(name)"
        case let .toolExecutionFailed(message):
            "Tool execution failed: \(message)"
        }
    }
}
