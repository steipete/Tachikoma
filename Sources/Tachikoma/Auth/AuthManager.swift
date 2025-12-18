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
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
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
        let credentialsPath = self.credentialsPath
        guard FileManager.default.fileExists(atPath: credentialsPath) else { return [:] }
        do {
            let content = try String(contentsOfFile: credentialsPath)
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
        let baseDir = self.baseDir
        let credentialsPath = "\(baseDir)/credentials"

        try FileManager.default.createDirectory(
            atPath: baseDir,
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
        try content.write(to: URL(fileURLWithPath: credentialsPath), atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: credentialsPath)
    }
}

public final class TKAuthManager {
    public nonisolated(unsafe) static let shared = TKAuthManager()

    private let store = TKCredentialStore()
    private let lock = NSLock()
    private var ignoreEnv = false
    private var ignoreStore = false

    private init() {}

    private func environmentValue(for key: String) -> String? {
        guard !self.ignoreEnv else { return nil }
        let value = key.withCString { keyPtr -> String? in
            guard let cValue = getenv(keyPtr) else { return nil }
            let string = String(cString: cValue)
            return string.isEmpty ? nil : string
        }
        if let value { return value }
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty { return value }
        return nil
    }

    @discardableResult
    public func setIgnoreEnvironment(_ value: Bool) -> Bool {
        self.lock.lock()
        let previous = self.ignoreEnv
        self.ignoreEnv = value
        self.lock.unlock()
        return previous
    }

    @discardableResult
    public func setIgnoreCredentialStore(_ value: Bool) -> Bool {
        self.lock.lock()
        let previous = self.ignoreStore
        self.ignoreStore = value
        self.lock.unlock()
        return previous
    }

    public func credentialValue(for key: String) -> String? {
        self.lock.lock()
        let creds = self.ignoreStore ? [:] : self.store.load()
        self.lock.unlock()
        if let env = self.environmentValue(for: key) { return env }
        return creds[key]
    }

