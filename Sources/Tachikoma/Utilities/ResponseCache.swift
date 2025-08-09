//
//  ResponseCache.swift
//  Tachikoma
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#endif

// MARK: - Cache Key

/// Hashable key for cache entries
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
internal struct CacheKey: Hashable {
    let hash: String
    let model: String? // Store model ID for invalidation
    
    init(from request: ProviderRequest, model: String? = nil) {
        self.model = model
        // Create a unique hash from the request
        var hasher = Hasher()
        // Combine message content
        for message in request.messages {
            hasher.combine(message.role.rawValue)
            for part in message.content {
                switch part {
                case .text(let text):
                    hasher.combine(text)
                case .image(let image):
                    hasher.combine(image.mimeType)
                    hasher.combine(image.data.prefix(100)) // Use first 100 chars of base64 data
                case .toolCall(let call):
                    hasher.combine(call.id)
                    hasher.combine(call.name)
                case .toolResult(let result):
                    hasher.combine(result.toolCallId)
                }
            }
        }
        // Combine tools
        if let tools = request.tools {
            hasher.combine(tools.map { $0.name })
        }
        // Combine settings
        hasher.combine(request.settings.temperature)
        hasher.combine(request.settings.maxTokens)
        hasher.combine(request.settings.topP)
        self.hash = String(hasher.finalize())
    }
}

// MARK: - Response Cache

