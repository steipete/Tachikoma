//
//  ReplicateProvider.swift
//  Tachikoma
//

import Foundation

/// Provider for Replicate models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class ReplicateProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    public init(modelId: String) throws {
        self.modelId = modelId
        self.baseURL = "https://api.replicate.com/v1"

        if let key = ProcessInfo.processInfo.environment["REPLICATE_API_TOKEN"] {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("REPLICATE_API_TOKEN not found")
        }

        self.capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTools: false, // Most Replicate models don't support tools
            supportsStreaming: true,
            contextLength: 32_000,
            maxOutputTokens: 4096
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Replicate provider not yet implemented")
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Replicate streaming not yet implemented")
    }
}