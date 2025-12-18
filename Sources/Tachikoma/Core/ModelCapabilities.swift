import Foundation

// MARK: - Model Parameter Capabilities

/// Defines complete capabilities of a model including parameter support and provider options
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ModelParameterCapabilities: Sendable {
    // MARK: Universal Parameter Support

    public var supportsTemperature: Bool = true
    public var supportsTopP: Bool = true
    public var supportsTopK: Bool = false
    public var supportsMaxTokens: Bool = true
    public var supportsStopSequences: Bool = true
    public var supportsFrequencyPenalty: Bool = true
    public var supportsPresencePenalty: Bool = true
    public var supportsSeed: Bool = false

    // MARK: Parameter Constraints

    public var temperatureRange: ClosedRange<Double>? = 0...2
    public var maxTokenLimit: Int?

    // MARK: Provider-Specific Capabilities

    public var supportedProviderOptions: SupportedProviderOptions = .init()

    // MARK: Special Behaviors

    /// Parameters that are forced to specific values (e.g., O1 forces temperature=1)
    public var forcedTemperature: Double?

    /// Parameters that should be excluded entirely (e.g., GPT-5 excludes temperature)
    public var excludedParameters: Set<String> = []

    public init(
        supportsTemperature: Bool = true,
        supportsTopP: Bool = true,
        supportsTopK: Bool = false,
        supportsMaxTokens: Bool = true,
        supportsStopSequences: Bool = true,
        supportsFrequencyPenalty: Bool = true,
        supportsPresencePenalty: Bool = true,
        supportsSeed: Bool = false,
        temperatureRange: ClosedRange<Double>? = 0...2,
        maxTokenLimit: Int? = nil,
        supportedProviderOptions: SupportedProviderOptions = .init(),
        forcedTemperature: Double? = nil,
        excludedParameters: Set<String> = [],
    ) {
        self.supportsTemperature = supportsTemperature
        self.supportsTopP = supportsTopP
        self.supportsTopK = supportsTopK
        self.supportsMaxTokens = supportsMaxTokens
        self.supportsStopSequences = supportsStopSequences
        self.supportsFrequencyPenalty = supportsFrequencyPenalty
        self.supportsPresencePenalty = supportsPresencePenalty
        self.supportsSeed = supportsSeed
        self.temperatureRange = temperatureRange
        self.maxTokenLimit = maxTokenLimit
        self.supportedProviderOptions = supportedProviderOptions
        self.forcedTemperature = forcedTemperature
        self.excludedParameters = excludedParameters
    }
}

// MARK: - Supported Provider Options

/// Defines which provider-specific options a model supports
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct SupportedProviderOptions: Sendable {
    // MARK: OpenAI Options

    public var supportsParallelToolCalls: Bool = false
    public var supportsResponseFormat: Bool = false
    public var supportsVerbosity: Bool = false
    public var supportsReasoningEffort: Bool = false
    public var supportsPreviousResponseId: Bool = false
    public var supportsLogprobs: Bool = false

    // MARK: Anthropic Options

    public var supportsThinking: Bool = false
    public var supportsCacheControl: Bool = false

    // MARK: Google Options

    public var supportsThinkingConfig: Bool = false
    public var supportsSafetySettings: Bool = false

    // MARK: Mistral Options

    public var supportsSafeMode: Bool = false

    // MARK: Groq Options

    public var supportsSpeedLevel: Bool = false

    // MARK: Grok Options

    public var supportsFunMode: Bool = false
    public var supportsCurrentEvents: Bool = false

    public init(
        supportsParallelToolCalls: Bool = false,
        supportsResponseFormat: Bool = false,
        supportsVerbosity: Bool = false,
        supportsReasoningEffort: Bool = false,
        supportsPreviousResponseId: Bool = false,
        supportsLogprobs: Bool = false,
        supportsThinking: Bool = false,
        supportsCacheControl: Bool = false,
        supportsThinkingConfig: Bool = false,
        supportsSafetySettings: Bool = false,
        supportsSafeMode: Bool = false,
        supportsSpeedLevel: Bool = false,
        supportsFunMode: Bool = false,
        supportsCurrentEvents: Bool = false,
    ) {
        self.supportsParallelToolCalls = supportsParallelToolCalls
        self.supportsResponseFormat = supportsResponseFormat
        self.supportsVerbosity = supportsVerbosity
        self.supportsReasoningEffort = supportsReasoningEffort
        self.supportsPreviousResponseId = supportsPreviousResponseId
        self.supportsLogprobs = supportsLogprobs
        self.supportsThinking = supportsThinking
        self.supportsCacheControl = supportsCacheControl
        self.supportsThinkingConfig = supportsThinkingConfig
        self.supportsSafetySettings = supportsSafetySettings
        self.supportsSafeMode = supportsSafeMode
        self.supportsSpeedLevel = supportsSpeedLevel
        self.supportsFunMode = supportsFunMode
        self.supportsCurrentEvents = supportsCurrentEvents
    }
}

