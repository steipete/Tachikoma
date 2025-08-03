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
        case gpt4_1
        case gpt4_1Mini
        
        // GPT-4o Series (Multimodal)
        case gpt4o
        case gpt4oMini
        
        // Legacy support
        case gpt4Turbo
        case gpt35Turbo
        
        // Fine-tuned models
        case custom(String)
        
        public static var allCases: [OpenAI] {
            return [.o3, .o3Mini, .o3Pro, .o4Mini, .gpt4_1, .gpt4_1Mini, .gpt4o, .gpt4oMini, .gpt4Turbo, .gpt35Turbo]
        }
        
        public var modelId: String {
            switch self {
            case .custom(let id): return id
            case .o3: return "o3"
            case .o3Mini: return "o3-mini"
            case .o3Pro: return "o3-pro"
            case .o4Mini: return "o4-mini"
            case .gpt4_1: return "gpt-4.1"
            case .gpt4_1Mini: return "gpt-4.1-mini"
            case .gpt4o: return "gpt-4o"
            case .gpt4oMini: return "gpt-4o-mini"
            case .gpt4Turbo: return "gpt-4-turbo"
            case .gpt35Turbo: return "gpt-3.5-turbo"
            }
        }
        
        public var supportsVision: Bool {
            switch self {
            case .gpt4o, .gpt4oMini: return true
            default: return false
            }
        }
        
        public var supportsTools: Bool {
            switch self {
            case .o3, .o3Mini, .o3Pro, .o4Mini, .gpt4_1, .gpt4_1Mini, .gpt4o, .gpt4oMini, .gpt4Turbo: return true
            case .gpt35Turbo: return true
            case .custom: return true // Assume custom models support tools
            }
        }
        
        public var contextLength: Int {
            switch self {
            case .o3, .o3Pro: return 1_000_000
            case .o3Mini, .o4Mini: return 128_000
            case .gpt4_1, .gpt4_1Mini: return 1_000_000
            case .gpt4o, .gpt4oMini: return 128_000
            case .gpt4Turbo: return 128_000
            case .gpt35Turbo: return 16_000
            case .custom: return 128_000 // Default assumption
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
        case sonnet3_7
        
        // Claude 3.5 Series
        case opus3_5
        case sonnet3_5
        case haiku3_5
        
        // Legacy Claude 3 Series
        case opus3
        case sonnet3
        case haiku3
        
        // Fine-tuned models
        case custom(String)
        
        public static var allCases: [Anthropic] {
            return [.opus4, .opus4Thinking, .sonnet4, .sonnet4Thinking, .sonnet3_7, .opus3_5, .sonnet3_5, .haiku3_5, .opus3, .sonnet3, .haiku3]
        }
        
        public var modelId: String {
            switch self {
            case .custom(let id): return id
            case .opus4: return "claude-opus-4-20250514"
            case .opus4Thinking: return "claude-opus-4-20250514-thinking"
            case .sonnet4: return "claude-sonnet-4-20250514"
            case .sonnet4Thinking: return "claude-sonnet-4-20250514-thinking"
            case .sonnet3_7: return "claude-3-7-sonnet"
            case .opus3_5: return "claude-3-5-opus"
            case .sonnet3_5: return "claude-3-5-sonnet"
            case .haiku3_5: return "claude-3-5-haiku"
            case .opus3: return "claude-3-opus"
            case .sonnet3: return "claude-3-sonnet"
            case .haiku3: return "claude-3-haiku"
            }
        }
        
        public var supportsVision: Bool {
            switch self {
            case .opus4, .opus4Thinking, .sonnet4, .sonnet4Thinking, .sonnet3_7, .opus3_5, .sonnet3_5, .haiku3_5: return true
            case .opus3, .sonnet3, .haiku3: return true
            case .custom: return true // Most modern Claude models support vision
            }
        }
        
        public var supportsTools: Bool { true } // All Claude models support tools
        
        public var contextLength: Int {
            switch self {
            case .opus4, .opus4Thinking, .sonnet4, .sonnet4Thinking: return 500_000
            case .sonnet3_7: return 200_000
            case .opus3_5, .sonnet3_5: return 200_000
            case .haiku3_5: return 200_000
            case .opus3, .sonnet3: return 200_000
            case .haiku3: return 200_000
            case .custom: return 200_000
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
        
        public var contextLength: Int {
            switch self {
            case .gemini2Flash, .gemini2FlashThinking: return 1_000_000
            case .gemini15Pro, .gemini15Flash: return 2_000_000
            case .gemini15Flash8B: return 1_000_000
            case .geminiPro, .geminiProVision: return 32_000
            }
        }
    }
    
    public enum Mistral: String, Sendable, Hashable, CaseIterable {
        case large2 = "mistral-large-2"
        case large = "mistral-large"
        case medium = "mistral-medium"
        case small = "mistral-small"
        case nemo = "mistral-nemo"
        case codestral = "codestral"
        
        public var supportsVision: Bool {
            switch self {
            case .large2, .large: return true
            default: return false
            }
        }
        
        public var supportsTools: Bool { true }
        
        public var contextLength: Int {
            switch self {
            case .large2, .large: return 128_000
            case .medium: return 32_000
            case .small: return 32_000
            case .nemo: return 128_000
            case .codestral: return 32_000
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
        
        public var contextLength: Int {
            switch self {
            case .llama31_70b, .llama31_8b: return 128_000
            case .llama3_70b, .llama3_8b: return 8_000
            case .mixtral8x7b: return 32_000
            case .gemma2_9b: return 8_000
            }
        }
    }
    
    public enum Grok: Sendable, Hashable, CaseIterable {
        // xAI Grok models
        case grok4
        case grok4_0709
        case grok4Latest
        case grok3
        case grok3Mini
        case grok3Fast
        case grok3MiniFast
        case grok2_1212
        case grok2Vision_1212
        case grok2Image_1212
        case grokBeta
        case grokVisionBeta
        
        // Custom models
        case custom(String)
        
        public static var allCases: [Grok] {
            return [.grok4, .grok4_0709, .grok4Latest, .grok3, .grok3Mini, .grok3Fast, .grok3MiniFast, 
                    .grok2_1212, .grok2Vision_1212, .grok2Image_1212, .grokBeta, .grokVisionBeta]
        }
        
        public var modelId: String {
            switch self {
            case .custom(let id): return id
            case .grok4: return "grok-4"
            case .grok4_0709: return "grok-4-0709"
            case .grok4Latest: return "grok-4-latest"
            case .grok3: return "grok-3"
            case .grok3Mini: return "grok-3-mini"
            case .grok3Fast: return "grok-3-fast"
            case .grok3MiniFast: return "grok-3-mini-fast"
            case .grok2_1212: return "grok-2-1212"
            case .grok2Vision_1212: return "grok-2-vision-1212"
            case .grok2Image_1212: return "grok-2-image-1212"
            case .grokBeta: return "grok-beta"
            case .grokVisionBeta: return "grok-vision-beta"
            }
        }
        
        public var supportsVision: Bool {
            switch self {
            case .grok2Vision_1212, .grok2Image_1212, .grokVisionBeta: return true
            case .custom: return true // Assume custom models support vision
            default: return false
            }
        }
        
        public var supportsTools: Bool { true }
        
        public var contextLength: Int {
            switch self {
            case .grok4, .grok4_0709, .grok4Latest: return 256_000
            case .grok3, .grok3Mini, .grok3Fast, .grok3MiniFast: return 128_000
            case .grok2_1212, .grok2Vision_1212, .grok2Image_1212: return 128_000
            case .grokBeta, .grokVisionBeta: return 128_000
            case .custom: return 128_000 // Default assumption for custom models
            }
        }
    }
    
    public enum Ollama: Sendable, Hashable, CaseIterable {
        // Recommended models for different use cases
        case llama33        // Best overall
        case llama3_3       // Alternative naming
        case llama32        // Good alternative  
        case llama3_2       // Alternative naming
        case llama31        // Older but reliable
        case llama3_1       // Alternative naming
        
        // Vision models (no tool support)
        case llava
        case bakllava
        case llama32Vision11b
        case llama3_2Vision11b
        case llama32Vision90b
        case llama3_2Vision90b
        case qwen2_5vl7b
        case qwen2_5vl32b
        
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
        case deepseekR1_8b
        case deepseekR1_671b
        case firefunction
        case commandR
        
        // Custom/other models
        case custom(String)
        
        public static var allCases: [Ollama] {
            return [.llama33, .llama3_3, .llama32, .llama3_2, .llama31, .llama3_1,
                    .llava, .bakllava, .llama32Vision11b, .llama3_2Vision11b, .llama32Vision90b, .llama3_2Vision90b,
                    .qwen2_5vl7b, .qwen2_5vl32b, .codellama, .mistralNemo, .qwen25, .deepseekR1, .commandRPlus,
                    .llama2, .llama4, .mistral, .mixtral, .neuralChat, .gemma, .devstral, .deepseekR1_8b, .deepseekR1_671b,
                    .firefunction, .commandR]
        }
        
        public var modelId: String {
            switch self {
            case .custom(let id): return id
            case .llama33, .llama3_3: return "llama3.3"
            case .llama32, .llama3_2: return "llama3.2"
            case .llama31, .llama3_1: return "llama3.1"
            case .llava: return "llava"
            case .bakllava: return "bakllava"
            case .llama32Vision11b, .llama3_2Vision11b: return "llama3.2-vision:11b"
            case .llama32Vision90b, .llama3_2Vision90b: return "llama3.2-vision:90b"
            case .qwen2_5vl7b: return "qwen2.5vl:7b"
            case .qwen2_5vl32b: return "qwen2.5vl:32b"
            case .codellama: return "codellama"
            case .mistralNemo: return "mistral-nemo"
            case .qwen25: return "qwen2.5"
            case .deepseekR1: return "deepseek-r1"
            case .commandRPlus: return "command-r-plus"
            case .llama2: return "llama2"
            case .llama4: return "llama4"
            case .mistral: return "mistral"
            case .mixtral: return "mixtral"
            case .neuralChat: return "neural-chat"
            case .gemma: return "gemma"
            case .devstral: return "devstral"
            case .deepseekR1_8b: return "deepseek-r1:8b"
            case .deepseekR1_671b: return "deepseek-r1:671b"
            case .firefunction: return "firefunction-v2"
            case .commandR: return "command-r"
            }
        }
        
        public var supportsVision: Bool {
            switch self {
            case .llava, .bakllava, .llama32Vision11b, .llama3_2Vision11b, .llama32Vision90b, .llama3_2Vision90b, .qwen2_5vl7b, .qwen2_5vl32b: return true
            default: return false
            }
        }
        
        public var supportsTools: Bool {
            switch self {
            case .llava, .bakllava, .llama32Vision11b, .llama3_2Vision11b, .llama32Vision90b, .llama3_2Vision90b, .qwen2_5vl7b, .qwen2_5vl32b: return false // Vision models don't support tools
            case .llama33, .llama3_3, .llama32, .llama3_2, .llama31, .llama3_1, .mistralNemo: return true
            case .codellama, .qwen25, .deepseekR1, .commandRPlus: return true
            case .llama2, .llama4, .mistral, .mixtral, .neuralChat, .gemma: return true
            case .deepseekR1_8b, .deepseekR1_671b, .firefunction, .commandR: return true
            case .devstral: return false // DevStral doesn't support tools
            case .custom: return true // Assume tools support
            }
        }
        
        public var contextLength: Int {
            switch self {
            case .llama33, .llama3_3, .llama32, .llama3_2, .llama31, .llama3_1: return 128_000
            case .llava, .bakllava: return 32_000
            case .llama32Vision11b, .llama3_2Vision11b: return 128_000
            case .llama32Vision90b, .llama3_2Vision90b: return 128_000
            case .qwen2_5vl7b, .qwen2_5vl32b: return 32_000
            case .codellama: return 32_000
            case .mistralNemo: return 128_000
            case .qwen25: return 32_000
            case .deepseekR1: return 128_000
            case .commandRPlus: return 128_000
            case .llama2, .llama4: return 128_000
            case .mistral, .mixtral: return 32_000
            case .neuralChat, .gemma: return 32_000
            case .devstral: return 16_000
            case .deepseekR1_8b: return 64_000
            case .deepseekR1_671b: return 128_000
            case .firefunction: return 32_000
            case .commandR: return 128_000
            case .custom: return 32_000
            }
        }
    }
    
    // MARK: - Model Properties
    
    public var description: String {
        switch self {
        case .openai(let model):
            return "OpenAI/\(model.modelId)"
        case .anthropic(let model):
            return "Anthropic/\(model.modelId)"
        case .google(let model):
            return "Google/\(model.rawValue)"
        case .mistral(let model):
            return "Mistral/\(model.rawValue)"
        case .groq(let model):
            return "Groq/\(model.rawValue)"
        case .grok(let model):
            return "Grok/\(model.modelId)"
        case .ollama(let model):
            return "Ollama/\(model.modelId)"
        case .openRouter(let modelId):
            return "OpenRouter/\(modelId)"
        case .together(let modelId):
            return "Together/\(modelId)"
        case .replicate(let modelId):
            return "Replicate/\(modelId)"
        case .openaiCompatible(let modelId, let baseURL):
            return "OpenAI-Compatible/\(modelId)@\(baseURL)"
        case .anthropicCompatible(let modelId, let baseURL):
            return "Anthropic-Compatible/\(modelId)@\(baseURL)"
        case .custom(let provider):
            return "Custom/\(provider.modelId)"
        }
    }
    
    public var modelId: String {
        switch self {
        case .openai(let model):
            return model.modelId
        case .anthropic(let model):
            return model.modelId
        case .google(let model):
            return model.rawValue
        case .mistral(let model):
            return model.rawValue
        case .groq(let model):
            return model.rawValue
        case .grok(let model):
            return model.modelId
        case .ollama(let model):
            return model.modelId
        case .openRouter(let modelId):
            return modelId
        case .together(let modelId):
            return modelId
        case .replicate(let modelId):
            return modelId
        case .openaiCompatible(let modelId, _):
            return modelId
        case .anthropicCompatible(let modelId, _):
            return modelId
        case .custom(let provider):
            return provider.modelId
        }
    }
    
    public var supportsVision: Bool {
        switch self {
        case .openai(let model):
            return model.supportsVision
        case .anthropic(let model):
            return model.supportsVision
        case .google(let model):
            return model.supportsVision
        case .mistral(let model):
            return model.supportsVision
        case .groq(let model):
            return model.supportsVision
        case .grok(let model):
            return model.supportsVision
        case .ollama(let model):
            return model.supportsVision
        case .openRouter, .together, .replicate:
            return false // Unknown, assume no vision support
        case .openaiCompatible, .anthropicCompatible:
            return false // Unknown, assume no vision support
        case .custom(let provider):
            return provider.capabilities.supportsVision
        }
    }
    
    public var supportsTools: Bool {
        switch self {
        case .openai(let model):
            return model.supportsTools
        case .anthropic(let model):
            return model.supportsTools
        case .google(let model):
            return model.supportsTools
        case .mistral(let model):
            return model.supportsTools
        case .groq(let model):
            return model.supportsTools
        case .grok(let model):
            return model.supportsTools
        case .ollama(let model):
            return model.supportsTools
        case .openRouter, .together, .replicate:
            return true // Most aggregator models support tools
        case .openaiCompatible, .anthropicCompatible:
            return true // Assume tools support for compatible APIs
        case .custom(let provider):
            return provider.capabilities.supportsTools
        }
    }
    
    public var contextLength: Int {
        switch self {
        case .openai(let model):
            return model.contextLength
        case .anthropic(let model):
            return model.contextLength
        case .google(let model):
            return model.contextLength
        case .mistral(let model):
            return model.contextLength
        case .groq(let model):
            return model.contextLength
        case .grok(let model):
            return model.contextLength
        case .ollama(let model):
            return model.contextLength
        case .openRouter, .together, .replicate:
            return 128_000 // Common default
        case .openaiCompatible, .anthropicCompatible:
            return 128_000 // Common default
        case .custom(let provider):
            return provider.capabilities.contextLength
        }
    }
    
    public var supportsStreaming: Bool {
        // All models support streaming by default
        return true
    }
    
    public var providerName: String {
        switch self {
        case .openai:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        case .google:
            return "Google"
        case .mistral:
            return "Mistral"
        case .groq:
            return "Groq"
        case .grok:
            return "Grok"
        case .ollama:
            return "Ollama"
        case .openRouter:
            return "OpenRouter"
        case .together:
            return "Together"
        case .replicate:
            return "Replicate"
        case .openaiCompatible:
            return "OpenAI-Compatible"
        case .anthropicCompatible:
            return "Anthropic-Compatible"
        case .custom(_):
            return "Custom"
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
    public let contextLength: Int
    public let maxOutputTokens: Int
    public let costPerToken: (input: Double, output: Double)?
    
    public init(
        supportsVision: Bool = false,
        supportsTools: Bool = true,
        supportsStreaming: Bool = true,
        contextLength: Int = 128_000,
        maxOutputTokens: Int = 4_096,
        costPerToken: (input: Double, output: Double)? = nil
    ) {
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.supportsStreaming = supportsStreaming
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