import Foundation

// MARK: - Modern Language Model System

/// Language model selection following AI SDK patterns
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum LanguageModel: Sendable, CustomStringConvertible {
    // Provider-specific models
    case openai(OpenAI)
    case anthropic(Anthropic)
    case google(Google)
    case mistral(Mistral)
    case groq(Groq)
    case grok(Grok)
    case ollama(Ollama)

    // Third-party aggregators
    case openRouter(modelId: String)
    case together(modelId: String)
    case replicate(modelId: String)

    // Custom endpoints
    case openaiCompatible(modelId: String, baseURL: String)
    case anthropicCompatible(modelId: String, baseURL: String)
    case custom(provider: any ModelProvider)

    // MARK: - Provider Sub-Enums

    public enum OpenAI: Sendable, Hashable, CaseIterable {
        // Latest models (2025)
        case o3
        case o3Mini
        case o3Pro
        case o4Mini

        // GPT-4.1 Series
        case gpt41
        case gpt41Mini

        // GPT-4o Series (Multimodal)
        case gpt4o
        case gpt4oMini

        // Legacy support
        case gpt4Turbo
        case gpt35Turbo

        // Fine-tuned models
        case custom(String)

        public static var allCases: [OpenAI] {
            [.o3, .o3Mini, .o3Pro, .o4Mini, .gpt41, .gpt41Mini, .gpt4o, .gpt4oMini, .gpt4Turbo, .gpt35Turbo]
        }

        public var modelId: String {
            switch self {
            case let .custom(id): id
            case .o3: "o3"
            case .o3Mini: "o3-mini"
            case .o3Pro: "o3-pro"
            case .o4Mini: "o4-mini"
            case .gpt41: "gpt-4.1"
            case .gpt41Mini: "gpt-4.1-mini"
            case .gpt4o: "gpt-4o"
            case .gpt4oMini: "gpt-4o-mini"
            case .gpt4Turbo: "gpt-4-turbo"
            case .gpt35Turbo: "gpt-3.5-turbo"
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .gpt4o, .gpt4oMini: true
            default: false
            }
        }

        public var supportsTools: Bool {
            switch self {
            case .o3, .o3Mini, .o3Pro, .o4Mini, .gpt41, .gpt41Mini, .gpt4o, .gpt4oMini, .gpt4Turbo: true
            case .gpt35Turbo: true
            case .custom: true // Assume custom models support tools
            }
        }

        public var supportsAudioInput: Bool {
            switch self {
            case .gpt4o, .gpt4oMini: true // GPT-4o models support native audio input
            default: false
            }
        }

        public var supportsAudioOutput: Bool {
            // OpenAI models can generate audio through TTS API, but not directly through chat
            false
        }

        public var contextLength: Int {
            switch self {
            case .o3, .o3Pro: 1_000_000
            case .o3Mini, .o4Mini: 128_000
            case .gpt41, .gpt41Mini: 1_000_000
            case .gpt4o, .gpt4oMini: 128_000
            case .gpt4Turbo: 128_000
            case .gpt35Turbo: 16_000
            case .custom: 128_000 // Default assumption
            }
        }
    }

    public enum Anthropic: Sendable, Hashable, CaseIterable {
        // Claude 4 Series (2025)
        case opus4
        case opus4Thinking
        case sonnet4
        case sonnet4Thinking

        // Claude 3.7 Series
        case sonnet37

        // Claude 3.5 Series
        case opus35
        case sonnet35
        case haiku35

        // Legacy Claude 3 Series
        case opus3
        case sonnet3
        case haiku3

        // Fine-tuned models
        case custom(String)

        public static var allCases: [Anthropic] {
            [
                .opus4,
                .opus4Thinking,
                .sonnet4,
                .sonnet4Thinking,
                .sonnet3_7,
                .opus3_5,
                .sonnet3_5,
                .haiku3_5,
                .opus3,
                .sonnet3,
                .haiku3,
            ]
        }

        public var modelId: String {
            switch self {
            case let .custom(id): id
            case .opus4: "claude-opus-4-20250514"
            case .opus4Thinking: "claude-opus-4-20250514-thinking"
            case .sonnet4: "claude-sonnet-4-20250514"
            case .sonnet4Thinking: "claude-sonnet-4-20250514-thinking"
            case .sonnet37: "claude-3-7-sonnet"
            case .opus35: "claude-3-5-opus"
            case .sonnet35: "claude-3-5-sonnet"
            case .haiku35: "claude-3-5-haiku"
            case .opus3: "claude-3-opus"
            case .sonnet3: "claude-3-sonnet"
            case .haiku3: "claude-3-haiku"
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .opus4, .opus4Thinking, .sonnet4, .sonnet4Thinking, .sonnet37, .opus35, .sonnet35, .haiku35: true
            case .opus3, .sonnet3, .haiku3: true
            case .custom: true // Most modern Claude models support vision
            }
        }

        public var supportsTools: Bool { true } // All Claude models support tools

        public var supportsAudioInput: Bool {
            // Anthropic has voice features in mobile apps but limited API support as of 2025
            false
        }

        public var supportsAudioOutput: Bool {
            // Anthropic does not currently support audio output through API
            false
        }

        public var contextLength: Int {
            switch self {
            case .opus4, .opus4Thinking, .sonnet4, .sonnet4Thinking: 500_000
            case .sonnet37: 200_000
            case .opus35, .sonnet35: 200_000
            case .haiku35: 200_000
            case .opus3, .sonnet3: 200_000
            case .haiku3: 200_000
            case .custom: 200_000
            }
        }
    }

    public enum Google: String, Sendable, Hashable, CaseIterable {
        // Gemini 2.0 Series
        case gemini2Flash = "gemini-2.0-flash"
        case gemini2FlashThinking = "gemini-2.0-flash-thinking"

        // Gemini 1.5 Series
        case gemini15Pro = "gemini-1.5-pro"
        case gemini15Flash = "gemini-1.5-flash"
        case gemini15Flash8B = "gemini-1.5-flash-8b"

        // Legacy
        case geminiPro = "gemini-pro"
        case geminiProVision = "gemini-pro-vision"

        public var supportsVision: Bool { true } // All Gemini models support vision
        public var supportsTools: Bool { true }

        public var supportsAudioInput: Bool {
            switch self {
            case .gemini2Flash, .gemini2FlashThinking: true // Gemini 2.0 has advanced audio capabilities
            case .gemini15Pro, .gemini15Flash: true // Gemini 1.5 supports audio
            default: false
            }
        }

        public var supportsAudioOutput: Bool {
            switch self {
            case .gemini2Flash, .gemini2FlashThinking: true // Gemini Live API supports audio output
            default: false
            }
        }

        public var contextLength: Int {
            switch self {
            case .gemini2Flash, .gemini2FlashThinking: 1_000_000
            case .gemini15Pro, .gemini15Flash: 2_000_000
            case .gemini15Flash8B: 1_000_000
            case .geminiPro, .geminiProVision: 32_000
            }
        }
    }

    public enum Mistral: String, Sendable, Hashable, CaseIterable {
        case large2 = "mistral-large-2"
        case large = "mistral-large"
        case medium = "mistral-medium"
        case small = "mistral-small"
        case nemo = "mistral-nemo"
        case codestral

        public var supportsVision: Bool {
            switch self {
            case .large2, .large: true
            default: false
            }
        }

        public var supportsTools: Bool { true }

        public var supportsAudioInput: Bool { false } // Mistral doesn't support audio yet
        public var supportsAudioOutput: Bool { false }

        public var contextLength: Int {
            switch self {
            case .large2, .large: 128_000
            case .medium: 32_000
            case .small: 32_000
            case .nemo: 128_000
            case .codestral: 32_000
            }
        }
    }

    public enum Groq: String, Sendable, Hashable, CaseIterable {
        // Groq-hosted models (ultra-fast inference)
        case llama31_70b = "llama-3.1-70b"
        case llama31_8b = "llama-3.1-8b"
        case llama3_70b = "llama-3-70b"
        case llama3_8b = "llama-3-8b"
        case mixtral8x7b = "mixtral-8x7b"
        case gemma2_9b = "gemma2-9b"

        public var supportsVision: Bool { false } // Groq models don't support vision yet
        public var supportsTools: Bool { true }

        public var supportsAudioInput: Bool { false } // Groq focuses on text inference speed
        public var supportsAudioOutput: Bool { false }

        public var contextLength: Int {
            switch self {
            case .llama31_70b, .llama31_8b: 128_000
            case .llama3_70b, .llama3_8b: 8000
            case .mixtral8x7b: 32_000
            case .gemma2_9b: 8000
            }
        }
    }

    public enum Grok: Sendable, Hashable, CaseIterable {
        // xAI Grok models
        case grok4
        case grok40709
        case grok4Latest
        case grok3
        case grok3Mini
        case grok3Fast
        case grok3MiniFast
        case grok21212
        case grok2Vision1212
        case grok2Image1212
        case grokBeta
        case grokVisionBeta

        // Custom models
        case custom(String)

        public static var allCases: [Grok] {
            [
                .grok4,
                .grok40709,
                .grok4Latest,
                .grok3,
                .grok3Mini,
                .grok3Fast,
                .grok3MiniFast,
                .grok21212,
                .grok2Vision1212,
                .grok2Image1212,
                .grokBeta,
                .grokVisionBeta,
            ]
        }

        public var modelId: String {
            switch self {
            case let .custom(id): id
            case .grok4: "grok-4"
            case .grok40709: "grok-4-0709"
            case .grok4Latest: "grok-4-latest"
            case .grok3: "grok-3"
            case .grok3Mini: "grok-3-mini"
            case .grok3Fast: "grok-3-fast"
            case .grok3MiniFast: "grok-3-mini-fast"
            case .grok21212: "grok-2-1212"
            case .grok2Vision1212: "grok-2-vision-1212"
            case .grok2Image1212: "grok-2-image-1212"
            case .grokBeta: "grok-beta"
            case .grokVisionBeta: "grok-vision-beta"
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .grok2Vision_1212, .grok2Image_1212, .grokVisionBeta: true
            case .custom: true // Assume custom models support vision
            default: false
            }
        }

        public var supportsTools: Bool { true }

        public var supportsAudioInput: Bool {
            // Grok has voice support but limited API access as of 2025
            false
        }

        public var supportsAudioOutput: Bool {
            // Grok supports 145+ language voice but API access is limited
            false
        }

        public var contextLength: Int {
            switch self {
            case .grok4, .grok4_0709, .grok4Latest: 256_000
            case .grok3, .grok3Mini, .grok3Fast, .grok3MiniFast: 128_000
            case .grok2_1212, .grok2Vision_1212, .grok2Image_1212: 128_000
            case .grokBeta, .grokVisionBeta: 128_000
            case .custom: 128_000 // Default assumption for custom models
            }
        }
    }

    public enum Ollama: Sendable, Hashable, CaseIterable {
        // Recommended models for different use cases
        case llama33 // Best overall
        case llama32 // Good alternative
        case llama31 // Older but reliable

        // Vision models (no tool support)
        case llava
        case bakllava
        case llama32Vision11b
        case llama32Vision90b
        case qwen25vl7b
        case qwen25vl32b

        // Specialized models
        case codellama
        case mistralNemo
        case qwen25
        case deepseekR1
        case commandRPlus

        // Additional models referenced by CLI
        case llama2
        case llama4
        case mistral
        case mixtral
        case neuralChat
        case gemma
        case devstral
        case deepseekR18b
        case deepseekR1671b
        case firefunction
        case commandR

        // Custom/other models
        case custom(String)

        public static var allCases: [Ollama] {
            [
                .llama33,
                .llama32,
                .llama31,
                .llava,
                .bakllava,
                .llama32Vision11b,
                .llama3_2Vision11b,
                .llama32Vision90b,
                .llama3_2Vision90b,
                .qwen2_5vl7b,
                .qwen2_5vl32b,
                .codellama,
                .mistralNemo,
                .qwen25,
                .deepseekR1,
                .commandRPlus,
                .llama2,
                .llama4,
                .mistral,
                .mixtral,
                .neuralChat,
                .gemma,
                .devstral,
                .deepseekR1_8b,
                .deepseekR1_671b,
                .firefunction,
                .commandR,
            ]
        }

        public var modelId: String {
            switch self {
            case let .custom(id): id
            case .llama33, .llama3_3: "llama3.3"
            case .llama32, .llama3_2: "llama3.2"
            case .llama31, .llama3_1: "llama3.1"
            case .llava: "llava"
            case .bakllava: "bakllava"
            case .llama32Vision11b, .llama3_2Vision11b: "llama3.2-vision:11b"
            case .llama32Vision90b, .llama3_2Vision90b: "llama3.2-vision:90b"
            case .qwen2_5vl7b: "qwen2.5vl:7b"
            case .qwen2_5vl32b: "qwen2.5vl:32b"
            case .codellama: "codellama"
            case .mistralNemo: "mistral-nemo"
            case .qwen25: "qwen2.5"
            case .deepseekR1: "deepseek-r1"
            case .commandRPlus: "command-r-plus"
            case .llama2: "llama2"
            case .llama4: "llama4"
            case .mistral: "mistral"
            case .mixtral: "mixtral"
            case .neuralChat: "neural-chat"
            case .gemma: "gemma"
            case .devstral: "devstral"
            case .deepseekR1_8b: "deepseek-r1:8b"
            case .deepseekR1_671b: "deepseek-r1:671b"
            case .firefunction: "firefunction-v2"
            case .commandR: "command-r"
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .llava, .bakllava, .llama32Vision11b, .llama3_2Vision11b, .llama32Vision90b, .llama3_2Vision90b,
                 .qwen2_5vl7b, .qwen2_5vl32b: true
            default: false
            }
        }

        public var supportsTools: Bool {
            switch self {
            case .llava, .bakllava, .llama32Vision11b, .llama3_2Vision11b, .llama32Vision90b, .llama3_2Vision90b,
                 .qwen2_5vl7b, .qwen2_5vl32b: false // Vision models don't support tools
            case .llama33, .llama3_3, .llama32, .llama3_2, .llama31, .llama3_1, .mistralNemo: true
            case .codellama, .qwen25, .deepseekR1, .commandRPlus: true
            case .llama2, .llama4, .mistral, .mixtral, .neuralChat, .gemma: true
            case .deepseekR1_8b, .deepseekR1_671b, .firefunction, .commandR: true
            case .devstral: false // DevStral doesn't support tools
            case .custom: true // Assume tools support
            }
        }

        public var supportsAudioInput: Bool { false
        } // Ollama models run locally and don't support native audio processing
        public var supportsAudioOutput: Bool { false }

        public var contextLength: Int {
            switch self {
            case .llama33, .llama3_3, .llama32, .llama3_2, .llama31, .llama3_1: 128_000
            case .llava, .bakllava: 32_000
            case .llama32Vision11b, .llama3_2Vision11b: 128_000
            case .llama32Vision90b, .llama3_2Vision90b: 128_000
            case .qwen2_5vl7b, .qwen2_5vl32b: 32_000
            case .codellama: 32_000
            case .mistralNemo: 128_000
            case .qwen25: 32_000
            case .deepseekR1: 128_000
            case .commandRPlus: 128_000
            case .llama2, .llama4: 128_000
            case .mistral, .mixtral: 32_000
            case .neuralChat, .gemma: 32_000
            case .devstral: 16_000
            case .deepseekR1_8b: 64_000
            case .deepseekR1_671b: 128_000
            case .firefunction: 32_000
            case .commandR: 128_000
            case .custom: 32_000
            }
        }
    }

    // MARK: - Model Properties

    public var description: String {
        switch self {
        case let .openai(model):
            "OpenAI/\(model.modelId)"
        case let .anthropic(model):
            "Anthropic/\(model.modelId)"
        case let .google(model):
            "Google/\(model.rawValue)"
        case let .mistral(model):
            "Mistral/\(model.rawValue)"
        case let .groq(model):
            "Groq/\(model.rawValue)"
        case let .grok(model):
            "Grok/\(model.modelId)"
        case let .ollama(model):
            "Ollama/\(model.modelId)"
        case let .openRouter(modelId):
            "OpenRouter/\(modelId)"
        case let .together(modelId):
            "Together/\(modelId)"
        case let .replicate(modelId):
            "Replicate/\(modelId)"
        case let .openaiCompatible(modelId, baseURL):
            "OpenAI-Compatible/\(modelId)@\(baseURL)"
        case let .anthropicCompatible(modelId, baseURL):
            "Anthropic-Compatible/\(modelId)@\(baseURL)"
        case let .custom(provider):
            "Custom/\(provider.modelId)"
        }
    }

    public var modelId: String {
        switch self {
        case let .openai(model):
            model.modelId
        case let .anthropic(model):
            model.modelId
        case let .google(model):
            model.rawValue
        case let .mistral(model):
            model.rawValue
        case let .groq(model):
            model.rawValue
        case let .grok(model):
            model.modelId
        case let .ollama(model):
            model.modelId
        case let .openRouter(modelId):
            modelId
        case let .together(modelId):
            modelId
        case let .replicate(modelId):
            modelId
        case let .openaiCompatible(modelId, _):
            modelId
        case let .anthropicCompatible(modelId, _):
            modelId
        case let .custom(provider):
            provider.modelId
        }
    }

    public var supportsVision: Bool {
        switch self {
        case let .openai(model):
            model.supportsVision
        case let .anthropic(model):
            model.supportsVision
        case let .google(model):
            model.supportsVision
        case let .mistral(model):
            model.supportsVision
        case let .groq(model):
            model.supportsVision
        case let .grok(model):
            model.supportsVision
        case let .ollama(model):
            model.supportsVision
        case .openRouter, .together, .replicate:
            false // Unknown, assume no vision support
        case .openaiCompatible, .anthropicCompatible:
            false // Unknown, assume no vision support
        case let .custom(provider):
            provider.capabilities.supportsVision
        }
    }

    public var supportsAudioInput: Bool {
        switch self {
        case let .openai(model):
            model.supportsAudioInput
        case let .anthropic(model):
            model.supportsAudioInput
        case let .google(model):
            model.supportsAudioInput
        case let .mistral(model):
            model.supportsAudioInput
        case let .groq(model):
            model.supportsAudioInput
        case let .grok(model):
            model.supportsAudioInput
        case let .ollama(model):
            model.supportsAudioInput
        case .openRouter, .together, .replicate:
            false // Unknown, assume no audio input support
        case .openaiCompatible, .anthropicCompatible:
            false // Unknown, assume no audio input support
        case let .custom(provider):
            provider.capabilities.supportsAudioInput
        }
    }

    public var supportsAudioOutput: Bool {
        switch self {
        case let .openai(model):
            model.supportsAudioOutput
        case let .anthropic(model):
            model.supportsAudioOutput
        case let .google(model):
            model.supportsAudioOutput
        case let .mistral(model):
            model.supportsAudioOutput
        case let .groq(model):
            model.supportsAudioOutput
        case let .grok(model):
            model.supportsAudioOutput
        case let .ollama(model):
            model.supportsAudioOutput
        case .openRouter, .together, .replicate:
            false // Unknown, assume no audio output support
        case .openaiCompatible, .anthropicCompatible:
            false // Unknown, assume no audio output support
        case let .custom(provider):
            provider.capabilities.supportsAudioOutput
        }
    }

    public var supportsTools: Bool {
        switch self {
        case let .openai(model):
            model.supportsTools
        case let .anthropic(model):
            model.supportsTools
        case let .google(model):
            model.supportsTools
        case let .mistral(model):
            model.supportsTools
        case let .groq(model):
            model.supportsTools
        case let .grok(model):
            model.supportsTools
        case let .ollama(model):
            model.supportsTools
        case .openRouter, .together, .replicate:
            true // Most aggregator models support tools
        case .openaiCompatible, .anthropicCompatible:
            true // Assume tools support for compatible APIs
        case let .custom(provider):
            provider.capabilities.supportsTools
        }
    }

    public var contextLength: Int {
        switch self {
        case let .openai(model):
            model.contextLength
        case let .anthropic(model):
            model.contextLength
        case let .google(model):
            model.contextLength
        case let .mistral(model):
            model.contextLength
        case let .groq(model):
            model.contextLength
        case let .grok(model):
            model.contextLength
        case let .ollama(model):
            model.contextLength
        case .openRouter, .together, .replicate:
            128_000 // Common default
        case .openaiCompatible, .anthropicCompatible:
            128_000 // Common default
        case let .custom(provider):
            provider.capabilities.contextLength
        }
    }

    public var supportsStreaming: Bool {
        // All models support streaming by default
        true
    }

    public var providerName: String {
        switch self {
        case .openai:
            "OpenAI"
        case .anthropic:
            "Anthropic"
        case .google:
            "Google"
        case .mistral:
            "Mistral"
        case .groq:
            "Groq"
        case .grok:
            "Grok"
        case .ollama:
            "Ollama"
        case .openRouter:
            "OpenRouter"
        case .together:
            "Together"
        case .replicate:
            "Replicate"
        case .openaiCompatible:
            "OpenAI-Compatible"
        case .anthropicCompatible:
            "Anthropic-Compatible"
        case .custom:
            "Custom"
        }
    }

    // MARK: - Default Model

    public static let `default`: LanguageModel = .anthropic(.opus4)

    // MARK: - Convenience Static Properties

    /// Default Claude model (opus4)
    public static let claude: LanguageModel = .anthropic(.opus4)

    /// Default GPT-4o model
    public static let gpt4o: LanguageModel = .openai(.gpt4o)

    /// Default Grok model
    public static let grok4: LanguageModel = .grok(.grok4)

    /// Default Llama model
    public static let llama: LanguageModel = .ollama(.llama33)
}

