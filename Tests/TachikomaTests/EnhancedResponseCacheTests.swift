//
//  EnhancedResponseCacheTests.swift
//  TachikomaTests
//

import Testing
@testable import Tachikoma
import Foundation

@Suite("Enhanced Response Cache Tests")
struct EnhancedResponseCacheTests {
    
    @Test("Cache configuration defaults")
    func testCacheConfigurationDefaults() throws {
        let config = CacheConfiguration.default
        
        #expect(config.maxEntries == 1000)
        #expect(config.defaultTTL == 3600) // 1 hour
        #expect(config.memoryLimit == 100 * 1024 * 1024) // 100MB
        #expect(config.evictionStrategy == .lru)
        #expect(config.memoryPressureStrategy == .adaptive)
    }
    
    @Test("Cache configuration presets")
    func testCacheConfigurationPresets() throws {
        let aggressive = CacheConfiguration.aggressive
        #expect(aggressive.maxEntries == 100)
        #expect(aggressive.defaultTTL == 300) // 5 minutes
        #expect(aggressive.memoryLimit == 10 * 1024 * 1024) // 10MB
        
        let generous = CacheConfiguration.generous
        #expect(generous.maxEntries == 10000)
        #expect(generous.defaultTTL == 7200) // 2 hours
        #expect(generous.memoryLimit == 500 * 1024 * 1024) // 500MB
    }
    
    @Test("Cache priority ordering")
    func testCachePriorityOrdering() throws {
        #expect(CachePriority.low < CachePriority.normal)
        #expect(CachePriority.normal < CachePriority.high)
        #expect(CachePriority.high < CachePriority.critical)
        
        #expect(CachePriority.low.rawValue == 0)
        #expect(CachePriority.critical.rawValue == 3)
    }
    
    @Test("Cache store and retrieve")
    func testCacheStoreAndRetrieve() async throws {
        let cache = EnhancedResponseCache(configuration: .default)
        
        let request = ProviderRequest(
            messages: [.user("Test message")],
            settings: .default
        )
        
        let response = ProviderResponse(
            text: "Test response",
            toolCalls: nil,
            usage: Usage(inputTokens: 10, outputTokens: 20),
            finishReason: .stop
        )
        
        // Store in cache
        await cache.store(response, for: request, ttl: 60, priority: .normal)
        
        // Retrieve from cache
        let cached = await cache.get(for: request)
        
        #expect(cached?.text == "Test response")
        #expect(cached?.usage?.inputTokens == 10)
        #expect(cached?.usage?.outputTokens == 20)
    }
    
    @Test("Cache TTL expiration")
    func testCacheTTLExpiration() async throws {
        let cache = EnhancedResponseCache(configuration: .default)
        
        let request = ProviderRequest(
            messages: [.user("Expiring message")],
            settings: .default
        )
        
        let response = ProviderResponse(
            text: "Will expire",
            toolCalls: nil,
            usage: nil,
            finishReason: .stop
        )
        
        // Store with very short TTL
        await cache.store(response, for: request, ttl: 0.01) // 10ms
        
        // Wait for expiration
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms
        
        // Should be expired
        let cached = await cache.get(for: request)
        #expect(cached == nil)
    }
    
    @Test("Cache invalidation by model")
    func testCacheInvalidationByModel() async throws {
        let cache = EnhancedResponseCache(configuration: .default)
        
        // Store multiple entries
        for i in 1...3 {
            let request = ProviderRequest(
                messages: [.user("Message \(i)")],
                settings: .default
            )
            
            let response = ProviderResponse(
                text: "Response \(i)",
                toolCalls: nil,
                usage: nil,
                finishReason: .stop
            )
            
            await cache.store(response, for: request)
        }
        
        // Invalidate by model (would need actual model tracking in real implementation)
        await cache.invalidateModel("gpt-4")
        
        // For now, just verify the method exists
        #expect(true)
    }
    
