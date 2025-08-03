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
    
    public enum OpenAI: String, Sendable, CaseIterable {
        // O3 Series (Reasoning Models)
        case o3 = "o3"
        case o3Mini = "o3-mini"
        case o3Pro = "o3-pro"
        
        // O4 Series
        case o4Mini = "o4-mini"
        
        // GPT-4.1 Series (Latest Generation)
        case gpt41 = "gpt-4.1"
        case gpt41Mini = "gpt-4.1-mini"
        
        // GPT-4o Series (Multimodal)
        case gpt4o = "gpt-4o"
        case gpt4oMini = "gpt-4o-mini"
        
        // Legacy aliases - use legacy model names but implement as redirects
        case gpt4 = "gpt-4"  
        case gpt4Turbo = "gpt-4-turbo"
        
        public var supportsVision: Bool {
            switch self {
            case .gpt4o, .gpt4oMini:
                return true
            default:
                return false
            }
        }
        
        public var supportsTools: Bool { true }
        public var supportsStreaming: Bool { true }
        public var supportsReasoning: Bool {
            switch self {
            case .o3, .o3Mini, .o3Pro, .o4Mini:
                return true
            default:
                return false
            }
        }
    }
    
    public enum Anthropic: String, Sendable, CaseIterable {
        // Claude 4 Series (Latest Generation - May 2025)
        case opus4 = "claude-opus-4-20250514"
        case sonnet4 = "claude-sonnet-4-20250514"
        case opus4Thinking = "claude-opus-4-20250514-thinking"
        case sonnet4Thinking = "claude-sonnet-4-20250514-thinking"
        
        // Claude 3.7 Series (February 2025)
        case sonnet37 = "claude-3-7-sonnet"
        
        // Claude 3.5 Series (Still Available)
        case haiku35 = "claude-3-5-haiku"
        case sonnet35 = "claude-3-5-sonnet"
        case opus35 = "claude-3-5-opus"
        
        // Legacy aliases - use legacy names but map to modern models
        case opus = "claude-3-opus"  
        case sonnet = "claude-3-sonnet"  
        case haiku = "claude-3-haiku"
        
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
    }
    
    public enum Grok: String, Sendable, CaseIterable {
        // Grok 4 Series (Latest)
        case grok4 = "grok-4"
        case grok4_0709 = "grok-4-0709"
        case grok4Latest = "grok-4-latest"
        
        // Grok 2 Series
        case grok2 = "grok-2-1212"
        case grok2Vision = "grok-2-vision-1212"
        
        // Beta Models
        case grokBeta = "grok-beta"
        case grokVisionBeta = "grok-vision-beta"
        
        // Legacy aliases
        case grok = "grok-2"  // Use different model ID
        
        public var supportsVision: Bool {
            switch self {
            case .grok2Vision, .grokVisionBeta:
                return true
            default:
                return false
            }
        }
        
        public var supportsTools: Bool { true }
        public var supportsStreaming: Bool { true }
    }
    
    public enum Ollama: String, Sendable, CaseIterable {
        // Recommended Models with Tool Support
        case llama33 = "llama3.3"
        case llama32 = "llama3.2"
        case llama31 = "llama3.1"
        case mistralNemo = "mistral-nemo"
        case firefunction = "firefunction-v2"
        case commandRPlus = "command-r-plus"
        case commandR = "command-r"
        
        // Vision Models (No Tool Support)
        case llava = "llava"
        case bakllava = "bakllava"
        case llama32Vision11b = "llama3.2-vision:11b"
        case llama32Vision90b = "llama3.2-vision:90b"
        case qwen25vl7b = "qwen2.5vl:7b"
        case qwen25vl32b = "qwen2.5vl:32b"
        
        // Other Models
        case devstral = "devstral"
        case mistral = "mistral"
        case mixtral = "mixtral"
        case codellama = "codellama"
        case deepseekR1_8b = "deepseek-r1:8b"
        case deepseekR1_671b = "deepseek-r1:671b"
        
        // Legacy aliases - use different model IDs
        case llama = "llama:latest"  
        case llama3 = "llama3:latest"
        
        public var supportsVision: Bool {
            switch self {
            case .llava, .bakllava, .llama32Vision11b, .llama32Vision90b, .qwen25vl7b, .qwen25vl32b:
                return true
            default:
                return false
            }
        }
        
        public var supportsTools: Bool {
            switch self {
            case .llama33, .llama32, .llama31, .mistralNemo, .firefunction, .commandRPlus, .commandR:
                return true
            default:
                return false
            }
        }
        
        public var supportsStreaming: Bool { true }
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
    static let grok = Model.grok(Model.Grok.grok4)
    static let llama = Model.ollama(Model.Ollama.llama33)
}