import Foundation

// swiftlint:disable file_length

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
    case azureOpenAI(deployment: String, resource: String? = nil, apiVersion: String? = nil, endpoint: String? = nil)

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
        case o4Mini

        // GPT-5.2 Series
        case gpt52 // Flagship GPT-5.2

        // GPT-5.1 Series (November 2025)
        case gpt51 // Flagship GPT-5.1

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
                .o4Mini,
                .gpt52,
                .gpt51,
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
            case .o4Mini: "o4-mini"
            case .gpt52: "gpt-5.2"
            case .gpt51: "gpt-5.1"
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
            case .gpt52,
                 .gpt51,
                 .gpt5, .gpt5Pro, .gpt5Mini, .gpt5Nano, .gpt5Thinking, .gpt5ThinkingMini, .gpt5ThinkingNano,
                 .gpt5ChatLatest: true // GPT-5+ supports multimodal
            case .gpt4o, .gpt4oMini, .gpt4oRealtime: true
            default: false
            }
        }

        public var supportsTools: Bool {
            switch self {
            case .o4Mini: true
            case .gpt52,
                 .gpt51,
                 .gpt5, .gpt5Pro, .gpt5Mini, .gpt5Nano, .gpt5Thinking, .gpt5ThinkingMini, .gpt5ThinkingNano,
                 .gpt5ChatLatest: true // GPT-5+ excels at tool calling
            case .gpt41, .gpt41Mini, .gpt4o, .gpt4oMini, .gpt4oRealtime, .gpt4Turbo: true
            case .gpt35Turbo: true
            case .custom: true // Assume custom models support tools
            }
        }

        public var supportsAudioInput: Bool {
            switch self {
            case .gpt52,
                 .gpt51,
                 .gpt5, .gpt5Pro, .gpt5Mini, .gpt5Nano, .gpt5Thinking, .gpt5ThinkingMini, .gpt5ThinkingNano,
                 .gpt5ChatLatest: true // GPT-5+ is fully multimodal
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
            case .o4Mini: 128_000
            case .gpt52,
                 .gpt51,
                 .gpt5, .gpt5Pro, .gpt5Mini, .gpt5Nano, .gpt5Thinking, .gpt5ThinkingMini, .gpt5ThinkingNano,
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
        // Claude 4.x / 4.5 Series (2025)
        case opus45
        case opus4
        case opus4Thinking
        case sonnet4
        case sonnet4Thinking
        case sonnet45
        case haiku45

        // Fine-tuned models
        case custom(String)

        public static var allCases: [Anthropic] {
            [
                .opus45,
                .opus4,
                .opus4Thinking,
                .sonnet4,
                .sonnet4Thinking,
                .sonnet45,
                .haiku45,
            ]
        }

        public var modelId: String {
            switch self {
            case let .custom(id): id
            case .opus45: "claude-opus-4-5"
            case .opus4: "claude-opus-4-1-20250805"
            case .opus4Thinking: "claude-opus-4-1-20250805-thinking"
            case .sonnet4: "claude-sonnet-4-20250514"
            case .sonnet4Thinking: "claude-sonnet-4-20250514-thinking"
            case .sonnet45: "claude-sonnet-4-5-20250929"
            case .haiku45: "claude-haiku-4.5"
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .opus45, .opus4, .opus4Thinking, .sonnet4, .sonnet4Thinking, .sonnet45, .haiku45: true
            case .custom: true // Assume custom models support vision
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
            case .opus45, .opus4, .opus4Thinking, .sonnet4, .sonnet4Thinking, .sonnet45, .haiku45: 500_000
            case .custom: 200_000 // Default assumption
            }
        }
    }

    public enum Google: String, Sendable, Hashable, CaseIterable {
        // NOTE: As of 2025-12-17, ListModels exposes Gemini 3 Flash as `gemini-3-flash-preview` on v1beta.
        // We keep the user-facing identifier as `gemini-3-flash` and map it to the preview model id for API calls.
        case gemini3Flash = "gemini-3-flash-preview"
        case gemini25Pro = "gemini-2.5-pro"
        case gemini25Flash = "gemini-2.5-flash"
        case gemini25FlashLite = "gemini-2.5-flash-lite"

        public var apiModelId: String { self.rawValue }

        public var userFacingModelId: String {
            switch self {
            case .gemini3Flash:
                "gemini-3-flash"
            default:
                self.rawValue
            }
        }

        public var supportsVision: Bool { true }
        public var supportsTools: Bool { true }

        public var supportsAudioInput: Bool {
            switch self {
            case .gemini3Flash, .gemini25Pro, .gemini25Flash:
                true
            case .gemini25FlashLite:
                false
            }
        }

        public var supportsAudioOutput: Bool { false }

        public var contextLength: Int {
            switch self {
            case .gemini3Flash, .gemini25Pro, .gemini25Flash:
                1_048_576
            case .gemini25FlashLite:
                524_288
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
        // xAI Grok models (2025 lineup)
        case grok4
        case grok4FastReasoning
        case grok4FastNonReasoning
        case grokCodeFast1
        case grok3
        case grok3Mini
        case grok2
        case grok2Vision
        case grok2Image
        case grokVisionBeta
        case grokBeta

        // Custom models
        case custom(String)

        public static var allCases: [Grok] {
            [
                .grok4,
                .grok4FastReasoning,
                .grok4FastNonReasoning,
                .grokCodeFast1,
                .grok3,
                .grok3Mini,
                .grok2,
                .grok2Vision,
                .grok2Image,
                .grokVisionBeta,
                .grokBeta,
            ]
        }

        public var modelId: String {
            switch self {
            case let .custom(id): id
            case .grok4: "grok-4-0709"
            case .grok4FastReasoning: "grok-4-fast-reasoning"
            case .grok4FastNonReasoning: "grok-4-fast-non-reasoning"
            case .grokCodeFast1: "grok-code-fast-1"
            case .grok3: "grok-3"
            case .grok3Mini: "grok-3-mini"
            case .grok2: "grok-2-1212"
            case .grok2Vision: "grok-2-vision-1212"
            case .grok2Image: "grok-2-image-1212"
            case .grokVisionBeta: "grok-vision-beta"
            case .grokBeta: "grok-beta"
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .grok2Vision, .grok2Image, .grokVisionBeta:
                true
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
            case .grok4,
                 .grok4FastReasoning,
                 .grok4FastNonReasoning:
                132_000
            case .grokCodeFast1,
                 .grok3,
                 .grok3Mini:
                131_072
            case .grok2,
                 .grok2Vision,
                 .grok2Image,
                 .grokVisionBeta,
                 .grokBeta:
                128_000
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
                 .qwen25vl7b, .qwen25vl32b:
                return true
            case let .custom(id):
                let lower = id.lowercased()
                // Heuristic: many Ollama vision models include "vision", "vl", or well-known model names.
                // Keep this permissive so `ollama/<anything-vision>` works from config strings.
                if lower.contains("llava") || lower.contains("bakllava") { return true }
                if lower.contains("vision") { return true }
                if lower.contains("qwen2.5vl") || lower.contains("qwen25vl") { return true }
                if lower.contains("vl:") || lower.contains("-vl") || lower.contains("_vl") { return true }
                return false
            default:
                return false
            }
        }

        public var supportsTools: Bool {
            switch self {
            case .gptOSS120B, .gptOSS20B:
                return true // GPT-OSS supports tools
            case .llava, .bakllava, .llama32Vision11b, .llama32Vision90b,
                 .qwen25vl7b, .qwen25vl32b:
                return false // Vision models don't support tools
            case .llama33, .llama32, .llama31, .mistralNemo:
                return true
            case .codellama, .qwen25, .deepseekR1, .commandRPlus:
                return true
            case .llama2, .llama4, .mistral, .mixtral, .neuralChat, .gemma:
                return true
            case .deepseekR18b, .deepseekR1671b, .firefunction, .commandR:
                return true
            case .devstral:
                return false // DevStral doesn't support tools
            case let .custom(id):
                // Heuristic: treat likely-vision models as tool-less unless explicitly modeled.
                let lower = id.lowercased()
                if lower.contains("llava") || lower.contains("bakllava") { return false }
                if lower.contains("vision") { return false }
                if lower.contains("qwen2.5vl") || lower.contains("qwen25vl") { return false }
                if lower.contains("vl:") || lower.contains("-vl") || lower.contains("_vl") { return false }
                return true
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
            return "OpenAI/\(model.modelId)"
        case let .anthropic(model):
            return "Anthropic/\(model.modelId)"
        case let .google(model):
            return "Google/\(model.userFacingModelId)"
        case let .mistral(model):
            return "Mistral/\(model.rawValue)"
        case let .groq(model):
            return "Groq/\(model.rawValue)"
        case let .grok(model):
            return "Grok/\(model.modelId)"
        case let .ollama(model):
            return "Ollama/\(model.modelId)"
        case let .lmstudio(model):
            return "LMStudio/\(model.modelId)"
        case let .azureOpenAI(deployment, resource, apiVersion, endpoint):
            let host = endpoint ?? resource ?? "endpoint"
            let version = apiVersion ?? "api-version-default"
            return "AzureOpenAI/\(deployment)@\(host)?v=\(version)"
        case let .openRouter(modelId):
            return "OpenRouter/\(modelId)"
        case let .together(modelId):
            return "Together/\(modelId)"
        case let .replicate(modelId):
            return "Replicate/\(modelId)"
        case let .openaiCompatible(modelId, baseURL):
            return "OpenAI-Compatible/\(modelId)@\(baseURL)"
        case let .anthropicCompatible(modelId, baseURL):
            return "Anthropic-Compatible/\(modelId)@\(baseURL)"
        case let .custom(provider):
            return "Custom/\(provider.modelId)"
        }
    }

    public var modelId: String {
        switch self {
        case let .openai(model):
            model.modelId
        case let .anthropic(model):
            model.modelId
        case let .google(model):
            model.userFacingModelId
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
        case let .azureOpenAI(deployment, _, _, _):
            deployment
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
        case .azureOpenAI:
            true // Azure mirrors OpenAI models with vision support when available
        case .openRouter, .together, .replicate:
            false // Unknown, assume no vision support
        case .openaiCompatible, .anthropicCompatible:
            false // Unknown, assume no vision support
        case let .custom(provider):
            provider.capabilities.supportsVision
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
        case .azureOpenAI:
            "AzureOpenAI"
        case .custom:
            "Custom"
        }
    }

    // MARK: - Default Model

    public static let `default`: LanguageModel = .anthropic(.opus45)

    // MARK: - Convenience Static Properties

    /// Default Claude model (opus45)
    public static let claude: LanguageModel = .anthropic(.opus45)

    /// Default GPT-4o model
    public static let gpt4o: LanguageModel = .openai(.gpt4o)

    /// Default Grok model (Grok-4-0709)
    public static let grok4: LanguageModel = .grok(.grok4)

    /// Default Llama model
    public static let llama: LanguageModel = .ollama(.llama33)
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension LanguageModel {
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
        case .azureOpenAI:
            false // Azure chat endpoints currently omit audio input
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
        case .azureOpenAI:
            false // Azure chat endpoints currently omit audio output
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
        case .azureOpenAI:
            true // Azure OpenAI mirrors OpenAI tool support
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
        case .azureOpenAI:
            128_000 // conservative default matching OpenAI tier
        case .openRouter, .together, .replicate:
            128_000 // Common default
        case .openaiCompatible, .anthropicCompatible:
            128_000 // Common default
        case let .custom(provider):
            provider.capabilities.contextLength
        }
    }
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
        case let .azureOpenAI(deployment, resource, apiVersion, endpoint):
            hasher.combine("azureOpenAI")
            hasher.combine(deployment)
            hasher.combine(resource)
            hasher.combine(apiVersion)
            hasher.combine(endpoint)
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
        case let (
            .azureOpenAI(lhsDeployment, lhsResource, lhsAPIVersion, lhsEndpoint),
            .azureOpenAI(rhsDeployment, rhsResource, rhsAPIVersion, rhsEndpoint),
        ):
            lhsDeployment == rhsDeployment &&
                lhsResource == rhsResource &&
                lhsAPIVersion == rhsAPIVersion &&
                lhsEndpoint == rhsEndpoint
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

        if dotted.contains("gpt-5-2") || compact.contains("gpt52") {
            // GPT-5.2 currently has no mini/nano variants; map those suffixes to GPT-5 mini/nano.
            if dotted.contains("nano") || compact.contains("nano") { return .openai(.gpt5Nano) }
            if dotted.contains("mini") || compact.contains("mini") { return .openai(.gpt5Mini) }
            return .openai(.gpt52)
        }

        if dotted.contains("gpt-5-1") || compact.contains("gpt51") {
            // GPT-5.1 currently has no mini/nano variants; map those suffixes to GPT-5 mini/nano.
            if dotted.contains("nano") || compact.contains("nano") { return .openai(.gpt5Nano) }
            if dotted.contains("mini") || compact.contains("mini") { return .openai(.gpt5Mini) }
            return .openai(.gpt51)
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

        if
            dashed == "o3" || compact == "o3" || dashed == "o3-pro" || dashed == "o3-mini" || compact == "o3mini" ||
            compact == "o3pro"
        {
            // o3 family is deprecated; steer callers to GPT-5.1 Mini
            return .openai(.gpt5Mini)
        }

        if dashed == "o4-mini" || compact == "o4mini" {
            return .openai(.o4Mini)
        }

        // MARK: Anthropic models

        if
            dotted.contains("claude-opus-4-5") ||
            dotted.contains("claude-opus-4.5") ||
            compact.contains("claudeopus45") ||
            dotted.contains("opus-4-5") ||
            dotted.contains("opus-4.5") ||
            compact.contains("opus45")
        {
            return .anthropic(.opus45)
        }

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

        if
            normalized.contains("claude-haiku-4.5") ||
            dotted.contains("claude-haiku-4-5") ||
            compact.contains("claudehaiku45")
        {
            return .anthropic(.haiku45)
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

        // MARK: Google models

        if dashed.contains("gemini-3-flash") || compact.contains("gemini3flash") {
            return .google(.gemini3Flash)
        }

        if dashed.contains("gemini-2.5-pro") || dotted.contains("gemini-2-5-pro") || compact.contains("gemini25pro") {
            return .google(.gemini25Pro)
        }

        if
            dashed.contains("gemini-2.5-flash-lite") || dotted.contains("gemini-2-5-flash-lite") || compact
                .contains("gemini25flashlite")
        {
            return .google(.gemini25FlashLite)
        }

        if
            dashed.contains("gemini-2.5-flash") || dotted.contains("gemini-2-5-flash") || compact
                .contains("gemini25flash")
        {
            return .google(.gemini25Flash)
        }

        let genericGeminiIdentifiers: Set<String> = [
            "gemini",
            "geminiflash",
            "gemini-flash",
            "gemini_flash",
            "google",
        ]

        if canonicalForms.contains(where: { genericGeminiIdentifiers.contains($0) }) {
            return .google(.gemini3Flash)
        }

        // MARK: Grok models

        if dotted.contains("grok-4-fast-reasoning") || compact.contains("grok4fastreasoning") {
            return .grok(.grok4FastReasoning)
        }

        if dotted.contains("grok-4-fast-non-reasoning") || compact.contains("grok4fastnonreasoning") {
            return .grok(.grok4FastNonReasoning)
        }

        if dotted.contains("grok-code-fast-1") || compact.contains("grokcodefast1") {
            return .grok(.grokCodeFast1)
        }

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
            if dotted.contains("vision") {
                return .grok(.grok2Vision)
            }
            if dotted.contains("image") {
                return .grok(.grok2Image)
            }
            return .grok(.grok2)
        }

        if dotted.contains("grok-vision-beta") || compact.contains("grokvisionbeta") {
            return .grok(.grokVisionBeta)
        }

        if dotted.contains("grok-beta") || compact.contains("grokbeta") {
            return .grok(.grokBeta)
        }

        if compact.contains("grok") {
            return .grok(.grok4FastReasoning)
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

        if compact.contains("o4") {
            return .openai(.o4Mini)
        }

        return nil
    }
}

// swiftlint:enable file_length