    public func resolveAuth(for provider: TKProviderId) -> TKAuthValue? {
        self.lock.lock()
        let creds = self.ignoreStore ? [:] : self.store.load()
        self.lock.unlock()
        switch provider {
        case .openai:
            if let env = self.environmentValue(for: "OPENAI_API_KEY") {
                return .bearer(env, betaHeader: nil)
            }
            if let access = creds["OPENAI_ACCESS_TOKEN"], !access.isEmpty {
                return .bearer(access, betaHeader: nil)
            }
            if let key = creds["OPENAI_API_KEY"], !key.isEmpty {
                return .apiKey(key)
            }
        case .anthropic:
            if let env = self.environmentValue(for: "ANTHROPIC_API_KEY") {
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
                if let env = self.environmentValue(for: k) {
                    return .bearer(env, betaHeader: nil)
                }
            }
            for k in envOrder {
                if let val = creds[k], !val.isEmpty { return .bearer(val, betaHeader: nil) }
            }
        case .gemini:
            if let env = self.environmentValue(for: "GEMINI_API_KEY") {
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
        print("After authorizing, paste the resulting code (callback URL, code param, or code#state) here:")
        guard let input = readLine(), !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.general("No code entered"))
        }
        let parsed = Self.parseOAuthCallback(from: input)
        let code = parsed.code
        let state = parsed.state
        guard !code.isEmpty else { return .failure(.general("Could not extract code")) }

        if !state.isEmpty, state != pkce.state {
            return .failure(.general("OAuth state mismatch (expected \(pkce.state), got \(state))"))
        }

        if config.requiresStateInTokenExchange, state.isEmpty {
            return .failure(.general("Missing OAuth state. Paste the full callback URL or code#state."))
        }

        let tokenResult = await OAuthTokenExchanger.exchange(
            config: config,
            code: code,
            state: state,
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
                tokenEncoding: .json,
                requiresStateInTokenExchange: true,
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

    private static func parseOAuthCallback(from input: String) -> (code: String, state: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed) {
            let query = url.queryItems
            let code = query["code"] ?? ""
            var state = query["state"] ?? ""

            if state.isEmpty, let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment {
                if fragment.contains("=") {
                    let items = URLComponents(string: "https://example.com?\(fragment)")?.queryItems ?? []
                    let fragmentParams = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
                    state = fragmentParams["state"] ?? ""
                } else {
                    state = fragment
                }
            }

            if !code.isEmpty { return (code, state) }
        }

        let parts = trimmed.split(separator: "#", maxSplits: 1)
        if parts.count > 1 { return (String(parts[0]), String(parts[1])) }
        return (trimmed, "")
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
    let state: String

    init() {
        let data = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        self.verifier = data.urlSafeBase64()
        self.challenge = Data(TKHasher.hash(data: self.verifier.data(using: .utf8)!)).urlSafeBase64()

        // Separate random state for CSRF protection
        let stateData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        self.state = stateData.urlSafeBase64()
    }
}

enum OAuthTokenEncoding {
    case formURLEncoded
    case json
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
    let tokenEncoding: OAuthTokenEncoding
    let requiresStateInTokenExchange: Bool
    let pkce: PKCE

    init(
        prefix: String,
        authorize: String,
        token: String,
        clientId: String,
        scope: String,
        redirect: String,
        extraAuthorize: [String: String],
        extraToken: [String: String],
        betaHeader: String?,
        tokenEncoding: OAuthTokenEncoding = .formURLEncoded,
        requiresStateInTokenExchange: Bool = false,
        pkce: PKCE,
    ) {
        self.prefix = prefix
        self.authorize = authorize
        self.token = token
        self.clientId = clientId
        self.scope = scope
        self.redirect = redirect
        self.extraAuthorize = extraAuthorize
        self.extraToken = extraToken
        self.betaHeader = betaHeader
        self.tokenEncoding = tokenEncoding
        self.requiresStateInTokenExchange = requiresStateInTokenExchange
        self.pkce = pkce
    }

    var authorizeURL: URL? {
        var components = URLComponents(string: self.authorize)
        var items: [URLQueryItem] = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: self.clientId),
            .init(name: "redirect_uri", value: self.redirect),
            .init(name: "scope", value: self.scope),
            .init(name: "code_challenge", value: self.pkce.challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: self.pkce.state),
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
    static func exchange(
        config: OAuthConfig,
        code: String,
        state: String = "",
        pkce: PKCE,
        timeout: Double,
        session: URLSession? = nil,
    ) async
        -> OAuthTokenResult
    {
        guard let url = URL(string: config.token) else { return .failure("Bad token URL") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        var body: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": config.clientId,
            "code": code,
            "redirect_uri": config.redirect,
            "code_verifier": pkce.verifier,
        ]
        if config.requiresStateInTokenExchange {
            if state.isEmpty { return .failure("Missing OAuth state") }
            body["state"] = state
        }
        config.extraToken.forEach { body[$0.key] = $0.value }

        let result: TKValidationResultJSON
        switch config.tokenEncoding {
        case .formURLEncoded:
            result = await HTTP.postForm(request: req, body: body, timeoutSeconds: timeout, session: session)
        case .json:
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            result = await HTTP.performJSON(request: req, timeoutSeconds: timeout, session: session)
        }

        switch result {
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
        // We continue to accept a loosely typed body here (used by existing refresh flows),
        // but the request is now encoded as standard form data for OAuth token endpoints.
        let stringBody = body.reduce(into: [String: String]()) { result, pair in
            result[pair.key] = String(describing: pair.value)
        }

        switch await HTTP.postForm(request: urlRequest, body: stringBody, timeoutSeconds: timeout) {
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
    static func postForm(
        request: URLRequest,
        body: [String: String],
        timeoutSeconds: Double,
        session: URLSession? = nil,
    ) async
        -> TKValidationResultJSON
    {
        let session = session ?? Self.makeSession(timeoutSeconds: timeoutSeconds)
        var req = request
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        var components = URLComponents()
        components.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
        req.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        return await self.performJSON(request: req, timeoutSeconds: timeoutSeconds, session: session)
    }

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
