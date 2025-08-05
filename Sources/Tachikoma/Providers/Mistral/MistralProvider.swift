//
//  MistralProvider.swift
//  Tachikoma
//

import Foundation

/// Provider for Mistral models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class MistralProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    private let model: LanguageModel.Mistral

    public init(model: LanguageModel.Mistral, configuration: TachikomaConfiguration) throws {
        self.model = model
        self.modelId = model.rawValue
        self.baseURL = configuration.getBaseURL(for: .mistral) ?? "https://api.mistral.ai/v1"

        if let key = configuration.getAPIKey(for: .mistral) {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("MISTRAL_API_KEY not found")
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
        throw TachikomaError.unsupportedOperation("Mistral provider not yet implemented")
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Mistral streaming not yet implemented")
    }
}