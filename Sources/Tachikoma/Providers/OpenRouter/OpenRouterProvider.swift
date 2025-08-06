//
//  OpenRouterProvider.swift
//  Tachikoma
//

import Foundation

/// Provider for OpenRouter models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class OpenRouterProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    public init(modelId: String, configuration: TachikomaConfiguration) throws {
        self.modelId = modelId
        self.baseURL = configuration.getBaseURL(for: .custom("openrouter")) ?? "https://openrouter.ai/api/v1"

        if let key = configuration.getAPIKey(for: .custom("openrouter")) {
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