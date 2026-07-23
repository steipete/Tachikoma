import Foundation
#if canImport(CFNetwork)
import CFNetwork
#endif
import Testing
@testable import Tachikoma

@Suite
struct ProxyAwareURLSessionTests {
    @Test
    func `ALL_PROXY configures a SOCKS session and exclusions`() throws {
        let dictionary = try #require(TKURLSessionFactory.proxyDictionary(environment: [
            "ALL_PROXY": "socks5h://127.0.0.1:6153",
            "NO_PROXY": "localhost,.example.test",
        ]))

        #expect(dictionary["SOCKSEnable"] as? Bool == true)
        #expect(dictionary["SOCKSProxy"] as? String == "127.0.0.1")
        #expect(dictionary["SOCKSPort"] as? Int == 6153)
        #expect(dictionary["SOCKSVersion"] as? Int == 5)
        #expect(dictionary["ExceptionsList"] as? [String] == [
            "localhost",
            "example.test",
            "*.example.test",
        ])
    }

    @Test
    func `HTTPS proxy takes precedence over ALL_PROXY`() throws {
        let dictionary = try #require(TKURLSessionFactory.proxyDictionary(environment: [
            "HTTPS_PROXY": "http://secure-proxy.example.test:8443",
            "ALL_PROXY": "socks5://127.0.0.1:1080",
        ]))

        #expect(dictionary["HTTPSEnable"] as? Bool == true)
        #expect(dictionary["HTTPSProxy"] as? String == "secure-proxy.example.test")
        #expect(dictionary["HTTPSPort"] as? Int == 8443)
        #expect(dictionary["SOCKSEnable"] as? Bool == true)
        #expect(dictionary["HTTPEnable"] == nil)
    }

    @Test
    func `lowercase proxy without a scheme defaults to HTTP`() throws {
        let dictionary = try #require(TKURLSessionFactory.proxyDictionary(environment: [
            "https_proxy": "proxy.example.test:3128",
        ]))

        #expect(dictionary["HTTPSEnable"] as? Bool == true)
        #expect(dictionary["HTTPSProxy"] as? String == "proxy.example.test")
        #expect(dictionary["HTTPSPort"] as? Int == 3128)
        #expect(dictionary["HTTPEnable"] == nil)
    }

    @Test
    func `HTTP and HTTPS proxies remain protocol specific`() throws {
        let dictionary = try #require(TKURLSessionFactory.proxyDictionary(environment: [
            "http_proxy": "http://plain-proxy.example.test:8080",
            "HTTPS_PROXY": "http://secure-proxy.example.test:8443",
        ]))

        #expect(dictionary["HTTPProxy"] as? String == "plain-proxy.example.test")
        #expect(dictionary["HTTPPort"] as? Int == 8080)
        #expect(dictionary["HTTPSProxy"] as? String == "secure-proxy.example.test")
        #expect(dictionary["HTTPSPort"] as? Int == 8443)
    }

    @Test
    func `lowercase variables win and uppercase HTTP_PROXY is ignored`() throws {
        let dictionary = try #require(TKURLSessionFactory.proxyDictionary(environment: [
            "http_proxy": "http://safe-http-proxy.example.test:8080",
            "HTTP_PROXY": "http://cgi-injected.example.test:9999",
            "https_proxy": "http://lowercase-https.example.test:8443",
            "HTTPS_PROXY": "http://uppercase-https.example.test:9443",
        ]))

        #expect(dictionary["HTTPProxy"] as? String == "safe-http-proxy.example.test")
        #expect(dictionary["HTTPSProxy"] as? String == "lowercase-https.example.test")
    }

    @Test
    func `NO_PROXY normalizes domains and strips ports`() throws {
        let dictionary = try #require(TKURLSessionFactory.proxyDictionary(environment: [
            "ALL_PROXY": "socks5://127.0.0.1:1080",
            "NO_PROXY": "example.org,.example.test,service.local:8443,127.0.0.1:9000",
        ]))

        #expect(dictionary["ExceptionsList"] as? [String] == [
            "example.org",
            "*.example.org",
            "example.test",
            "*.example.test",
            "service.local",
            "*.service.local",
            "127.0.0.1",
        ])
    }

    #if canImport(CFNetwork)
    @Test
    func `normalized NO_PROXY bypasses bare domains and subdomains in CFNetwork`() throws {
        let dictionary = try #require(TKURLSessionFactory.proxyDictionary(environment: [
            "ALL_PROXY": "socks5://127.0.0.1:1080",
            "NO_PROXY": "example.org:443",
        ]))

        #expect(try Self.proxyType(for: "https://example.org", dictionary: dictionary) == kCFProxyTypeNone as String)
        #expect(try Self.proxyType(for: "https://sub.example.org", dictionary: dictionary) == kCFProxyTypeNone as String)
    }
    #endif

    @Test
    func `invalid HTTPS proxy falls back to ALL_PROXY`() throws {
        let dictionary = try #require(TKURLSessionFactory.proxyDictionary(environment: [
            "HTTPS_PROXY": "ftp://invalid.example.test:21",
            "ALL_PROXY": "socks5://127.0.0.1:1080",
        ]))

        #expect(dictionary["SOCKSEnable"] as? Bool == true)
        #expect(dictionary["SOCKSProxy"] as? String == "127.0.0.1")
    }

    @Test
    func `NO_PROXY wildcard disables environment proxy`() throws {
        let dictionary = try #require(TKURLSessionFactory.proxyDictionary(environment: [
            "ALL_PROXY": "socks5://127.0.0.1:1080",
            "NO_PROXY": "*",
        ]))

        #expect(dictionary.isEmpty)
    }

    @Test
    func `unsupported proxy schemes are ignored`() {
        let dictionary = TKURLSessionFactory.proxyDictionary(environment: [
            "ALL_PROXY": "ftp://proxy.example.test:21",
        ])

        #expect(dictionary == nil)
    }

    #if canImport(CFNetwork)
    private static func proxyType(
        for urlString: String,
        dictionary: [AnyHashable: Any],
    ) throws -> String? {
        let url = try #require(URL(string: urlString))
        let proxies = CFNetworkCopyProxiesForURL(
            url as CFURL,
            dictionary as CFDictionary,
        ).takeRetainedValue() as NSArray
        let firstProxy = proxies.firstObject as? [AnyHashable: Any]
        return firstProxy?[kCFProxyTypeKey as String] as? String
    }
    #endif
}
