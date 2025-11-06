import Foundation

// MARK: - Modern Language Model System

/// Language model selection following AI SDK patterns
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum LanguageModel: Sendable, CustomStringConvertible, Hashable {
    // Provider-specific models
    case openai(OpenAI)
    case anthropic(Anthropic)
    case google(Google)
    case mistral(Mistral)
    case groq(Groq)
    case grok(Grok)
    case ollama(Ollama)
    case lmstudio(LMStudio)

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

        // GPT-5 Series (August 2025)
        case gpt5 // Best for coding and agentic tasks
        case gpt5Pro // Higher reasoning budget
        case gpt5Mini // Cost-optimized
        case gpt5Nano // Ultra-low latency
        case gpt5Thinking // Extended reasoning traces
        case gpt5ThinkingMini
        case gpt5ThinkingNano
        case gpt5ChatLatest // Non-reasoning default chat deployment

        // GPT-4.1 Series
        case gpt41
        case gpt41Mini

        // GPT-4o Series (Multimodal)
        case gpt4o
        case gpt4oMini
        case gpt4oRealtime // Realtime API support

        // Legacy support
        case gpt4Turbo
        case gpt35Turbo

        // Fine-tuned models
        case custom(String)

        public static var allCases: [OpenAI] {
            [
                .o3,
                .o3Mini,
                .o3Pro,
                .o4Mini,
                .gpt5,
                .gpt5Pro,
                .gpt5Mini,
                .gpt5Nano,
                .gpt5Thinking,
                .gpt5ThinkingMini,
                .gpt5ThinkingNano,
                .gpt5ChatLatest,
                .gpt41,
                .gpt41Mini,
                .gpt4o,
                .gpt4oMini,
                .gpt4oRealtime,
                .gpt4Turbo,
                .gpt35Turbo,
            ]
        }

        public var modelId: String {
            switch self {
            case let .custom(id): id
            case .o3: "o3"
            case .o3Mini: "o3-mini"
            case .o3Pro: "o3-pro"
            case .o4Mini: "o4-mini"
            case .gpt5: "gpt-5"
            case .gpt5Pro: "gpt-5-pro"
            case .gpt5Mini: "gpt-5-mini"
            case .gpt5Nano: "gpt-5-nano"
            case .gpt5Thinking: "gpt-5-thinking"
            case .gpt5ThinkingMini: "gpt-5-thinking-mini"
            case .gpt5ThinkingNano: "gpt-5-thinking-nano"
            case .gpt5ChatLatest: "gpt-5-chat-latest"
            case .gpt41: "gpt-4.1"
            case .gpt41Mini: "gpt-4.1-mini"
            case .gpt4o: "gpt-4o"
            case .gpt4oMini: "gpt-4o-mini"
            case .gpt4oRealtime: "gpt-4o-realtime-preview"
            case .gpt4Turbo: "gpt-4-turbo"
            case .gpt35Turbo: "gpt-3.5-turbo"
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .gpt5, .gpt5Pro, .gpt5Mini, .gpt5Nano, .gpt5Thinking, .gpt5ThinkingMini, .gpt5ThinkingNano,
                 .gpt5ChatLatest: true // GPT-5 supports multimodal
            case .gpt4o, .gpt4oMini, .gpt4oRealtime: true
            default: false
            }
        }

        public var supportsTools: Bool {
            switch self {
            case .o3, .o3Mini, .o3Pro, .o4Mini: true
            case .gpt5, .gpt5Pro, .gpt5Mini, .gpt5Nano, .gpt5Thinking, .gpt5ThinkingMini, .gpt5ThinkingNano,
                 .gpt5ChatLatest: true // GPT-5 excels at tool calling
            case .gpt41, .gpt41Mini, .gpt4o, .gpt4oMini, .gpt4oRealtime, .gpt4Turbo: true
            case .gpt35Turbo: true
            case .custom: true // Assume custom models support tools
            }
        }

        public var supportsAudioInput: Bool {
            switch self {
            case .gpt5, .gpt5Pro, .gpt5Mini, .gpt5Nano, .gpt5Thinking, .gpt5ThinkingMini, .gpt5ThinkingNano,
                 .gpt5ChatLatest: true // GPT-5 is fully multimodal
            case .gpt4o, .gpt4oMini, .gpt4oRealtime: true // GPT-4o models support native audio input
            default: false
            }
        }

        public var supportsAudioOutput: Bool {
            switch self {
            case .gpt4oRealtime: true // Realtime API supports native audio output
            default: false
            }
        }

        public var supportsRealtime: Bool {
            switch self {
            case .gpt4oRealtime: true
            default: false
            }
        }

        public var contextLength: Int {
            switch self {
            case .o3, .o3Pro: 1_000_000
            case .o3Mini, .o4Mini: 128_000
            case .gpt5, .gpt5Pro, .gpt5Mini, .gpt5Nano, .gpt5Thinking, .gpt5ThinkingMini, .gpt5ThinkingNano,
                 .gpt5ChatLatest: 400_000 // 272k input + 128k output
            case .gpt41, .gpt41Mini: 1_000_000
            case .gpt4o, .gpt4oMini, .gpt4oRealtime: 128_000
            case .gpt4Turbo: 128_000
            case .gpt35Turbo: 16000
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
        case sonnet45
        case haiku45

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
                .sonnet45,
                .haiku45,
                .sonnet37,
                .opus35,
                .sonnet35,
                .haiku35,
                .opus3,
                .sonnet3,
                .haiku3,
            ]
        }

        public var modelId: String {
            switch self {
            case let .custom(id): id
            case .opus4: "claude-opus-4-1-20250805"
            case .opus4Thinking: "claude-opus-4-1-20250805-thinking"
            case .sonnet4: "claude-sonnet-4-20250514"
            case .sonnet4Thinking: "claude-sonnet-4-20250514-thinking"
            case .sonnet45: "claude-sonnet-4-5-20250929"
            case .haiku45: "claude-haiku-4.5"
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
            case .opus4, .opus4Thinking, .sonnet4, .sonnet4Thinking, .sonnet45, .haiku45, .sonnet37, .opus35, .sonnet35,
                 .haiku35: true
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
            case .opus4, .opus4Thinking, .sonnet4, .sonnet4Thinking, .sonnet45, .haiku45: 500_000
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
            case .geminiPro, .geminiProVision: 32000
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
            case .medium: 32000
            case .small: 32000
            case .nemo: 128_000
            case .codestral: 32000
            }
        }
    }

    public enum Groq: String, Sendable, Hashable, CaseIterable {
        // Groq-hosted models (ultra-fast inference)
        case llama3170b = "llama-3.1-70b"
        case llama318b = "llama-3.1-8b"
        case llama370b = "llama-3-70b"
        case llama38b = "llama-3-8b"
        case mixtral8x7b = "mixtral-8x7b"
        case gemma29b = "gemma2-9b"

        public var supportsVision: Bool { false } // Groq models don't support vision yet
        public var supportsTools: Bool { true }

        public var supportsAudioInput: Bool { false } // Groq focuses on text inference speed
        public var supportsAudioOutput: Bool { false }

        public var contextLength: Int {
            switch self {
            case .llama3170b, .llama318b: 128_000
            case .llama370b, .llama38b: 8000
            case .mixtral8x7b: 32000
            case .gemma29b: 8000
            }
        }
    }

    public enum Grok: Sendable, Hashable, CaseIterable {
        // xAI Grok models (only models available in API)
        case grok4
        case grok3
        case grok3Mini
        case grok2Image

        // Custom models
        case custom(String)

        public static var allCases: [Grok] {
            [
                .grok4,
                .grok3,
                .grok3Mini,
                .grok2Image,
            ]
        }

        public var modelId: String {
            switch self {
            case let .custom(id): id
            case .grok4: "grok-4-0709"
            case .grok3: "grok-3"
            case .grok3Mini: "grok-3-mini"
            case .grok2Image: "grok-2-image-1212"
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .grok2Image: true
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
            case .grok4: 256_000
            case .grok3, .grok3Mini: 131_072
            case .grok2Image: 128_000
            case .custom: 128_000 // Default assumption for custom models
            }
        }
    }

    public enum Ollama: Sendable, Hashable, CaseIterable {
        // GPT-OSS models
        case gptOSS120B
        case gptOSS20B

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
                .gptOSS120B,
                .gptOSS20B,
                .llama33,
                .llama32,
                .llama31,
                .llava,
                .bakllava,
                .llama32Vision11b,
                .llama32Vision90b,
                .qwen25vl7b,
                .qwen25vl32b,
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
                .deepseekR18b,
                .deepseekR1671b,
                .firefunction,
                .commandR,
            ]
        }

        public var modelId: String {
            switch self {
            case let .custom(id): id
            case .gptOSS120B: "gpt-oss:120b"
            case .gptOSS20B: "gpt-oss:20b"
            case .llama33: "llama3.3"
            case .llama32: "llama3.2"
            case .llama31: "llama3.1"
            case .llava: "llava"
            case .bakllava: "bakllava"
            case .llama32Vision11b: "llama3.2-vision:11b"
            case .llama32Vision90b: "llama3.2-vision:90b"
            case .qwen25vl7b: "qwen2.5vl:7b"
            case .qwen25vl32b: "qwen2.5vl:32b"
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
            case .deepseekR18b: "deepseek-r1:8b"
            case .deepseekR1671b: "deepseek-r1:671b"
            case .firefunction: "firefunction-v2"
            case .commandR: "command-r"
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .llava, .bakllava, .llama32Vision11b, .llama32Vision90b,
                 .qwen25vl7b, .qwen25vl32b: true
            default: false
            }
        }

        public var supportsTools: Bool {
            switch self {
            case .gptOSS120B, .gptOSS20B: true // GPT-OSS supports tools
            case .llava, .bakllava, .llama32Vision11b, .llama32Vision90b,
                 .qwen25vl7b, .qwen25vl32b: false // Vision models don't support tools
            case .llama33, .llama32, .llama31, .mistralNemo: true
            case .codellama, .qwen25, .deepseekR1, .commandRPlus: true
            case .llama2, .llama4, .mistral, .mixtral, .neuralChat, .gemma: true
            case .deepseekR18b, .deepseekR1671b, .firefunction, .commandR: true
            case .devstral: false // DevStral doesn't support tools
            case .custom: true // Assume tools support
            }
        }

        public var supportsAudioInput: Bool { false
        } // Ollama models run locally and don't support native audio processing
        public var supportsAudioOutput: Bool { false }

        public var contextLength: Int {
            switch self {
            case .gptOSS120B, .gptOSS20B: 128_000
            case .llama33, .llama32, .llama31: 128_000
            case .llava, .bakllava: 32000
            case .llama32Vision11b: 128_000
            case .llama32Vision90b: 128_000
            case .qwen25vl7b, .qwen25vl32b: 32000
            case .codellama: 32000
            case .mistralNemo: 128_000
            case .qwen25: 32000
            case .deepseekR1: 128_000
            case .commandRPlus: 128_000
            case .llama2, .llama4: 128_000
            case .mistral, .mixtral: 32000
            case .neuralChat, .gemma: 32000
            case .devstral: 16000
            case .deepseekR18b: 64000
            case .deepseekR1671b: 128_000
            case .firefunction: 32000
            case .commandR: 128_000
            case .custom: 32000
            }
        }
    }

    public enum LMStudio: Sendable, Hashable, CaseIterable {
        // GPT-OSS models
        case gptOSS120B
        case gptOSS20B

        // Common local models
        case llama370B
        case llama333B
        case mixtral8x7B
        case codeLlama34B
        case mistral7B
        case phi3Mini

        // Currently loaded model
        case current

        // Custom model path
        case custom(String)

        public static var allCases: [LMStudio] {
            [
                .gptOSS120B,
                .gptOSS20B,
                .llama370B,
                .llama333B,
                .mixtral8x7B,
                .codeLlama34B,
                .mistral7B,
                .phi3Mini,
                .current,
            ]
        }

        public var modelId: String {
            switch self {
            case .gptOSS120B: "gpt-oss-120b"
            case .gptOSS20B: "gpt-oss-20b"
            case .llama370B: "llama-3-70b"
            case .llama333B: "llama-3.3-70b"
            case .mixtral8x7B: "mixtral-8x7b"
            case .codeLlama34B: "codellama-34b"
            case .mistral7B: "mistral-7b"
            case .phi3Mini: "phi-3-mini"
            case .current: "current"
            case let .custom(id): id
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .gptOSS120B, .gptOSS20B: false
            case .llama370B, .llama333B: false
            default: false
            }
        }

        public var supportsTools: Bool {
            switch self {
            case .current, .custom: true // Assume support
            default: true // Most modern models support tools
            }
        }

        public var contextLength: Int {
            switch self {
            case .gptOSS120B, .gptOSS20B: 128_000
            case .llama370B, .llama333B: 128_000
            case .mixtral8x7B: 32000
            case .codeLlama34B: 16000
            case .mistral7B: 32000
            case .phi3Mini: 4096
            case .current: 16000 // Conservative default
            case .custom: 16000
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
        case let .lmstudio(model):
            "LMStudio/\(model.modelId)"
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
        case let .lmstudio(model):
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
        case let .lmstudio(model):
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
        case .lmstudio:
            false // LMStudio doesn't support audio input
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
        case .lmstudio:
            false // LMStudio doesn't support audio output
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
        case let .lmstudio(model):
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
        case let .lmstudio(model):
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
        case .lmstudio:
            "LMStudio"
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

    /// Default Grok model (Grok-4-0709)
    public static let grok4: LanguageModel = .grok(.grok4)

    /// Default Llama model
    public static let llama: LanguageModel = .ollama(.llama33)
}

// MARK: - Hashable Conformance

extension LanguageModel {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .openai(model):
            hasher.combine("openai")
            hasher.combine(model)
        case let .anthropic(model):
            hasher.combine("anthropic")
            hasher.combine(model)
        case let .google(model):
            hasher.combine("google")
            hasher.combine(model)
        case let .mistral(model):
            hasher.combine("mistral")
            hasher.combine(model)
        case let .groq(model):
            hasher.combine("groq")
            hasher.combine(model)
        case let .grok(model):
            hasher.combine("grok")
            hasher.combine(model)
        case let .ollama(model):
            hasher.combine("ollama")
            hasher.combine(model)
        case let .lmstudio(model):
            hasher.combine("lmstudio")
            hasher.combine(model)
        case let .openRouter(modelId):
            hasher.combine("openRouter")
            hasher.combine(modelId)
        case let .together(modelId):
            hasher.combine("together")
            hasher.combine(modelId)
        case let .replicate(modelId):
            hasher.combine("replicate")
            hasher.combine(modelId)
        case let .openaiCompatible(modelId, baseURL):
            hasher.combine("openaiCompatible")
            hasher.combine(modelId)
            hasher.combine(baseURL)
        case let .anthropicCompatible(modelId, baseURL):
            hasher.combine("anthropicCompatible")
            hasher.combine(modelId)
            hasher.combine(baseURL)
        case let .custom(provider):
            hasher.combine("custom")
            hasher.combine(provider.modelId)
            hasher.combine(provider.baseURL)
        }
    }

    public static func == (lhs: LanguageModel, rhs: LanguageModel) -> Bool {
        switch (lhs, rhs) {
        case let (.openai(lhsModel), .openai(rhsModel)):
            lhsModel == rhsModel
        case let (.anthropic(lhsModel), .anthropic(rhsModel)):
            lhsModel == rhsModel
        case let (.google(lhsModel), .google(rhsModel)):
            lhsModel == rhsModel
        case let (.mistral(lhsModel), .mistral(rhsModel)):
            lhsModel == rhsModel
        case let (.groq(lhsModel), .groq(rhsModel)):
            lhsModel == rhsModel
        case let (.grok(lhsModel), .grok(rhsModel)):
            lhsModel == rhsModel
        case let (.ollama(lhsModel), .ollama(rhsModel)):
            lhsModel == rhsModel
        case let (.lmstudio(lhsModel), .lmstudio(rhsModel)):
            lhsModel == rhsModel
        case let (.openRouter(lhsId), .openRouter(rhsId)):
            lhsId == rhsId
        case let (.together(lhsId), .together(rhsId)):
            lhsId == rhsId
        case let (.replicate(lhsId), .replicate(rhsId)):
            lhsId == rhsId
        case let (.openaiCompatible(lhsId, lhsURL), .openaiCompatible(rhsId, rhsURL)):
            lhsId == rhsId && lhsURL == rhsURL
        case let (.anthropicCompatible(lhsId, lhsURL), .anthropicCompatible(rhsId, rhsURL)):
            lhsId == rhsId && lhsURL == rhsURL
        case let (.custom(lhsProvider), .custom(rhsProvider)):
            lhsProvider.modelId == rhsProvider.modelId && lhsProvider.baseURL == rhsProvider.baseURL
        default:
            false
        }
    }
}

