#if canImport(CryptoKit)
import CryptoKit

private typealias TKHasher = CryptoKit.SHA256
#else
import Crypto

private typealias TKHasher = Crypto.SHA256
#endif
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(AppKit)
import AppKit
#endif

public enum TKProviderId: String, CaseIterable, Sendable {
    case openai
    case anthropic
    case grok
    case gemini

    public static func normalize(_ value: String) -> TKProviderId? {
        let lower = value.lowercased()
        if lower == "xai" { return .grok }
        return TKProviderId(rawValue: lower)
    }

    public var displayName: String {
        switch self {
        case .openai: "OpenAI"
        case .anthropic: "Anthropic"
        case .grok: "Grok (xAI)"
        case .gemini: "Gemini"
        }
    }

    public var credentialKeys: [String] {
        switch self {
        case .openai: ["OPENAI_API_KEY", "OPENAI_ACCESS_TOKEN"]
        // swiftformat:disable indent
        case .anthropic: [
            "ANTHROPIC_API_KEY",
            "ANTHROPIC_ACCESS_TOKEN",
            "ANTHROPIC_BETA_HEADER",
            "ANTHROPIC_REFRESH_TOKEN",
            "ANTHROPIC_ACCESS_EXPIRES",
        ]
        // swiftformat:enable indent
        case .grok: ["X_AI_API_KEY", "XAI_API_KEY", "GROK_API_KEY"]
        case .gemini: ["GEMINI_API_KEY"]
        }
    }

    public var supportsOAuth: Bool {
        self == .openai || self == .anthropic
    }
}

public enum TKAuthValue: Sendable {
    case apiKey(String)
    case bearer(String, betaHeader: String?)
}

public enum TKValidationResult: Sendable {
    case success
    case failure(String)
    case timeout(Double)
}

public struct TKCredentialStore {
    public init() {}

    private var baseDir: String {
        let dir = TachikomaConfiguration.profileDirectoryName
        return NSString(string: "~/" + dir).expandingTildeInPath
    }

    private var credentialsPath: String {
        "\(self.baseDir)/credentials"
    }

    public func load() -> [String: String] {
        guard FileManager.default.fileExists(atPath: self.credentialsPath) else { return [:] }
        do {
            let content = try String(contentsOfFile: self.credentialsPath)
            var result: [String: String] = [:]
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }
                result[String(parts[0])] = String(parts[1])
            }
            return result
        } catch {
            return [:]
        }
    }

    public func save(_ credentials: [String: String]) throws {
        try FileManager.default.createDirectory(
            atPath: self.baseDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700],
        )

        let header = [
            "# Tachikoma credentials file",
            "# Sensitive; keep permissions strict",
            "",
        ]
        let body = credentials.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        let content = (header + body).joined(separator: "\n")
        try content.write(to: URL(fileURLWithPath: self.credentialsPath), atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: self.credentialsPath)
    }
}

public final class TKAuthManager {
    public nonisolated(unsafe) static let shared = TKAuthManager()

    private let store = TKCredentialStore()
    private let lock = NSLock()
    private var ignoreEnv = false

    private init() {}

    @discardableResult
    public func setIgnoreEnvironment(_ value: Bool) -> Bool {
        self.lock.lock()
        let previous = self.ignoreEnv
        self.ignoreEnv = value
        self.lock.unlock()
        return previous
    }

    public func credentialValue(for key: String) -> String? {
        self.lock.lock()
        let creds = self.store.load()
        self.lock.unlock()
        if !self.ignoreEnv, let env = ProcessInfo.processInfo.environment[key], !env.isEmpty { return env }
        return creds[key]
    }