// MARK: - Model Capability Registry

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class ModelCapabilityRegistry: @unchecked Sendable {
    public static let shared = ModelCapabilityRegistry()

    private var capabilities: [String: ModelParameterCapabilities] = [:]
    private let lock = NSLock()

    private init() {
        self.registerDefaultCapabilities()
    }

    /// Get capabilities for a model
    public func capabilities(for model: LanguageModel) -> ModelParameterCapabilities {
        // Get capabilities for a model
        let key = self.capabilityKey(for: model)

        self.lock.lock()
        defer { lock.unlock() }

        // Check for registered capabilities
        if let registered = capabilities[key] {
            return registered
        }

        // Return default based on model type
        return self.defaultCapabilities(for: model)
    }

    /// Register custom capabilities for a model
    public func register(_ capabilities: ModelParameterCapabilities, for model: LanguageModel) {
        // Register custom capabilities for a model
        let key = self.capabilityKey(for: model)

        self.lock.lock()
        defer { lock.unlock() }

        self.capabilities[key] = capabilities
    }

    /// Register capabilities for an OpenAI-compatible endpoint
    public func registerOpenAICompatible(endpoint: String, capabilities: ModelParameterCapabilities) {
        // Register capabilities for an OpenAI-compatible endpoint
        let key = "openai-compatible:\(endpoint):default"

        self.lock.lock()
        defer { lock.unlock() }

        self.capabilities[key] = capabilities
    }

    // MARK: - Private Helpers

    private func capabilityKey(for model: LanguageModel) -> String {
        switch model {
        case let .openai(submodel):
            "openai:\(submodel.modelId)"
        case let .anthropic(submodel):
            "anthropic:\(submodel.modelId)"
        case let .google(submodel):
            "google:\(submodel.rawValue)"
        case let .mistral(submodel):
            "mistral:\(submodel.rawValue)"
        case let .groq(submodel):
            "groq:\(submodel.rawValue)"
        case let .grok(submodel):
            "grok:\(submodel.modelId)"
        case let .ollama(submodel):
            "ollama:\(submodel.modelId)"
        case let .lmstudio(submodel):
            "lmstudio:\(submodel.modelId)"
        case let .openRouter(modelId):
            "openrouter:\(modelId)"
        case let .together(modelId):
            "together:\(modelId)"
        case let .replicate(modelId):
            "replicate:\(modelId)"
        case let .openaiCompatible(endpoint, modelId):
            "openai-compatible:\(endpoint):\(modelId)"
        case let .anthropicCompatible(endpoint, modelId):
            "anthropic-compatible:\(endpoint):\(modelId)"
        case let .azureOpenAI(deployment, resource, apiVersion, endpoint):
            "azure-openai:\(endpoint ?? resource ?? "resource"):\(deployment):\(apiVersion ?? "")"
        case let .custom(provider):
            "custom:\(provider.modelId)"
        }
    }

    private func registerDefaultCapabilities() {
        // GPT-5 Series (Responses API only, no temperature/topP)
        let gpt5Capabilities = ModelParameterCapabilities(
            supportsTemperature: false,
            supportsTopP: false,
            supportsFrequencyPenalty: false,
            supportsPresencePenalty: false,
            supportedProviderOptions: .init(
                supportsVerbosity: true,
                supportsPreviousResponseId: true,
            ),
            excludedParameters: ["temperature", "topP", "frequencyPenalty", "presencePenalty"],
        )

        self.capabilities["openai:gpt-5.1"] = gpt5Capabilities
        self.capabilities["openai:gpt-5.2"] = gpt5Capabilities
        self.capabilities["openai:gpt-5"] = gpt5Capabilities
        self.capabilities["openai:gpt-5-pro"] = gpt5Capabilities
        self.capabilities["openai:gpt-5-mini"] = gpt5Capabilities
        self.capabilities["openai:gpt-5-nano"] = gpt5Capabilities
        self.capabilities["openai:gpt-5-thinking"] = gpt5Capabilities
        self.capabilities["openai:gpt-5-thinking-mini"] = gpt5Capabilities
        self.capabilities["openai:gpt-5-thinking-nano"] = gpt5Capabilities
        self.capabilities["openai:gpt-5-chat-latest"] = gpt5Capabilities

        // O4/GPT-5 reasoning models (fixed temperature, reasoning effort)
        let reasoningCapabilities = ModelParameterCapabilities(
            supportsTemperature: false,
            supportsTopP: false,
            supportedProviderOptions: .init(
                supportsReasoningEffort: true,
                supportsPreviousResponseId: true,
            ),
            forcedTemperature: 1.0,
            excludedParameters: ["temperature", "topP"],
        )

        self.capabilities["openai:o4"] = reasoningCapabilities
        self.capabilities["openai:o4-mini"] = reasoningCapabilities

        // Standard GPT-4 models
        let gpt4Capabilities = ModelParameterCapabilities(
            supportedProviderOptions: .init(
                supportsParallelToolCalls: true,
                supportsResponseFormat: true,
                supportsLogprobs: true,
            ),
        )

        self.capabilities["openai:gpt-4o"] = gpt4Capabilities
        self.capabilities["openai:gpt-4o-mini"] = gpt4Capabilities
        self.capabilities["openai:gpt-4.1"] = gpt4Capabilities
        self.capabilities["openai:gpt-4.1-mini"] = gpt4Capabilities
        self.capabilities["openai:gpt-4-turbo"] = gpt4Capabilities

        // Claude 4 models with thinking
        let claude4Capabilities = ModelParameterCapabilities(
            supportedProviderOptions: .init(
                supportsThinking: true,
                supportsCacheControl: true,
            ),
        )

        self.capabilities["anthropic:claude-opus-4-5"] = claude4Capabilities
        self.capabilities["anthropic:claude-opus-4-1-20250805"] = claude4Capabilities
        self.capabilities["anthropic:claude-sonnet-4-20250514"] = claude4Capabilities
        self.capabilities["anthropic:claude-sonnet-4-5-20250929"] = claude4Capabilities
        self.capabilities["anthropic:claude-haiku-4.5"] = claude4Capabilities

        // Google Gemini with thinking
        let geminiCapabilities = ModelParameterCapabilities(
            supportsTopK: true,
            supportedProviderOptions: .init(
                supportsThinkingConfig: true,
                supportsSafetySettings: true,
            ),
        )

        self.capabilities["google:gemini-2.5-pro"] = geminiCapabilities
        self.capabilities["google:gemini-2.5-flash"] = geminiCapabilities
        self.capabilities["google:gemini-2.5-flash-lite"] = geminiCapabilities
        self.capabilities["google:gemini-3-flash"] = geminiCapabilities
        self.capabilities["google:gemini-3-flash-preview"] = geminiCapabilities

        // Mistral models
        let mistralCapabilities = ModelParameterCapabilities(
            supportedProviderOptions: .init(
                supportsSafeMode: true,
            ),
        )

        self.capabilities["mistral:mistral-large-2"] = mistralCapabilities
        self.capabilities["mistral:codestral"] = mistralCapabilities

        // Groq models (ultra-fast inference)
        let groqCapabilities = ModelParameterCapabilities(
            supportedProviderOptions: .init(
                supportsSpeedLevel: true,
            ),
        )

        self.capabilities["groq:llama-3.1-70b"] = groqCapabilities
        self.capabilities["groq:llama-3.1-8b"] = groqCapabilities
        self.capabilities["groq:llama-3-70b"] = groqCapabilities
        self.capabilities["groq:llama-3-8b"] = groqCapabilities
        self.capabilities["groq:mixtral-8x7b"] = groqCapabilities
        self.capabilities["groq:gemma2-9b"] = groqCapabilities

        // Grok models
        let grokCapabilities = ModelParameterCapabilities(
            supportedProviderOptions: .init(
                supportsFunMode: true,
                supportsCurrentEvents: true,
            ),
        )

        self.capabilities["grok:grok-4-0709"] = grokCapabilities
        self.capabilities["grok:grok-4-fast-reasoning"] = grokCapabilities
        self.capabilities["grok:grok-4-fast-non-reasoning"] = grokCapabilities
        self.capabilities["grok:grok-code-fast-1"] = grokCapabilities
        self.capabilities["grok:grok-3"] = grokCapabilities
        self.capabilities["grok:grok-3-mini"] = grokCapabilities
        self.capabilities["grok:grok-2-1212"] = grokCapabilities
        self.capabilities["grok:grok-2-vision-1212"] = grokCapabilities
        self.capabilities["grok:grok-2-image-1212"] = grokCapabilities
        self.capabilities["grok:grok-vision-beta"] = grokCapabilities
        self.capabilities["grok:grok-beta"] = grokCapabilities
    }

    private func defaultCapabilities(for model: LanguageModel) -> ModelParameterCapabilities {
        // Check if we have registered capabilities for this specific model
        let key = self.capabilityKey(for: model)
        if let registered = capabilities[key] {
            return registered
        }

        // Return provider-based defaults
        switch model {
        case .openai:
            // Default OpenAI capabilities
            return ModelParameterCapabilities()

        case .anthropic:
            // Default Anthropic capabilities
            return ModelParameterCapabilities(
                supportedProviderOptions: .init(
                    supportsCacheControl: true,
                ),
            )

        case .google:
            // Default Google capabilities
            return ModelParameterCapabilities(
                supportsTopK: true,
                supportedProviderOptions: .init(
                    supportsSafetySettings: true,
                ),
            )

        case .ollama, .lmstudio:
            // Local models - basic capabilities
            return ModelParameterCapabilities(
                supportsSeed: true,
            )

        default:
            // Default capabilities for unknown models
            return ModelParameterCapabilities()
        }
    }
}