// MARK: - Backward Compatibility

/// Backward compatibility alias for LanguageModel
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public typealias Model = LanguageModel

// MARK: - Convenience Properties

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension LanguageModel {
    /// GPT-OSS-120B via Ollama (default quantization)
    public static let gptOSS120B = LanguageModel.ollama(.gptOSS120B)

    /// GPT-OSS-120B via LMStudio (default quantization)
    public static let gptOSS120B_LMStudio = LanguageModel.lmstudio(.gptOSS120B)

    /// Parse a loose model string (as entered by users or configuration files) into a strongly typed model.
    public static func parse(from modelString: String) -> LanguageModel? {
        // Parse a loose model string (as entered by users or configuration files) into a strongly typed model.
        let trimmed = modelString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.lowercased()
        let dashed = normalized.replacingOccurrences(of: "_", with: "-")
        let compact = dashed.replacingOccurrences(of: "-", with: "")
        let dotted = dashed.replacingOccurrences(of: ".", with: "-")

        // MARK: OpenAI models

        if dashed == "gpt-5-pro" || compact == "gpt5pro" {
            return .openai(.gpt5Pro)
        }

        if dotted.contains("gpt-5-thinking") || compact.contains("gpt5thinking") {
            if dotted.contains("nano") || compact.contains("nano") {
                return .openai(.gpt5ThinkingNano)
            }
            if dotted.contains("mini") || compact.contains("mini") {
                return .openai(.gpt5ThinkingMini)
            }
            return .openai(.gpt5Thinking)
        }

        if dotted.contains("gpt-5-chat") || compact.contains("gpt5chat") {
            return .openai(.gpt5ChatLatest)
        }

        if dashed == "gpt-5-nano" || compact == "gpt5nano" {
            return .openai(.gpt5Nano)
        }

        if dashed == "gpt-5-mini" || compact == "gpt5mini" {
            return .openai(.gpt5Mini)
        }

        if dashed == "gpt-5" || compact == "gpt5" {
            return .openai(.gpt5)
        }

        if dotted.contains("gpt-4o-realtime") || compact.contains("gpt4orealtime") {
            return .openai(.gpt4oRealtime)
        }

        if dotted.contains("gpt-4o-mini") || compact.contains("gpt4omini") {
            return .openai(.gpt4oMini)
        }

        if dotted.contains("gpt-4o") || compact.contains("gpt4o") {
            return .openai(.gpt4o)
        }

        if dotted.contains("gpt-4.1-mini") || compact.contains("gpt41mini") {
            return .openai(.gpt41Mini)
        }

        if dotted.contains("gpt-4.1") || compact.contains("gpt41") {
            return .openai(.gpt41)
        }

        if dashed == "o3" || compact == "o3" {
            return .openai(.o3)
        }

        if dashed == "o3-mini" || compact == "o3mini" {
            return .openai(.o3Mini)
        }

        if dashed == "o3-pro" || compact == "o3pro" {
            return .openai(.o3Pro)
        }

        if dashed == "o4-mini" || compact == "o4mini" {
            return .openai(.o4Mini)
        }

        // MARK: Anthropic models

        if dotted.contains("claude-opus-4") || compact.contains("claudeopus4") || dotted.contains("opus-4") {
            if dotted.contains("thinking") {
                return .anthropic(.opus4Thinking)
            }
            return .anthropic(.opus4)
        }

        if
            dotted.contains("claude-sonnet-4-5-20250929") ||
            dotted.contains("claude-sonnet-4.5") ||
            compact.contains("claudesonnet45") ||
            dotted.contains("sonnet-4-5")
        {
            return .anthropic(.sonnet45)
        }

        if dotted.contains("claude-sonnet-4") || compact.contains("claudesonnet4") {
            if dotted.contains("thinking") {
                return .anthropic(.sonnet4Thinking)
            }
            return .anthropic(.sonnet4)
        }

        if dotted.contains("claude-3-7-sonnet") || compact.contains("claude37sonnet") {
            return .anthropic(.sonnet37)
        }

        if dotted.contains("claude-3-5-sonnet") || compact.contains("claude35sonnet") {
            return .anthropic(.sonnet35)
        }

        if dotted.contains("claude-3-5-haiku") || compact.contains("claude35haiku") {
            return .anthropic(.haiku35)
        }

        if dotted.contains("claude-3-5-opus") || compact.contains("claude35opus") {
            return .anthropic(.opus35)
        }

        if
            normalized.contains("claude-haiku-4.5") ||
            dotted.contains("claude-haiku-4-5") ||
            compact.contains("claudehaiku45")
        {
            return .anthropic(.haiku45)
        }

        if dotted.contains("claude-3-opus") || compact.contains("claude3opus") {
            return .anthropic(.opus3)
        }

        if dotted.contains("claude-3-sonnet") || compact.contains("claude3sonnet") {
            return .anthropic(.sonnet3)
        }

        if dotted.contains("claude-3-haiku") || compact.contains("claude3haiku") {
            return .anthropic(.haiku3)
        }

        let genericClaudeIdentifiers: Set<String> = [
            "claude",
            "claudelatest",
            "claude-latest",
            "claude_latest",
            "claude-default",
            "claude_default",
        ]

        let canonicalForms = [normalized, dashed, compact]
        if canonicalForms.contains(where: { genericClaudeIdentifiers.contains($0) }) {
            return .anthropic(.sonnet45)
        }

        // MARK: Grok models

        if dotted.contains("grok-4") || compact.contains("grok4") {
            return .grok(.grok4)
        }

        if dotted.contains("grok-3") || compact.contains("grok3") {
            if dotted.contains("mini") || compact.contains("mini") {
                return .grok(.grok3Mini)
            }
            return .grok(.grok3)
        }

        if dotted.contains("grok-2") || compact.contains("grok2") {
            if dotted.contains("image") {
                return .grok(.grok2Image)
            }
            return .grok(.grok2Image)
        }

        if compact.contains("grok") {
            return .grok(.grok4)
        }

        // MARK: Ollama models

        if compact.contains("gptoss") {
            if compact.contains("20b") {
                return .ollama(.gptOSS20B)
            }
            return .ollama(.gptOSS120B)
        }

        if compact.contains("llama33") || dashed.contains("llama3.3") {
            return .ollama(.llama33)
        }

        if compact.contains("llama32") || dashed.contains("llama3.2") {
            return .ollama(.llama32)
        }

        if compact.contains("llama31") || dashed.contains("llama3.1") {
            return .ollama(.llama31)
        }

        if compact.contains("llama") {
            return .ollama(.llama33)
        }

        // MARK: Generic fallbacks

        if compact.contains("gpt") {
            return .openai(.gpt5Mini)
        }

        if compact.contains("o3") {
            return .openai(.o3)
        }

        if compact.contains("o4") {
            return .openai(.o4Mini)
        }

        return nil
    }
}