    public func resolveAuth(for provider: TKProviderId) -> TKAuthValue? {
        self.lock.lock()
        let creds = self.store.load()
        self.lock.unlock()
        switch provider {
        case .openai:
            if !self.ignoreEnv, let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !env.isEmpty {
                return .bearer(env, betaHeader: nil)
            }
            if let access = creds["OPENAI_ACCESS_TOKEN"], !access.isEmpty {
                return .bearer(access, betaHeader: nil)
            }
            if let key = creds["OPENAI_API_KEY"], !key.isEmpty {
                return .apiKey(key)
            }
        case .anthropic:
            if !self.ignoreEnv, let env = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !env.isEmpty {
                return .apiKey(env)
            }
            if let access = creds["ANTHROPIC_ACCESS_TOKEN"], !access.isEmpty {
                let beta = creds["ANTHROPIC_BETA_HEADER"]
                return .bearer(access, betaHeader: beta)
            }
            if let key = creds["ANTHROPIC_API_KEY"], !key.isEmpty {
                return .apiKey(key)
            }
        case .grok:
            let envOrder = ["X_AI_API_KEY", "XAI_API_KEY", "GROK_API_KEY"]
            for k in envOrder {
                if !self.ignoreEnv, let env = ProcessInfo.processInfo.environment[k], !env.isEmpty { return .bearer(
                    env,
                    betaHeader: nil,
                ) }
            }
            for k in envOrder {
                if let val = creds[k], !val.isEmpty { return .bearer(val, betaHeader: nil) }
            }
        case .gemini:
            if !self.ignoreEnv, let env = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !env.isEmpty {
                return .apiKey(env)
            }
            if let val = creds["GEMINI_API_KEY"], !val.isEmpty { return .apiKey(val) }
        }
        return nil
    }

    public func setCredential(key: String, value: String) throws {
        self.lock.lock()
        var creds = self.store.load()
        creds[key] = value
        try self.store.save(creds)
        self.lock.unlock()
    }

    // MARK: Validation

    public func validate(provider: TKProviderId, secret: String, timeout: Double = 30) async -> TKValidationResult {
        let v = TKProviderValidator(timeoutSeconds: timeout)
        return await v.validate(provider: provider, secret: secret)
    }

    // MARK: OAuth

    public func oauthLogin(
        provider: TKProviderId,
        timeout: Double = 30,
        noBrowser: Bool = false,
    ) async
        -> Result<Void, TKAuthError>
    {
        guard provider.supportsOAuth else { return .failure(.unsupported) }
        let pkce = PKCE()
        let config = self.oauthConfig(for: provider, pkce: pkce)
        guard let authorizeURL = config.authorizeURL else { return .failure(.general("Bad authorize URL")) }

        #if canImport(AppKit)
        if !noBrowser { NSWorkspace.shared.open(authorizeURL) }
        #endif

        print("Open this URL in a browser if it did not open automatically:\n  \(authorizeURL.absoluteString)\n")
        print("After authorizing, paste the resulting code (full callback URL or code parameter) here:")
        guard let input = readLine(), !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.general("No code entered"))
        }
        let code = Self.parseCode(from: input)
        guard !code.isEmpty else { return .failure(.general("Could not extract code")) }

        let tokenResult = await OAuthTokenExchanger.exchange(
            config: config,
            code: code,
            pkce: pkce,
            timeout: timeout,
        )
        return self.persistOAuthResult(tokenResult, config: config)
    }

    private func oauthConfig(for provider: TKProviderId, pkce: PKCE) -> OAuthConfig {
        switch provider {
        case .openai:
            OAuthConfig(
                prefix: "OPENAI",
                authorize: "https://auth.openai.com/oauth/authorize",
                token: "https://auth.openai.com/oauth/token",
                clientId: "app_EMoamEEZ73f0CkXaXp7hrann",
                scope: "openid profile email offline_access",
                redirect: "http://localhost:1455/auth/callback",
                extraAuthorize: [:],
                extraToken: [:],
                betaHeader: nil,
                pkce: pkce,
            )
        case .anthropic:
            OAuthConfig(
                prefix: "ANTHROPIC",
                authorize: "https://claude.ai/oauth/authorize",
                token: "https://console.anthropic.com/v1/oauth/token",
                clientId: "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
                scope: "org:create_api_key user:profile user:inference",
                redirect: "https://console.anthropic.com/oauth/code/callback",
                extraAuthorize: ["code": "true"],
                extraToken: [:],
                betaHeader: "oauth-2025-04-20,claude-code-20250219,interleaved-thinking-2025-05-14,fine-grained-tool-streaming-2025-05-14",
                pkce: pkce,
            )
        case .grok, .gemini:
            OAuthConfig(
                prefix: "",
                authorize: "",
                token: "",
                clientId: "",
                scope: "",
                redirect: "",
                extraAuthorize: [:],
                extraToken: [:],
                betaHeader: nil,
                pkce: pkce,
            )
        }
    }

    private static func parseCode(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let code = url.queryItems["code"] { return code }
        if let hash = trimmed.firstIndex(of: "#") { return String(trimmed[..<hash]) }
        return trimmed
    }

    private func persistOAuthResult(_ result: OAuthTokenResult, config: OAuthConfig) -> Result<Void, TKAuthError> {
        switch result {
        case let .success(token):
            do {
                try self.setCredential(key: "\(config.prefix)_ACCESS_TOKEN", value: token.access)
                try self.setCredential(key: "\(config.prefix)_REFRESH_TOKEN", value: token.refresh)
                try self.setCredential(
                    key: "\(config.prefix)_ACCESS_EXPIRES",
                    value: String(Int(token.expires.timeIntervalSince1970)),
                )
                if let beta = config.betaHeader {
                    try self.setCredential(key: "\(config.prefix)_BETA_HEADER", value: beta)
                }
                return .success(())
            } catch {
                return .failure(.general("Failed to store tokens: \(error)"))
            }
        case let .failure(reason):
            return .failure(.general(reason))
        }
    }
}

