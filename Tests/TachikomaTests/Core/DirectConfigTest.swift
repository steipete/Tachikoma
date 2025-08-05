//
//  DirectConfigTest.swift
//  TachikomaTests
//

import Foundation
import Testing
@testable import Tachikoma

@Suite("Direct Configuration Tests")
struct DirectConfigTests {
    
    @Test("Direct configuration access")
    func directConfigAccess() {
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        
        // Just test basic access without test helpers
        _ = config.configuredProviders
        
        #expect(true) // If we get here, no infinite loop
    }
    
    @Test("Provider enum direct access")  
    func providerEnumDirect() {
        let provider = Provider.openai
        #expect(provider.identifier == "openai")
        #expect(provider.displayName == "OpenAI")
    }
    
    @Test("Configuration instance creation")
    func configurationInstanceCreation() {
        let config1 = TachikomaConfiguration()
        let config2 = TachikomaConfiguration(loadFromEnvironment: false)
        let config3 = TachikomaConfiguration(apiKeys: ["openai": "test"])
        
        // All should be valid instances
        #expect(config1.configuredProviders.count >= 0)
        #expect(config2.configuredProviders.isEmpty)
        #expect(config3.hasAPIKey(for: .openai))
    }
}