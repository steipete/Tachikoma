//
//  Provider.swift
//  Tachikoma
//

import Foundation

/// Type-safe provider enumeration supporting both standard and custom AI providers.
///
/// This enum provides compile-time safety for standard providers while maintaining
/// flexibility for custom provider configurations. All standard providers include
/// their corresponding environment variable names for automatic configuration.
///
/// Example usage:
/// ```swift
/// let config = TachikomaConfiguration()
/// // Type-safe standard providers
/// config.setAPIKey("sk-...", for: .openai)
/// config.setAPIKey("sk-...", for: .anthropic)
/// 
/// // Custom providers
/// config.setAPIKey("key", for: .custom("my-provider"))
/// ```
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum Provider: Sendable, Hashable, Codable {
    /// OpenAI provider (GPT models, DALL-E, etc.)
    case openai
    
    /// Anthropic provider (Claude models)
    case anthropic
    
    /// Grok provider (X.AI models)
    case grok
    
    /// Groq provider (ultra-fast inference)
    case groq
    
    /// Mistral AI provider
    case mistral
    
    /// Google provider (Gemini models)
    case google
    
    /// Ollama provider (local model hosting)
    case ollama
    
    /// Custom provider with user-defined identifier
    case custom(String)
    
    /// String identifier for this provider
    public var identifier: String {
        switch self {
        case .openai: return "openai"
        case .anthropic: return "anthropic"
        case .grok: return "grok"
        case .groq: return "groq"
        case .mistral: return "mistral"
        case .google: return "google"
        case .ollama: return "ollama"
        case .custom(let id): return id
        }
    }
    
    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .grok: return "Grok"
        case .groq: return "Groq"
        case .mistral: return "Mistral"
        case .google: return "Google"
        case .ollama: return "Ollama"
        case .custom(let id): return id.capitalized
        }
    }
    
    /// Environment variable name for API key (empty for custom providers)
    public var environmentVariable: String {
        switch self {
        case .openai: return "OPENAI_API_KEY"
        case .anthropic: return "ANTHROPIC_API_KEY"
        case .grok: return "X_AI_API_KEY"
        case .groq: return "GROQ_API_KEY"
        case .mistral: return "MISTRAL_API_KEY"
        case .google: return "GOOGLE_API_KEY"
        case .ollama: return "OLLAMA_API_KEY"
        case .custom: return "" // Custom providers manage their own env vars
        }
    }
    
    /// Alternative environment variable names (for compatibility)
    public var alternativeEnvironmentVariables: [String] {
        switch self {
        case .grok: return ["XAI_API_KEY"] // Alternative Grok API key name
        default: return []
        }
    }
    
    /// Default base URL for this provider (nil for custom providers)
    public var defaultBaseURL: String? {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com"
        case .grok: return "https://api.x.ai/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .mistral: return "https://api.mistral.ai/v1"
        case .google: return "https://generativelanguage.googleapis.com/v1beta"
        case .ollama: return "http://localhost:11434"
        case .custom: return nil
        }
    }
    
    /// Whether this provider requires an API key
    public var requiresAPIKey: Bool {
        switch self {
        case .ollama: return false // Ollama typically doesn't require API key
        case .custom: return true // Assume custom providers need keys
        default: return true
        }
    }
    
    /// All standard providers (excludes custom)
    public static var standardProviders: [Provider] {
        [.openai, .anthropic, .grok, .groq, .mistral, .google, .ollama]
    }
    
    /// Create provider from string identifier
    public static func from(identifier: String) -> Provider {
        switch identifier.lowercased() {
        case "openai": return .openai
        case "anthropic": return .anthropic
        case "grok": return .grok
        case "groq": return .groq
        case "mistral": return .mistral
        case "google": return .google
        case "ollama": return .ollama
        default: return .custom(identifier)
        }
    }
}

// MARK: - Environment Variable Loading

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension Provider {
    /// Load API key from environment variables
    /// Checks primary environment variable first, then alternatives
    public func loadAPIKeyFromEnvironment() -> String? {
        let environment = ProcessInfo.processInfo.environment
        
        // Check primary environment variable
        if !environmentVariable.isEmpty {
            if let key = environment[environmentVariable], !key.isEmpty {
                return key
            }
        }
        
        // Check alternative environment variables
        for altVar in alternativeEnvironmentVariables {
            if let key = environment[altVar], !key.isEmpty {
                return key
            }
        }
        
        return nil
    }
    
    /// Check if API key is available in environment
    public var hasEnvironmentAPIKey: Bool {
        loadAPIKeyFromEnvironment() != nil
    }
}

// MARK: - Codable Implementation

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension Provider {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        self = Provider.from(identifier: identifier)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(identifier)
    }
}