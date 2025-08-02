import Foundation

// MARK: - Model Provider

/// Singleton provider for managing model instances in Tachikoma
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public actor ModelProvider {
    /// Shared instance
    public static let shared = ModelProvider()

    /// Registered model factories
    private var modelFactories: [String: @Sendable () throws -> any ModelInterface] = [:]

    /// Model instance cache
    private var modelCache: [String: any ModelInterface] = [:]

    private init() {
        // Register default models when initialized
        Task {
            await self.registerDefaultModels()
        }
    }

    // MARK: - Public Methods

    /// Register a model factory
    /// - Parameters:
    ///   - name: The model name
    ///   - factory: Factory closure that creates the model
    public func register(
        modelName: String,
        factory: @escaping @Sendable () throws -> any ModelInterface)
    {
        self.modelFactories[modelName] = factory
        // Clear cache for this model
        self.modelCache.removeValue(forKey: modelName)
    }

    /// Get a model by name
    /// - Parameter modelName: The name of the model
    /// - Returns: A model instance
    /// - Throws: TachikomaError if model not found
    public func getModel(modelName: String) throws -> any ModelInterface {
        // Check cache first
        if let cached = modelCache[modelName] {
            return cached
        }

        // Check for custom provider first (format: provider-id/model-path)
        if let slashIndex = modelName.firstIndex(of: "/") {
            let providerId = String(modelName[..<slashIndex])
            let modelPath = String(modelName[modelName.index(after: slashIndex)...])
            
            if let model = try? createCustomProviderModel(providerId: providerId, modelPath: modelPath) {
                self.modelCache[modelName] = model
                return model
            }
        }

        // Try exact match for built-in models
        if let factory = modelFactories[modelName] {
            let model = try factory()
            self.modelCache[modelName] = model
            return model
        }

        // Try lenient matching for shortened names
        if let resolvedName = resolveLenientModelName(modelName),
           let factory = modelFactories[resolvedName]
        {
            let model = try factory()
            // Cache with both original and resolved names
            self.modelCache[modelName] = model
            self.modelCache[resolvedName] = model
            return model
        }

        // Model not found in registry
        throw TachikomaError.modelNotFound(modelName)
    }

    /// List all registered models
    public func listModels() -> [String] {
        Array(self.modelFactories.keys).sorted()
    }

    /// Clear model cache
    public func clearCache() {
        self.modelCache.removeAll()
    }

    /// Clear all model registrations and cache (useful for testing)
    public func clearAll() async {
        self.modelCache.removeAll()
        self.modelFactories.removeAll()
        // Re-register default models
        await self.registerDefaultModels()
    }

    /// Unregister a model
    public func unregister(modelName: String) {
        self.modelFactories.removeValue(forKey: modelName)
        self.modelCache.removeValue(forKey: modelName)
    }

    // MARK: - Private Methods

    private func registerDefaultModels() async {
        // Register OpenAI models
        self.registerOpenAIModels()

        // Register Anthropic models
        self.registerAnthropicModels()

        // Register Grok models
        self.registerGrokModels()

        // Register Ollama models
        self.registerOllamaModels()
    }

    /// Resolve lenient model names to their full versions
    private func resolveLenientModelName(_ modelName: String) -> String? {
        let lowercased = modelName.lowercased()

        // Claude model shortcuts
        if lowercased == "claude-4-opus" || lowercased == "claude-opus-4" || lowercased == "claude-opus" {
            return "claude-opus-4-20250514"
        }
        if lowercased == "claude-4-sonnet" || lowercased == "claude-sonnet-4" || lowercased == "claude-sonnet" {
            return "claude-sonnet-4-20250514"
        }
        if lowercased == "claude-3.7-sonnet" || lowercased == "claude-3-7-sonnet" || lowercased == "claude-sonnet-3.7" {
            return "claude-3-7-sonnet"
        }
        if lowercased == "claude-3.5-sonnet" || lowercased == "claude-3-5-sonnet" || lowercased == "claude-sonnet-3.5" {
            return "claude-3-5-sonnet"
        }
        if lowercased == "claude-3.5-haiku" || lowercased == "claude-3-5-haiku" || lowercased == "claude-haiku-3.5" {
            return "claude-3-5-haiku"
        }
        if lowercased == "claude-3.5-opus" || lowercased == "claude-3-5-opus" || lowercased == "claude-opus-3.5" {
            return "claude-3-5-opus"
        }
        if lowercased == "claude" {
            return "claude-opus-4-20250514" // Default to Claude Opus 4
        }

        // OpenAI model shortcuts
        if lowercased == "gpt4" || lowercased == "gpt-4" {
            return "gpt-4.1"
        }
        if lowercased == "gpt4-mini" || lowercased == "gpt-4-mini" {
            return "gpt-4.1-mini"
        }
        if lowercased == "gpt" {
            return "gpt-4.1" // Default to latest GPT
        }

        // Grok model shortcuts
        if lowercased == "grok" || lowercased == "grok4" || lowercased == "grok-4" {
            return "grok-4-0709"
        }
        if lowercased == "grok3" || lowercased == "grok-3" {
            return "grok-3"
        }
        if lowercased == "grok2" || lowercased == "grok-2" {
            return "grok-2-vision-1212"
        }

        // Ollama model shortcuts
        if lowercased == "ollama" || lowercased == "llama" {
            return "llama3.3" // Default to llama3.3 - best for agent tasks with tool support
        }
        if lowercased == "llama3" || lowercased == "llama-3" {
            return "llama3.3" // Default to latest llama 3.x
        }

        // Check if it's a partial match for any registered model
        let registeredModels = Array(modelFactories.keys)
        for model in registeredModels {
            if model.lowercased().contains(lowercased) || lowercased.contains(model.lowercased()) {
                return model
            }
        }

        return nil
    }

    private func registerOpenAIModels() {
        let models = [
            // GPT-4o series
            "gpt-4o",
            "gpt-4o-mini",

            // GPT-4.1 series
            "gpt-4.1",
            "gpt-4.1-mini",

            // o3 series (Responses API only)
            "o3",
            "o3-mini",
            "o3-pro",

            // o4 series (Responses API only)
            "o4-mini",
        ]

        for modelName in models {
            self.register(modelName: modelName) {
                guard let apiKey = self.getOpenAIAPIKey() else {
                    throw TachikomaError.authenticationFailed
                }

                return OpenAIModel(apiKey: apiKey, modelName: modelName)
            }
        }
    }

    nonisolated private func getOpenAIAPIKey() -> String? {
        // Check environment variable
        if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            return apiKey
        }

        // Check standard configuration directory
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".tachikoma")
            .appendingPathComponent("credentials")

        if let credentials = try? String(contentsOf: configPath) {
            for line in credentials.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("OPENAI_API_KEY=") {
                    return String(trimmed.dropFirst("OPENAI_API_KEY=".count))
                }
            }
        }

        return nil
    }

    private func registerAnthropicModels() {
        // Map of model names to their actual IDs
        let modelMappings: [String: String] = [
            // Claude 4 series (Latest - May 2025)
            "claude-opus-4-20250514": "claude-opus-4-20250514",
            "claude-opus-4-20250514-thinking": "claude-opus-4-20250514-thinking",
            "claude-sonnet-4-20250514": "claude-sonnet-4-20250514",
            "claude-sonnet-4-20250514-thinking": "claude-sonnet-4-20250514-thinking",

            // Claude 3.7 series (February 2025)
            "claude-3-7-sonnet": "claude-3-7-sonnet",

            // Claude 3.5 series (Still available)
            "claude-3-5-haiku": "claude-3-5-haiku",
            "claude-3-5-sonnet": "claude-3-5-sonnet",
            "claude-3-5-opus": "claude-3-5-opus",
        ]

        for (alias, actualModelId) in modelMappings {
            self.register(modelName: alias) {
                guard let apiKey = self.getAnthropicAPIKey() else {
                    throw TachikomaError.authenticationFailed
                }

                return AnthropicModel(apiKey: apiKey, modelName: actualModelId)
            }
        }
    }

    nonisolated private func getAnthropicAPIKey() -> String? {
        // Check environment variable
        if let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            return apiKey
        }

        // Check standard configuration directory
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".tachikoma")
            .appendingPathComponent("credentials")

        if let credentials = try? String(contentsOf: configPath) {
            for line in credentials.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("ANTHROPIC_API_KEY=") {
                    return String(trimmed.dropFirst("ANTHROPIC_API_KEY=".count))
                }
            }
        }

        return nil
    }

    private func registerGrokModels() {
        let models = [
            // Grok 4 series
            "grok-4",
            "grok-4-0709",
            "grok-4-latest",

            // Grok 3 series
            "grok-3",
            "grok-3-mini",
            "grok-3-fast",
            "grok-3-mini-fast",

            // Grok 2 series
            "grok-2-1212",
            "grok-2-vision-1212",
            "grok-2-image-1212",

            // Beta models
            "grok-beta",
            "grok-vision-beta",
        ]

        for modelName in models {
            self.register(modelName: modelName) {
                guard let apiKey = self.getGrokAPIKey() else {
                    throw TachikomaError.authenticationFailed
                }

                return GrokModel(apiKey: apiKey, modelName: modelName)
            }
        }
    }

    nonisolated private func getGrokAPIKey() -> String? {
        // Check environment variables (both variants)
        if let apiKey = ProcessInfo.processInfo.environment["X_AI_API_KEY"] {
            return apiKey
        }
        if let apiKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] {
            return apiKey
        }

        // Check standard configuration directory
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".tachikoma")
            .appendingPathComponent("credentials")

        if let credentials = try? String(contentsOf: configPath) {
            for line in credentials.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("X_AI_API_KEY=") {
                    return String(trimmed.dropFirst("X_AI_API_KEY=".count))
                }
                if trimmed.hasPrefix("XAI_API_KEY=") {
                    return String(trimmed.dropFirst("XAI_API_KEY=".count))
                }
            }
        }

        return nil
    }

    private func registerOllamaModels() {
        // Common Ollama models
        let models = [
            // Language models with tool support (recommended for agent tasks)
            "llama3.3",
            "llama3.3:latest",
            "llama3.2",
            "llama3.2:latest",

            // Vision models (NOTE: These do NOT support tool calling)
            "llava:latest",
            "llava",
            "bakllava:latest",
            "bakllava",
            "llama3.2-vision:11b",
            "llama3.2-vision:90b",
            "qwen2.5vl:7b",
            "qwen2.5vl:32b",

            // Other language models (tool support varies)
            "llama2",
            "llama2:latest",
            "llama4",
            "llama4:latest",
            "codellama",
            "codellama:latest",
            "mistral",
            "mistral:latest",
            "mixtral",
            "mixtral:latest",
            "neural-chat",
            "neural-chat:latest",
            "gemma",
            "gemma:latest",
            "devstral",
            "devstral:latest",
            "deepseek-r1:8b",
            "deepseek-r1:671b",
        ]

        // Get base URL from environment or default
        let baseURLString = ProcessInfo.processInfo.environment["TACHIKOMA_OLLAMA_BASE_URL"] ?? "http://localhost:11434"
        guard let baseURL = URL(string: baseURLString) else { return }

        for modelName in models {
            self.register(modelName: modelName) {
                OllamaModel(modelName: modelName, baseURL: baseURL)
            }
        }
    }

    // MARK: - Custom Provider Support

    /// Create a model instance for a custom provider
    /// - Parameters:
    ///   - providerId: The custom provider ID
    ///   - modelPath: The model path within the provider
    /// - Returns: A model instance
    /// - Throws: TachikomaError if provider not found or configuration invalid
    private func createCustomProviderModel(providerId: String, modelPath: String) throws -> any ModelInterface {
        // For now, return a basic implementation
        // This can be extended with a configuration system later
        throw TachikomaError.modelNotFound("Custom providers not yet implemented")
    }
}

