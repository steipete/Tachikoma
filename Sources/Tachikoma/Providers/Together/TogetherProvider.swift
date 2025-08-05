//
//  TogetherProvider.swift
//  Tachikoma
//

import Foundation

/// Provider for Together AI models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class TogetherProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    public init(modelId: String, configuration: TachikomaConfiguration) throws {
        self.modelId = modelId
        self.baseURL = configuration.getBaseURL(for: .custom("together")) ?? "https://api.together.xyz/v1"

        if let key = configuration.getAPIKey(for: .custom("together")) {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("TOGETHER_API_KEY not found")
        }

        self.capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTools: true,
            supportsStreaming: true,
            contextLength: 128_000,
            maxOutputTokens: 4096
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Together provider not yet implemented")
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Together streaming not yet implemented")
    }
}