// MARK: - Helpers

struct PKCE {
    let verifier: String
    let challenge: String

    init() {
        let data = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        self.verifier = data.urlSafeBase64()
        self.challenge = Data(TKHasher.hash(data: self.verifier.data(using: .utf8)!)).urlSafeBase64()
    }
}

struct OAuthConfig {
    let prefix: String
    let authorize: String
    let token: String
    let clientId: String
    let scope: String
    let redirect: String
    let extraAuthorize: [String: String]
    let extraToken: [String: String]
    let betaHeader: String?
    let pkce: PKCE

    var authorizeURL: URL? {
        var components = URLComponents(string: self.authorize)
        var items: [URLQueryItem] = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: self.clientId),
            .init(name: "redirect_uri", value: self.redirect),
            .init(name: "scope", value: self.scope),
            .init(name: "code_challenge", value: self.pkce.challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: self.pkce.verifier),
        ]
        items.append(contentsOf: self.extraAuthorize.map { URLQueryItem(name: $0.key, value: $0.value) })
        components?.queryItems = items
        return components?.url
    }
}

struct OAuthToken {
    let access: String
    let refresh: String
    let expires: Date
}

enum OAuthTokenResult {
    case success(OAuthToken)
    case failure(String)
}

enum OAuthTokenExchanger {
    static func exchange(config: OAuthConfig, code: String, pkce: PKCE, timeout: Double) async -> OAuthTokenResult {
        guard let url = URL(string: config.token) else { return .failure("Bad token URL") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "grant_type": "authorization_code",
            "client_id": config.clientId,
            "code": code,
            "redirect_uri": config.redirect,
            "code_verifier": pkce.verifier,
        ]
        config.extraToken.forEach { body[$0.key] = $0.value }

        switch await HTTP.postJSON(request: req, body: body, timeoutSeconds: timeout) {
        case let .success(json):
            guard
                let access = json["access_token"] as? String,
                let refresh = json["refresh_token"] as? String,
                let expiresIn = json["expires_in"] as? Double else { return .failure("Invalid token response") }
            let expires = Date().addingTimeInterval(expiresIn)
            return .success(OAuthToken(access: access, refresh: refresh, expires: expires))
        case let .failure(reason):
            return .failure(reason)
        case let .timeout(seconds):
            return .failure("timed out after \(Int(seconds))s")
        }
    }

    static func exchangeRefresh(
        urlRequest: URLRequest,
        body: [String: Any],
        timeout: Double,
    ) async
        -> OAuthTokenResult
    {
        switch await HTTP.postJSON(request: urlRequest, body: body, timeoutSeconds: timeout) {
        case let .success(json):
            guard
                let access = json["access_token"] as? String,
                let refresh = json["refresh_token"] as? String,
                let expiresIn = json["expires_in"] as? Double else { return .failure("Invalid token response") }
            let expires = Date().addingTimeInterval(expiresIn)
            return .success(OAuthToken(access: access, refresh: refresh, expires: expires))
        case let .failure(reason):
            return .failure(reason)
        case let .timeout(seconds):
            return .failure("timed out after \(Int(seconds))s")
        }
    }
}

