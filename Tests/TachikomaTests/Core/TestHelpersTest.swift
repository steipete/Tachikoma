//
//  TestHelpersTest.swift
//  TachikomaTests
//

import Foundation
import Testing
@testable import Tachikoma

@Suite("Test Helpers Tests")
struct TestHelpersTests {
    
    @Test("Test helper create configuration")
    func testHelperCreateConfiguration() {
        let config = TestHelpers.createTestConfiguration(apiKeys: ["openai": "test-key"])
        
        #expect(config.getAPIKey(for: .openai) == "test-key")
        #expect(config.hasConfiguredAPIKey(for: .openai))
    }
    
    @Test("Test helper with empty configuration")
    func testHelperEmptyConfiguration() async {
        let result = await TestHelpers.withEmptyTestConfiguration { config in
            return config.getAPIKey(for: .openai)
        }
        
        // Should be nil in empty configuration
        #expect(result == nil)
    }
    
    @Test("Test helper with standard test configuration")
    func testHelperStandardConfiguration() async {
        let result = await TestHelpers.withStandardTestConfiguration { config in
            return config.getAPIKey(for: .openai)
        }
        
        // Should have standard test key
        #expect(result == "test-key")
    }
    
    @Test("Test helper with selective configuration")
    func testHelperSelectiveConfiguration() async {
        let result = await TestHelpers.withSelectiveTestConfiguration(present: ["openai"]) { config in
            return (config.getAPIKey(for: .openai), config.getAPIKey(for: .anthropic))
        }
        
        // Should have OpenAI key but not Anthropic
        #expect(result.0 == "test-key")
        #expect(result.1 == nil)
    }
}