/// Cache with TTL, memory management, and invalidation strategies
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor ResponseCache {
    // MARK: - Properties
    
    private var cache: [CacheKey: CacheEntry] = [:]
    private let configuration: CacheConfiguration
    private var accessOrder: [CacheKey] = []
    private var memoryPressureObserver: NSObjectProtocol?
    private var cleanupTimer: Timer?
    private var statistics = CacheStatisticsTracker()
    
    // MARK: - Initialization
    
    public init(configuration: CacheConfiguration = .default) {
        self.configuration = configuration
        Task {
            await setupMemoryPressureHandling()
            await setupPeriodicCleanup()
        }
    }
    
    
    // MARK: - Public Methods
    
    /// Get cached response with TTL validation
    public func get(
        for request: ProviderRequest,
        ttlOverride: TimeInterval? = nil
    ) -> ProviderResponse? {
        let key = CacheKey(from: request)
        
        guard let entry = cache[key] else {
            statistics.recordMiss()
            return nil
        }
        
        // Check TTL
        let ttl = ttlOverride ?? entry.ttl ?? configuration.defaultTTL
        if entry.isExpired(ttl: ttl) {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            statistics.recordEviction(reason: .expired)
            return nil
        }
        
        // Update access time and order for LRU
        entry.recordAccess()
        updateAccessOrder(for: key)
        
        statistics.recordHit()
        return entry.response
    }
    
    /// Store response with custom TTL and priority
    public func store(
        _ response: ProviderResponse,
        for request: ProviderRequest,
        ttl: TimeInterval? = nil,
        priority: CachePriority = .normal
    ) {
        let key = CacheKey(from: request)
        
        // Check memory limit
        if shouldEvictForMemory() {
            evictByStrategy()
        }
        
        // Check count limit
        if cache.count >= configuration.maxEntries && cache[key] == nil {
            evictByStrategy()
        }
        
        let entry = CacheEntry(
            response: response,
            ttl: ttl,
            priority: priority
        )
        
        cache[key] = entry
        updateAccessOrder(for: key)
        statistics.recordStore()
    }
    
    /// Invalidate entries matching predicate
    func invalidate(
        matching predicate: @escaping (CacheKey, CacheEntry) -> Bool
    ) {
        let toRemove = cache.filter { predicate($0.key, $0.value) }
        
        for (key, _) in toRemove {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            statistics.recordEviction(reason: .invalidated)
        }
    }
    
    /// Invalidate entries by model
    public func invalidateModel(_ modelId: String) {
        invalidate { key, _ in
            key.model == modelId
        }
    }
    
    /// Invalidate entries older than specified age
    public func invalidateOlderThan(_ age: TimeInterval) {
        let cutoff = Date().addingTimeInterval(-age)
        invalidate { _, entry in
            entry.createdAt < cutoff
        }
    }
    
    /// Clear all cache entries
    public func clear() {
        let count = cache.count
        cache.removeAll()
        accessOrder.removeAll()
        statistics.recordBulkEviction(count: count, reason: .cleared)
    }
    
    /// Get cache statistics
    public func getStatistics() -> EnhancedCacheStatistics {
        return statistics.snapshot(
            currentEntries: cache.count,
            maxEntries: configuration.maxEntries
        )
    }
    
    /// Prewarm cache with common requests
    public func prewarm(
        with requests: [(ProviderRequest, ProviderResponse)],
        ttl: TimeInterval? = nil
    ) {
        for (request, response) in requests {
            store(response, for: request, ttl: ttl, priority: .high)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMemoryPressureHandling() {
        #if os(iOS) || os(tvOS) || os(watchOS)
        memoryPressureObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleMemoryPressure()
            }
        }
        #elseif os(macOS)
        // macOS doesn't have UIApplication memory warnings
        // Could use ProcessInfo.processInfo.thermalState monitoring instead
        #endif
    }
    
    private func setupPeriodicCleanup() {
        // Run cleanup every minute
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                performCleanup()
            }
        }
    }
    
    private func performCleanup() {
        var evictedCount = 0
        
        // Remove expired entries
        let expiredKeys = cache.compactMap { key, entry -> CacheKey? in
            let ttl = entry.ttl ?? configuration.defaultTTL
            return entry.isExpired(ttl: ttl) ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            evictedCount += 1
        }
        
        if evictedCount > 0 {
            statistics.recordBulkEviction(count: evictedCount, reason: .expired)
        }
    }
    
    private func handleMemoryPressure() async {
        switch configuration.memoryPressureStrategy {
        case .clearAll:
            clear()
        case .clearHalf:
            evictPercentage(50)
        case .clearLowPriority:
            evictLowPriority()
        case .adaptive:
            // Remove 30% of least recently used
            evictPercentage(30)
        }
    }
    
    private func shouldEvictForMemory() -> Bool {
        guard configuration.memoryLimit > 0 else { return false }
        
        // Estimate memory usage (simplified)
        let estimatedSize = cache.values.reduce(0) { total, entry in
            total + entry.estimatedMemorySize()
        }
        
        return estimatedSize > configuration.memoryLimit
    }
    
    private func evictByStrategy() {
        switch configuration.evictionStrategy {
        case .lru:
            evictLRU()
        case .lfu:
            evictLFU()
        case .fifo:
            evictFIFO()
        case .priority:
            evictLowestPriority()
        }
    }
    
    private func evictLRU() {
        guard let firstKey = accessOrder.first else { return }
        cache.removeValue(forKey: firstKey)
        accessOrder.removeFirst()
        statistics.recordEviction(reason: .capacityReached)
    }
    
    private func evictLFU() {
        // Evict least frequently used
        let leastUsed = cache.min { $0.value.accessCount < $1.value.accessCount }
        if let key = leastUsed?.key {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            statistics.recordEviction(reason: .capacityReached)
        }
    }
    
    private func evictFIFO() {
        // Evict oldest entry
        let oldest = cache.min { $0.value.createdAt < $1.value.createdAt }
        if let key = oldest?.key {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            statistics.recordEviction(reason: .capacityReached)
        }
    }
    
    private func evictLowestPriority() {
        // Find lowest priority entries
        let sorted = cache.sorted { $0.value.priority.rawValue < $1.value.priority.rawValue }
        if let first = sorted.first {
            cache.removeValue(forKey: first.key)
            accessOrder.removeAll { $0 == first.key }
            statistics.recordEviction(reason: .capacityReached)
        }
    }
    
    private func evictLowPriority() {
        let lowPriorityKeys = cache.compactMap { key, entry -> CacheKey? in
            entry.priority == .low ? key : nil
        }
        
        for key in lowPriorityKeys {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
        
        statistics.recordBulkEviction(count: lowPriorityKeys.count, reason: .memoryPressure)
    }
    
    private func evictPercentage(_ percentage: Int) {
        let toRemove = max(1, cache.count * percentage / 100)
        
        // Remove least recently used
        for _ in 0..<toRemove {
            guard !accessOrder.isEmpty else { break }
            let key = accessOrder.removeFirst()
            cache.removeValue(forKey: key)
        }
        
        statistics.recordBulkEviction(count: toRemove, reason: .memoryPressure)
    }
    
    private func updateAccessOrder(for key: CacheKey) {
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
    }
}