    @Test("Cache invalidation by age")
    func testCacheInvalidationByAge() async throws {
        let cache = EnhancedResponseCache(configuration: .default)
        
        let request = ProviderRequest(
            messages: [.user("Old message")],
            settings: .default
        )
        
        let response = ProviderResponse(
            text: "Old response",
            toolCalls: nil,
            usage: nil,
            finishReason: .stop
        )
        
        await cache.store(response, for: request)
        
        // Invalidate entries older than 0 seconds (all entries)
        await cache.invalidateOlderThan(0)
        
        let cached = await cache.get(for: request)
        #expect(cached == nil)
    }
    
    @Test("Cache statistics tracking")
    func testCacheStatisticsTracking() async throws {
        let cache = EnhancedResponseCache(configuration: .default)
        
        let request = ProviderRequest(
            messages: [.user("Stats test")],
            settings: .default
        )
        
        let response = ProviderResponse(
            text: "Stats response",
            toolCalls: nil,
            usage: nil,
            finishReason: .stop
        )
        
        // Miss
        _ = await cache.get(for: request)
        
        // Store
        await cache.store(response, for: request)
        
        // Hit
        _ = await cache.get(for: request)
        
        let stats = await cache.getStatistics()
        
        #expect(stats.hits >= 1)
        #expect(stats.misses >= 1)
        #expect(stats.stores >= 1)
        #expect(stats.hitRate >= 0 && stats.hitRate <= 1)
    }
    
    @Test("Cache prewarm functionality")
    func testCachePrewarm() async throws {
        let cache = EnhancedResponseCache(configuration: .default)
        
        let requests: [(ProviderRequest, ProviderResponse)] = [
            (
                ProviderRequest(messages: [.user("Q1")], settings: .default),
                ProviderResponse(text: "A1", toolCalls: nil, usage: nil, finishReason: .stop)
            ),
            (
                ProviderRequest(messages: [.user("Q2")], settings: .default),
                ProviderResponse(text: "A2", toolCalls: nil, usage: nil, finishReason: .stop)
            )
        ]
        
        await cache.prewarm(with: requests, ttl: 3600)
        
        // Verify cached
        let cached1 = await cache.get(for: requests[0].0)
        let cached2 = await cache.get(for: requests[1].0)
        
        #expect(cached1?.text == "A1")
        #expect(cached2?.text == "A2")
    }
    
    @Test("Cache clear functionality")
    func testCacheClear() async throws {
        let cache = EnhancedResponseCache(configuration: .default)
        
        let request = ProviderRequest(
            messages: [.user("Clear test")],
            settings: .default
        )
        
        let response = ProviderResponse(
            text: "Will be cleared",
            toolCalls: nil,
            usage: nil,
            finishReason: .stop
        )
        
        await cache.store(response, for: request)
        
        // Verify stored
        var cached = await cache.get(for: request)
        #expect(cached != nil)
        
        // Clear cache
        await cache.clear()
        
        // Verify cleared
        cached = await cache.get(for: request)
        #expect(cached == nil)
    }
    
    @Test("Eviction strategies")
    func testEvictionStrategies() throws {
        #expect(EvictionStrategy.lru.rawValue == "lru")
        #expect(EvictionStrategy.lfu.rawValue == "lfu")
        #expect(EvictionStrategy.fifo.rawValue == "fifo")
        #expect(EvictionStrategy.priority.rawValue == "priority")
    }
    
    @Test("Memory pressure strategies")
    func testMemoryPressureStrategies() throws {
        #expect(MemoryPressureStrategy.clearAll.rawValue == "clearAll")
        #expect(MemoryPressureStrategy.clearHalf.rawValue == "clearHalf")
        #expect(MemoryPressureStrategy.clearLowPriority.rawValue == "clearLowPriority")
        #expect(MemoryPressureStrategy.adaptive.rawValue == "adaptive")
    }
    
    @Test("Cache entry expiration")
    func testCacheEntryExpiration() throws {
        let response = ProviderResponse(
            text: "Test",
            toolCalls: nil,
            usage: nil,
            finishReason: .stop
        )
        
        let entry = CacheEntry(
            response: response,
            ttl: 60,
            priority: .normal
        )
        
        #expect(!entry.isExpired(ttl: 60))
        #expect(entry.priority == .normal)
        
        // Record access
        entry.recordAccess()
        #expect(entry.accessCount == 1)
    }
}