import Foundation

// MARK: - CLI Model Selection

/// Smart model parsing and selection for command-line interfaces
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ModelSelector {
    /// Parse a model string with intelligent fallbacks and shortcuts
    public static func parseModel(_ modelString: String) throws -> Model {
        // Parse a model string with intelligent fallbacks and shortcuts
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

        // Google shortcuts and models
        if let googleModel = parseGoogleModel(normalized) {
            return .google(googleModel)
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
        // GPT-5.2 models
        case "gpt-5.2", "gpt5.2", "gpt-5-2", "gpt5-2", "gpt52":
            return .gpt52
        case "gpt-5.2-mini", "gpt5.2-mini", "gpt52-mini", "gpt52mini", "gpt-5-2-mini", "gpt5-2-mini":
            return .gpt5Mini
        case "gpt-5.2-nano", "gpt5.2-nano", "gpt52-nano", "gpt52nano", "gpt-5-2-nano", "gpt5-2-nano":
            return .gpt5Nano
        // GPT-5.1 models (latest)
        case "gpt-5.1", "gpt5.1", "gpt-5-1", "gpt5-1", "gpt51":
            return .gpt51
        case "gpt-5.1-mini", "gpt5.1-mini", "gpt51-mini", "gpt51mini", "gpt-5-1-mini", "gpt5-1-mini":
            return .gpt5Mini
        case "gpt-5.1-nano", "gpt5.1-nano", "gpt51-nano", "gpt51nano", "gpt-5-1-nano", "gpt5-1-nano":
            return .gpt5Nano
        // GPT-5 models
        case "gpt-5", "gpt5":
            return .gpt5
        case "gpt-5-pro", "gpt5-pro", "gpt5pro":
            return .gpt5Pro
        case "gpt-5-mini", "gpt5-mini", "gpt5mini":
            return .gpt5Mini
        case "gpt-5-nano", "gpt5-nano", "gpt5nano":
            return .gpt5Nano
        case "gpt-5-thinking", "gpt5-thinking", "gpt5thinking":
            return .gpt5Thinking
        case "gpt-5-thinking-mini", "gpt5-thinking-mini", "gpt5thinkingmini":
            return .gpt5ThinkingMini
        case "gpt-5-thinking-nano", "gpt5-thinking-nano", "gpt5thinkingnano":
            return .gpt5ThinkingNano
        case "gpt-5-chat-latest", "gpt5-chat-latest":
            return .gpt5ChatLatest
        // Direct matches
        case "gpt-4o", "gpt4o":
            return .gpt4o
        case "gpt-4o-mini", "gpt4o-mini", "gpt4omini":
            return .gpt4oMini
        case "gpt-4.1", "gpt4.1", "gpt41":
            return .gpt41
        case "gpt-4.1-mini", "gpt4.1-mini", "gpt41mini":
            return .gpt41Mini
        case "o4-mini", "o4mini":
            return .o4Mini
        // Shortcuts
        case "gpt":
            return .gpt51 // Default to flagship GPT-5.1
        case "gpt4", "gpt-4":
            return .gpt4o // Default to latest GPT-4 variant
        case "openai":
            return .gpt51 // Default to GPT-5.1
        default:
            // Check if it's an OpenAI model ID
            if input.hasPrefix("gpt") || input.hasPrefix("o4") {
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
        case "claude-opus-4-5", "claude-opus-4.5", "opus-4-5", "opus-4.5", "opus45":
            return .opus45
        case "claude-sonnet-4-20250514":
            return .sonnet4
        case "claude-sonnet-4-20250514-thinking":
            return .sonnet4Thinking
        case "claude-sonnet-4-5-20250929", "claude-sonnet-4.5":
            return .sonnet45
        // Shortcuts
        case "claude":
            return .sonnet45 // Default plain Claude alias to latest Sonnet
        case "claude-opus", "opus":
            return .opus45
        case "claude-sonnet", "sonnet":
            return .sonnet4
        case "claude-haiku", "haiku":
            return .haiku45
        case "anthropic":
            return .opus45 // Default Anthropic model
        default:
            // Check if it's a Claude model ID
            if input.hasPrefix("claude") {
                return .custom(input)
            }
            return nil
        }
    }

    private static func parseGoogleModel(_ input: String) -> Model.Google? {
        switch input {
        case "gemini-3-flash", "gemini-3-flash-preview", "gemini3flash", "gemini-3flash":
            .gemini3Flash
        case "gemini-2.5-pro", "gemini25pro", "gemini2.5pro":
            .gemini25Pro
        case "gemini-2.5-flash", "gemini25flash":
            .gemini25Flash
        case "gemini-2.5-flash-lite", "gemini25flashlite", "gemini-2.5-flashlite":
            .gemini25FlashLite
        case "gemini":
            .gemini3Flash
        case "google":
            .gemini25Pro
        default:
            nil
        }
    }

    private static func parseGrokModel(_ input: String) -> Model.Grok? {
        switch input {
        // Direct matches for available models only
        case "grok-4-0709":
            return .grok4
        case "grok-4-fast-reasoning":
            return .grok4FastReasoning
        case "grok-4-fast-non-reasoning":
            return .grok4FastNonReasoning
        case "grok-code-fast-1":
            return .grokCodeFast1
        case "grok-3", "grok3":
            return .grok3
        case "grok-3-mini":
            return .grok3Mini
        case "grok-2-1212", "grok-2":
            return .grok2
        case "grok-2-vision-1212":
            return .grok2Vision
        case "grok-2-image-1212":
            return .grok2Image
        case "grok-vision-beta":
            return .grokVisionBeta
        case "grok-beta":
            return .grokBeta
        // Shortcuts
        case "grok":
            return .grok4FastReasoning // Default to the latest fast Grok model
        case "xai":
            return .grok3 // Default xAI model
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
            .llama33
        case "llama3.2", "llama3.2:latest":
            .llama32
        case "llama3.1", "llama3.1:latest":
            .llama31
        case "llava", "llava:latest":
            .llava
        case "bakllava", "bakllava:latest":
            .bakllava
        case "llama3.2-vision:11b":
            .llama32Vision11b
        case "llama3.2-vision:90b":
            .llama32Vision90b
        case "qwen2.5vl:7b":
            .qwen25vl7b
        case "qwen2.5vl:32b":
            .qwen25vl32b
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
            .deepseekR18b
        case "deepseek-r1:671b":
            .deepseekR1671b
        case "firefunction-v2", "firefunction-v2:latest":
            .firefunction
        case "command-r", "command-r:latest":
            .commandR
        case "command-r-plus", "command-r-plus:latest":
            .commandRPlus
        // Shortcuts
        case "llama", "llama3":
            .llama33 // Default to latest Llama
        case "ollama":
            .llama33 // Default Ollama model
        default:
            // For Ollama, accept any model ID as custom
            .custom(input)
        }
    }

    // MARK: - Model Information

    /// Get available models for a specific provider
    public static func availableModels(for provider: String) -> [String] {
        // Get available models for a specific provider
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
        case "google", "gemini":
            return Model.Google.allCases.map(\.userFacingModelId)
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
        // Get model capabilities for CLI display
        ModelCapabilityInfo(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: model.supportsStreaming,
            provider: model.providerName,
            modelId: model.modelId,
        )
    }
}

// MARK: - CLI Helpers

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
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
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func formatModelList(title: String, models: [String]) -> String {
    var output = "\n\(title):\n"
    for model in models.sorted() {
        output += "  • \(model)\n"
    }
    return output
}

/// Get all available models for CLI help
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func getAllAvailableModels() -> String {
    var output = "Available Models:\n"

    output += formatModelList(
        title: "OpenAI",
        models: ModelSelector.availableModels(for: "openai"),
    )

    output += formatModelList(
        title: "Anthropic",
        models: ModelSelector.availableModels(for: "anthropic"),
    )

    output += formatModelList(
        title: "Google",
        models: ModelSelector.availableModels(for: "google"),
    )

    output += formatModelList(
        title: "Grok (xAI)",
        models: ModelSelector.availableModels(for: "grok"),
    )

    output += formatModelList(
        title: "Ollama",
        models: ModelSelector.availableModels(for: "ollama"),
    )

    output += "\nShortcuts:\n"
    output += "  • claude, claude-opus, opus → claude-opus-4-20250514\n"
    output += "  • gpt, gpt4 → gpt-4.1\n"
    output += "  • gemini → gemini-3-flash\n"
    output += "  • grok → grok-4-fast-reasoning\n"
    output += "  • llama, llama3 → llama3.3\n"

    output += "\nCustom Models:\n"
    output += "  • OpenRouter: anthropic/claude-3.5-sonnet\n"
    output += "  • Custom OpenAI: custom-gpt-model\n"
    output += "  • Local Ollama: any-model:tag\n"

    return output
}

// MARK: - Model Validation

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension ModelSelector {
    /// Validate that a model supports the required capabilities
    public static func validateModel(_ model: Model, requiresVision: Bool = false, requiresTools: Bool = false) throws {
        // Validate that a model supports the required capabilities
        if requiresVision, !model.supportsVision {
            throw ModelValidationError.visionNotSupported(model.modelId)
        }

        if requiresTools, !model.supportsTools {
            throw ModelValidationError.toolsNotSupported(model.modelId)
        }
    }

    /// Get recommended models for specific use cases
    public static func recommendedModels(for useCase: UseCase) -> [Model] {
        // Get recommended models for specific use cases
        switch useCase {
        case .coding:
            [.claude, .gpt4o, .google(.gemini25Pro)]
        case .vision:
            [.claude, .gpt4o, .google(.gemini3Flash)]
        case .reasoning:
            [.openai(.gpt5Mini), .claude, .google(.gemini25Pro)]
        case .local:
            [.llama, .ollama(.mistralNemo), .ollama(.commandRPlus)]
        case .general:
            [.claude, .gpt4o, .google(.gemini3Flash), .grok(.grok4FastReasoning), .llama]
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum UseCase {
    case coding
    case vision
    case reasoning
    case local
    case general
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
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
