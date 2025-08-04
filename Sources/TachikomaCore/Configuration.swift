import Foundation

// MARK: - Configuration Management

/// Global configuration manager for Tachikoma AI SDK
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class TachikomaConfiguration: @unchecked Sendable {
    /// Shared configuration instance
    public static let shared = TachikomaConfiguration()

    private let lock = NSLock()
    private var _apiKeys: [String: String] = [:]
    private var _baseURLs: [String: String] = [:]
    private var _defaultSettings: GenerationSettings = .default

    // Test-specific overrides
    private var _testOverrides: [String: String] = [:]
    private var _isTestMode: Bool = false

    private init() {
        self.loadConfiguration()
    }

    // MARK: - API Key Management

    /// Set an API key for a specific provider
    public func setAPIKey(_ key: String, for provider: String) {
        self.lock.withLock {
            self._apiKeys[provider.lowercased()] = key
        }
    }

    /// Get an API key for a specific provider
    /// - Parameter provider: The provider name (e.g., "openai", "anthropic")
    /// - Returns: The API key if available
    public func getAPIKey(for provider: String) -> String? {
        self.lock.withLock {
            let lowercaseProvider = provider.lowercased()

            // In test mode, check test overrides first
            if self._isTestMode, let testKey = _testOverrides[lowercaseProvider] {
                return testKey
            }

            return self._apiKeys[lowercaseProvider]
        }
    }

    /// Remove an API key for a specific provider
    public func removeAPIKey(for provider: String) {
        self.lock.withLock {
            _ = self._apiKeys.removeValue(forKey: provider.lowercased())
        }
    }

    /// Check if an API key is available for a provider
    public func hasAPIKey(for provider: String) -> Bool {
        self.getAPIKey(for: provider) != nil
    }

    // MARK: - Base URL Configuration

    /// Set a custom base URL for a provider
    public func setBaseURL(_ url: String, for provider: String) {
        self.lock.withLock {
            self._baseURLs[provider.lowercased()] = url
        }
    }

    /// Get the base URL for a provider
    public func getBaseURL(for provider: String) -> String? {
        self.lock.withLock {
            self._baseURLs[provider.lowercased()]
        }
    }

    /// Remove a custom base URL for a provider
    public func removeBaseURL(for provider: String) {
        self.lock.withLock {
            _ = self._baseURLs.removeValue(forKey: provider.lowercased())
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

        // Load API keys from environment
        let keyMappings: [String: String] = [
            "openai": "OPENAI_API_KEY",
            "anthropic": "ANTHROPIC_API_KEY",
            "grok": "X_AI_API_KEY", // Grok uses X_AI_API_KEY
            "groq": "GROQ_API_KEY",
            "mistral": "MISTRAL_API_KEY",
            "google": "GOOGLE_API_KEY",
            "ollama": "OLLAMA_API_KEY",
        ]

        for (provider, envVar) in keyMappings {
            if let key = environment[envVar] {
                self.setAPIKey(key, for: provider)
            }
        }

        // Also check for alternative Grok API key name
        if !self.hasAPIKey(for: "grok"), let xaiKey = environment["XAI_API_KEY"] {
            self.setAPIKey(xaiKey, for: "grok")
        }

        // Load base URLs from environment
        let urlMappings: [String: String] = [
            "openai": "OPENAI_BASE_URL",
            "anthropic": "ANTHROPIC_BASE_URL",
            "ollama": "OLLAMA_BASE_URL",
        ]

        for (provider, envVar) in urlMappings {
            if let url = environment[envVar] {
                self.setBaseURL(url, for: provider)
            }
        }
    }

    /// Load configuration from credentials file
    private func loadFromCredentials() {
        guard let homeDirectory = ProcessInfo.processInfo.environment["HOME"] else {
            return
        }

        let credentialsPath = "\(homeDirectory)/.tachikoma/credentials"
        let credentialsURL = URL(fileURLWithPath: credentialsPath)

        guard
            let credentialsData = try? Data(contentsOf: credentialsURL),
            let credentialsString = String(data: credentialsData, encoding: .utf8) else {
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
                    self.setAPIKey(value, for: "openai")
                } else if lowercaseKey.contains("anthropic") || lowercaseKey.contains("claude") {
                    self.setAPIKey(value, for: "anthropic")
                } else if lowercaseKey.contains("grok") {
                    self.setAPIKey(value, for: "grok")
                } else if lowercaseKey.contains("groq") {
                    self.setAPIKey(value, for: "groq")
                } else if lowercaseKey.contains("mistral") {
                    self.setAPIKey(value, for: "mistral")
                } else if lowercaseKey.contains("google") || lowercaseKey.contains("gemini") {
                    self.setAPIKey(value, for: "google")
                }
            }
        }
    }

    // MARK: - Persistence

    /// Save current configuration to credentials file
    public func saveCredentials() throws {
        guard let homeDirectory = ProcessInfo.processInfo.environment["HOME"] else {
            throw TachikomaError.invalidConfiguration("HOME directory not found")
        }

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

        // Set restrictive permissions (owner read/write only)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: credentialsPath)
    }

    // MARK: - Test Support

    /// Set test mode and provide API key overrides for testing
    /// This allows tests to override API keys without affecting the real configuration
    public func setTestMode(_ enabled: Bool, overrides: [String: String] = [:]) {
        self.lock.withLock {
            self._isTestMode = enabled
            if enabled {
                self._testOverrides = overrides.reduce(into: [:]) { result, pair in
                    result[pair.key.lowercased()] = pair.value
                }
            } else {
                self._testOverrides.removeAll()
            }
        }
    }

    /// Set a test API key override for a specific provider
    /// Only works when test mode is enabled
    public func setTestAPIKey(_ key: String?, for provider: String) {
        self.lock.withLock {
            guard self._isTestMode else { return }

            let lowercaseProvider = provider.lowercased()
            if let key {
                self._testOverrides[lowercaseProvider] = key
            } else {
                self._testOverrides.removeValue(forKey: lowercaseProvider)
            }
        }
    }

    /// Check if currently in test mode
    public var isTestMode: Bool {
        self.lock.withLock {
            self._isTestMode
        }
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

    /// Get all configured providers
    public var configuredProviders: [String] {
        self.lock.withLock {
            Array(self._apiKeys.keys).sorted()
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

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension NSLock {
    /// Execute a closure while holding the lock
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

// MARK: - Provider Integration

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension ProviderFactory {
    /// Create a provider with automatic configuration resolution
    public static func createConfiguredProvider(for model: LanguageModel) throws -> any ModelProvider {
        let provider = try createProvider(for: model)

        // Apply configuration overrides if available
        let config = TachikomaConfiguration.shared
        let providerName = model.providerName.lowercased()

        if config.getBaseURL(for: providerName) != nil {
            // Note: This would require providers to support runtime base URL changes
            // For now, this is a placeholder for future enhancement
        }

        return provider
    }
}
