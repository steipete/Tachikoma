//
//  GrokProvider.swift
//  Tachikoma
//

import Foundation

/// Provider for Grok (xAI) models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class GrokProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    private let model: LanguageModel.Grok

    public init(model: LanguageModel.Grok) throws {
        self.model = model
        self.modelId = model.modelId
        self.baseURL = "https://api.x.ai/v1"

        // Get API key from configuration system (environment or credentials)
        if let key = TachikomaConfiguration.shared.getAPIKey(for: "grok") {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("X_AI_API_KEY or XAI_API_KEY not found")
        }

        self.capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            contextLength: model.contextLength,
            maxOutputTokens: 4096
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        // Grok uses OpenAI-compatible API format - delegate to shared implementation
        return try await OpenAICompatibleHelper.generateText(
            request: request,
            modelId: self.modelId,
            baseURL: self.baseURL!,
            apiKey: self.apiKey!,
            providerName: "Grok"
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        // Grok uses OpenAI-compatible API format - delegate to shared implementation
        return try await OpenAICompatibleHelper.streamText(
            request: request,
            modelId: self.modelId,
            baseURL: self.baseURL!,
            apiKey: self.apiKey!,
            providerName: "Grok"
        )
    }
}