// MARK: - Model Provider Protocol

/// Protocol for AI model providers
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public protocol ModelProvider: Sendable {
    var modelId: String { get }
    var baseURL: String? { get }
    var apiKey: String? { get }
    var capabilities: ModelCapabilities { get }

    func generateText(request: ProviderRequest) async throws -> ProviderResponse
    func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error>
}

/// Model capabilities
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModelCapabilities: Sendable {
    public let supportsVision: Bool
    public let supportsTools: Bool
    public let supportsStreaming: Bool
    public let supportsAudioInput: Bool
    public let supportsAudioOutput: Bool
    public let contextLength: Int
    public let maxOutputTokens: Int
    public let costPerToken: (input: Double, output: Double)?

    public init(
        supportsVision: Bool = false,
        supportsTools: Bool = true,
        supportsStreaming: Bool = true,
        supportsAudioInput: Bool = false,
        supportsAudioOutput: Bool = false,
        contextLength: Int = 128_000,
        maxOutputTokens: Int = 4096,
        costPerToken: (input: Double, output: Double)? = nil
    ) {
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.supportsStreaming = supportsStreaming
        self.supportsAudioInput = supportsAudioInput
        self.supportsAudioOutput = supportsAudioOutput
        self.contextLength = contextLength
        self.maxOutputTokens = maxOutputTokens
        self.costPerToken = costPerToken
    }
}

// MARK: - Provider Request/Response Types

/// Request to a model provider
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ProviderRequest: Sendable {
    public let messages: [ModelMessage]
    public let tools: [SimpleTool]?
    public let settings: GenerationSettings
    public let outputFormat: OutputFormat?

    public enum OutputFormat: Sendable {
        case text
        case json
    }

    public init(
        messages: [ModelMessage],
        tools: [SimpleTool]? = nil,
        settings: GenerationSettings = .default,
        outputFormat: OutputFormat? = nil
    ) {
        self.messages = messages
        self.tools = tools
        self.settings = settings
        self.outputFormat = outputFormat
    }
}

/// Response from a model provider
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ProviderResponse: Sendable {
    public let text: String
    public let usage: Usage?
    public let finishReason: FinishReason?
    public let toolCalls: [ToolCall]?

    public init(
        text: String,
        usage: Usage? = nil,
        finishReason: FinishReason? = nil,
        toolCalls: [ToolCall]? = nil
    ) {
        self.text = text
        self.usage = usage
        self.finishReason = finishReason
        self.toolCalls = toolCalls
    }
}

// MARK: - Backward Compatibility

/// Backward compatibility alias for LanguageModel
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public typealias Model = LanguageModel
