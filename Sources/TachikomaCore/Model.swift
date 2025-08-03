import Foundation

// MARK: - Modern Model Selection System

/// Modern type-safe model selection with provider-specific enums
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum Model: Sendable, Hashable, CustomStringConvertible {
    case openai(OpenAI)
    case anthropic(Anthropic)
    case grok(Grok)
    case ollama(Ollama)
    case openRouter(modelId: String)
    case openaiCompatible(modelId: String, baseURL: String)
    
    // MARK: - Provider Sub-Enums
    
    public enum OpenAI: Sendable, Hashable, CaseIterable {
        // O3 Series (Reasoning Models)
        case o3
        case o3Mini
        case o3Pro
        
        // O4 Series
        case o4Mini
        
        // GPT-4.1 Series (Latest Generation)
        case gpt41
        case gpt4_1  // Alternative naming
        case gpt41Mini
        case gpt4_1Mini  // Alternative naming
        
        // GPT-4o Series (Multimodal)
        case gpt4o
        case gpt4oMini
        
        // Legacy aliases - use legacy model names but implement as redirects
        case gpt4
        case gpt4Turbo
        
        // Custom/unknown model support
        case custom(String)
        
        public var rawValue: String {
            switch self {
            case .o3: return "o3"
            case .o3Mini: return "o3-mini"
            case .o3Pro: return "o3-pro"
            case .o4Mini: return "o4-mini"
            case .gpt41: return "gpt-4.1"
            case .gpt4_1: return "gpt-4.1-alt"
            case .gpt41Mini: return "gpt-4.1-mini"
            case .gpt4_1Mini: return "gpt-4.1-mini-alt"
            case .gpt4o: return "gpt-4o"
            case .gpt4oMini: return "gpt-4o-mini"
            case .gpt4: return "gpt-4"
            case .gpt4Turbo: return "gpt-4-turbo"
            case .custom(let modelId): return modelId
            }
        }
        
        public var supportsVision: Bool {
            switch self {
            case .gpt4o, .gpt4oMini:
                return true
            case .custom:
                return false  // Unknown, assume not
            default:
                return false
            }
        }
        
        public var supportsTools: Bool { 
            switch self {
            case .custom:
                return true  // Assume most models support tools
            default:
                return true
            }
        }
        
        public var supportsStreaming: Bool { 
            switch self {
            case .custom:
                return true  // Assume most models support streaming
            default:
                return true
            }
        }
        
        public var supportsReasoning: Bool {
            switch self {
            case .o3, .o3Mini, .o3Pro, .o4Mini:
                return true
            case .custom:
                return false  // Unknown, assume not
            default:
                return false
            }
        }
        
        public static var allCases: [OpenAI] {
            [.o3, .o3Mini, .o3Pro, .o4Mini, .gpt41, .gpt4_1, .gpt41Mini, .gpt4_1Mini, .gpt4o, .gpt4oMini, .gpt4, .gpt4Turbo]
        }
    }
    
    public enum Anthropic: Sendable, Hashable, CaseIterable {
        // Claude 4 Series (Latest Generation - May 2025)
        case opus4
        case sonnet4
        case opus4Thinking
        case sonnet4Thinking
        
        // Claude 3.7 Series (February 2025)
        case sonnet37
        case sonnet3_7  // Alternative naming
        
        // Claude 3.5 Series (Still Available)
        case haiku35
        case haiku3_5  // Alternative naming
        case sonnet35
        case sonnet3_5  // Alternative naming
        case opus35
        case opus3_5  // Alternative naming
        
        // Legacy aliases - use legacy names but map to modern models
        case opus
        case sonnet
        case haiku
        
        // Custom/unknown model support
        case custom(String)
        
        public var rawValue: String {
            switch self {
            case .opus4: return "claude-opus-4-20250514"
            case .sonnet4: return "claude-sonnet-4-20250514"
            case .opus4Thinking: return "claude-opus-4-20250514-thinking"
            case .sonnet4Thinking: return "claude-sonnet-4-20250514-thinking"
            case .sonnet37: return "claude-3-7-sonnet"
            case .sonnet3_7: return "claude-3-7-sonnet-alt"
            case .haiku35: return "claude-3-5-haiku"
            case .haiku3_5: return "claude-3-5-haiku-alt"
            case .sonnet35: return "claude-3-5-sonnet"
            case .sonnet3_5: return "claude-3-5-sonnet-alt"
            case .opus35: return "claude-3-5-opus"
            case .opus3_5: return "claude-3-5-opus-alt"
            case .opus: return "claude-3-opus"
            case .sonnet: return "claude-3-sonnet"
            case .haiku: return "claude-3-haiku"
            case .custom(let modelId): return modelId
            }
        }
        
        public var supportsVision: Bool { true }
        public var supportsTools: Bool { true }
        public var supportsStreaming: Bool { true }
        public var supportsThinking: Bool {
            switch self {
            case .opus4Thinking, .sonnet4Thinking:
                return true
            default:
                return false
            }
        }
        
        public static var allCases: [Anthropic] {
            [.opus4, .sonnet4, .opus4Thinking, .sonnet4Thinking, .sonnet37, .sonnet3_7, .haiku35, .haiku3_5, .sonnet35, .sonnet3_5, .opus35, .opus3_5, .opus, .sonnet, .haiku]
        }
    }
    
    public enum Grok: Sendable, Hashable, CaseIterable {
        // Grok 4 Series (Latest)
        case grok4
        case grok4_0709
        case grok4Latest
        
        // Grok 3 Series
        case grok3
        case grok3Mini
        case grok3Fast
        case grok3MiniFast
        
        // Grok 2 Series
        case grok2
        case grok2_1212
        case grok2Vision
        case grok2Vision_1212
        case grok2Image_1212
        
        // Beta Models
        case grokBeta
        case grokVisionBeta
        
        // Legacy aliases
        case grok
        
        // Custom/unknown model support
        case custom(String)
        
        public var rawValue: String {
            switch self {
            case .grok4: return "grok-4"
            case .grok4_0709: return "grok-4-0709"
            case .grok4Latest: return "grok-4-latest"
            case .grok3: return "grok-3"
            case .grok3Mini: return "grok-3-mini"
            case .grok3Fast: return "grok-3-fast"
            case .grok3MiniFast: return "grok-3-mini-fast"
            case .grok2: return "grok-2-1212"
            case .grok2_1212: return "grok-2-1212"
            case .grok2Vision: return "grok-2-vision-1212"
            case .grok2Vision_1212: return "grok-2-vision-1212"
            case .grok2Image_1212: return "grok-2-image-1212"
            case .grokBeta: return "grok-beta"
            case .grokVisionBeta: return "grok-vision-beta"
            case .grok: return "grok-2"
            case .custom(let modelId): return modelId
            }
        }
        
        public var supportsVision: Bool {
            switch self {
            case .grok2Vision, .grok2Vision_1212, .grok2Image_1212, .grokVisionBeta:
                return true
            default:
                return false
            }
        }
        
        public var supportsTools: Bool { true }
        public var supportsStreaming: Bool { true }
        
        public static var allCases: [Grok] {
            [.grok4, .grok4_0709, .grok4Latest, .grok3, .grok3Mini, .grok3Fast, .grok3MiniFast, .grok2, .grok2_1212, .grok2Vision, .grok2Vision_1212, .grok2Image_1212, .grokBeta, .grokVisionBeta, .grok]
        }
    }
    
    public enum Ollama: Sendable, Hashable, CaseIterable {
        // Recommended Models with Tool Support
        case llama33
        case llama3_3
        case llama32
        case llama3_2
        case llama31
        case llama3_1
        case llama2
        case llama4
        case mistralNemo
        case firefunction
        case commandRPlus
        case commandR
        
        // Vision Models (No Tool Support)
        case llava
        case bakllava
        case llama32Vision11b
        case llama3_2Vision11b
        case llama32Vision90b
        case llama3_2Vision90b
        case qwen25vl7b
        case qwen2_5vl7b
        case qwen25vl32b
        case qwen2_5vl32b
        
        // Other Models
        case devstral
        case mistral
        case mixtral
        case codellama
        case neuralChat
        case gemma
        case deepseekR1_8b
        case deepseekR1_671b
        
        // Legacy aliases - use different model IDs
        case llama
        case llama3
        
        // Custom/unknown model support
        case custom(String)
        
        public var rawValue: String {
            switch self {
            case .llama33: return "llama3.3"
            case .llama3_3: return "llama3.3"
            case .llama32: return "llama3.2"
            case .llama3_2: return "llama3.2"
            case .llama31: return "llama3.1"
            case .llama3_1: return "llama3.1"
            case .llama2: return "llama2"
            case .llama4: return "llama4"
            case .mistralNemo: return "mistral-nemo"
            case .firefunction: return "firefunction-v2"
            case .commandRPlus: return "command-r-plus"
            case .commandR: return "command-r"
            case .llava: return "llava"
            case .bakllava: return "bakllava"
            case .llama32Vision11b: return "llama3.2-vision:11b"
            case .llama3_2Vision11b: return "llama3.2-vision:11b"
            case .llama32Vision90b: return "llama3.2-vision:90b"
            case .llama3_2Vision90b: return "llama3.2-vision:90b"
            case .qwen25vl7b: return "qwen2.5vl:7b"
            case .qwen2_5vl7b: return "qwen2.5vl:7b"
            case .qwen25vl32b: return "qwen2.5vl:32b"
            case .qwen2_5vl32b: return "qwen2.5vl:32b"
            case .devstral: return "devstral"
            case .mistral: return "mistral"
            case .mixtral: return "mixtral"
            case .codellama: return "codellama"
            case .neuralChat: return "neural-chat"
            case .gemma: return "gemma"
            case .deepseekR1_8b: return "deepseek-r1:8b"
            case .deepseekR1_671b: return "deepseek-r1:671b"
            case .llama: return "llama:latest"
            case .llama3: return "llama3:latest"
            case .custom(let modelId): return modelId
            }
        }
        
        public var supportsVision: Bool {
            switch self {
            case .llava, .bakllava, .llama32Vision11b, .llama3_2Vision11b, .llama32Vision90b, .llama3_2Vision90b, .qwen25vl7b, .qwen2_5vl7b, .qwen25vl32b, .qwen2_5vl32b:
                return true
            default:
                return false
            }
        }
        
        public var supportsTools: Bool {
            switch self {
            case .llama33, .llama3_3, .llama32, .llama3_2, .llama31, .llama3_1, .llama2, .llama4, .mistralNemo, .firefunction, .commandRPlus, .commandR:
                return true
            default:
                return false
            }
        }
        
        public var supportsStreaming: Bool { true }
        
        public static var allCases: [Ollama] {
            [.llama33, .llama3_3, .llama32, .llama3_2, .llama31, .llama3_1, .llama2, .llama4, .mistralNemo, .firefunction, .commandRPlus, .commandR, .llava, .bakllava, .llama32Vision11b, .llama3_2Vision11b, .llama32Vision90b, .llama3_2Vision90b, .qwen25vl7b, .qwen2_5vl7b, .qwen25vl32b, .qwen2_5vl32b, .devstral, .mistral, .mixtral, .codellama, .neuralChat, .gemma, .deepseekR1_8b, .deepseekR1_671b, .llama, .llama3]
        }
    }
    
    // MARK: - Model Properties
    
    public var description: String {
        switch self {
        case .openai(let model):
            return model.rawValue
        case .anthropic(let model):
            return model.rawValue
        case .grok(let model):
            return model.rawValue
        case .ollama(let model):
            return model.rawValue
        case .openRouter(let modelId):
            return "openrouter/\(modelId)"
        case .openaiCompatible(let modelId, _):
            return "custom/\(modelId)"
        }
    }
    
    public var supportsVision: Bool {
        switch self {
        case .openai(let model):
            return model.supportsVision
        case .anthropic(let model):
            return model.supportsVision
        case .grok(let model):
            return model.supportsVision
        case .ollama(let model):
            return model.supportsVision
        case .openRouter, .openaiCompatible:
            return false // Unknown, assume not
        }
    }
    
    public var supportsTools: Bool {
        switch self {
        case .openai(let model):
            return model.supportsTools
        case .anthropic(let model):
            return model.supportsTools
        case .grok(let model):
            return model.supportsTools
        case .ollama(let model):
            return model.supportsTools
        case .openRouter, .openaiCompatible:
            return true // Most models support tools
        }
    }
    
    public var supportsStreaming: Bool {
        switch self {
        case .openai(let model):
            return model.supportsStreaming
        case .anthropic(let model):
            return model.supportsStreaming
        case .grok(let model):
            return model.supportsStreaming
        case .ollama(let model):
            return model.supportsStreaming
        case .openRouter, .openaiCompatible:
            return true // Most models support streaming
        }
    }
    
    public var providerName: String {
        switch self {
        case .openai:
            return "openai"
        case .anthropic:
            return "anthropic"
        case .grok:
            return "grok"
        case .ollama:
            return "ollama"
        case .openRouter:
            return "openrouter"
        case .openaiCompatible:
            return "custom"
        }
    }
    
    public var modelId: String {
        switch self {
        case .openai(let model):
            return model.rawValue
        case .anthropic(let model):
            return model.rawValue
        case .grok(let model):
            return model.rawValue
        case .ollama(let model):
            return model.rawValue
        case .openRouter(let modelId):
            return modelId
        case .openaiCompatible(let modelId, _):
            return modelId
        }
    }
    
    // MARK: - Default Models
    
    /// Default model for the entire SDK (Claude Opus 4)
    public static var `default`: Model {
        .anthropic(.opus4)
    }
    
    /// Recommended models for specific use cases
    public static var recommended: RecommendedModels {
        RecommendedModels()
    }
    
    public struct RecommendedModels {
        public let coding = Model.anthropic(Model.Anthropic.opus4)
        public let reasoning = Model.openai(Model.OpenAI.o3)
        public let vision = Model.openai(Model.OpenAI.gpt4o)
        public let speed = Model.openai(Model.OpenAI.gpt4oMini)
        public let local = Model.ollama(Model.Ollama.llama33)
        public let budget = Model.anthropic(Model.Anthropic.haiku35)
    }
}

// MARK: - Model Creation Helpers

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public extension Model {
    /// Create custom OpenRouter model
    static func openRouter(_ modelId: String) -> Model {
        .openRouter(modelId: modelId)
    }
    
    /// Create custom OpenAI-compatible model
    static func custom(_ modelId: String, baseURL: String) -> Model {
        .openaiCompatible(modelId: modelId, baseURL: baseURL)
    }
}

// MARK: - Convenience Shortcuts

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public extension Model {
    /// Quick access to popular models
    static let claude = Model.anthropic(Model.Anthropic.opus4)
    static let gpt4 = Model.openai(Model.OpenAI.gpt4o)
    static let gpt4o = Model.openai(Model.OpenAI.gpt4o)
    static let grok = Model.grok(Model.Grok.grok4)
    static let grok4 = Model.grok(Model.Grok.grok4)
    static let llama = Model.ollama(Model.Ollama.llama33)
}