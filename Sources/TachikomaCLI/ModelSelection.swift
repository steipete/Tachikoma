import Foundation
import TachikomaCore

// MARK: - CLI Model Selection

/// Smart model parsing and selection for command-line interfaces
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModelSelector {
    /// Parse a model string with intelligent fallbacks and shortcuts
    public static func parseModel(_ modelString: String) throws -> Model {
        let normalized = modelString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle empty or default
        if normalized.isEmpty || normalized == "default" {
            return .default
        }

        // OpenAI shortcuts and models
        if let openaiModel = parseOpenAIModel(normalized) {
            return .openai(openaiModel)
        }

        // Anthropic shortcuts and models
        if let anthropicModel = parseAnthropicModel(normalized) {
            return .anthropic(anthropicModel)
        }

        // Grok shortcuts and models
        if let grokModel = parseGrokModel(normalized) {
            return .grok(grokModel)
        }

        // Ollama shortcuts and models
        if let ollamaModel = parseOllamaModel(normalized) {
            return .ollama(ollamaModel)
        }

        // OpenRouter format (contains slash)
        if normalized.contains("/") {
            return .openRouter(modelId: normalized)
        }

        // Custom model ID - try to infer provider
        if normalized.contains("gpt") || normalized.contains("o3") || normalized.contains("o4") {
            return .openai(.custom(normalized))
        }

        if normalized.contains("claude") {
            return .anthropic(.custom(normalized))
        }

        if normalized.contains("grok") {
            return .grok(.custom(normalized))
        }

        // Default to Ollama for local models
        return .ollama(.custom(normalized))
    }

    // MARK: - Provider-Specific Parsing

    private static func parseOpenAIModel(_ input: String) -> Model.OpenAI? {
        switch input {
        // Direct matches
        case "gpt-4o", "gpt4o":
            return .gpt4o
        case "gpt-4o-mini", "gpt4o-mini", "gpt4omini":
            return .gpt4oMini
        case "gpt-4.1", "gpt4.1", "gpt41":
            return .gpt4_1
        case "gpt-4.1-mini", "gpt4.1-mini", "gpt41mini":
            return .gpt4_1Mini
        case "o3":
            return .o3
        case "o3-mini", "o3mini":
            return .o3Mini
        case "o3-pro", "o3pro":
            return .o3Pro
        case "o4-mini", "o4mini":
            return .o4Mini
        // Shortcuts
        case "gpt", "gpt4", "gpt-4":
            return .gpt4_1 // Default to latest GPT-4 variant
        case "openai":
            return .gpt4o // Default OpenAI model
        default:
            // Check if it's an OpenAI model ID
            if input.hasPrefix("gpt") || input.hasPrefix("o3") || input.hasPrefix("o4") {
                return .custom(input)
            }
            return nil
        }
    }

    private static func parseAnthropicModel(_ input: String) -> Model.Anthropic? {
        switch input {
        // Direct matches
        case "claude-opus-4-20250514":
            return .opus4
        case "claude-opus-4-20250514-thinking":
            return .opus4Thinking
        case "claude-sonnet-4-20250514":
            return .sonnet4
        case "claude-sonnet-4-20250514-thinking":
            return .sonnet4Thinking
        case "claude-3-7-sonnet":
            return .sonnet3_7
        case "claude-3-5-haiku":
            return .haiku3_5
        case "claude-3-5-sonnet":
            return .sonnet3_5
        case "claude-3-5-opus":
            return .opus3_5
        // Shortcuts
        case "claude", "claude-opus", "opus":
            return .opus4 // Default to best Claude model
        case "claude-sonnet", "sonnet":
            return .sonnet4
        case "claude-haiku", "haiku":
            return .haiku3_5
        case "anthropic":
            return .opus4 // Default Anthropic model
        default:
            // Check if it's a Claude model ID
            if input.hasPrefix("claude") {
                return .custom(input)
            }
            return nil
        }
    }

    private static func parseGrokModel(_ input: String) -> Model.Grok? {
        switch input {
        // Direct matches
        case "grok-4", "grok4":
            return .grok4
        case "grok-4-0709":
            return .grok4_0709
        case "grok-4-latest":
            return .grok4Latest
        case "grok-3", "grok3":
            return .grok3
        case "grok-3-mini":
            return .grok3Mini
        case "grok-3-fast":
            return .grok3Fast
        case "grok-3-mini-fast":
            return .grok3MiniFast
        case "grok-2-1212":
            return .grok2_1212
        case "grok-2-vision-1212":
            return .grok2Vision_1212
        case "grok-2-image-1212":
            return .grok2Image_1212
        case "grok-beta":
            return .grokBeta
        case "grok-vision-beta":
            return .grokVisionBeta
        // Shortcuts
        case "grok":
            return .grok4 // Default to latest Grok
        case "xai":
            return .grok4 // Default xAI model
        default:
            // Check if it's a Grok model ID
            if input.hasPrefix("grok") {
                return .custom(input)
            }
            return nil
        }
    }

    private static func parseOllamaModel(_ input: String) -> Model.Ollama? {
        switch input {
        // Direct matches
        case "llama3.3", "llama3.3:latest":
            .llama3_3
        case "llama3.2", "llama3.2:latest":
            .llama3_2
        case "llama3.1", "llama3.1:latest":
            .llama3_1
        case "llava", "llava:latest":
            .llava
        case "bakllava", "bakllava:latest":
            .bakllava
        case "llama3.2-vision:11b":
            .llama3_2Vision11b
        case "llama3.2-vision:90b":
            .llama3_2Vision90b
        case "qwen2.5vl:7b":
            .qwen2_5vl7b
        case "qwen2.5vl:32b":
            .qwen2_5vl32b
        case "llama2", "llama2:latest":
            .llama2
        case "llama4", "llama4:latest":
            .llama4
        case "codellama", "codellama:latest":
            .codellama
        case "mistral", "mistral:latest":
            .mistral
        case "mistral-nemo", "mistral-nemo:latest":
            .mistralNemo
        case "mixtral", "mixtral:latest":
            .mixtral
        case "neural-chat", "neural-chat:latest":
            .neuralChat
        case "gemma", "gemma:latest":
            .gemma
        case "devstral", "devstral:latest":
            .devstral
        case "deepseek-r1:8b":
            .deepseekR1_8b
        case "deepseek-r1:671b":
            .deepseekR1_671b
        case "firefunction-v2", "firefunction-v2:latest":
            .firefunction
        case "command-r", "command-r:latest":
            .commandR
        case "command-r-plus", "command-r-plus:latest":
            .commandRPlus
        // Shortcuts
        case "llama", "llama3":
            .llama3_3 // Default to latest Llama
        case "ollama":
            .llama3_3 // Default Ollama model
        default:
            // For Ollama, accept any model ID as custom
            .custom(input)
        }
    }

    // MARK: - Model Information

    /// Get available models for a specific provider
    public static func availableModels(for provider: String) -> [String] {
        let normalizedProvider = provider.lowercased()

        switch normalizedProvider {
        case "openai":
            return Model.OpenAI.allCases.compactMap {
                if case .custom = $0 { return nil }
                return $0.modelId
            }
        case "anthropic", "claude":
            return Model.Anthropic.allCases.compactMap {
                if case .custom = $0 { return nil }
                return $0.modelId
            }
        case "grok", "xai":
            return Model.Grok.allCases.compactMap {
                if case .custom = $0 { return nil }
                return $0.modelId
            }
        case "ollama":
            return Model.Ollama.allCases.compactMap {
                if case .custom = $0 { return nil }
                return $0.modelId
            }
        default:
            return []
        }
    }

    /// Get model capabilities for CLI display
    public static func getCapabilities(for model: Model) -> ModelCapabilityInfo {
        ModelCapabilityInfo(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: model.supportsStreaming,
            provider: model.providerName,
            modelId: model.modelId)
    }
}

