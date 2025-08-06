//
//  ResponseCache.swift
//  Tachikoma
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto  // swift-crypto package for Linux/Windows
#endif

// MARK: - Response Cache

/// Thread-safe cache for AI model responses
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor ResponseCache {
    private var cache: [CacheKey: CachedResponse] = [:]
    private let maxSize: Int
    private let ttl: TimeInterval
    private var accessOrder: [CacheKey] = []
    
    public init(maxSize: Int = 100, ttl: TimeInterval = 3600) {
        self.maxSize = maxSize
        self.ttl = ttl
    }
    
    /// Get cached response for a request
    public func get(for request: ProviderRequest) -> ProviderResponse? {
        let key = CacheKey(from: request)
        
        guard let cached = cache[key] else {
            return nil
        }
        
        // Check if expired
        if Date().timeIntervalSince(cached.timestamp) > ttl {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            return nil
        }
        
        // Update access order for LRU
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
        
        return cached.response
    }
    
    /// Store response for a request
    public func store(_ response: ProviderResponse, for request: ProviderRequest) {
        let key = CacheKey(from: request)
        
        // Check cache size and evict if necessary
        if cache.count >= maxSize && cache[key] == nil {
            evictLRU()
        }
        
        cache[key] = CachedResponse(
            response: response,
            timestamp: Date()
        )
        
        // Update access order
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
    }
    
    /// Invalidate cache entries matching a predicate
    func invalidate(matching predicate: (CacheKey) -> Bool) {
        let keysToRemove = cache.keys.filter(predicate)
        for key in keysToRemove {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
    }
    
    /// Clear all cache entries
    public func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }
    
    /// Get cache statistics
    public func statistics() -> CacheStatistics {
        let validEntries = cache.compactMap { key, value -> CachedResponse? in
            Date().timeIntervalSince(value.timestamp) <= ttl ? value : nil
        }
        
        return CacheStatistics(
            totalEntries: cache.count,
            validEntries: validEntries.count,
            cacheSize: maxSize,
            oldestEntry: cache.values.min(by: { $0.timestamp < $1.timestamp })?.timestamp,
            newestEntry: cache.values.max(by: { $0.timestamp < $1.timestamp })?.timestamp
        )
    }
    
    private func evictLRU() {
        guard let firstKey = accessOrder.first else { return }
        cache.removeValue(forKey: firstKey)
        accessOrder.removeFirst()
    }
}

// MARK: - Cache Types

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct CacheKey: Hashable, Sendable {
    let hash: String
    let model: String?
    let messageCount: Int
    
    init(from request: ProviderRequest) {
        // Create a deterministic hash from request
        var hasher = SHA256()
        
        // Hash messages
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        if let messagesData = try? encoder.encode(request.messages) {
            hasher.update(data: messagesData)
        }
        
        // Hash settings
        if let settingsData = try? encoder.encode(request.settings) {
            hasher.update(data: settingsData)
        }
        
        // Hash tools (if present)
        if let tools = request.tools {
            let toolSignatures = tools.map { "\($0.name):\($0.namespace ?? ""):\($0.recipient ?? "")" }.joined(separator: ",")
            hasher.update(data: Data(toolSignatures.utf8))
        }
        
        let digest = hasher.finalize()
        self.hash = digest.compactMap { String(format: "%02x", $0) }.joined()
        self.model = nil // Will be set from provider
        self.messageCount = request.messages.count
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct CachedResponse: Sendable {
    let response: ProviderResponse
    let timestamp: Date
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct CacheStatistics: Sendable {
    public let totalEntries: Int
    public let validEntries: Int
    public let cacheSize: Int
    public let oldestEntry: Date?
    public let newestEntry: Date?
}

// MARK: - Cache-Aware Generation

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension TachikomaConfiguration {
    /// Global response cache (opt-in)
    static let sharedCache = ResponseCache()
    
    /// Whether to use response caching
    var useCache: Bool {
        get { _useCache ?? false }
        set { _useCache = newValue }
    }
    
    private var _useCache: Bool? {
        get { nil }
        set { }
    }
}

// MARK: - Integration with Generation

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension ResponseCache {
    /// Wrap a provider with caching
    public func wrap<T: ModelProvider>(_ provider: T) -> CachedProvider<T> {
        CachedProvider(provider: provider, cache: self)
    }
}

/// Provider wrapper that adds caching
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct CachedProvider<Base: ModelProvider>: ModelProvider {
    let provider: Base
    let cache: ResponseCache
    
    public var modelId: String { provider.modelId }
    public var baseURL: String? { provider.baseURL }
    public var apiKey: String? { provider.apiKey }
    public var capabilities: ModelCapabilities { provider.capabilities }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        // Check cache first
        if let cached = await cache.get(for: request) {
            return cached
        }
        
        // Generate and cache
        let response = try await provider.generateText(request: request)
        await cache.store(response, for: request)
        return response
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        // Streaming doesn't use cache
        try await provider.streamText(request: request)
    }
}