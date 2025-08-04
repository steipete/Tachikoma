//
//  OpenRouterProvider.swift
//  Tachikoma
//

import Foundation

/// Provider for OpenRouter models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class OpenRouterProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    public init(modelId: String) throws {
        self.modelId = modelId
        self.baseURL = "https://openrouter.ai/api/v1"

        if let key = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("OPENROUTER_API_KEY not found")
        }

        self.capabilities = ModelCapabilities(
            supportsVision: false, // Unknown, assume no vision
            supportsTools: true,
            supportsStreaming: true,
            contextLength: 128_000,
            maxOutputTokens: 4096
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("OpenRouter provider not yet implemented")
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("OpenRouter streaming not yet implemented")
    }
}