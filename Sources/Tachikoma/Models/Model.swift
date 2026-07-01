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
    case minimax(MiniMax)
    case minimaxCN(MiniMax)
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
        /// Latest ChatGPT Instant alias.
        case chatLatest

        /// GPT-5 snapshot previously used in ChatGPT.
        case gpt5ChatLatest

        /// GPT-5.5 Series
        case gpt55 // Flagship GPT-5.5

        /// GPT-5.4 Series
        case gpt54
        case gpt54Mini
        case gpt54Nano

        // GPT-5 Series (August 2025)
        case gpt5 // Best for coding and agentic tasks
        case gpt5Pro // Higher reasoning budget
        case gpt5Mini // Cost-optimized
        case gpt5Nano // Ultra-low latency

        /// Fine-tuned models
        case custom(String)

        public static var allCases: [OpenAI] {
            [
                .chatLatest,
                .gpt5ChatLatest,
                .gpt55,
                .gpt54,
                .gpt54Mini,
                .gpt54Nano,
                .gpt5,
                .gpt5Pro,
                .gpt5Mini,
                .gpt5Nano,
            ]
        }

        public var modelId: String {
            switch self {
            case let .custom(id): id
            case .chatLatest: "chat-latest"
            case .gpt5ChatLatest: "gpt-5-chat-latest"
            case .gpt55: "gpt-5.5"
            case .gpt54: "gpt-5.4"
            case .gpt54Mini: "gpt-5.4-mini"
            case .gpt54Nano: "gpt-5.4-nano"
            case .gpt5: "gpt-5"
            case .gpt5Pro: "gpt-5-pro"
            case .gpt5Mini: "gpt-5-mini"
            case .gpt5Nano: "gpt-5-nano"
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .chatLatest,
                 .gpt5ChatLatest,
                 .gpt55,
                 .gpt54, .gpt54Mini, .gpt54Nano,
                 .gpt5, .gpt5Pro, .gpt5Mini, .gpt5Nano: true // GPT-5+ supports multimodal
            default: false
            }
        }

        public var supportsTools: Bool {
            switch self {
            case .chatLatest,
                 .gpt5ChatLatest,
                 .gpt55,
                 .gpt54, .gpt54Mini, .gpt54Nano,
                 .gpt5, .gpt5Pro, .gpt5Mini, .gpt5Nano: true // GPT-5+ excels at tool calling
            case .custom: true // Assume custom models support tools
            }
        }

        public var supportsAudioInput: Bool {
            switch self {
            case .gpt55,
                 .gpt54, .gpt54Mini, .gpt54Nano,
                 .gpt5, .gpt5Pro, .gpt5Mini, .gpt5Nano: true // GPT-5+ is fully multimodal
            default: false
            }
        }

        public var supportsAudioOutput: Bool {
            switch self {
            case let .custom(id): id.contains("realtime")
            default: false
            }
        }

        public var supportsRealtime: Bool {
            switch self {
            case let .custom(id): id.contains("realtime")
            default: false
            }
        }

        public var contextLength: Int {
            switch self {
            case .gpt5ChatLatest:
                128_000
            case .chatLatest, .gpt55,
                 .gpt54, .gpt54Mini, .gpt54Nano,
                 .gpt5, .gpt5Pro, .gpt5Mini, .gpt5Nano: 400_000 // 272k input + 128k output
            case .custom: 128_000 // Default assumption
            }
        }

        public var isUnsupportedLegacyFamily: Bool {
            let normalized = self.modelId.lowercased()
            let compact = normalized.replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ".", with: "")
            return normalized.hasPrefix("gpt-4") || compact.hasPrefix("gpt4") ||
                normalized.hasPrefix("gpt-3") || compact.hasPrefix("gpt3") ||
                normalized.hasPrefix("o3") || normalized.hasPrefix("o4") ||
                normalized.hasPrefix("gpt-5.1") || compact.hasPrefix("gpt51") ||
                normalized.hasPrefix("gpt-5.2") || compact.hasPrefix("gpt52") ||
                normalized.contains("gpt-5-thinking") || compact.contains("gpt5thinking")
        }
    }

    public enum Anthropic: Sendable, Hashable, CaseIterable {
        // Claude 5 / 4.x Series
        case fable5
        case opus48
        case opus47
        case opus45
        case opus4
        case sonnet46
        case sonnet45
        case haiku45

        /// Fine-tuned models
        case custom(String)

        public static var allCases: [Anthropic] {
            [
                .fable5,
                .opus48,
                .opus47,
                .opus45,
                .opus4,
                .sonnet46,
                .sonnet45,
                .haiku45,
            ]
        }

        public var modelId: String {
            switch self {
            case let .custom(id): id
            case .fable5: "claude-fable-5"
            case .opus48: "claude-opus-4-8"
            case .opus47: "claude-opus-4-7"
            case .opus45: "claude-opus-4-5"
            case .opus4: "claude-opus-4-1-20250805"
            case .sonnet46: "claude-sonnet-4-6"
            case .sonnet45: "claude-sonnet-4-5-20250929"
            case .haiku45: "claude-haiku-4-5"
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .fable5, .opus48, .opus47, .opus45, .opus4, .sonnet46, .sonnet45, .haiku45:
                true
            case .custom: true // Assume custom models support vision
            }
        }

        public var supportsTools: Bool {
            true
        } // All Claude models support tools

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
            case .fable5, .opus48, .opus47, .sonnet46: 1_000_000
            case .haiku45: 200_000
            case .opus45, .opus4, .sonnet45: 500_000
            case let .custom(id):
                Self.isFable(modelId: id) ? 1_000_000 : 200_000 // Default assumption
            }
        }

        public var maxOutputTokens: Int {
            switch self {
            case .fable5, .opus48, .opus47: 128_000
            case .sonnet46, .haiku45: 64000
            case let .custom(id):
                Self.isFable(modelId: id) ? 128_000 : 8192
            case .opus45, .opus4, .sonnet45: 4096
            }
        }

        public var supportsStreaming: Bool {
            !Self.hasStreamingRefusalRisk(modelId: self.modelId)
        }

        public static func isFable(modelId: String) -> Bool {
            let normalized = modelId.lowercased()
            let pathSegments = normalized
                .components(separatedBy: CharacterSet(charactersIn: "/:@"))
                .filter { !$0.isEmpty }
            let dotSegments = pathSegments.flatMap { $0.components(separatedBy: ".") }
                .filter { !$0.isEmpty }
            let segments = pathSegments + dotSegments
            let canonicalSegments: Set = [
                "claude-fable-5",
                "fable-5",
                "fable5",
                "fable",
            ]
            return normalized == Self.fable5.modelId || segments.contains { segment in
                if canonicalSegments.contains(segment) { return true }
                let compactSegment = segment
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "_", with: "")
                    .replacingOccurrences(of: ".", with: "")
                return compactSegment == "claudefable5" || compactSegment == "fable5"
            }
        }

        public static func isOpus48(modelId: String) -> Bool {
            let normalized = modelId.lowercased()
            let compactExact = normalized
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: ".", with: "")
            let pathSegments = normalized
                .components(separatedBy: CharacterSet(charactersIn: "/:@"))
                .filter { !$0.isEmpty }
            let dotSegments = pathSegments.flatMap { $0.components(separatedBy: ".") }
                .filter { !$0.isEmpty }
            let segments = pathSegments + dotSegments
            let canonicalSegments: Set = [
                "claude-opus-4-8",
                "opus-4-8",
                "opus48",
            ]
            return normalized == Self.opus48.modelId || segments.contains { segment in
                if canonicalSegments.contains(segment) { return true }
                let compactSegment = segment
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "_", with: "")
                    .replacingOccurrences(of: ".", with: "")
                return compactSegment == "claudeopus48" || compactSegment == "opus48"
            } || compactExact == "claudeopus48" || compactExact == "opus48"
        }

        public static func hasStreamingRefusalRisk(modelId: String) -> Bool {
            self.isFable(modelId: modelId) || self.isOpus48(modelId: modelId)
        }
    }

    public enum Google: String, Sendable, Hashable, CaseIterable {
        case gemini35Flash = "gemini-3.5-flash"
        case gemini31ProPreview = "gemini-3.1-pro-preview"
        case gemini31FlashLite = "gemini-3.1-flash-lite"
        // NOTE: As of 2025-12-17, ListModels exposes Gemini 3 Flash as `gemini-3-flash-preview` on v1beta.
        // We keep the user-facing identifier as `gemini-3-flash` and map it to the preview model id for API calls.
        case gemini3Flash = "gemini-3-flash-preview"
        case gemini25Pro = "gemini-2.5-pro"
        case gemini25Flash = "gemini-2.5-flash"
        case gemini25FlashLite = "gemini-2.5-flash-lite"

        public var apiModelId: String {
            self.rawValue
        }

        public var userFacingModelId: String {
            switch self {
            case .gemini35Flash:
                "gemini-3.5-flash"
            case .gemini3Flash:
                "gemini-3-flash"
            case .gemini31ProPreview:
                "gemini-3.1-pro-preview"
            case .gemini31FlashLite:
                "gemini-3.1-flash-lite"
            default:
                self.rawValue
            }
        }

        public var supportsVision: Bool {
            true
        }

        public var supportsTools: Bool {
            true
        }

        public var supportsAudioInput: Bool {
            switch self {
            case .gemini35Flash, .gemini31ProPreview, .gemini3Flash, .gemini25Pro, .gemini25Flash:
                true
            case .gemini31FlashLite, .gemini25FlashLite:
                false
            }
        }

        public var supportsAudioOutput: Bool {
            false
        }

        public var contextLength: Int {
            switch self {
            case .gemini35Flash, .gemini31ProPreview, .gemini31FlashLite, .gemini3Flash, .gemini25Pro,
                 .gemini25Flash:
                1_048_576
            case .gemini25FlashLite:
                524_288
            }
        }
    }

    public enum MiniMax: String, Sendable, Hashable, CaseIterable {
        case m27 = "MiniMax-M2.7"
        case m27Highspeed = "MiniMax-M2.7-highspeed"
        case m3 = "MiniMax-M3"

        public var modelId: String {
            self.rawValue
        }

        public var supportsVision: Bool {
            switch self {
            case .m3: true
            case .m27, .m27Highspeed: false
            }
        }

        public var supportsTools: Bool {
            true
        }

        public var supportsAudioInput: Bool {
            false
        }

        public var supportsAudioOutput: Bool {
            false
        }

        public var contextLength: Int {
            switch self {
            case .m3: 1_000_000
            case .m27, .m27Highspeed: 204_800
            }
        }
    }

    public enum Mistral: String, Sendable, Hashable, CaseIterable {
        case largeLatest = "mistral-large-latest"
        case mediumLatest = "mistral-medium-latest"
        case medium35 = "mistral-medium-3-5"
        case smallLatest = "mistral-small-latest"
        case nemo = "open-mistral-nemo-2407"
        case codestralLatest = "codestral-latest"

        public var supportsVision: Bool {
            switch self {
            case .largeLatest, .mediumLatest, .medium35, .smallLatest: true
            default: false
            }
        }

        public var supportsTools: Bool {
            true
        }

        public var supportsAudioInput: Bool {
            false
        } // Mistral doesn't support audio yet
        public var supportsAudioOutput: Bool {
            false
        }

        public var contextLength: Int {
            switch self {
            case .largeLatest, .mediumLatest, .medium35, .smallLatest: 128_000
            case .nemo: 128_000
            case .codestralLatest: 256_000
            }
        }
    }

    public enum Groq: String, Sendable, Hashable, CaseIterable {
        // Groq-hosted models (ultra-fast inference)
        case gptOSS120B = "openai/gpt-oss-120b"
        case gptOSS20B = "openai/gpt-oss-20b"
        case llama3370b = "llama-3.3-70b-versatile"
        case llama318b = "llama-3.1-8b-instant"
        case llama4Maverick = "meta-llama/llama-4-maverick-17b-128e-instruct"
        case llama4Scout = "meta-llama/llama-4-scout-17b-16e-instruct"

        public var supportsVision: Bool {
            false
        } // Groq models don't support vision yet
        public var supportsTools: Bool {
            true
        }

        public var supportsAudioInput: Bool {
            false
        } // Groq focuses on text inference speed
        public var supportsAudioOutput: Bool {
            false
        }

        public var contextLength: Int {
            switch self {
            case .gptOSS120B, .gptOSS20B, .llama3370b, .llama318b, .llama4Maverick, .llama4Scout:
                128_000
            }
        }
    }

    public enum Grok: Sendable, Hashable, CaseIterable {
        // xAI Grok models
        case grok43
        case grok420MultiAgent
        case grok420Reasoning
        case grok420NonReasoning

        /// Custom models
        case custom(String)

        public static var allCases: [Grok] {
            [
                .grok43,
                .grok420Reasoning,
                .grok420NonReasoning,
            ]
        }

        public var modelId: String {
            switch self {
            case let .custom(id): id
            case .grok43: "grok-4.3"
            case .grok420MultiAgent: "grok-4.20-multi-agent-0309"
            case .grok420Reasoning: "grok-4.20-0309-reasoning"
            case .grok420NonReasoning: "grok-4.20-0309-non-reasoning"
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .grok43, .grok420Reasoning, .grok420NonReasoning, .custom:
                true
            case .grok420MultiAgent:
                // Upstream supports images, but this model requires Responses API routing.
                false
            }
        }

        public var supportsTools: Bool {
            switch self {
            case .grok420MultiAgent:
                false
            default:
                true
            }
        }

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
            case .grok43:
                1_000_000
            case .grok420MultiAgent,
                 .grok420Reasoning,
                 .grok420NonReasoning:
                2_000_000
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
        case mistralNemo
        case qwen25
        case commandRPlus

        // Additional models referenced by CLI
        case llama4
        case mistral
        case devstral
        case deepseekR18b
        case deepseekR1671b
        case firefunction
        case commandR

        /// Custom/other models
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
                .mistralNemo,
                .qwen25,
                .commandRPlus,
                .llama4,
                .mistral,
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
            case .mistralNemo: "mistral-nemo"
            case .qwen25: "qwen2.5"
            case .commandRPlus: "command-r-plus"
            case .llama4: "llama4"
            case .mistral: "mistral"
            case .devstral: "devstral"
            case .deepseekR18b: "deepseek-r1:8b"
            case .deepseekR1671b: "deepseek-r1:671b"
            case .firefunction: "firefunction-v2"
            case .commandR: "command-r"
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .llama4, .llava, .bakllava, .llama32Vision11b, .llama32Vision90b,
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
            case .qwen25, .commandRPlus:
                return true
            case .llama4, .mistral, .devstral:
                return true
            case .deepseekR18b, .deepseekR1671b, .firefunction, .commandR:
                return true
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

        public var supportsAudioInput: Bool {
            false
        } // Ollama models run locally and don't support native audio processing
        public var supportsAudioOutput: Bool {
            false
        }

        public var contextLength: Int {
            switch self {
            case .gptOSS120B, .gptOSS20B: 128_000
            case .llama33, .llama32, .llama31: 128_000
            case .llava, .bakllava: 32000
            case .llama32Vision11b: 128_000
            case .llama32Vision90b: 128_000
            case .qwen25vl7b, .qwen25vl32b: 125_000
            case .mistralNemo: 128_000
            case .qwen25: 32000
            case .commandRPlus: 128_000
            case .llama4: 1_000_000
            case .mistral: 32000
            case .devstral: 128_000
            case .deepseekR18b: 64000
            case .deepseekR1671b: 128_000
            case .firefunction: 8000
            case .commandR: 128_000
            case .custom: 32000
            }
        }
    }

    public enum LMStudio: Sendable, Hashable, CaseIterable {
        // GPT-OSS models
        case gptOSS120B
        case gptOSS20B

        /// Common local models
        case llama3370B

        /// Custom model path
        case custom(String)

        public static var allCases: [LMStudio] {
            [
                .gptOSS120B,
                .gptOSS20B,
                .llama3370B,
            ]
        }

        public var modelId: String {
            switch self {
            case .gptOSS120B: "openai/gpt-oss-120b"
            case .gptOSS20B: "openai/gpt-oss-20b"
            case .llama3370B: "meta/llama-3.3-70b"
            case let .custom(id): id
            }
        }

        public var supportsVision: Bool {
            switch self {
            case .gptOSS120B, .gptOSS20B: false
            case .llama3370B: false
            default: false
            }
        }

        public var supportsTools: Bool {
            switch self {
            case .custom: true // Assume support
            default: true // Most modern models support tools
            }
        }

        public var contextLength: Int {
            switch self {
            case .gptOSS120B, .gptOSS20B: 128_000
            case .llama3370B: 128_000
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
        case let .minimax(model):
            return "MiniMax/\(model.modelId)"
        case let .minimaxCN(model):
            return "MiniMax China/\(model.modelId)"
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
        case let .minimax(model):
            model.modelId
        case let .minimaxCN(model):
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
        case let .minimax(model):
            model.supportsVision
        case let .minimaxCN(model):
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
        if case let .anthropic(model) = self {
            return model.supportsStreaming
        }
        if case let .anthropicCompatible(modelId, _) = self {
            return !Anthropic.hasStreamingRefusalRisk(modelId: modelId)
        }
        if case let .openRouter(modelId) = self {
            return !Anthropic.hasStreamingRefusalRisk(modelId: modelId)
        }
        if case let .together(modelId) = self {
            return !Anthropic.hasStreamingRefusalRisk(modelId: modelId)
        }
        if case let .openaiCompatible(modelId, _) = self {
            guard !Anthropic.hasStreamingRefusalRisk(modelId: modelId) else {
                return false
            }
            let normalized = modelId.lowercased()
            guard
                normalized.contains("claude") ||
                normalized.hasPrefix("anthropic/") ||
                normalized.hasPrefix("anthropic.") else
            {
                return true
            }
            return true
        }
        if
            case let .custom(provider) = self,
            let parsed = ProviderParser.parse(provider.modelId),
            CustomProviderRegistry.shared.get(parsed.provider)?.kind == .anthropic
        {
            return !Anthropic.hasStreamingRefusalRisk(modelId: parsed.model)
        }
        if case let .custom(provider) = self {
            return provider.capabilities.supportsStreaming
        }
        return true
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
        case .minimax:
            "MiniMax"
        case .minimaxCN:
            "MiniMax China"
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

    public static let `default`: LanguageModel = .anthropic(.opus48)
    public static let defaultStreaming: LanguageModel = .openai(.gpt55)

    // MARK: - Convenience Static Properties

    /// Default Claude model (Opus 4.8)
    public static let claude: LanguageModel = .anthropic(.opus48)

    /// Default Grok model (Grok 4.3)
    public static let grok4: LanguageModel = .grok(.grok43)

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
        case let .minimax(model):
            model.supportsAudioInput
        case let .minimaxCN(model):
            model.supportsAudioInput
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
        case let .minimax(model):
            model.supportsAudioOutput
        case let .minimaxCN(model):
            model.supportsAudioOutput
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
        case let .minimax(model):
            model.supportsTools
        case let .minimaxCN(model):
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
        case let .minimax(model):
            model.contextLength
        case let .minimaxCN(model):
            model.contextLength
        case .azureOpenAI:
            128_000 // conservative default matching OpenAI tier
        case let .openRouter(modelId), let .together(modelId):
            Anthropic.isFable(modelId: modelId) ? 1_000_000 : 128_000
        case .replicate:
            128_000 // Common default
        case let .openaiCompatible(modelId, _):
            Anthropic.isFable(modelId: modelId) ? 1_000_000 : 128_000
        case let .anthropicCompatible(modelId, _):
            Anthropic.isFable(modelId: modelId) ? 1_000_000 : 128_000
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
        case let .minimax(model):
            hasher.combine("minimax")
            hasher.combine(model)
        case let .minimaxCN(model):
            hasher.combine("minimax-cn")
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
        case let (.minimax(lhsModel), .minimax(rhsModel)):
            lhsModel == rhsModel
        case let (.minimaxCN(lhsModel), .minimaxCN(rhsModel)):
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

        let qualified = ProviderParser.parse(trimmed)

        if
            let qualified,
            qualified.provider.lowercased() == "ollama"
        {
            return .ollama(Self.parseOllamaModelIdentifier(qualified.model))
        }

        if
            let qualified,
            ["lmstudio", "lm-studio"].contains(qualified.provider.lowercased())
        {
            return .lmstudio(Self.parseLMStudioModelIdentifier(qualified.model))
        }

        if
            let qualified,
            qualified.provider.lowercased() == "minimax"
        {
            return Self.parseMiniMaxModelIdentifier(qualified.model).map(LanguageModel.minimax)
        }

        if
            let qualified,
            ["minimax-cn", "minimax_cn", "minimaxi"].contains(qualified.provider.lowercased())
        {
            return Self.parseMiniMaxModelIdentifier(qualified.model).map(LanguageModel.minimaxCN)
        }

        if let qualified {
            let provider = qualified.provider.lowercased()
            if provider == "openai" {
                guard
                    let parsed = Self.parse(from: qualified.model),
                    case .openai = parsed else { return nil }

                return parsed
            }
            if provider == "openrouter" {
                return .openRouter(modelId: qualified.model)
            }
            if !["openai", "anthropic", "google", "gemini", "grok", "xai"].contains(provider) {
                return .openRouter(modelId: trimmed)
            }
            return Self.parseKnownProviderQualified(qualified)
        }

        let modelIdentifier = if
            let qualified,
            ["openai", "anthropic", "google", "gemini", "grok", "xai"]
                .contains(qualified.provider.lowercased())
        {
            qualified.model
        } else {
            trimmed
        }

        let normalized = modelIdentifier.lowercased()
        let dashed = normalized.replacingOccurrences(of: "_", with: "-")
        let compact = dashed.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ".", with: "")
        let dotted = dashed.replacingOccurrences(of: ".", with: "-")

        // MARK: OpenAI models

        if
            compact.contains("gpt4") || compact.contains("gpt3") || compact.contains("o3") || compact.contains("o4") ||
            compact.contains("gpt51") || compact.contains("gpt52") ||
            compact.contains("gpt5thinking")
        {
            return nil
        }

        if dashed == "chat-latest" || compact == "chatlatest" {
            return .openai(.chatLatest)
        }

        if dashed == "gpt-5-chat-latest" || compact == "gpt5chatlatest" {
            return .openai(.gpt5ChatLatest)
        }

        if dashed == "gpt-5-pro" || compact == "gpt5pro" {
            return .openai(.gpt5Pro)
        }

        if dotted.contains("gpt-5-5") || compact.contains("gpt55") {
            // GPT-5.5 currently has no mini/nano variants; map those suffixes to GPT-5 mini/nano.
            if dotted.contains("nano") || compact.contains("nano") { return .openai(.gpt5Nano) }
            if dotted.contains("mini") || compact.contains("mini") { return .openai(.gpt5Mini) }
            return .openai(.gpt55)
        }

        if dotted.contains("gpt-5-4") || compact.contains("gpt54") {
            if dotted.contains("nano") || compact.contains("nano") { return .openai(.gpt54Nano) }
            if dotted.contains("mini") || compact.contains("mini") { return .openai(.gpt54Mini) }
            return .openai(.gpt54)
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

        // MARK: Anthropic models

        func matchesExactAlias(_ aliases: Set<String>, compactAliases: Set<String> = []) -> Bool {
            aliases.contains(normalized) ||
                aliases.contains(dashed) ||
                aliases.contains(dotted) ||
                compactAliases.contains(compact)
        }

        if dotted.contains("claude-3") || compact.contains("claude3") {
            return nil
        }

        if
            normalized == "claude-opus-4-20250514" ||
            normalized == "claude-sonnet-4-20250514" ||
            normalized.contains("-thinking")
        {
            return nil
        }

        if
            matchesExactAlias(
                [
                    "claude-fable-5",
                    "fable-5",
                    "fable.5",
                    "fable5",
                    "fable",
                ],
                compactAliases: ["claudefable5", "fable5"],
            )
        {
            return .anthropic(.fable5)
        }

        if
            matchesExactAlias(
                [
                    "claude-opus-4-8",
                    "claude-opus-4.8",
                    "opus-4-8",
                    "opus-4.8",
                    "opus48",
                ],
                compactAliases: ["claudeopus48", "opus48"],
            )
        {
            return .anthropic(.opus48)
        }

        if
            dotted.contains("claude-opus-4-7") ||
            dotted.contains("claude-opus-4.7") ||
            compact.contains("claudeopus47") ||
            dotted.contains("opus-4-7") ||
            dotted.contains("opus-4.7") ||
            compact.contains("opus47")
        {
            return .anthropic(.opus47)
        }

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

        if
            dotted.contains("claude-opus-4-1-20250805") ||
            dotted.contains("claude-opus-4") ||
            compact.contains("claudeopus4") ||
            dotted.contains("opus-4")
        {
            return .anthropic(.opus4)
        }

        if
            dotted.contains("claude-sonnet-4-6") ||
            compact.contains("claudesonnet46") ||
            dotted.contains("sonnet-4-6")
        {
            return .anthropic(.sonnet46)
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
            return .anthropic(.sonnet46)
        }

        if
            normalized.contains("claude-haiku-4.5") ||
            dotted.contains("claude-haiku-4-5") ||
            compact.contains("claudehaiku45")
        {
            return .anthropic(.haiku45)
        }

        let genericClaudeIdentifiers: Set = [
            "claude",
            "claudelatest",
            "claude-latest",
            "claude_latest",
            "claude-default",
            "claude_default",
        ]

        let canonicalForms = [normalized, dashed, compact]
        if canonicalForms.contains(where: { genericClaudeIdentifiers.contains($0) }) {
            return .anthropic(.opus48)
        }

        // MARK: Google models

        if
            dashed.contains("gemini-3.5-flash") || dotted.contains("gemini-3-5-flash") || compact
                .contains("gemini35flash")
        {
            return .google(.gemini35Flash)
        }

        if
            dashed.contains("gemini-3.1-pro") || dotted.contains("gemini-3-1-pro") || compact
                .contains("gemini31pro")
        {
            return .google(.gemini31ProPreview)
        }

        if
            dashed.contains("gemini-3.1-flash-lite") || dotted.contains("gemini-3-1-flash-lite") || compact
                .contains("gemini31flashlite")
        {
            return .google(.gemini31FlashLite)
        }

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

        let genericGeminiIdentifiers: Set = [
            "gemini",
            "geminiflash",
            "gemini-flash",
            "gemini_flash",
            "google",
        ]

        if canonicalForms.contains(where: { genericGeminiIdentifiers.contains($0) }) {
            return .google(.gemini35Flash)
        }

        // MARK: MiniMax models

        if
            dashed.contains("minimax-cn-m3") ||
            dotted.contains("minimax-cn-m-3") ||
            compact.contains("minimaxcnm3") ||
            compact.contains("minimaxim3")
        {
            return .minimaxCN(.m3)
        }

        if
            dashed.contains("minimax-cn-m2.7-highspeed") ||
            dotted.contains("minimax-cn-m2-7-highspeed") ||
            compact.contains("minimaxcnm27highspeed") ||
            compact.contains("minimaxim27highspeed")
        {
            return .minimaxCN(.m27Highspeed)
        }

        if
            dashed == "minimax-cn" ||
            dashed == "minimaxi" ||
            dashed.contains("minimax-cn-m2.7") ||
            dotted.contains("minimax-cn-m2-7") ||
            compact.contains("minimaxcnm27") ||
            compact.contains("minimaxim27")
        {
            return .minimaxCN(.m27)
        }

        if
            dashed.contains("minimax-m2.7-highspeed") ||
            dotted.contains("minimax-m2-7-highspeed") ||
            compact.contains("minimaxm27highspeed") ||
            dashed == "m2.7-highspeed" ||
            dotted == "m2-7-highspeed"
        {
            return .minimax(.m27Highspeed)
        }

        if
            dashed.contains("minimax-m2.7") ||
            dotted.contains("minimax-m2-7") ||
            compact.contains("minimaxm27") ||
            dashed == "m2.7" ||
            dotted == "m2-7" ||
            normalized == "minimax"
        {
            return .minimax(.m27)
        }

        if
            dashed.contains("minimax-m3") ||
            dotted.contains("minimax-m-3") ||
            compact.contains("minimaxm3") ||
            dashed == "m3" ||
            dotted == "m-3"
        {
            return .minimax(.m3)
        }

        // MARK: Grok models

        let unsupportedGrok = normalized.contains("grok-4.20-multi-agent") ||
            dotted.contains("grok-4-20-multi-agent") ||
            compact.contains("grok420multiagent")
        if unsupportedGrok {
            return nil
        }

        if dotted.contains("grok-4-20-0309-reasoning") || compact.contains("grok4200309reasoning") {
            return .grok(.grok420Reasoning)
        }

        if dotted.contains("grok-4-20-0309-non-reasoning") || compact.contains("grok4200309nonreasoning") {
            return .grok(.grok420NonReasoning)
        }

        if
            dotted.contains("grok-4-3") ||
            normalized.contains("grok-4.3") ||
            compact.contains("grok43") ||
            normalized == "grok-4-latest" ||
            normalized == "grok-4" ||
            normalized == "grok-latest"
        {
            return .grok(.grok43)
        }

        if normalized.hasPrefix("grok-") {
            return .grok(.custom(modelIdentifier))
        }

        if compact.contains("grok") {
            return .grok(.grok43)
        }

        // MARK: Ollama models

        if normalized == "ollama" {
            return .ollama(.llama33)
        }

        if normalized == "lmstudio" || normalized == "lm-studio" {
            return .lmstudio(.gptOSS120B)
        }

        if compact.contains("gptoss") {
            if compact.contains("20b") {
                return .ollama(.gptOSS20B)
            }
            return .ollama(.gptOSS120B)
        }

        if compact.contains("qwen25vl") {
            return .ollama(Self.parseOllamaModelIdentifier(trimmed))
        }

        if normalized == "qwen2.5" || normalized == "qwen2.5:latest" || compact == "qwen25" {
            return .ollama(.qwen25)
        }

        if compact.contains("llama4") {
            return .ollama(.llama4)
        }

        if compact.contains("llama2") {
            return nil
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
            return .openai(.gpt55)
        }

        return nil
    }

    private static func parseKnownProviderQualified(_ qualified: ProviderParser.ProviderConfig) -> LanguageModel? {
        let provider = qualified.provider.lowercased()
        let model = qualified.model
        let normalized = model.lowercased()

        func unqualifiedModel(matchingProvider expectedProvider: (LanguageModel) -> Bool) -> LanguageModel? {
            guard let parsed = Self.parse(from: model), expectedProvider(parsed) else { return nil }
            return parsed
        }

        switch provider {
        case "openai":
            guard !Self.looksAnthropic(normalized), !Self.looksGoogle(normalized), !Self.looksGrok(normalized) else {
                return nil
            }
            return unqualifiedModel { if case .openai = $0 { true } else { false } }
                ??
                (Self.looksOpenAI(normalized) && !Self
                    .isUnsupportedOpenAI(normalized) ? .openai(.custom(model)) : nil)
        case "anthropic":
            guard !Self.looksOpenAI(normalized), !Self.looksGoogle(normalized), !Self.looksGrok(normalized) else {
                return nil
            }
            return unqualifiedModel { if case .anthropic = $0 { true } else { false } }
                ??
                (Self.looksAnthropic(normalized) && !Self
                    .isUnsupportedAnthropic(normalized) ? .anthropic(.custom(model)) : nil)
        case "google", "gemini":
            guard !Self.looksOpenAI(normalized), !Self.looksAnthropic(normalized), !Self.looksGrok(normalized) else {
                return nil
            }
            return unqualifiedModel { if case .google = $0 { true } else { false } }
        case "grok", "xai":
            guard !Self.looksOpenAI(normalized), !Self.looksAnthropic(normalized), !Self.looksGoogle(normalized) else {
                return nil
            }
            return unqualifiedModel { if case .grok = $0 { true } else { false } }
                ?? (Self.looksGrok(normalized) && !Self.isUnsupportedGrok(normalized) ? .grok(.custom(model)) : nil)
        default:
            return nil
        }
    }

    private static func looksOpenAI(_ normalized: String) -> Bool {
        normalized.contains("gpt") || normalized.hasPrefix("o3") || normalized.hasPrefix("o4") || normalized == "openai"
    }

    private static func looksAnthropic(_ normalized: String) -> Bool {
        normalized.contains("claude") || normalized.contains("fable") || normalized.contains("opus") ||
            normalized.contains("sonnet") || normalized.contains("haiku") || normalized == "anthropic"
    }

    private static func looksGoogle(_ normalized: String) -> Bool {
        normalized.contains("gemini") || normalized == "google"
    }

    private static func looksGrok(_ normalized: String) -> Bool {
        normalized.contains("grok") || normalized == "xai"
    }

    private static func isUnsupportedOpenAI(_ normalized: String) -> Bool {
        let compact = normalized.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ".", with: "")
        return compact.contains("gpt4") || compact.contains("gpt3") || compact.contains("o3") || compact
            .contains("o4") ||
            compact.contains("gpt51") || compact.contains("gpt52") ||
            compact.contains("gpt5thinking") || compact.contains("gpt5chat")
    }

    private static func isUnsupportedAnthropic(_ normalized: String) -> Bool {
        let compact = normalized.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ".", with: "")
        return normalized.hasPrefix("claude-3") || compact.hasPrefix("claude3") ||
            normalized == "claude-opus-4-20250514" ||
            normalized == "claude-sonnet-4-20250514" ||
            normalized.contains("-thinking")
    }

    private static func isUnsupportedGrok(_ normalized: String) -> Bool {
        normalized.contains("grok-4.20-multi-agent") ||
            normalized.contains("grok-4-20-multi-agent") ||
            normalized.contains("grok420multiagent")
    }

    private static func parseOllamaModelIdentifier(_ modelString: String) -> Ollama {
        let trimmed = modelString.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()

        switch normalized {
        case "gpt-oss:120b", "gpt-oss-120b":
            return .gptOSS120B
        case "gpt-oss:20b", "gpt-oss-20b":
            return .gptOSS20B
        case "llama3.3", "llama3.3:latest":
            return .llama33
        case "llama3.2", "llama3.2:latest":
            return .llama32
        case "llama3.1", "llama3.1:latest":
            return .llama31
        case "llava", "llava:latest":
            return .llava
        case "bakllava", "bakllava:latest":
            return .bakllava
        case "llama3.2-vision:11b":
            return .llama32Vision11b
        case "llama3.2-vision:90b":
            return .llama32Vision90b
        case "qwen2.5vl:7b":
            return .qwen25vl7b
        case "qwen2.5vl:32b":
            return .qwen25vl32b
        case "qwen2.5", "qwen2.5:latest":
            return .qwen25
        default:
            return .custom(trimmed)
        }
    }

    private static func parseLMStudioModelIdentifier(_ modelString: String) -> LMStudio {
        let trimmed = modelString.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()

        switch normalized {
        case "openai/gpt-oss-120b", "gpt-oss-120b", "gpt-oss:120b":
            return .gptOSS120B
        case "openai/gpt-oss-20b", "gpt-oss-20b", "gpt-oss:20b":
            return .gptOSS20B
        case "meta/llama-3.3-70b", "llama-3.3-70b", "llama3.3-70b":
            return .llama3370B
        default:
            return .custom(trimmed)
        }
    }

    private static func parseMiniMaxModelIdentifier(_ modelString: String) -> MiniMax? {
        let normalized = modelString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch normalized {
        case "minimax-m2.7", "minimax-m2-7", "m2.7", "m2-7":
            return .m27
        case "minimax-m2.7-highspeed", "minimax-m2-7-highspeed", "m2.7-highspeed", "m2-7-highspeed":
            return .m27Highspeed
        case "minimax-m3", "m3":
            return .m3
        default:
            return nil
        }
    }
}