public enum TKAuthError: Error, Sendable {
    case unsupported
    case general(String)
}

struct TKProviderValidator {
    let timeoutSeconds: Double

    func validate(provider: TKProviderId, secret: String) async -> TKValidationResult {
        switch provider {
        case .openai:
            return await self.validateBearer(
                url: "https://api.openai.com/v1/models",
                secret: secret,
                header: "Authorization",
                valuePrefix: "Bearer ",
            )
        case .anthropic:
            var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            request.httpMethod = "POST"
            request.setValue(secret, forHTTPHeaderField: "x-api-key")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.httpBody = try? JSONSerialization.data(withJSONObject: [
                "model": "claude-3-haiku-20241022",
                "max_tokens": 1,
                "messages": [
                    ["role": "user", "content": "ping"],
                ],
            ])
            return await HTTP.perform(request: request, timeoutSeconds: self.timeoutSeconds)
        case .grok:
            return await self.validateBearer(
                url: "https://api.x.ai/v1/models",
                secret: secret,
                header: "Authorization",
                valuePrefix: "Bearer ",
            )
        case .gemini:
            let url = "https://generativelanguage.googleapis.com/v1beta/models?key=\(secret)"
            var request = URLRequest(url: URL(string: url)!)
            request.httpMethod = "GET"
            return await HTTP.perform(request: request, timeoutSeconds: self.timeoutSeconds)
        }
    }

    private func validateBearer(
        url: String,
        secret: String,
        header: String,
        valuePrefix: String,
    ) async
        -> TKValidationResult
    {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        request.setValue(valuePrefix + secret, forHTTPHeaderField: header)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return await HTTP.perform(request: request, timeoutSeconds: self.timeoutSeconds)
    }
}

enum HTTP {
    static func perform(
        request: URLRequest,
        timeoutSeconds: Double,
        session: URLSession? = nil,
    ) async
        -> TKValidationResult
    {
        let session = session ?? Self.makeSession(timeoutSeconds: timeoutSeconds)
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure("invalid response") }
            if (200...299).contains(http.statusCode) { return .success }
            return .failure("status \(http.statusCode)")
        } catch {
            if (error as? URLError)?.code == .timedOut {
                return .timeout(timeoutSeconds)
            }
            return .failure(error.localizedDescription)
        }
    }

    static func postJSON(
        request: URLRequest,
        body: [String: Any],
        timeoutSeconds: Double,
        session: URLSession? = nil,
    ) async
        -> TKValidationResultJSON
    {
        let session = session ?? Self.makeSession(timeoutSeconds: timeoutSeconds)
        var req = request
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return await self.performJSON(request: req, timeoutSeconds: timeoutSeconds, session: session)
    }

    static func performJSON(
        request: URLRequest,
        timeoutSeconds: Double,
        session: URLSession? = nil,
    ) async
        -> TKValidationResultJSON
    {
        let session = session ?? Self.makeSession(timeoutSeconds: timeoutSeconds)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure("invalid response") }
            if (200...299).contains(http.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return .success(json)
                }
                return .failure("invalid json")
            }
            return .failure("status \(http.statusCode)")
        } catch {
            if (error as? URLError)?.code == .timedOut {
                return .timeout(timeoutSeconds)
            }
            return .failure(error.localizedDescription)
        }
    }
}

enum TKValidationResultJSON {
    case success([String: Any])
    case failure(String)
    case timeout(Double)
}

extension HTTP {
    fileprivate static func makeSession(timeoutSeconds: Double) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds
        return URLSession(configuration: config)
    }
}

extension URL {
    fileprivate var queryItems: [String: String] {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .reduce(into: [String: String]()) { $0[$1.name] = $1.value } ?? [:]
    }
}

extension Data {
    fileprivate func urlSafeBase64() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
