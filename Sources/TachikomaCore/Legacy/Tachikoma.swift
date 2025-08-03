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

/**
 * The core model management class that provides dependency injection for AI models.
 *
 * `AIModelProvider` is the heart of Tachikoma's dependency injection architecture, replacing
 * the previous singleton pattern. It manages a collection of AI model instances and provides
 * type-safe access to them through a simple string-based identifier system.
 *
 * ## Key Features
 * - **Thread-safe**: All operations are safe for concurrent access
 * - **Immutable**: Model collections are immutable, changes return new instances
 * - **Type-safe**: Full compile-time type checking for model interfaces
 * - **Provider-agnostic**: Works with any AI provider (OpenAI, Anthropic, Ollama, etc.)
 *
 * ## Usage Example
 * ```swift
 * // Create models using the factory
 * let openAIModel = AIModelFactory.openAI(apiKey: "sk-...", modelName: "gpt-4.1")
 * let claudeModel = AIModelFactory.anthropic(apiKey: "sk-ant-...", modelName: "claude-opus-4")
 *
 * // Create provider with models
 * let provider = AIModelProvider(models: [
 *     "gpt-4.1": openAIModel,
 *     "claude-opus-4": claudeModel
 * ])
 *
 * // Use the models
 * let model = try provider.getModel("gpt-4.1")
 * let response = try await model.getResponse(request: request)
 * ```
 *
 * ## Architecture Benefits
 * - **Testability**: Easy to inject mock models for testing
 * - **Configuration flexibility**: Multiple providers can coexist
 * - **Explicit dependencies**: No hidden global state
 * - **Memory efficiency**: Models are shared across usage contexts
 *
 * - Note: This class is thread-safe and all methods are synchronous for performance
 * - Important: Always use `AIModelFactory` or `AIConfiguration.fromEnvironment()` to create model instances
 * - Since: Tachikoma 3.0.0 (replaced singleton architecture)
 */
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class AIModelProvider: Sendable {
    /// Internal storage of model instances, keyed by model identifier
    private let models: [String: any LegacyModelInterface]
    
    /**
     * Initialize a new model provider with the specified models.
     *
     * - Parameter models: Dictionary mapping model identifiers to model instances.
     *                    Use `AIModelFactory` methods to create the model instances.
     *
     * ## Example
     * ```swift
     * let provider = AIModelProvider(models: [
     *     "gpt-4.1": AIModelFactory.openAI(apiKey: "sk-...", modelName: "gpt-4.1"),
     *     "claude-opus-4": AIModelFactory.anthropic(apiKey: "sk-ant-...", modelName: "claude-opus-4")
     * ])
     * ```
     */
    public init(models: [String: any LegacyModelInterface] = [:]) {
        self.models = models
    }
    
    /**
     * Retrieves a model instance by its identifier.
     *
     * This is the primary method for accessing configured AI models. The model identifier
     * should match one that was provided during initialization or added via `withModel()`.
     *
     * - Parameter modelName: The model identifier (e.g., "gpt-4.1", "claude-opus-4", "llama3.3")
     * - Returns: A model instance conforming to `ModelInterface`
     * - Throws: `TachikomaError.modelNotFound` if the model identifier is not registered
     *
     * ## Example
     * ```swift
     * let provider = AIModelProvider(models: ["gpt-4.1": openAIModel])
     * let model = try provider.getModel("gpt-4.1")
     * let response = try await model.getResponse(request: request)
     * ```
     *
     * - Important: This method is synchronous and thread-safe
     */
    public func getModel(_ modelName: String) throws -> any LegacyModelInterface {
        guard let model = models[modelName] else {
            throw TachikomaError.modelNotFound(modelName)
        }
        return model
    }
    
    /**
     * Returns a sorted list of all available model identifiers.
     *
     * Use this method to discover which models are available in the current provider
     * instance. Useful for debugging, UI generation, or dynamic model selection.
     *
     * - Returns: Array of model identifiers sorted alphabetically
     *
     * ## Example
     * ```swift
     * let availableModels = provider.availableModels()
     * print("Available models: \(availableModels.joined(separator: ", "))")
     * // Output: "Available models: claude-opus-4, gpt-4.1, llama3.3"
     * ```
     */
    public func availableModels() -> [String] {
        return Array(models.keys).sorted()
    }
    
    /**
     * Creates a new provider instance with an additional or updated model.
     *
     * Since `AIModelProvider` is immutable, this method returns a new instance with
     * the specified model added or updated. The original provider is unchanged.
     *
     * - Parameters:
     *   - modelName: The model identifier to add or update
     *   - model: The model instance to associate with the identifier
     * - Returns: A new `AIModelProvider` instance containing the additional model
     *
     * ## Example
     * ```swift
     * let baseProvider = AIModelProvider()
     * let provider = baseProvider
     *     .withModel("gpt-4.1", model: AIModelFactory.openAI(apiKey: "sk-...", modelName: "gpt-4.1"))
     *     .withModel("claude-opus-4", model: AIModelFactory.anthropic(apiKey: "sk-ant-...", modelName: "claude-opus-4"))
     * ```
     *
     * - Note: Returns a new instance, original provider is unchanged (immutable design)
     */
    public func withModel(_ modelName: String, model: any LegacyModelInterface) -> AIModelProvider {
        var newModels = self.models
        newModels[modelName] = model
        return AIModelProvider(models: newModels)
    }
    
    /**
     * Creates a new provider instance with multiple additional or updated models.
     *
     * This is a convenience method for adding multiple models at once, equivalent to
     * calling `withModel()` for each model individually but more efficient.
     *
     * - Parameter models: Dictionary mapping model identifiers to model instances
     * - Returns: A new `AIModelProvider` instance containing all the additional models
     *
     * ## Example
     * ```swift
     * let newModels: [String: any ModelInterface] = [
     *     "gpt-4.1": AIModelFactory.openAI(apiKey: "sk-...", modelName: "gpt-4.1"),
     *     "claude-opus-4": AIModelFactory.anthropic(apiKey: "sk-ant-...", modelName: "claude-opus-4"),
     *     "llama3.3": AIModelFactory.ollama(modelName: "llama3.3")
     * ]
     * let provider = baseProvider.withModels(newModels)
     * ```
     *
     * - Note: If a model identifier already exists, it will be replaced with the new instance
     */
    public func withModels(_ models: [String: any LegacyModelInterface]) -> AIModelProvider {
        var newModels = self.models
        for (name, model) in models {
            newModels[name] = model
        }
        return AIModelProvider(models: newModels)
    }
}

