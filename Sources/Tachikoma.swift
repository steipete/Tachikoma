import Foundation
@_exported import Logging

/// Tachikoma - A comprehensive Swift package for AI model integration
///
/// Tachikoma provides a unified interface for connecting to various AI providers
/// including OpenAI, Anthropic, Grok (xAI), Ollama, and custom endpoints.
/// It supports both streaming and non-streaming responses, tool calling,
/// multimodal inputs, and configuration management.
///
/// Named after the AI entity from Ghost in the Shell, Tachikoma embodies
/// the cyberpunk aesthetic of autonomous AI systems.

// MARK: - AIModelProvider

/// Manages multiple AI model instances with explicit dependency injection
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class AIModelProvider: Sendable {
    private let models: [String: any ModelInterface]
    
    public init(models: [String: any ModelInterface] = [:]) {
        self.models = models
    }
    
    /// Get a model instance for the specified model name
    /// - Parameter modelName: The model identifier (e.g., "gpt-4.1", "claude-opus-4", "provider-id/model-name")
    /// - Returns: A model instance conforming to ModelInterface
    /// - Throws: TachikomaError if the model is not available or configuration is invalid
    public func getModel(_ modelName: String) throws -> any ModelInterface {
        guard let model = models[modelName] else {
            throw TachikomaError.modelNotFound(modelName)
        }
        return model
    }
    
    /// List all available models
    /// - Returns: Array of available model identifiers
    public func availableModels() -> [String] {
        return Array(models.keys).sorted()
    }
    
    /// Add or update a model
    /// - Parameters:
    ///   - modelName: The model identifier
    ///   - model: The model instance
    public func withModel(_ modelName: String, model: any ModelInterface) -> AIModelProvider {
        var newModels = self.models
        newModels[modelName] = model
        return AIModelProvider(models: newModels)
    }
    
    /// Add multiple models
    /// - Parameter models: Dictionary of model name to model instance
    public func withModels(_ models: [String: any ModelInterface]) -> AIModelProvider {
        var newModels = self.models
        for (name, model) in models {
            newModels[name] = model
        }
        return AIModelProvider(models: newModels)
    }
}

// MARK: - AIModelFactory

/// Factory for creating commonly used model configurations
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AIModelFactory {
    
    /// Create an OpenAI model
    public static func openAI(apiKey: String, modelName: String, baseURL: URL? = nil, organizationId: String? = nil) -> any ModelInterface {
        return OpenAIModel(
            apiKey: apiKey,
            baseURL: baseURL ?? URL(string: "https://api.openai.com/v1")!,
            organizationId: organizationId,
            modelName: modelName
        )
    }
    
    /// Create an Anthropic model
    public static func anthropic(apiKey: String, modelName: String, baseURL: URL? = nil) -> any ModelInterface {
        return AnthropicModel(
            apiKey: apiKey,
            baseURL: baseURL ?? URL(string: "https://api.anthropic.com/v1")!,
            modelName: modelName
        )
    }
    
    /// Create a Grok model
    public static func grok(apiKey: String, modelName: String, baseURL: URL? = nil) -> any ModelInterface {
        return GrokModel(
            apiKey: apiKey,
            modelName: modelName,
            baseURL: baseURL ?? URL(string: "https://api.x.ai/v1")!
        )
    }
    
    /// Create an Ollama model
    public static func ollama(modelName: String, baseURL: URL? = nil) -> any ModelInterface {
        return OllamaModel(
            modelName: modelName,
            baseURL: baseURL ?? URL(string: "http://localhost:11434")!
        )
    }
}

// MARK: - AIConfiguration