// MARK: - CLI Helpers

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModelCapabilityInfo {
    public let supportsVision: Bool
    public let supportsTools: Bool
    public let supportsStreaming: Bool
    public let provider: String
    public let modelId: String

    /// Format capabilities for CLI display
    public var description: String {
        var capabilities: [String] = []
        if self.supportsVision { capabilities.append("vision") }
        if self.supportsTools { capabilities.append("tools") }
        if self.supportsStreaming { capabilities.append("streaming") }

        let capabilityString = capabilities.isEmpty ? "basic" : capabilities.joined(separator: ", ")
        return "\(self.provider)/\(self.modelId) (\(capabilityString))"
    }
}

/// Format model list for CLI display
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func formatModelList(title: String, models: [String]) -> String {
    var output = "\n\(title):\n"
    for model in models.sorted() {
        output += "  • \(model)\n"
    }
    return output
}

/// Get all available models for CLI help
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func getAllAvailableModels() -> String {
    var output = "Available Models:\n"

    output += formatModelList(
        title: "OpenAI",
        models: ModelSelector.availableModels(for: "openai"))

    output += formatModelList(
        title: "Anthropic",
        models: ModelSelector.availableModels(for: "anthropic"))

    output += formatModelList(
        title: "Grok (xAI)",
        models: ModelSelector.availableModels(for: "grok"))

    output += formatModelList(
        title: "Ollama",
        models: ModelSelector.availableModels(for: "ollama"))

    output += "\nShortcuts:\n"
    output += "  • claude, claude-opus, opus → claude-opus-4-20250514\n"
    output += "  • gpt, gpt4 → gpt-4.1\n"
    output += "  • grok → grok-4\n"
    output += "  • llama, llama3 → llama3.3\n"

    output += "\nCustom Models:\n"
    output += "  • OpenRouter: anthropic/claude-3.5-sonnet\n"
    output += "  • Custom OpenAI: custom-gpt-model\n"
    output += "  • Local Ollama: any-model:tag\n"

    return output
}

// MARK: - Model Validation

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension ModelSelector {
    /// Validate that a model supports the required capabilities
    public static func validateModel(_ model: Model, requiresVision: Bool = false, requiresTools: Bool = false) throws {
        if requiresVision, !model.supportsVision {
            throw ModelValidationError.visionNotSupported(model.modelId)
        }

        if requiresTools, !model.supportsTools {
            throw ModelValidationError.toolsNotSupported(model.modelId)
        }
    }

    /// Get recommended models for specific use cases
    public static func recommendedModels(for useCase: UseCase) -> [Model] {
        switch useCase {
        case .coding:
            [.claude, .gpt4o, .grok4]
        case .vision:
            [.claude, .gpt4o, .ollama(.llava)]
        case .reasoning:
            [.openai(.o3), .claude, .grok4]
        case .local:
            [.llama, .ollama(.mistralNemo), .ollama(.commandRPlus)]
        case .general:
            [.claude, .gpt4o, .grok4, .llama]
        }
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum UseCase {
    case coding
    case vision
    case reasoning
    case local
    case general
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ModelValidationError: Error, LocalizedError {
    case visionNotSupported(String)
    case toolsNotSupported(String)

    public var errorDescription: String? {
        switch self {
        case let .visionNotSupported(modelId):
            "Model '\(modelId)' does not support vision inputs"
        case let .toolsNotSupported(modelId):
            "Model '\(modelId)' does not support tool calling"
        }
    }
}