// MARK: - Model Provider Configuration

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

// MARK: - Model Provider Extensions

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension ModelProvider {
    /// Configure OpenAI models with specific settings
    public func configureOpenAI(_ config: ProviderConfiguration.OpenAI) {
        let models = [
            // GPT-4o series
            "gpt-4o",
            "gpt-4o-mini",

            // GPT-4.1 series
            "gpt-4.1",
            "gpt-4.1-mini",

            // o3 series (Responses API only)
            "o3",
            "o3-mini",
            "o3-pro",

            // o4 series (Responses API only)
            "o4-mini",
        ]

        for modelName in models {
            self.register(modelName: modelName) {
                OpenAIModel(
                    apiKey: config.apiKey,
                    baseURL: config.baseURL ?? URL(string: "https://api.openai.com/v1")!,
                    organizationId: config.organizationId,
                    modelName: modelName)
            }
        }
    }

    /// Configure Anthropic models with specific settings
    public func configureAnthropic(_ config: ProviderConfiguration.Anthropic) {
        // Map of model names to their actual IDs
        let modelMappings: [String: String] = [
            // Claude 4 series (Latest - May 2025)
            "claude-opus-4-20250514": "claude-opus-4-20250514",
            "claude-opus-4-20250514-thinking": "claude-opus-4-20250514-thinking",
            "claude-sonnet-4-20250514": "claude-sonnet-4-20250514",
            "claude-sonnet-4-20250514-thinking": "claude-sonnet-4-20250514-thinking",

            // Claude 3.7 series (February 2025)
            "claude-3-7-sonnet": "claude-3-7-sonnet",

            // Claude 3.5 series (Still available)
            "claude-3-5-haiku": "claude-3-5-haiku",
            "claude-3-5-sonnet": "claude-3-5-sonnet",
            "claude-3-5-opus": "claude-3-5-opus",
        ]

        for (alias, actualModelId) in modelMappings {
            self.register(modelName: alias) {
                AnthropicModel(
                    apiKey: config.apiKey,
                    baseURL: config.baseURL ?? URL(string: "https://api.anthropic.com/v1")!,
                    modelName: actualModelId)
            }
        }
    }

    /// Configure Ollama models with specific settings
    public func configureOllama(_ config: ProviderConfiguration.Ollama) {
        let models = [
            // Vision models
            "llava:latest",
            "llava",
            "bakllava:latest",
            "bakllava",
            "llama3.2-vision:11b",
            "llama3.2-vision:90b",
            "qwen2.5vl:7b",
            "qwen2.5vl:32b",

            // Language models
            "llama2",
            "llama2:latest",
            "llama3.2",
            "llama3.2:latest",
            "llama3.3",
            "llama3.3:latest",
            "llama4",
            "llama4:latest",
            "codellama",
            "codellama:latest",
            "mistral",
            "mistral:latest",
            "mixtral",
            "mixtral:latest",
            "neural-chat",
            "neural-chat:latest",
            "gemma",
            "gemma:latest",
            "devstral",
            "devstral:latest",
            "deepseek-r1:8b",
            "deepseek-r1:671b",
        ]

        for modelName in models {
            self.register(modelName: modelName) {
                OllamaModel(modelName: modelName, baseURL: config.baseURL)
            }
        }
    }

    /// Configure Grok models with specific settings
    public func configureGrok(_ config: ProviderConfiguration.Grok) {
        let models = [
            // Grok 4 series
            "grok-4",
            "grok-4-0709",
            "grok-4-latest",

            // Grok 3 series
            "grok-3",
            "grok-3-mini",
            "grok-3-fast",
            "grok-3-mini-fast",

            // Grok 2 series
            "grok-2-1212",
            "grok-2-vision-1212",
            "grok-2-image-1212",

            // Beta models
            "grok-beta",
            "grok-vision-beta",
        ]

        for modelName in models {
            self.register(modelName: modelName) {
                GrokModel(
                    apiKey: config.apiKey,
                    modelName: modelName,
                    baseURL: config.baseURL ?? URL(string: "https://api.x.ai/v1")!)
            }
        }
    }

    /// Quick setup with API key from environment
    public func setupFromEnvironment() async throws {
        if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            self.configureOpenAI(ProviderConfiguration.OpenAI(apiKey: apiKey))
        }

        if let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            self.configureAnthropic(ProviderConfiguration.Anthropic(apiKey: apiKey))
        }

        // Configure Ollama (no API key needed)
        let ollamaBaseURL = ProcessInfo.processInfo.environment["TACHIKOMA_OLLAMA_BASE_URL"] ?? "http://localhost:11434"
        if let baseURL = URL(string: ollamaBaseURL) {
            self.configureOllama(ProviderConfiguration.Ollama(baseURL: baseURL))
        }

        // Configure Grok with various API key options
        if let apiKey = ProcessInfo.processInfo.environment["X_AI_API_KEY"] ??
            ProcessInfo.processInfo.environment["XAI_API_KEY"]
        {
            self.configureGrok(ProviderConfiguration.Grok(apiKey: apiKey))
        }
    }
}