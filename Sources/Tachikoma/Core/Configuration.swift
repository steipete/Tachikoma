import Foundation

// MARK: - Configuration Management

/// Configuration manager for Tachikoma AI SDK
/// Create instances for different contexts rather than using a global singleton
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class TachikomaConfiguration: @unchecked Sendable {
    private let lock = NSLock()
    private var _apiKeys: [String: String] = [:]
    private var _baseURLs: [String: String] = [:]
    private var _defaultSettings: GenerationSettings = .default
    private let _loadFromEnvironment: Bool

    /// Shared default configuration instance that loads from environment on first access
    /// This provides better performance than creating new instances for each API call
    public static let shared: TachikomaConfiguration = TachikomaConfiguration()

    /// Create a new configuration instance
    public init(loadFromEnvironment: Bool = true) {
        self._loadFromEnvironment = loadFromEnvironment
        if loadFromEnvironment {
            self.loadConfiguration()
        }
    }
    
    /// Create a configuration with specific API keys
    public convenience init(apiKeys: [String: String], baseURLs: [String: String] = [:]) {
        self.init(loadFromEnvironment: false)
        for (provider, key) in apiKeys {
            self.setAPIKey(key, for: provider)
        }
        for (provider, url) in baseURLs {
            self.setBaseURL(url, for: provider)
        }
    }

    // MARK: - API Key Management

    /// Set an API key for a specific provider (type-safe)
    public func setAPIKey(_ key: String, for provider: Provider) {
        self.lock.withLock {
            self._apiKeys[provider.identifier] = key
        }
    }

    /// Get an API key for a specific provider (type-safe)
    /// Returns configured key or loads from environment if not set (when loadFromEnvironment is true)
    public func getAPIKey(for provider: Provider) -> String? {
        self.lock.withLock {
            // Return configured key if available
            if let configuredKey = self._apiKeys[provider.identifier] {
                return configuredKey
            }
            
            // Fall back to environment variable only if loadFromEnvironment is true
            if self._loadFromEnvironment {
                return provider.loadAPIKeyFromEnvironment()
            }
            
            return nil
        }
    }

    /// Remove an API key for a specific provider (type-safe)
    public func removeAPIKey(for provider: Provider) {
        self.lock.withLock {
            _ = self._apiKeys.removeValue(forKey: provider.identifier)
        }
    }

    /// Check if an API key is available for a provider (type-safe)
    /// Checks both configured keys and environment variables
    public func hasAPIKey(for provider: Provider) -> Bool {
        self.getAPIKey(for: provider) != nil
    }
    
    /// Check if provider has a configured API key (not from environment)
    public func hasConfiguredAPIKey(for provider: Provider) -> Bool {
        self.lock.withLock {
            return self._apiKeys[provider.identifier] != nil
        }
    }
    
    /// Check if provider has an environment API key available
    public func hasEnvironmentAPIKey(for provider: Provider) -> Bool {
        provider.hasEnvironmentAPIKey
    }
    
    // MARK: - String-based API (for compatibility with Mac app that doesn't import Provider enum)
    
    /// Set an API key for a specific provider using string identifier
    public func setAPIKey(_ key: String, for providerString: String) {
        let provider = Provider.from(identifier: providerString)
        setAPIKey(key, for: provider)
    }
    
    /// Get an API key for a specific provider using string identifier
    public func getAPIKey(for providerString: String) -> String? {
        let provider = Provider.from(identifier: providerString)
        return getAPIKey(for: provider)
    }
    
    /// Set a custom base URL for a provider using string identifier
    public func setBaseURL(_ url: String, for providerString: String) {
        let provider = Provider.from(identifier: providerString)
        setBaseURL(url, for: provider)
    }
    
    /// Get the base URL for a provider using string identifier
    public func getBaseURL(for providerString: String) -> String? {
        let provider = Provider.from(identifier: providerString)
        return getBaseURL(for: provider)
    }
    
    /// Check if an API key is available for a provider using string identifier
    public func hasAPIKey(for providerString: String) -> Bool {
        let provider = Provider.from(identifier: providerString)
        return hasAPIKey(for: provider)
    }

    // MARK: - Base URL Configuration

    /// Set a custom base URL for a provider (type-safe)
    public func setBaseURL(_ url: String, for provider: Provider) {
        self.lock.withLock {
            self._baseURLs[provider.identifier] = url
        }
    }

    /// Get the base URL for a provider (type-safe)
    /// Returns configured URL or default URL for standard providers
    public func getBaseURL(for provider: Provider) -> String? {
        self.lock.withLock {
            // Return configured URL if available
            if let configuredURL = self._baseURLs[provider.identifier] {
                return configuredURL
            }
            
            // Fall back to default URL for standard providers
            return provider.defaultBaseURL
        }
    }

    /// Remove a custom base URL for a provider (type-safe)
    public func removeBaseURL(for provider: Provider) {
        self.lock.withLock {
            _ = self._baseURLs.removeValue(forKey: provider.identifier)
        }
    }

    // MARK: - Default Settings

    /// Set default generation settings
    public func setDefaultSettings(_ settings: GenerationSettings) {
        self.lock.withLock {
            self._defaultSettings = settings
        }
    }

    /// Get default generation settings
    public var defaultSettings: GenerationSettings {
        self.lock.withLock {
            self._defaultSettings
        }
    }

    // MARK: - Configuration Loading

    /// Load configuration from environment variables and credentials
    private func loadConfiguration() {
        self.loadFromEnvironment()
        self.loadFromCredentials()
    }

    /// Load configuration from environment variables
    private func loadFromEnvironment() {
        let environment = ProcessInfo.processInfo.environment

        // Load API keys for all standard providers from environment
        for provider in Provider.standardProviders {
            if let key = provider.loadAPIKeyFromEnvironment() {
                self.setAPIKey(key, for: provider)
            }
        }

        // Load base URLs from environment
        let urlMappings: [Provider: String] = [
            .openai: "OPENAI_BASE_URL",
            .anthropic: "ANTHROPIC_BASE_URL",
            .ollama: "OLLAMA_BASE_URL",
        ]

        for (provider, envVar) in urlMappings {
            if let url = environment[envVar], !url.isEmpty {
                self.setBaseURL(url, for: provider)
            }
        }
    }

    /// Load configuration from credentials file
    private func loadFromCredentials() {
        #if os(Windows)
        let homeDirectory = ProcessInfo.processInfo.environment["USERPROFILE"] ?? 
                           (ProcessInfo.processInfo.environment["HOMEDRIVE"] ?? "" + 
                            (ProcessInfo.processInfo.environment["HOMEPATH"] ?? ""))
        guard !homeDirectory.isEmpty else { return }
        #else
        guard let homeDirectory = ProcessInfo.processInfo.environment["HOME"] else {
            return
        }
        #endif

        let credentialsPath = "\(homeDirectory)/.tachikoma/credentials"
        let credentialsURL = URL(fileURLWithPath: credentialsPath)

        guard
            let credentialsData = try? Data(contentsOf: credentialsURL),
            let credentialsString = String(data: credentialsData, encoding: .utf8) else
        {
            return
        }

        // Parse key=value format
        let lines = credentialsString.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines and comments
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }

            // Parse key=value
            let components = trimmedLine.components(separatedBy: "=")
            if components.count >= 2 {
                let key = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = components[1...].joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)

                // Map credential keys to providers
                let lowercaseKey = key.lowercased()
                if lowercaseKey.contains("openai") {
                    self.setAPIKey(value, for: .openai)
                } else if lowercaseKey.contains("anthropic") || lowercaseKey.contains("claude") {
                    self.setAPIKey(value, for: .anthropic)
                } else if lowercaseKey.contains("grok") {
                    self.setAPIKey(value, for: .grok)
                } else if lowercaseKey.contains("groq") {
                    self.setAPIKey(value, for: .groq)
                } else if lowercaseKey.contains("mistral") {
                    self.setAPIKey(value, for: .mistral)
                } else if lowercaseKey.contains("google") || lowercaseKey.contains("gemini") {
                    self.setAPIKey(value, for: .google)
                } else if lowercaseKey.contains("ollama") {
                    self.setAPIKey(value, for: .ollama)
                }
            }
        }
    }

    // MARK: - Persistence

    /// Save current configuration to credentials file
    public func saveCredentials() throws {
        #if os(Windows)
        let homeDirectory = ProcessInfo.processInfo.environment["USERPROFILE"] ?? 
                           (ProcessInfo.processInfo.environment["HOMEDRIVE"] ?? "" + 
                            (ProcessInfo.processInfo.environment["HOMEPATH"] ?? ""))
        guard !homeDirectory.isEmpty else {
            throw TachikomaError.invalidConfiguration("USERPROFILE directory not found")
        }
        #else
        guard let homeDirectory = ProcessInfo.processInfo.environment["HOME"] else {
            throw TachikomaError.invalidConfiguration("HOME directory not found")
        }
        #endif

        let tachikomatDir = "\(homeDirectory)/.tachikoma"
        let credentialsPath = "\(tachikomatDir)/credentials"

        // Create directory if needed
        let tachikomaURL = URL(fileURLWithPath: tachikomatDir)
        try FileManager.default.createDirectory(at: tachikomaURL, withIntermediateDirectories: true)

        // Build credentials content
        var lines: [String] = []
        lines.append("# Tachikoma AI SDK Credentials")
        lines.append("# Format: KEY=value")
        lines.append("")

        self.lock.withLock {
            for (provider, key) in self._apiKeys {
                let envVarName = "\(provider.uppercased())_API_KEY"
                lines.append("\(envVarName)=\(key)")
            }
        }

        let content = lines.joined(separator: "\n")
        let credentialsURL = URL(fileURLWithPath: credentialsPath)

        try content.write(to: credentialsURL, atomically: true, encoding: .utf8)

        // Set restrictive permissions (owner read/write only) - not available on Windows
        #if !os(Windows)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: credentialsPath)
        #endif
    }


    // MARK: - Utility Methods

    /// Clear all stored configuration
    public func clearAll() {
        self.lock.withLock {
            self._apiKeys.removeAll()
            self._baseURLs.removeAll()
            self._defaultSettings = .default
        }
    }

    /// Get all configured providers (type-safe)
    public var configuredProviders: [Provider] {
        self.lock.withLock {
            let identifiers = Array(self._apiKeys.keys)
            return identifiers.map { Provider.from(identifier: $0) }.sorted { $0.identifier < $1.identifier }
        }
    }

    /// Get configuration summary for debugging
    public var summary: String {
        self.lock.withLock {
            var lines: [String] = []
            lines.append("Tachikoma Configuration:")
            lines.append("  Configured providers: \(self._apiKeys.keys.sorted().joined(separator: ", "))")
            lines.append("  Custom base URLs: \(self._baseURLs.keys.sorted().joined(separator: ", "))")
            lines.append("  Default max tokens: \(self._defaultSettings.maxTokens?.description ?? "nil")")
            lines.append("  Default temperature: \(self._defaultSettings.temperature?.description ?? "nil")")
            return lines.joined(separator: "\n")
        }
    }
}

// MARK: - Convenience Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension NSLock {
    /// Execute a closure while holding the lock
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

// MARK: - Provider Integration

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension ProviderFactory {
    /// Create a provider with configuration
    public static func createConfiguredProvider(for model: LanguageModel, configuration: TachikomaConfiguration) throws -> any ModelProvider {
        let provider = try createProvider(for: model, configuration: configuration)

        // Apply configuration overrides if available
        let providerEnum = Provider.from(identifier: model.providerName)

        if configuration.getBaseURL(for: providerEnum) != nil {
            // Note: This would require providers to support runtime base URL changes
            // For now, this is a placeholder for future enhancement
        }

        return provider
    }
}
