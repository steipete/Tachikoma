import Foundation

// MARK: - Configuration Management

/// Configuration manager for Tachikoma AI SDK
/// Create instances for different contexts rather than using a global singleton
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public typealias ProviderFactoryOverride = (LanguageModel, TachikomaConfiguration) throws -> any ModelProvider

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class TachikomaConfiguration: @unchecked Sendable {
    // MARK: - Profile Directory (for config/credentials)

    /// Name of the profile directory under the user's HOME, or an absolute path,
    /// used to store configuration and credentials (e.g. \.tachikoma, \.peekaboo).
    /// Defaults to ".tachikoma". Host applications (like Peekaboo) should set this
    /// to their own folder/path during startup.
    public nonisolated(unsafe) static var profileDirectoryName: String = ".tachikoma"

    public static var profileDirectoryPath: String {
        let profile = self.profileDirectoryName
        if self.isAbsoluteProfilePath(profile) || profile.hasPrefix("~") {
            return NSString(string: profile).expandingTildeInPath
        }

        guard let homeDirectory = self.homeDirectoryPath else {
            return profile
        }

        return "\(homeDirectory)/\(profile)"
    }

    private static func isAbsoluteProfilePath(_ profile: String) -> Bool {
        if profile.hasPrefix("/") {
            return true
        }

        #if os(Windows)
        if profile.hasPrefix("\\\\") {
            return true
        }

        if profile.count >= 3 {
            let driveIndex = profile.index(after: profile.startIndex)
            let separatorIndex = profile.index(after: driveIndex)
            let drive = profile[profile.startIndex]
            let separator = profile[separatorIndex]
            return drive.isASCII && drive.isLetter && profile[driveIndex] == ":" &&
                (separator == "\\" || separator == "/")
        }
        #endif

        return false
    }

    private static var homeDirectoryPath: String? {
        #if os(Windows)
        let homeDirectory = ProcessInfo.processInfo.environment["USERPROFILE"] ??
            ((ProcessInfo.processInfo.environment["HOMEDRIVE"] ?? "") +
                (ProcessInfo.processInfo.environment["HOMEPATH"] ?? ""))
        return homeDirectory.isEmpty ? nil : homeDirectory
        #else
        return ProcessInfo.processInfo.environment["HOME"]
        #endif
    }

    private let lock = NSLock()
    private var _apiKeys: [String: String] = [:]
    private var _baseURLs: [String: String] = [:]
    private var _defaultSettings: GenerationSettings = .default
    private let _loadFromEnvironment: Bool
    private var _verbose: Bool = false
    private var _providerFactoryOverride: ProviderFactoryOverride?
    private var _azureOpenAIDefaultAPIVersion: String = "2025-04-01-preview"

    /// Thread-safe storage for the default configuration
    private static let defaultLock = NSLock()
    private nonisolated(unsafe) static var _default: TachikomaConfiguration?

    /// Optional default configuration set by the application
    public static var `default`: TachikomaConfiguration? {
        get {
            defaultLock.withLock { _default }
        }
        set {
            defaultLock.withLock { _default = newValue }
        }
    }

    /// Singleton created once when needed (if no default is set)
    private static let autoInstance = TachikomaConfiguration()

    /// The current effective default configuration
    /// Returns user-set default or auto-created singleton
    public static var current: TachikomaConfiguration {
        Self.default ?? autoInstance
    }

    /// Resolves configuration with proper fallback chain
    /// Priority: provided > default > auto singleton
    @inlinable
    public static func resolve(_ provided: TachikomaConfiguration? = nil) -> TachikomaConfiguration {
        provided ?? self.current
    }

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
        // Set an API key for a specific provider (type-safe)
        self.lock.withLock {
            self._apiKeys[provider.identifier] = key
        }
    }

    /// Get an API key for a specific provider (type-safe)
    /// Returns configured key or loads from environment if not set (when loadFromEnvironment is true)
    public func getAPIKey(for provider: Provider) -> String? {
        // Get an API key for a specific provider (type-safe)
        self.lock.withLock {
            // Return configured key if available
            if let configuredKey = self._apiKeys[provider.identifier] {
                return configuredKey
            }

            if provider == .minimaxCN, let sharedMiniMaxKey = self._apiKeys[Provider.minimax.identifier] {
                return sharedMiniMaxKey
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
        // Remove an API key for a specific provider (type-safe)
        self.lock.withLock {
            _ = self._apiKeys.removeValue(forKey: provider.identifier)
        }
    }

    /// Check if an API key is available for a provider (type-safe)
    /// Checks both configured keys and environment variables
    public func hasAPIKey(for provider: Provider) -> Bool {
        // Check if an API key is available for a provider (type-safe)
        self.getAPIKey(for: provider) != nil
    }

    /// Check if provider has a configured API key (not from environment)
    public func hasConfiguredAPIKey(for provider: Provider) -> Bool {
        // Check if provider has a configured API key (not from environment)
        self.lock.withLock {
            self._apiKeys[provider.identifier] != nil
        }
    }

    /// Check if provider has an environment API key available
    public func hasEnvironmentAPIKey(for provider: Provider) -> Bool {
        // Check if provider has an environment API key available
        provider.hasEnvironmentAPIKey
    }

    // MARK: - String-based API (for compatibility with Mac app that doesn't import Provider enum)

    /// Set an API key for a specific provider using string identifier
    public func setAPIKey(_ key: String, for providerString: String) {
        // Set an API key for a specific provider using string identifier
        let provider = Provider.from(identifier: providerString)
        self.setAPIKey(key, for: provider)
    }

    /// Get an API key for a specific provider using string identifier
    public func getAPIKey(for providerString: String) -> String? {
        // Get an API key for a specific provider using string identifier
        let provider = Provider.from(identifier: providerString)
        return self.getAPIKey(for: provider)
    }

    /// Set a custom base URL for a provider using string identifier
    public func setBaseURL(_ url: String, for providerString: String) {
        // Set a custom base URL for a provider using string identifier
        let provider = Provider.from(identifier: providerString)
        self.setBaseURL(url, for: provider)
    }

    /// Get the base URL for a provider using string identifier
    public func getBaseURL(for providerString: String) -> String? {
        // Get the base URL for a provider using string identifier
        let provider = Provider.from(identifier: providerString)
        return self.getBaseURL(for: provider)
    }

    /// Check if an API key is available for a provider using string identifier
    public func hasAPIKey(for providerString: String) -> Bool {
        // Check if an API key is available for a provider using string identifier
        let provider = Provider.from(identifier: providerString)
        return self.hasAPIKey(for: provider)
    }

    // MARK: - Base URL Configuration

    /// Set a custom base URL for a provider (type-safe)
    public func setBaseURL(_ url: String, for provider: Provider) {
        // Set a custom base URL for a provider (type-safe)
        self.lock.withLock {
            self._baseURLs[provider.identifier] = url
        }
    }

    /// Retrieve a credential from the shared Tachikoma auth manager (includes env + credentials file).
    public func credentialValue(for key: String) -> String? {
        TKAuthManager.shared.credentialValue(for: key)
    }

    /// Get the base URL for a provider (type-safe)
    /// Returns configured URL or default URL for standard providers
    public func getBaseURL(for provider: Provider) -> String? {
        // Get the base URL for a provider (type-safe)
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
        // Remove a custom base URL for a provider (type-safe)
        self.lock.withLock {
            _ = self._baseURLs.removeValue(forKey: provider.identifier)
        }
    }

    // MARK: - Provider Factory Overrides

    /// Override the provider factory used when helper APIs create providers
    public func setProviderFactoryOverride(_ override: ProviderFactoryOverride?) {
        self.lock.withLock {
            self._providerFactoryOverride = override
        }
    }

    /// Create a provider for a given model, respecting any override
    public func makeProvider(for model: LanguageModel) throws -> any ModelProvider {
        let override = self.lock.withLock { self._providerFactoryOverride }
        if let override {
            return try override(model, self)
        }
        return try ProviderFactory.createProvider(for: model, configuration: self)
    }

    // MARK: - Default Settings

    /// Set default generation settings
    public func setDefaultSettings(_ settings: GenerationSettings) {
        // Set default generation settings
        self.lock.withLock {
            self._defaultSettings = settings
        }
    }

    /// Set verbose mode for debug logging
    public func setVerbose(_ verbose: Bool) {
        // Set verbose mode for debug logging
        self.lock.withLock {
            self._verbose = verbose
        }
    }

    /// Get/set verbose mode setting
    public var verbose: Bool {
        get {
            self.lock.withLock {
                self._verbose
            }
        }
        set {
            self.lock.withLock {
                self._verbose = newValue
            }
        }
    }

    /// Get default generation settings
    public var defaultSettings: GenerationSettings {
        self.lock.withLock {
            self._defaultSettings
        }
    }

    // MARK: - Azure OpenAI Defaults

    public var azureOpenAIDefaultAPIVersion: String {
        get { self.lock.withLock { self._azureOpenAIDefaultAPIVersion } }
        set { self.lock.withLock { self._azureOpenAIDefaultAPIVersion = newValue } }
    }

    // MARK: - Configuration Loading

    /// Load configuration from environment variables and credentials
    private func loadConfiguration() {
        // Load credentials first (baseline), then let environment override
        self.loadFromCredentials()
        self.loadFromEnvironment()
    }

    /// Load configuration from environment variables.
    ///
    /// Marked `@inline(never)` to work around a Swift release-mode optimizer
    /// issue where inlining this function into the singleton-init path causes
    /// the `_baseURLs[.anthropic]` write to be incorrectly eliminated, leaving
    /// `AnthropicProvider.init` reading a stale (default) value via
    /// `getBaseURL`. OpenAI / Ollama / MiniMax / Azure writes happen to
    /// survive the optimization; only Anthropic is empirically affected.
    /// Removing this annotation reintroduces the bug observed in
    /// openclaw/Peekaboo release builds for `claude-*` models. See #17.
    @inline(never)
    private func loadFromEnvironment() {
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
            .minimax: "MINIMAX_BASE_URL",
            .minimaxCN: "MINIMAX_CN_BASE_URL",
            .kimi: "MOONSHOT_BASE_URL",
            .ollama: "OLLAMA_BASE_URL",
            .azureOpenAI: "AZURE_OPENAI_ENDPOINT",
        ]

        for (provider, envVar) in urlMappings {
            if let url = Provider.environmentValue(for: envVar), !url.isEmpty {
                self.setBaseURL(url, for: provider)
            }
        }

        if let apiVersion = Provider.environmentValue(for: "AZURE_OPENAI_API_VERSION"), !apiVersion.isEmpty {
            self.azureOpenAIDefaultAPIVersion = apiVersion
        }
    }

    /// Load configuration from credentials file
    private func loadFromCredentials() {
        // Load configuration from credentials file
        // Primary: configured profile directory/path (e.g. .peekaboo or PEEKABOO_CONFIG_DIR)
        let primaryCredentialsPath = "\(Self.profileDirectoryPath)/credentials"

        // Fallback: legacy .tachikoma directory for non-Peekaboo users
        let fallbackCredentialsPath = Self.homeDirectoryPath.map { "\($0)/.tachikoma/credentials" }

        let candidates = [primaryCredentialsPath, fallbackCredentialsPath].compactMap(\.self)
        let credentialsPath = candidates.first { FileManager.default.fileExists(atPath: $0) }
        guard let path = credentialsPath else { return }
        let credentialsURL = URL(fileURLWithPath: path)

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

                if let provider = Self.provider(forCredentialKey: key) {
                    self.setAPIKey(value, for: provider)
                }
            }
        }
    }

    private static func provider(forCredentialKey key: String) -> Provider? {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return Provider.standardProviders.first { provider in
            let keys = ([provider.environmentVariable] + provider.alternativeEnvironmentVariables)
                .filter { !$0.isEmpty }
                .map { $0.uppercased() }
            return keys.contains(normalizedKey)
        }
    }

    // MARK: - Persistence

    /// Save current configuration to credentials file
    public func saveCredentials() throws {
        // Save current configuration to credentials file
        let profileDir = Self.profileDirectoryPath
        guard !profileDir.isEmpty else {
            throw TachikomaError.invalidConfiguration("Profile directory not found")
        }
        let credentialsPath = "\(profileDir)/credentials"

        // Create directory if needed
        let profileURL = URL(fileURLWithPath: profileDir)
        try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)

        // Build credentials content
        var lines: [String] = []
        lines.append("# Tachikoma AI SDK Credentials")
        lines.append("# Format: KEY=value")
        lines.append("")

        self.lock.withLock {
            for (provider, key) in self._apiKeys {
                let standardEnvVar = Provider.from(identifier: provider).environmentVariable
                let envVarName = standardEnvVar.isEmpty ? "\(provider.uppercased())_API_KEY" : standardEnvVar
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
        // Clear all stored configuration
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
        // Execute a closure while holding the lock
        lock()
        defer { unlock() }
        return try body()
    }
}

// MARK: - Provider Integration

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension ProviderFactory {
    /// Create a provider with configuration
    public static func createConfiguredProvider(
        for model: LanguageModel,
        configuration: TachikomaConfiguration,
    ) throws
        -> any ModelProvider
    {
        // Create a provider with configuration
        try createProvider(for: model, configuration: configuration)
    }
}
