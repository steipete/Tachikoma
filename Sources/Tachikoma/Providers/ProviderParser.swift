import Foundation

/// Utility for parsing AI provider configuration strings and determining default models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum ProviderParser {
    /// Represents a parsed AI provider configuration
    public struct ProviderConfig: Equatable, Sendable {
        /// The provider name (e.g., "openai", "anthropic", "ollama")
        public let provider: String

        /// The model name (e.g., "gpt-4", "claude-3", "llava:latest")
        public let model: String

        /// The full string representation (e.g., "openai/gpt-4")
        public var fullString: String {
            "\(self.provider)/\(self.model)"
        }

        public init(provider: String, model: String) {
            self.provider = provider
            self.model = model
        }
    }

    /// Parse a provider string in the format "provider/model"
    /// - Parameter providerString: String like "openai/gpt-4" or "ollama/llava:latest"
    /// - Returns: Parsed configuration or nil if invalid format
    public static func parse(_ providerString: String) -> ProviderConfig? {
        // Parse a provider string in the format "provider/model"
        let trimmed = providerString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let slashIndex = trimmed.firstIndex(of: "/") else {
            return nil
        }

        let provider = String(trimmed[..<slashIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let model = String(trimmed[trimmed.index(after: slashIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate both parts are non-empty
        guard !provider.isEmpty, !model.isEmpty else {
            return nil
        }

        return ProviderConfig(provider: provider, model: model)
    }

    /// Parse a comma-separated list of providers
    /// - Parameter providersString: String like "openai/gpt-4,anthropic/claude-3,ollama/llava:latest"
    /// - Returns: Array of parsed configurations
    public static func parseList(_ providersString: String) -> [ProviderConfig] {
        // Parse a comma-separated list of providers
        providersString
            .split(separator: ",")
            .compactMap { self.parse(String($0)) }
    }

    /// Get the first provider from a comma-separated list
    /// - Parameter providersString: String like "openai/gpt-4,anthropic/claude-3"
    /// - Returns: First parsed configuration or nil if none valid
    public static func parseFirst(_ providersString: String) -> ProviderConfig? {
        // Get the first provider from a comma-separated list
        self.parseList(providersString).first
    }

    /// Result of determining the default model with conflict information
    public struct ModelDetermination {
        /// The determined language model
        public let model: LanguageModel

        /// Whether there was a conflict between env var and config
        public let hasConflict: Bool

        /// The model from environment variable (if any)
        public let environmentModel: String?

        /// The model from configuration (if any)
        public let configModel: String?

        public init(
            model: LanguageModel,
            hasConflict: Bool,
            environmentModel: String? = nil,
            configModel: String? = nil,
        ) {
            self.model = model
            self.hasConflict = hasConflict
            self.environmentModel = environmentModel
            self.configModel = configModel
        }
    }

    /// Determine the default model based on available providers and API keys
    /// - Parameters:
    ///   - providersString: The AI_PROVIDERS string (e.g., from TACHIKOMA_AI_PROVIDERS env var)
    ///   - hasOpenAI: Whether OpenAI API key is available
    ///   - hasAnthropic: Whether Anthropic API key is available
    ///   - hasGrok: Whether Grok API key is available
    ///   - hasOllama: Whether Ollama is available (always true as it doesn't require API key)
    ///   - configuredDefault: Optional default from configuration
    ///   - isEnvironmentProvided: Whether the providers string came from environment variable
    /// - Returns: Model determination result with conflict information
    public static func determineDefaultModelWithConflict(
        from providersString: String,
        hasOpenAI: Bool,
        hasAnthropic: Bool,
        hasGrok: Bool = false,
        hasOllama: Bool = true,
        configuredDefault: LanguageModel? = nil,
        isEnvironmentProvided: Bool = false,
    )
        -> ModelDetermination
    {
        // Parse providers and find first available one
        let providers = self.parseList(providersString)
        var environmentModel: LanguageModel?

        for config in providers {
            switch config.provider.lowercased() {
            case "openai" where hasOpenAI:
                environmentModel = self.parseOpenAIModel(config.model)
            case "anthropic" where hasAnthropic:
                environmentModel = self.parseAnthropicModel(config.model)
            case "google", "gemini":
                environmentModel = self.parseGoogleModel(config.model)
            case "grok" where hasGrok, "xai" where hasGrok:
                environmentModel = self.parseGrokModel(config.model)
            case "ollama" where hasOllama:
                environmentModel = self.parseOllamaModel(config.model)
            default:
                continue
            }
            if environmentModel != nil { break }
        }

        // Determine if there's a conflict
        let hasConflict = isEnvironmentProvided &&
            environmentModel != nil &&
            configuredDefault != nil &&
            !self.modelsAreEqual(environmentModel, configuredDefault)

        // Environment variable takes precedence over config
        let finalModel: LanguageModel = if let envModel = environmentModel, isEnvironmentProvided {
            envModel
        } else if let configuredDefault {
            configuredDefault
        } else if let envModel = environmentModel {
            // Use the first available provider from the list even when not from environment
            envModel
        } else {
            // Fall back to defaults based on available API keys
            self.getDefaultFallbackModel(
                hasOpenAI: hasOpenAI,
                hasAnthropic: hasAnthropic,
                hasGrok: hasGrok,
                hasOllama: hasOllama,
            )
        }

        return ModelDetermination(
            model: finalModel,
            hasConflict: hasConflict,
            environmentModel: environmentModel?.description,
            configModel: configuredDefault?.description,
        )
    }

    /// Determine the default model based on available providers and API keys (simple version)
    public static func determineDefaultModel(
        from providersString: String,
        hasOpenAI: Bool,
        hasAnthropic: Bool,
        hasGrok: Bool = false,
        hasOllama: Bool = true,
        configuredDefault: LanguageModel? = nil,
    )
        -> LanguageModel
    {
        // Determine the default model based on available providers and API keys (simple version)
        let determination = self.determineDefaultModelWithConflict(
            from: providersString,
            hasOpenAI: hasOpenAI,
            hasAnthropic: hasAnthropic,
            hasGrok: hasGrok,
            hasOllama: hasOllama,
            configuredDefault: configuredDefault,
            isEnvironmentProvided: false,
        )
        return determination.model
    }

    /// Extract provider name from a full provider/model string
    public static func extractProvider(from fullString: String) -> String? {
        // Extract provider name from a full provider/model string
        self.parse(fullString)?.provider
    }

    /// Extract model name from a full provider/model string
    public static func extractModel(from fullString: String) -> String? {
        // Extract model name from a full provider/model string
        self.parse(fullString)?.model
    }

    // MARK: - Private Helpers

    private static func parseOpenAIModel(_ modelString: String) -> LanguageModel? {
        switch modelString.lowercased() {
        case "o4-mini": .openai(.o4Mini)
        case "gpt-5.2", "gpt5.2", "gpt-5-2", "gpt5-2", "gpt52": .openai(.gpt52)
        case "gpt-5.2-mini", "gpt5.2-mini", "gpt-5-2-mini", "gpt5-2-mini", "gpt52-mini", "gpt52mini":
            .openai(.gpt5Mini)
        case "gpt-5.2-nano", "gpt5.2-nano", "gpt-5-2-nano", "gpt5-2-nano", "gpt52-nano", "gpt52nano":
            .openai(.gpt5Nano)
        case "gpt-5.1", "gpt5.1", "gpt-5-1", "gpt5-1", "gpt51": .openai(.gpt51)
        case "gpt-5.1-mini", "gpt5.1-mini", "gpt-5-1-mini", "gpt5-1-mini", "gpt51-mini", "gpt51mini":
            .openai(.gpt5Mini)
        case "gpt-5.1-nano", "gpt5.1-nano", "gpt-5-1-nano", "gpt5-1-nano", "gpt51-nano", "gpt51nano":
            .openai(.gpt5Nano)
        case "gpt-5", "gpt5": .openai(.gpt5)
        case "gpt-5-pro", "gpt5-pro", "gpt5pro": .openai(.gpt5Pro)
        case "gpt-5-mini", "gpt5-mini", "gpt5mini": .openai(.gpt5Mini)
        case "gpt-5-nano", "gpt5-nano", "gpt5nano": .openai(.gpt5Nano)
        case "gpt-5-thinking", "gpt5-thinking", "gpt5thinking": .openai(.gpt5Thinking)
        case "gpt-5-thinking-mini", "gpt5-thinking-mini", "gpt5thinkingmini": .openai(.gpt5ThinkingMini)
        case "gpt-5-thinking-nano", "gpt5-thinking-nano", "gpt5thinkingnano": .openai(.gpt5ThinkingNano)
        case "gpt-5-chat-latest", "gpt5-chat-latest": .openai(.gpt5ChatLatest)
        case "gpt-4.1", "gpt4.1": .openai(.gpt41)
        case "gpt-4.1-mini", "gpt4.1-mini": .openai(.gpt41Mini)
        case "gpt-4o", "gpt4o": .openai(.gpt4o)
        case "gpt-4o-mini", "gpt4o-mini": .openai(.gpt4oMini)
        case "gpt-4-turbo", "gpt4-turbo": .openai(.gpt4Turbo)
        case "gpt-3.5-turbo", "gpt35-turbo": .openai(.gpt35Turbo)
        default:
            // Handle custom/fine-tuned models
            .openai(.custom(modelString))
        }
    }

    private static func parseAnthropicModel(_ modelString: String) -> LanguageModel? {
        switch modelString.lowercased() {
        case "claude-opus-4-5", "claude-opus-4.5", "claude-opus-4-5-latest", "opus-4-5", "opus-4.5", "opus45":
            .anthropic(.opus45)
        case "claude-opus-4-1-20250805", "claude-opus-4-20250514", "claude-opus-4", "opus-4": .anthropic(.opus4)
        case "claude-opus-4-1-20250805-thinking", "claude-opus-4-20250514-thinking", "claude-opus-4-thinking",
             "opus-4-thinking": .anthropic(.opus4Thinking)
        case "claude-sonnet-4-20250514", "claude-sonnet-4", "sonnet-4": .anthropic(.sonnet4)
        case "claude-sonnet-4-20250514-thinking", "claude-sonnet-4-thinking",
             "sonnet-4-thinking": .anthropic(.sonnet4Thinking)
        default:
            // Handle custom models
            .anthropic(.custom(modelString))
        }
    }

    private static func parseGoogleModel(_ modelString: String) -> LanguageModel? {
        switch modelString.lowercased() {
        case "gemini-3-flash", "gemini-3-flash-preview", "gemini3flash", "gemini-3flash":
            .google(.gemini3Flash)
        case "gemini-2.5-pro", "gemini25pro", "gemini2.5pro":
            .google(.gemini25Pro)
        case "gemini-2.5-flash", "gemini25flash":
            .google(.gemini25Flash)
        case "gemini-2.5-flash-lite", "gemini25flashlite", "gemini-2.5-flashlite":
            .google(.gemini25FlashLite)
        case "gemini":
            .google(.gemini3Flash)
        default:
            nil
        }
    }

    private static func parseGrokModel(_ modelString: String) -> LanguageModel? {
        switch modelString.lowercased() {
        case "grok-4-0709": .grok(.grok4)
        case "grok-4-fast-reasoning": .grok(.grok4FastReasoning)
        case "grok-4-fast-non-reasoning": .grok(.grok4FastNonReasoning)
        case "grok-code-fast-1": .grok(.grokCodeFast1)
        case "grok-3", "grok3": .grok(.grok3)
        case "grok-3-mini": .grok(.grok3Mini)
        case "grok-2-1212": .grok(.grok2)
        case "grok-2-vision-1212": .grok(.grok2Vision)
        case "grok-2-image-1212": .grok(.grok2Image)
        case "grok-vision-beta": .grok(.grokVisionBeta)
        case "grok-beta": .grok(.grokBeta)
        default:
            .grok(.custom(modelString))
        }
    }

    private static func parseOllamaModel(_ modelString: String) -> LanguageModel? {
        switch modelString.lowercased() {
        // GPT-OSS models
        case "gpt-oss:120b", "gpt-oss-120b": .ollama(.gptOSS120B)
        case "gpt-oss:20b", "gpt-oss-20b": .ollama(.gptOSS20B)
        // Quantized versions removed - not defined in model enum
        // Llama models
        case "llama3.3", "llama3.3:latest": .ollama(.llama33)
        case "llama3.2", "llama3.2:latest": .ollama(.llama32)
        case "llama3.1", "llama3.1:latest": .ollama(.llama31)
        case "llava", "llava:latest": .ollama(.llava)
        case "llava:13b": .ollama(.custom("llava:13b"))
        case "llava:34b": .ollama(.custom("llava:34b"))
        case "mistral-nemo", "mistral-nemo:latest": .ollama(.mistralNemo)
        case "qwen2.5", "qwen2.5:latest": .ollama(.qwen25)
        case "codellama", "codellama:latest": .ollama(.codellama)
        default:
            .ollama(.custom(modelString))
        }
    }

    private static func getDefaultFallbackModel(
        hasOpenAI: Bool,
        hasAnthropic: Bool,
        hasGrok: Bool,
        hasOllama _: Bool,
    )
        -> LanguageModel
    {
        if hasAnthropic {
            .anthropic(.opus4)
        } else if hasOpenAI {
            .openai(.gpt5Mini)
        } else if hasGrok {
            .grok(.grok4FastReasoning)
        } else {
            .ollama(.llama33)
        }
    }

    private static func modelsAreEqual(_ model1: LanguageModel?, _ model2: LanguageModel?) -> Bool {
        guard let model1, let model2 else { return false }
        return model1.description == model2.description
    }
}
