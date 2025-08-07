//
//  TestProviderFactory.swift
//  TachikomaTests
//

import Foundation
@testable import Tachikoma

/// Test-specific provider factory that can use mock providers
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct TestProviderFactory {
    /// Create a provider for testing, using mock when appropriate
    public static func createProvider(for model: LanguageModel, configuration: TachikomaConfiguration) throws -> any ModelProvider {
        // Check if we should use mock providers
        if ProcessInfo.processInfo.environment["TACHIKOMA_DISABLE_API_TESTS"] == "true" ||
           ProcessInfo.processInfo.environment["TACHIKOMA_TEST_MODE"] == "mock" ||
           configuration.getAPIKey(for: model.providerName)?.starts(with: "test-") == true ||
           configuration.getAPIKey(for: model.providerName) == "mock-api-key" {
            
            // Even in mock mode, validate API keys if explicitly testing missing key scenarios
            let providerName = model.providerName.lowercased()
            if !configuration.hasAPIKey(for: providerName) {
                throw TachikomaError.authenticationFailed("\(providerName.uppercased())_API_KEY not found")
            }
            
            return MockProvider(model: model)
        }
        
        // Otherwise use the real provider factory
        return try ProviderFactory.createProvider(for: model, configuration: configuration)
    }
}