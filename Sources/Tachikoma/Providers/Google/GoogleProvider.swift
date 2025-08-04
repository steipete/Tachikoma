//
//  GoogleProvider.swift
//  Tachikoma
//

import Foundation

/// Provider for Google Gemini models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class GoogleProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    private let model: LanguageModel.Google

    public init(model: LanguageModel.Google) throws {
        self.model = model
        self.modelId = model.rawValue
        self.baseURL = "https://generativelanguage.googleapis.com/v1beta"

        if let key = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("GOOGLE_API_KEY not found")
        }

        self.capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            contextLength: model.contextLength,
            maxOutputTokens: 8192
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Google provider not yet implemented")
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Google streaming not yet implemented")
    }
}