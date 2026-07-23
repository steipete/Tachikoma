import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum TKURLSessionFactory {
    private enum ProxyTarget {
        case http
        case https
    }

    private struct ProxyEndpoint {
        let scheme: String
        let host: String
        let port: Int
        let user: String?
        let password: String?

        var isSOCKS: Bool {
            ["socks", "socks5", "socks5h"].contains(self.scheme)
        }
    }

    static func make(
        configuration: URLSessionConfiguration = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
    ) -> URLSession {
        if let proxyDictionary = self.proxyDictionary(environment: environment) {
            configuration.connectionProxyDictionary = proxyDictionary
        }
        return URLSession(configuration: configuration)
    }

    static func proxyDictionary(environment: [String: String]) -> [AnyHashable: Any]? {
        let exclusions = self.noProxyEntries(environment: environment)
        if exclusions.contains("*") {
            return [:]
        }

        let fallback = self.proxyEndpoint(keys: ["all_proxy", "ALL_PROXY"], environment: environment)
        // Match curl's HTTPoxy protection: uppercase HTTP_PROXY is intentionally ignored.
        let httpProxy = self.proxyEndpoint(keys: ["http_proxy"], environment: environment) ?? fallback
        let httpsProxy = self.proxyEndpoint(keys: ["https_proxy", "HTTPS_PROXY"], environment: environment) ?? fallback
        guard httpProxy != nil || httpsProxy != nil else {
            return nil
        }

        var dictionary: [AnyHashable: Any] = [:]
        if let httpProxy {
            self.apply(httpProxy, to: &dictionary, target: .http)
        }
        if let httpsProxy {
            self.apply(httpsProxy, to: &dictionary, target: .https)
        }
        if !exclusions.isEmpty {
            dictionary["ExceptionsList"] = exclusions
        }
        return dictionary
    }

    private static func apply(
        _ endpoint: ProxyEndpoint,
        to dictionary: inout [AnyHashable: Any],
        target: ProxyTarget,
    ) {
        if endpoint.isSOCKS {
            dictionary["SOCKSEnable"] = true
            dictionary["SOCKSProxy"] = endpoint.host
            dictionary["SOCKSPort"] = endpoint.port
            dictionary["SOCKSVersion"] = 5
            if let user = endpoint.user, !user.isEmpty {
                dictionary["SOCKSUser"] = user
            }
            if let password = endpoint.password, !password.isEmpty {
                dictionary["SOCKSPassword"] = password
            }
            return
        }

        switch target {
        case .http:
            dictionary.merge([
                "HTTPEnable": true,
                "HTTPProxy": endpoint.host,
                "HTTPPort": endpoint.port,
            ]) { _, new in new }
            if let user = endpoint.user, !user.isEmpty {
                dictionary["HTTPUser"] = user
            }
            if let password = endpoint.password, !password.isEmpty {
                dictionary["HTTPPassword"] = password
            }
        case .https:
            dictionary.merge([
                "HTTPSEnable": true,
                "HTTPSProxy": endpoint.host,
                "HTTPSPort": endpoint.port,
            ]) { _, new in new }
            if let user = endpoint.user, !user.isEmpty {
                dictionary["HTTPSUser"] = user
            }
            if let password = endpoint.password, !password.isEmpty {
                dictionary["HTTPSPassword"] = password
            }
        }
    }

    private static func proxyEndpoint(
        keys: [String],
        environment: [String: String],
    ) -> ProxyEndpoint? {
        for key in keys {
            guard let rawValue = environment[key], !rawValue.isEmpty else { continue }
            if let endpoint = self.proxyEndpoint(from: rawValue) {
                return endpoint
            }
        }
        return nil
    }

    private static func proxyEndpoint(from rawValue: String) -> ProxyEndpoint? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let normalized = value.contains("://") ? value : "http://\(value)"
        guard
            let components = URLComponents(string: normalized),
            let scheme = components.scheme?.lowercased(),
            ["http", "https", "socks", "socks5", "socks5h"].contains(scheme),
            let host = components.host,
            !host.isEmpty
        else {
            return nil
        }
        return ProxyEndpoint(
            scheme: scheme,
            host: host,
            port: components.port ?? self.defaultPort(for: scheme),
            user: components.user,
            password: components.password,
        )
    }

    private static func noProxyEntries(environment: [String: String]) -> [String] {
        let rawValue = ["NO_PROXY", "no_proxy"]
            .lazy
            .compactMap { environment[$0] }
            .first(where: { !$0.isEmpty }) ?? ""
        let tokens = rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var entries: [String] = []
        var seen: Set<String> = []
        for token in tokens {
            for entry in self.normalizedNoProxyEntries(for: token) where seen.insert(entry).inserted {
                entries.append(entry)
            }
        }
        return entries
    }

    private static func normalizedNoProxyEntries(for token: String) -> [String] {
        if token == "*" { return [token] }

        let host = self.noProxyHost(from: token).lowercased()
        guard !host.isEmpty else { return [] }
        if host == "<local>" || host.contains("/") || self.isIPAddress(host) {
            return [host]
        }
        if host.contains("*"), !host.hasPrefix("*.") {
            return [host]
        }

        let bareHost: String
        if host.hasPrefix("*.") {
            bareHost = String(host.dropFirst(2))
        } else if host.hasPrefix(".") {
            bareHost = String(host.dropFirst())
        } else {
            bareHost = host
        }
        guard !bareHost.isEmpty else { return [] }
        if bareHost.contains(".") {
            return [bareHost, "*.\(bareHost)"]
        }
        return [bareHost]
    }

    private static func noProxyHost(from token: String) -> String {
        if token.hasPrefix("["), let closingBracket = token.firstIndex(of: "]") {
            return String(token[token.index(after: token.startIndex)..<closingBracket])
        }

        let parts = token.split(separator: ":", omittingEmptySubsequences: false)
        if parts.count == 2, Int(parts[1]) != nil {
            return String(parts[0])
        }
        return token
    }

    private static func isIPAddress(_ host: String) -> Bool {
        if host.contains(":") { return true }
        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        return octets.count == 4 && octets.allSatisfy { octet in
            guard let value = Int(octet) else { return false }
            return (0...255).contains(value)
        }
    }

    private static func defaultPort(for scheme: String) -> Int {
        switch scheme {
        case "socks", "socks5", "socks5h": 1080
        case "https": 443
        default: 80
        }
    }
}