// MARK: - AIModelFactory

/**
 * Factory for creating AI model instances with sensible defaults.
 *
 * `AIModelFactory` provides convenient static methods for creating model instances from
 * popular AI providers. Each method encapsulates the provider-specific configuration
 * and uses sensible defaults for common use cases.
 *
 * ## Supported Providers
 * - **OpenAI**: GPT-4.1, GPT-4o, o3/o4 reasoning models
 * - **Anthropic**: Claude Opus 4, Claude Sonnet 4, and legacy Claude 3.x models  
 * - **Grok (xAI)**: Grok-4, Grok-3, and Grok-2 models
 * - **Ollama**: Local models including Llama 3.3, LLaVA, and others
 *
 * ## Usage Pattern
 * ```swift
 * // Create individual models
 * let gptModel = AIModelFactory.openAI(apiKey: "sk-...", modelName: "gpt-4.1")
 * let claudeModel = AIModelFactory.anthropic(apiKey: "sk-ant-...", modelName: "claude-opus-4")
 * let ollamaModel = AIModelFactory.ollama(modelName: "llama3.3")
 *
 * // Use with AIModelProvider
 * let provider = AIModelProvider(models: [
 *     "gpt-4.1": gptModel,
 *     "claude-opus-4": claudeModel,
 *     "llama3.3": ollamaModel
 * ])
 * ```
 *
 * - Important: API keys should be stored securely and never hardcoded in production
 * - Note: All methods return instances conforming to `LegacyModelInterface`
 * - Since: Tachikoma 3.0.0
 */
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AIModelFactory {
    
    /**
     * Creates an OpenAI model instance.
     *
     * Supports all modern OpenAI models including GPT-4.1, GPT-4o, and o3/o4 reasoning models.
     * Automatically handles API versioning and authentication.
     *
     * - Parameters:
     *   - apiKey: OpenAI API key (format: "sk-...")
     *   - modelName: Model identifier (e.g., "gpt-4.1", "gpt-4o", "o3", "o4-mini")
     *   - baseURL: Custom API endpoint (defaults to OpenAI's official API)
     *   - organizationId: Optional organization ID for API billing
     * - Returns: Configured OpenAI model instance
     *
     * ## Example
     * ```swift
     * let model = AIModelFactory.openAI(
     *     apiKey: "sk-proj-...",
     *     modelName: "gpt-4.1"
     * )
     * ```
     *
     * - Note: Supports both Chat Completions and Responses APIs automatically
     */
    public static func openAI(apiKey: String, modelName: String, baseURL: URL? = nil, organizationId: String? = nil) -> any LegacyModelInterface {
        return OpenAIModel(
            apiKey: apiKey,
            baseURL: baseURL ?? URL(string: "https://api.openai.com/v1")!,
            organizationId: organizationId,
            modelName: modelName
        )
    }
    
    /**
     * Creates an Anthropic Claude model instance.
     *
     * Supports all Claude models including the latest Claude Opus 4 and Sonnet 4 models,
     * as well as legacy Claude 3.x series for backwards compatibility.
     *
     * - Parameters:
     *   - apiKey: Anthropic API key (format: "sk-ant-...")
     *   - modelName: Model identifier (e.g., "claude-opus-4-20250514", "claude-sonnet-4-20250514")
     *   - baseURL: Custom API endpoint (defaults to Anthropic's official API)
     * - Returns: Configured Anthropic model instance
     *
     * ## Example
     * ```swift
     * let model = AIModelFactory.anthropic(
     *     apiKey: "sk-ant-api03-...",
     *     modelName: "claude-opus-4-20250514"
     * )
     * ```
     *
     * - Note: Supports extended thinking modes (add "-thinking" suffix to model name)
     */
    public static func anthropic(apiKey: String, modelName: String, baseURL: URL? = nil) -> any LegacyModelInterface {
        return AnthropicModel(
            apiKey: apiKey,
            baseURL: baseURL ?? URL(string: "https://api.anthropic.com/v1")!,
            modelName: modelName
        )
    }
    
    /**
     * Creates a Grok (xAI) model instance.
     *
     * Supports all Grok models from xAI including Grok-4, Grok-3, and Grok-2 variants.
     * Uses OpenAI-compatible API format for easy integration.
     *
     * - Parameters:
     *   - apiKey: xAI API key (format: "xai-...")
     *   - modelName: Model identifier (e.g., "grok-4", "grok-3", "grok-2-vision-1212")
     *   - baseURL: Custom API endpoint (defaults to xAI's official API)
     * - Returns: Configured Grok model instance
     *
     * ## Example
     * ```swift
     * let model = AIModelFactory.grok(
     *     apiKey: "xai-...",
     *     modelName: "grok-4"
     * )
     * ```
     *
     * - Note: Grok-4 models have parameter restrictions (no frequency/presence penalty)
     */
    public static func grok(apiKey: String, modelName: String, baseURL: URL? = nil) -> any LegacyModelInterface {
        return GrokModel(
            apiKey: apiKey,
            modelName: modelName,
            baseURL: baseURL ?? URL(string: "https://api.x.ai/v1")!
        )
    }
    
    /**
     * Creates an Ollama model instance for local AI models.
     *
     * Ollama runs AI models locally without requiring API keys. Supports a wide range
     * of open-source models including Llama, LLaVA, Mistral, and custom models.
     *
     * - Parameters:
     *   - modelName: Model identifier (e.g., "llama3.3", "llava:latest", "mistral")
     *   - baseURL: Ollama server endpoint (defaults to localhost:11434)
     * - Returns: Configured Ollama model instance
     *
     * ## Example
     * ```swift
     * // Local Ollama server
     * let model = AIModelFactory.ollama(modelName: "llama3.3")
     *
     * // Remote Ollama server
     * let remoteModel = AIModelFactory.ollama(
     *     modelName: "llama3.3",
     *     baseURL: URL(string: "http://ollama-server:11434")!
     * )
     * ```
     *
     * - Important: Ensure the model is pulled locally before use (`ollama pull llama3.3`)
     * - Note: No API key required, but Ollama daemon must be running
     */
    public static func ollama(modelName: String, baseURL: URL? = nil) -> any LegacyModelInterface {
        return OllamaModel(
            modelName: modelName,
            baseURL: baseURL ?? URL(string: "http://localhost:11434")!
        )
    }
}