/// Configuration helper for setting up AI providers from environment variables
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AIConfiguration {
    
    /// Create an AIModelProvider from environment variables and standard model configurations
    public static func fromEnvironment() throws -> AIModelProvider {
        var models: [String: any ModelInterface] = [:]
        
        // OpenAI models
        if let apiKey = getOpenAIAPIKey() {
            let openAIModels = [
                "gpt-4o", "gpt-4o-mini",
                "gpt-4.1", "gpt-4.1-mini", 
                "o3", "o3-mini", "o3-pro",
                "o4-mini"
            ]
            
            for modelName in openAIModels {
                models[modelName] = AIModelFactory.openAI(apiKey: apiKey, modelName: modelName)
            }
        }
        
        // Anthropic models
        if let apiKey = getAnthropicAPIKey() {
            let anthropicModels = [
                "claude-opus-4-20250514", "claude-opus-4-20250514-thinking",
                "claude-sonnet-4-20250514", "claude-sonnet-4-20250514-thinking",
                "claude-3-7-sonnet",
                "claude-3-5-haiku", "claude-3-5-sonnet", "claude-3-5-opus"
            ]
            
            for modelName in anthropicModels {
                models[modelName] = AIModelFactory.anthropic(apiKey: apiKey, modelName: modelName)
            }
        }
        
        // Grok models
        if let apiKey = getGrokAPIKey() {
            let grokModels = [
                "grok-4", "grok-4-0709", "grok-4-latest",
                "grok-3", "grok-3-mini", "grok-3-fast", "grok-3-mini-fast",
                "grok-2-1212", "grok-2-vision-1212", "grok-2-image-1212",
                "grok-beta", "grok-vision-beta"
            ]
            
            for modelName in grokModels {
                models[modelName] = AIModelFactory.grok(apiKey: apiKey, modelName: modelName)
            }
        }
        
        // Ollama models (no API key required)
        let ollamaBaseURL = ProcessInfo.processInfo.environment["TACHIKOMA_OLLAMA_BASE_URL"] ?? "http://localhost:11434"
        if let baseURL = URL(string: ollamaBaseURL) {
            let ollamaModels = [
                "llama3.3", "llama3.3:latest",
                "llama3.2", "llama3.2:latest",
                "llava:latest", "llava",
                "bakllava:latest", "bakllava",
                "llama3.2-vision:11b", "llama3.2-vision:90b",
                "qwen2.5vl:7b", "qwen2.5vl:32b",
                "llama2", "llama2:latest",
                "llama4", "llama4:latest",
                "codellama", "codellama:latest",
                "mistral", "mistral:latest",
                "mixtral", "mixtral:latest",
                "neural-chat", "neural-chat:latest",
                "gemma", "gemma:latest",
                "devstral", "devstral:latest",
                "deepseek-r1:8b", "deepseek-r1:671b"
            ]
            
            for modelName in ollamaModels {
                models[modelName] = AIModelFactory.ollama(modelName: modelName, baseURL: baseURL)
            }
        }
        
        return AIModelProvider(models: models)
    }
    
    // MARK: - Private Helpers
    
    private static func getOpenAIAPIKey() -> String? {
        if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            return apiKey
        }
        return getAPIKeyFromCredentials(key: "OPENAI_API_KEY")
    }
    
    private static func getAnthropicAPIKey() -> String? {
        if let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            return apiKey
        }
        return getAPIKeyFromCredentials(key: "ANTHROPIC_API_KEY")
    }
    
    private static func getGrokAPIKey() -> String? {
        if let apiKey = ProcessInfo.processInfo.environment["X_AI_API_KEY"] {
            return apiKey
        }
        if let apiKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] {
            return apiKey
        }
        return getAPIKeyFromCredentials(key: "X_AI_API_KEY") ?? getAPIKeyFromCredentials(key: "XAI_API_KEY")
    }
    
    private static func getAPIKeyFromCredentials(key: String) -> String? {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".tachikoma")
            .appendingPathComponent("credentials")
        
        guard let credentials = try? String(contentsOf: configPath) else {
            return nil
        }
        
        for line in credentials.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("\(key)=") {
                return String(trimmed.dropFirst("\(key)=".count))
            }
        }
        
        return nil
    }
}

// MARK: - Legacy Compatibility (DEPRECATED)

/// Legacy Tachikoma singleton class - DEPRECATED
/// Use AIModelProvider with dependency injection instead
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@available(*, deprecated, message: "Use AIModelProvider with dependency injection instead of Tachikoma.shared singleton")
public final class Tachikoma: @unchecked Sendable {
    public static let shared = Tachikoma()
    
    private let logger: Logger
    private var modelProvider: AIModelProvider
    
    private init() {
        self.logger = Logger(label: "build.tachikoma")
        self.modelProvider = (try? AIConfiguration.fromEnvironment()) ?? AIModelProvider()
    }
    
    /// Get the shared logger instance
    public var log: Logger {
        logger
    }
    
    /// Get a model instance for the specified model name
    /// - Parameter modelName: The model identifier (e.g., "gpt-4.1", "claude-opus-4", "provider-id/model-name")
    /// - Returns: A model instance conforming to ModelInterface
    /// - Throws: TachikomaError if the model is not available or configuration is invalid
    public func getModel(_ modelName: String) async throws -> any ModelInterface {
        return try modelProvider.getModel(modelName)
    }
    
    /// Configure OpenAI provider with specific settings
    /// - Parameter configuration: OpenAI configuration
    public func configureOpenAI(_ configuration: ProviderConfiguration.OpenAI) async {
        // Update the model provider with new OpenAI models
        var models: [String: any ModelInterface] = [:]
        let openAIModels = ["gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini", "o3", "o3-mini", "o3-pro", "o4-mini"]
        
        for modelName in openAIModels {
            models[modelName] = AIModelFactory.openAI(
                apiKey: configuration.apiKey,
                modelName: modelName,
                baseURL: configuration.baseURL,
                organizationId: configuration.organizationId
            )
        }
        
        self.modelProvider = self.modelProvider.withModels(models)
    }
    
