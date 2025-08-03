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
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - API Key Management
    
    /// Set an API key for a specific provider
    public func setAPIKey(_ key: String, for provider: String) {
        lock.withLock {
            _apiKeys[provider.lowercased()] = key
        }
    }
    
    /// Get an API key for a specific provider
    /// - Parameter provider: The provider name (e.g., "openai", "anthropic")
    /// - Returns: The API key if available
    public func getAPIKey(for provider: String) -> String? {
        lock.withLock {
            return _apiKeys[provider.lowercased()]
        }
    }
    
    /// Remove an API key for a specific provider
    public func removeAPIKey(for provider: String) {
        lock.withLock {
            _apiKeys.removeValue(forKey: provider.lowercased())
        }
    }
    
    /// Check if an API key is available for a provider
    public func hasAPIKey(for provider: String) -> Bool {
        return getAPIKey(for: provider) != nil
    }
    
    // MARK: - Base URL Configuration
    
    /// Set a custom base URL for a provider
    public func setBaseURL(_ url: String, for provider: String) {
        lock.withLock {
            _baseURLs[provider.lowercased()] = url
        }
    }
    
    /// Get the base URL for a provider
    public func getBaseURL(for provider: String) -> String? {
        lock.withLock {
            return _baseURLs[provider.lowercased()]
        }
    }
    
    /// Remove a custom base URL for a provider
    public func removeBaseURL(for provider: String) {
        lock.withLock {
            _baseURLs.removeValue(forKey: provider.lowercased())
        }
    }
    
    // MARK: - Default Settings
    
    /// Set default generation settings
    public func setDefaultSettings(_ settings: GenerationSettings) {
        lock.withLock {
            _defaultSettings = settings
        }
    }
    
    /// Get default generation settings
    public var defaultSettings: GenerationSettings {
        lock.withLock {
            return _defaultSettings
        }
    }
    
    // MARK: - Configuration Loading
    
    /// Load configuration from environment variables and credentials
    private func loadConfiguration() {
        loadFromEnvironment()
        loadFromCredentials()
    }
    
    /// Load configuration from environment variables
    private func loadFromEnvironment() {
        let environment = ProcessInfo.processInfo.environment
        
        // Load API keys from environment
        let keyMappings: [String: String] = [
            "openai": "OPENAI_API_KEY",
            "anthropic": "ANTHROPIC_API_KEY",
            "grok": "GROK_API_KEY",
            "groq": "GROQ_API_KEY",
            "mistral": "MISTRAL_API_KEY",
            "google": "GOOGLE_API_KEY",
            "ollama": "OLLAMA_API_KEY"
        ]
        
        for (provider, envVar) in keyMappings {
            if let key = environment[envVar] {
                setAPIKey(key, for: provider)
            }
        }
        
        // Load base URLs from environment
        let urlMappings: [String: String] = [
            "openai": "OPENAI_BASE_URL",
            "anthropic": "ANTHROPIC_BASE_URL",
            "ollama": "OLLAMA_BASE_URL"
        ]
        
        for (provider, envVar) in urlMappings {
            if let url = environment[envVar] {
                setBaseURL(url, for: provider)
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
        
        guard let credentialsData = try? Data(contentsOf: credentialsURL),
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
                    setAPIKey(value, for: "openai")
                } else if lowercaseKey.contains("anthropic") || lowercaseKey.contains("claude") {
                    setAPIKey(value, for: "anthropic")
                } else if lowercaseKey.contains("grok") {
                    setAPIKey(value, for: "grok")
                } else if lowercaseKey.contains("groq") {
                    setAPIKey(value, for: "groq")
                } else if lowercaseKey.contains("mistral") {
                    setAPIKey(value, for: "mistral")
                } else if lowercaseKey.contains("google") || lowercaseKey.contains("gemini") {
                    setAPIKey(value, for: "google")
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
        
        lock.withLock {
            for (provider, key) in _apiKeys {
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
    
    // MARK: - Utility Methods
    
    /// Clear all stored configuration
    public func clearAll() {
        lock.withLock {
            _apiKeys.removeAll()
            _baseURLs.removeAll()
            _defaultSettings = .default
        }
    }
    
    /// Get all configured providers
    public var configuredProviders: [String] {
        lock.withLock {
            return Array(_apiKeys.keys).sorted()
        }
    }
    
    /// Get configuration summary for debugging
    public var summary: String {
        lock.withLock {
            var lines: [String] = []
            lines.append("Tachikoma Configuration:")
            lines.append("  Configured providers: \(_apiKeys.keys.sorted().joined(separator: ", "))")
            lines.append("  Custom base URLs: \(_baseURLs.keys.sorted().joined(separator: ", "))")
            lines.append("  Default max tokens: \(_defaultSettings.maxTokens?.description ?? "nil")")
            lines.append("  Default temperature: \(_defaultSettings.temperature?.description ?? "nil")")
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