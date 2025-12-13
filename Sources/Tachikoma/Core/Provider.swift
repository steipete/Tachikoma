import Configuration
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
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
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
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

    /// LMStudio provider (local model hosting with GUI)
    case lmstudio

    /// Azure-hosted OpenAI service
    case azureOpenAI

    /// Custom provider with user-defined identifier
    case custom(String)

    /// String identifier for this provider
    public var identifier: String {
        switch self {
        case .openai: "openai"
        case .anthropic: "anthropic"
        case .grok: "grok"
        case .groq: "groq"
        case .mistral: "mistral"
        case .google: "google"
        case .ollama: "ollama"
        case .lmstudio: "lmstudio"
        case .azureOpenAI: "azure-openai"
        case let .custom(id): id
        }
    }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .openai: "OpenAI"
        case .anthropic: "Anthropic"
        case .grok: "Grok"
        case .groq: "Groq"
        case .mistral: "Mistral"
        case .google: "Google"
        case .ollama: "Ollama"
        case .lmstudio: "LMStudio"
        case .azureOpenAI: "Azure OpenAI"
        case let .custom(id): id.capitalized
        }
    }

    /// Environment variable name for API key (empty for custom providers)
    public var environmentVariable: String {
        switch self {
        case .openai: "OPENAI_API_KEY"
        case .anthropic: "ANTHROPIC_API_KEY"
        case .grok: "X_AI_API_KEY"
        case .groq: "GROQ_API_KEY"
        case .mistral: "MISTRAL_API_KEY"
        case .google: "GEMINI_API_KEY"
        case .ollama: "OLLAMA_API_KEY"
        case .lmstudio: "" // LMStudio doesn't need API keys
        case .azureOpenAI: "AZURE_OPENAI_API_KEY"
        case .custom: "" // Custom providers manage their own env vars
        }
    }

    /// Alternative environment variable names (for compatibility)
    public var alternativeEnvironmentVariables: [String] {
        switch self {
        case .grok: ["XAI_API_KEY"] // Additional Grok alias
        case .google: ["GOOGLE_API_KEY", "GOOGLE_APPLICATION_CREDENTIALS"] // Backwards compatibility
        case .azureOpenAI: ["AZURE_OPENAI_TOKEN", "AZURE_OPENAI_BEARER_TOKEN"]
        default: []
        }
    }

    /// Default base URL for this provider (nil for custom providers)
    public var defaultBaseURL: String? {
        switch self {
        case .openai: "https://api.openai.com/v1"
        case .anthropic: "https://api.anthropic.com"
        case .grok: "https://api.x.ai/v1"
        case .groq: "https://api.groq.com/openai/v1"
        case .mistral: "https://api.mistral.ai/v1"
        case .google: "https://generativelanguage.googleapis.com/v1beta"
        case .ollama: "http://localhost:11434"
        case .lmstudio: "http://localhost:1234/v1"
        case .azureOpenAI: nil // Requires resource or endpoint
        case .custom: nil
        }
    }

    /// Whether this provider requires an API key
    public var requiresAPIKey: Bool {
        switch self {
        case .ollama: false // Ollama typically doesn't require API key
        case .lmstudio: false // LMStudio doesn't require API key
        case .custom: true // Assume custom providers need keys
        default: true
        }
    }

    /// All standard providers (excludes custom)
    public static var standardProviders: [Provider] {
        [.openai, .anthropic, .grok, .groq, .mistral, .google, .ollama, .azureOpenAI]
    }

    /// Create provider from string identifier
    public static func from(identifier: String) -> Provider {
        // Create provider from string identifier
        switch identifier.lowercased() {
        case "openai": .openai
        case "anthropic": .anthropic
        case "grok", "xai": .grok
        case "groq": .groq
        case "mistral": .mistral
        case "google": .google
        case "ollama": .ollama
        case "azure-openai", "azure_openai", "azureopenai": .azureOpenAI
        default: .custom(identifier)
        }
    }
}

// MARK: - Environment Variable Loading

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension Provider {
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, *)
    private static var environmentReader: ConfigReader {
        enum Holder {
            static let reader = ConfigReader(
                provider: EnvironmentVariablesProvider(
                    secretsSpecifier: .dynamic { key, _ in
                        let lowercased = key.lowercased()
                        return lowercased.contains("key") ||
                            lowercased.contains("token") ||
                            lowercased.contains("secret")
                    },
                ),
            )
        }
        return Holder.reader
    }

    /// Load API key from environment variables
    /// Checks primary environment variable first, then alternatives
    public func loadAPIKeyFromEnvironment() -> String? {
        // Check primary environment variable
        if !self.environmentVariable.isEmpty {
            if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, *) {
                if
                    let key = Self.environmentReader.string(
                        forKey: ConfigKey([self.environmentVariable]),
                        isSecret: true,
                    ),
                    !key.isEmpty
                {
                    return key
                }
            } else if
                let key = ProcessInfo.processInfo.environment[environmentVariable],
                !key.isEmpty
            {
                return key
            }
        }

        // Check alternative environment variables
        for altVar in self.alternativeEnvironmentVariables {
            if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, *) {
                if
                    let key = Self.environmentReader.string(forKey: ConfigKey([altVar]), isSecret: true),
                    !key.isEmpty
                {
                    return key
                }
            } else if let key = ProcessInfo.processInfo.environment[altVar], !key.isEmpty {
                return key
            }
        }

        return nil
    }

    /// Check if API key is available in environment
    public var hasEnvironmentAPIKey: Bool {
        self.loadAPIKeyFromEnvironment() != nil
    }

    /// Read an environment value using the shared configuration reader.
    public static func environmentValue(for key: String, isSecret: Bool = false) -> String? {
        // Read an environment value using the shared configuration reader.
        if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, *) {
            if
                let value = environmentReader.string(forKey: ConfigKey([key]), isSecret: isSecret),
                !value.isEmpty
            {
                return value
            }
        }

        guard let pointer = getenv(key) else {
            return nil
        }
        return String(cString: pointer)
    }
}

// MARK: - Codable Implementation

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension Provider {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        self = Provider.from(identifier: identifier)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.identifier)
    }
}