// MARK: - AIConfiguration

/**
 * Configuration utility for automatic AI model setup from environment variables.
 *
 * `AIConfiguration` provides a convenient way to automatically configure all available
 * AI models based on environment variables and credential files. This is the easiest
 * way to get started with Tachikoma in most applications.
 *
 * ## Environment Variables
 * The following environment variables are automatically detected:
 * - `OPENAI_API_KEY`: OpenAI API key for GPT models
 * - `ANTHROPIC_API_KEY`: Anthropic API key for Claude models  
 * - `X_AI_API_KEY` or `XAI_API_KEY`: xAI API key for Grok models
 * - `TACHIKOMA_OLLAMA_BASE_URL`: Custom Ollama server URL (optional)
 *
 * ## Credential Files
 * API keys can also be stored in `~/.tachikoma/credentials` file:
 * ```
 * OPENAI_API_KEY=sk-proj-...
 * ANTHROPIC_API_KEY=sk-ant-api03-...
 * X_AI_API_KEY=xai-...
 * ```
 *
 * ## Usage Example
 * ```swift
 * // Automatic configuration from environment
 * let provider = try AIConfiguration.fromEnvironment()
 * let availableModels = provider.availableModels()
 * print("Configured models: \(availableModels)")
 *
 * // Use any available model
 * let model = try provider.getModel("claude-opus-4-20250514")
 * let response = try await model.getResponse(request: request)
 * ```
 *
 * ## Model Auto-Registration
 * When API keys are found, the following models are automatically registered:
 * - **OpenAI**: gpt-4.1, gpt-4o, o3, o4-mini, and variants
 * - **Anthropic**: claude-opus-4, claude-sonnet-4, claude-3.x series
 * - **Grok**: grok-4, grok-3, grok-2 variants
 * - **Ollama**: llama3.3, llava, mistral, and 15+ other models
 *
 * - Important: Only providers with valid API keys will be configured
 * - Note: Ollama models are always included (no API key required)
 * - Since: Tachikoma 3.0.0
 */
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AIConfiguration {
    
    /**
     * Creates an AIModelProvider with all available models from environment configuration.
     *
     * This method scans environment variables and credential files to automatically
     * configure all available AI providers. Only providers with valid API keys will
     * be included in the resulting provider.
     *
     * - Returns: Configured `AIModelProvider` with all available models
     * - Throws: `TachikomaError` if configuration parsing fails (not for missing API keys)
     *
     * ## Example
     * ```swift
     * // Set environment variables
     * setenv("OPENAI_API_KEY", "sk-proj-...", 1)
     * setenv("ANTHROPIC_API_KEY", "sk-ant-api03-...", 1)
     *
     * // Auto-configure all available models
     * let provider = try AIConfiguration.fromEnvironment()
     * print("Available models: \(provider.availableModels())")
     * // Output: ["claude-opus-4-20250514", "gpt-4.1", "llama3.3", ...]
     * ```
     *
     * - Note: Missing API keys are silently ignored, not treated as errors
     * - Important: This method is safe to call even with no credentials configured
     */
    public static func fromEnvironment() throws -> AIModelProvider {
        var models: [String: any LegacyModelInterface] = [:]
        
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

/**
 * Legacy singleton interface for Tachikoma - DEPRECATED.
 *
 * This class provides backward compatibility with the previous singleton-based architecture.
 * It is deprecated and will be removed in a future version. New code should use `AIModelProvider`
 * with dependency injection instead.
 *
 * ## Migration Path
 * Instead of using the singleton:
 * ```swift
 * // OLD (deprecated)
 * let model = try await Tachikoma.shared.getModel("gpt-4.1")
 *
 * // NEW (recommended)
 * let provider = try AIConfiguration.fromEnvironment()
 * let model = try provider.getModel("gpt-4.1")
 * ```
 *
 * ## Why Deprecated?
 * - **Testing**: Singletons make unit testing difficult
 * - **Configuration**: Hard to support multiple configurations
 * - **Dependencies**: Hidden global state makes code harder to understand
 * - **Threading**: Singleton access patterns can cause race conditions
 *
 * - Warning: This class will be removed in Tachikoma 4.0
 * - Important: Use `AIModelProvider` for all new code
 * - Since: Tachikoma 1.0.0 (deprecated in 3.0.0)
 */
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@available(*, deprecated, message: "Use AIModelProvider with dependency injection instead of Tachikoma.shared singleton")
public final class Tachikoma: @unchecked Sendable {
    /// Shared singleton instance (deprecated)
    public static let shared = Tachikoma()
    
    /// Internal logger for debugging and diagnostics
    private let logger: Logger
    
    /// Internal model provider that powers the singleton interface
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
    /// - Returns: A model instance conforming to LegacyModelInterface
    /// - Throws: TachikomaError if the model is not available or configuration is invalid
    public func getModel(_ modelName: String) async throws -> any LegacyModelInterface {
        return try modelProvider.getModel(modelName)
    }
    
    /// Configure OpenAI provider with specific settings
    /// - Parameter configuration: OpenAI configuration
    public func configureOpenAI(_ configuration: ProviderConfiguration.OpenAI) async {
        // Update the model provider with new OpenAI models
        var models: [String: any LegacyModelInterface] = [:]
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
        var models: [String: any LegacyModelInterface] = [:]
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
        var models: [String: any LegacyModelInterface] = [:]
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
        var models: [String: any LegacyModelInterface] = [:]
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
        factory: @escaping @Sendable () throws -> any LegacyModelInterface
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