    /// Configure Anthropic provider with specific settings
    /// - Parameter configuration: Anthropic configuration
    public func configureAnthropic(_ configuration: ProviderConfiguration.Anthropic) async {
        var models: [String: any ModelInterface] = [:]
        let anthropicModels = [
            "claude-opus-4-20250514", "claude-opus-4-20250514-thinking",
            "claude-sonnet-4-20250514", "claude-sonnet-4-20250514-thinking",
            "claude-3-7-sonnet",
            "claude-3-5-haiku", "claude-3-5-sonnet", "claude-3-5-opus"
        ]
        
        for modelName in anthropicModels {
            models[modelName] = AIModelFactory.anthropic(
                apiKey: configuration.apiKey,
                modelName: modelName,
                baseURL: configuration.baseURL
            )
        }
        
        self.modelProvider = self.modelProvider.withModels(models)
    }
    
    /// Configure Ollama provider with specific settings
    /// - Parameter configuration: Ollama configuration
    public func configureOllama(_ configuration: ProviderConfiguration.Ollama) async {
        var models: [String: any ModelInterface] = [:]
        let ollamaModels = [
            "llama3.3", "llama3.3:latest", "llama3.2", "llama3.2:latest",
            "llava:latest", "llava", "bakllava:latest", "bakllava"
        ]
        
        for modelName in ollamaModels {
            models[modelName] = AIModelFactory.ollama(modelName: modelName, baseURL: configuration.baseURL)
        }
        
        self.modelProvider = self.modelProvider.withModels(models)
    }
    
    /// Configure Grok provider with specific settings
    /// - Parameter configuration: Grok configuration
    public func configureGrok(_ configuration: ProviderConfiguration.Grok) async {
        var models: [String: any ModelInterface] = [:]
        let grokModels = [
            "grok-4", "grok-4-0709", "grok-4-latest",
            "grok-3", "grok-3-mini", "grok-2-1212", "grok-2-vision-1212"
        ]
        
        for modelName in grokModels {
            models[modelName] = AIModelFactory.grok(
                apiKey: configuration.apiKey,
                modelName: modelName,
                baseURL: configuration.baseURL
            )
        }
        
        self.modelProvider = self.modelProvider.withModels(models)
    }
    
    /// Set up all providers from environment variables
    /// - Throws: TachikomaError if setup fails
    public func setupFromEnvironment() async throws {
        self.modelProvider = try AIConfiguration.fromEnvironment()
    }
    
    /// List all available models from configured providers
    /// - Returns: Array of available model identifiers
    public func availableModels() async -> [String] {
        return modelProvider.availableModels()
    }
    
    /// Clear all cached model instances
    public func clearModelCache() async {
        // Not needed in the new architecture since models are immutable
    }
    
    /// Register a custom model factory
    /// - Parameters:
    ///   - modelName: The model name to register
    ///   - factory: Factory closure that creates the model instance
    public func registerModel(
        name modelName: String,
        factory: @escaping @Sendable () throws -> any ModelInterface
    ) async {
        do {
            let model = try factory()
            self.modelProvider = self.modelProvider.withModel(modelName, model: model)
        } catch {
            logger.error("Failed to register model \(modelName): \(error)")
        }
    }
}

// MARK: - Provider Configuration (Kept for compatibility)

/// Configuration for model providers
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ProviderConfiguration {
    /// OpenAI configuration
    public struct OpenAI: Sendable {
        public let apiKey: String
        public let organizationId: String?
        public let baseURL: URL?

        public init(
            apiKey: String,
            organizationId: String? = nil,
            baseURL: URL? = nil)
        {
            self.apiKey = apiKey
            self.organizationId = organizationId
            self.baseURL = baseURL
        }
    }

    /// Anthropic configuration
    public struct Anthropic: Sendable {
        public let apiKey: String
        public let baseURL: URL?

        public init(
            apiKey: String,
            baseURL: URL? = nil)
        {
            self.apiKey = apiKey
            self.baseURL = baseURL
        }
    }

    /// Ollama configuration
    public struct Ollama: Sendable {
        public let baseURL: URL

        public init(baseURL: URL = URL(string: "http://localhost:11434")!) {
            self.baseURL = baseURL
        }
    }

    /// Grok/xAI configuration
    public struct Grok: Sendable {
        public let apiKey: String
        public let baseURL: URL?

        public init(
            apiKey: String,
            baseURL: URL? = nil)
        {
            self.apiKey = apiKey
            self.baseURL = baseURL
        }
    }
}