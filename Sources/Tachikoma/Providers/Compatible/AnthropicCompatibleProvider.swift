//
//  AnthropicCompatibleProvider.swift
//  Tachikoma
//

import Foundation

/// Provider for Anthropic-compatible APIs
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class AnthropicCompatibleProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    public init(modelId: String, baseURL: String) throws {
        self.modelId = modelId
        self.baseURL = baseURL

        if
            let key = ProcessInfo.processInfo.environment["ANTHROPIC_COMPATIBLE_API_KEY"] ??
                ProcessInfo.processInfo.environment["API_KEY"]
        {
            self.apiKey = key
        } else {
            self.apiKey = nil
        }

        self.capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTools: true,
            supportsStreaming: true,
            contextLength: 200_000,
            maxOutputTokens: 8192
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Anthropic-compatible provider not yet implemented")
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Anthropic-compatible streaming not yet implemented")
    }
}