// MARK: - GenerationSettings Extension

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension GenerationSettings {
    /// Validates and adjusts settings based on model capabilities
    public func validated(for model: LanguageModel) -> GenerationSettings {
        // Validates and adjusts settings based on model capabilities
        let capabilities = ModelCapabilityRegistry.shared.capabilities(for: model)

        var adjustedTemperature = temperature
        var adjustedTopP = topP
        var adjustedFrequencyPenalty = frequencyPenalty
        var adjustedPresencePenalty = presencePenalty
        var adjustedProviderOptions = providerOptions

        // Handle excluded parameters
        if capabilities.excludedParameters.contains("temperature") {
            adjustedTemperature = nil
        }
        if capabilities.excludedParameters.contains("topP") {
            adjustedTopP = nil
        }
        if capabilities.excludedParameters.contains("frequencyPenalty") {
            adjustedFrequencyPenalty = nil
        }
        if capabilities.excludedParameters.contains("presencePenalty") {
            adjustedPresencePenalty = nil
        }

        // Apply forced temperature
        if let forcedTemp = capabilities.forcedTemperature {
            adjustedTemperature = forcedTemp
        }

        // Validate provider options
        adjustedProviderOptions = self.validateProviderOptions(
            adjustedProviderOptions,
            capabilities: capabilities,
            model: model,
        )

        return GenerationSettings(
            maxTokens: maxTokens,
            temperature: adjustedTemperature,
            topP: adjustedTopP,
            topK: topK,
            frequencyPenalty: adjustedFrequencyPenalty,
            presencePenalty: adjustedPresencePenalty,
            stopSequences: stopSequences,
            reasoningEffort: reasoningEffort,
            stopConditions: stopConditions,
            seed: seed,
            providerOptions: adjustedProviderOptions,
        )
    }

    private func validateProviderOptions(
        _ options: ProviderOptions,
        capabilities: ModelParameterCapabilities,
        model: LanguageModel,
    )
        -> ProviderOptions
    {
        var validated = options
        let supported = capabilities.supportedProviderOptions

        // Only validate options for the current provider
        // Other provider options are kept as-is for flexibility

        // Validate OpenAI options only for OpenAI models
        if case .openai = model, let openaiOpts = options.openai {
            var validatedOpenAI = openaiOpts

            if !supported.supportsVerbosity {
                validatedOpenAI.verbosity = nil
            }
            if !supported.supportsReasoningEffort {
                validatedOpenAI.reasoningEffort = nil
            }
            if !supported.supportsParallelToolCalls {
                validatedOpenAI.parallelToolCalls = nil
            }
            if !supported.supportsResponseFormat {
                validatedOpenAI.responseFormat = nil
            }
            if !supported.supportsPreviousResponseId {
                validatedOpenAI.previousResponseId = nil
            }
            if !supported.supportsLogprobs {
                validatedOpenAI.logprobs = nil
                validatedOpenAI.topLogprobs = nil
            }

            validated.openai = validatedOpenAI
        }

        // Validate Anthropic options only for Anthropic models
        if case .anthropic = model, let anthropicOpts = options.anthropic {
            var validatedAnthropic = anthropicOpts

            if !supported.supportsThinking {
                validatedAnthropic.thinking = nil
            }
            if !supported.supportsCacheControl {
                validatedAnthropic.cacheControl = nil
            }

            validated.anthropic = validatedAnthropic
        }

        // Validate Google options only for Google models
        if case .google = model, let googleOpts = options.google {
            var validatedGoogle = googleOpts

            if !supported.supportsThinkingConfig {
                validatedGoogle.thinkingConfig = nil
            }
            if !supported.supportsSafetySettings {
                validatedGoogle.safetySettings = nil
            }

            validated.google = validatedGoogle
        }

        // Note: We don't remove options for other providers as they may be used
        // when switching between providers or for debugging purposes

        return validated
    }

    /// Filters settings to only include supported parameters (legacy compatibility)
    public func filtered(for model: LanguageModel) -> GenerationSettings {
        // Filters settings to only include supported parameters (legacy compatibility)
        self.validated(for: model)
    }
}