// MARK: - Cache Configuration

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct CacheConfiguration: Sendable {
    public let maxEntries: Int
    public let defaultTTL: TimeInterval
    public let memoryLimit: Int // in bytes, 0 = unlimited
    public let evictionStrategy: EvictionStrategy
    public let memoryPressureStrategy: MemoryPressureStrategy
    
    public init(
        maxEntries: Int = 1000,
        defaultTTL: TimeInterval = 3600, // 1 hour
        memoryLimit: Int = 100 * 1024 * 1024, // 100MB
        evictionStrategy: EvictionStrategy = .lru,
        memoryPressureStrategy: MemoryPressureStrategy = .adaptive
    ) {
        self.maxEntries = maxEntries
        self.defaultTTL = defaultTTL
        self.memoryLimit = memoryLimit
        self.evictionStrategy = evictionStrategy
        self.memoryPressureStrategy = memoryPressureStrategy
    }
    
    public static let `default` = CacheConfiguration()
    
    public static let aggressive = CacheConfiguration(
        maxEntries: 100,
        defaultTTL: 300, // 5 minutes
        memoryLimit: 10 * 1024 * 1024 // 10MB
    )
    
    public static let generous = CacheConfiguration(
        maxEntries: 10000,
        defaultTTL: 7200, // 2 hours
        memoryLimit: 500 * 1024 * 1024 // 500MB
    )
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum EvictionStrategy: String, Sendable {
    case lru // Least Recently Used
    case lfu // Least Frequently Used
    case fifo // First In First Out
    case priority // Priority-based
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum MemoryPressureStrategy: String, Sendable {
    case clearAll
    case clearHalf
    case clearLowPriority
    case adaptive
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum CachePriority: Int, Sendable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
    
    public static func < (lhs: CachePriority, rhs: CachePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Cache Entry

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class CacheEntry: @unchecked Sendable {
    let response: ProviderResponse
    let createdAt: Date
    let ttl: TimeInterval?
    let priority: CachePriority
    
    private(set) var lastAccessedAt: Date
    private(set) var accessCount: Int
    
    init(
        response: ProviderResponse,
        ttl: TimeInterval? = nil,
        priority: CachePriority = .normal
    ) {
        self.response = response
        self.createdAt = Date()
        self.ttl = ttl
        self.priority = priority
        self.lastAccessedAt = Date()
        self.accessCount = 0
    }
    
    func recordAccess() {
        lastAccessedAt = Date()
        accessCount += 1
    }
    
    func isExpired(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(createdAt) > ttl
    }
    
    func estimatedMemorySize() -> Int {
        // Rough estimation based on response content
        let textSize = response.text.utf8.count
        let toolCallsSize = (response.toolCalls?.count ?? 0) * 100 // Estimate 100 bytes per tool call
        let usageSize = 50 // Fixed overhead for usage data
        
        return textSize + toolCallsSize + usageSize + 100 // 100 bytes overhead
    }
}

// MARK: - Statistics Tracking

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class CacheStatisticsTracker: @unchecked Sendable {
    private var hits: Int = 0
    private var misses: Int = 0
    private var stores: Int = 0
    private var evictions: [EvictionReason: Int] = [:]
    private let startTime = Date()
    
    func recordHit() {
        hits += 1
    }
    
    func recordMiss() {
        misses += 1
    }
    
    func recordStore() {
        stores += 1
    }
    
    func recordEviction(reason: EvictionReason) {
        evictions[reason, default: 0] += 1
    }
    
    func recordBulkEviction(count: Int, reason: EvictionReason) {
        evictions[reason, default: 0] += count
    }
    
    func snapshot(currentEntries: Int, maxEntries: Int) -> EnhancedCacheStatistics {
        let hitRate = hits + misses > 0 ? Double(hits) / Double(hits + misses) : 0
        
        return EnhancedCacheStatistics(
            currentEntries: currentEntries,
            maxEntries: maxEntries,
            hits: hits,
            misses: misses,
            hitRate: hitRate,
            stores: stores,
            evictions: evictions,
            uptime: Date().timeIntervalSince(startTime)
        )
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum EvictionReason: String, Sendable {
    case expired
    case capacityReached
    case memoryPressure
    case invalidated
    case cleared
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct EnhancedCacheStatistics: Sendable {
    public let currentEntries: Int
    public let maxEntries: Int
    public let hits: Int
    public let misses: Int
    public let hitRate: Double
    public let stores: Int
    public let evictions: [EvictionReason: Int]
    public let uptime: TimeInterval
}

// MARK: - Cache Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension ResponseCache {
    /// Create a cache-aware provider
    func wrapProvider<T: ModelProvider>(_ provider: T) -> CacheAwareProvider<T> {
        CacheAwareProvider(provider: provider, cache: self)
    }
}

/// Cache-aware provider with enhanced features
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct CacheAwareProvider<Base: ModelProvider>: ModelProvider {
    let provider: Base
    let cache: ResponseCache
    
    public var modelId: String { provider.modelId }
    public var baseURL: String? { provider.baseURL }
    public var apiKey: String? { provider.apiKey }
    public var capabilities: ModelCapabilities { provider.capabilities }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        // Check cache with smart TTL based on request type
        let ttl = determineTTL(for: request)
        
        if let cached = await cache.get(for: request, ttlOverride: ttl) {
            return cached
        }
        
        // Generate and cache with appropriate priority
        let response = try await provider.generateText(request: request)
        let priority = determinePriority(for: request)
        
        await cache.store(response, for: request, ttl: ttl, priority: priority)
        return response
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        // Streaming bypasses cache but could cache the final result
        try await provider.streamText(request: request)
    }
    
    private func determineTTL(for request: ProviderRequest) -> TimeInterval {
        // Shorter TTL for requests with tools (more dynamic)
        if request.tools != nil && !request.tools!.isEmpty {
            return 300 // 5 minutes
        }
        
        // Longer TTL for simple completions
        return 3600 // 1 hour
    }
    
    private func determinePriority(for request: ProviderRequest) -> CachePriority {
        // Higher priority for expensive requests
        if let maxTokens = request.settings.maxTokens, maxTokens > 2000 {
            return .high
        }
        
        // Higher priority for requests with many messages (conversation history)
        if request.messages.count > 10 {
            return .high
        }
        
        return .normal
    }
}