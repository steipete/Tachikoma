import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct OpenAIEmbeddingProvider: EmbeddingProvider, ModelProvider {
    let model: EmbeddingModel.OpenAIEmbedding
    let apiKey: String?
    let baseURL: String?

    var modelId: String { self.model.rawValue }
    var capabilities: ModelCapabilities { ModelCapabilities() }

    // ModelProvider conformance (not used for embeddings)
    func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Text generation not supported for embedding models")
    }

    func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Streaming not supported for embedding models")
    }

    /// Call OpenAI's embeddings endpoint and translate the response into Tachikoma's embedding result.
    func generateEmbedding(request: EmbeddingRequest) async throws -> EmbeddingResult {
        guard let apiKey else {
            throw TachikomaError.authenticationFailed("OpenAI API key not configured")
        }

        let url = URL(string: "\(baseURL ?? "https://api.openai.com/v1")/embeddings")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build request body
        var body: [String: Any] = [
            "model": model.rawValue,
            "input": request.input.asTexts,
        ]

        if let dimensions = request.settings.dimensions {
            body["dimensions"] = dimensions
        }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TachikomaError.apiError("OpenAI Embedding Error (HTTP \(httpResponse.statusCode)): \(errorText)")
        }

        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        guard let dataArray = json["data"] as? [[String: Any]] else {
            throw TachikomaError.apiError("Invalid response format from OpenAI")
        }

        let embeddings = dataArray.compactMap { item -> [Double]? in
            item["embedding"] as? [Double]
        }

        // Parse usage
        var usage: Usage?
        if
            let usageDict = json["usage"] as? [String: Any],
            let promptTokens = usageDict["prompt_tokens"] as? Int,
            usageDict["total_tokens"] != nil
        {
            usage = Usage(inputTokens: promptTokens, outputTokens: 0)
        }

        return EmbeddingResult(
            embeddings: embeddings,
            model: self.model.rawValue,
            usage: usage,
            metadata: EmbeddingMetadata(
                truncated: false,
                normalizedL2: request.settings.normalizeEmbeddings,
            ),
        )
    }
}

// Placeholder providers for other services
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct CohereEmbeddingProvider: EmbeddingProvider, ModelProvider {
    let model: EmbeddingModel.CohereEmbedding
    let apiKey: String?

    var modelId: String { self.model.rawValue }
    var baseURL: String? { nil }
    var capabilities: ModelCapabilities { ModelCapabilities() }

    // ModelProvider conformance (not used for embeddings)
    func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Text generation not supported for embedding models")
    }

    func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Streaming not supported for embedding models")
    }

    func generateEmbedding(request _: EmbeddingRequest) async throws -> EmbeddingResult {
        throw TachikomaError.unsupportedOperation("Cohere embeddings not yet implemented")
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct VoyageEmbeddingProvider: EmbeddingProvider, ModelProvider {
    let model: EmbeddingModel.VoyageEmbedding
    let apiKey: String?

    var modelId: String { self.model.rawValue }
    var baseURL: String? { nil }
    var capabilities: ModelCapabilities { ModelCapabilities() }

    // ModelProvider conformance (not used for embeddings)
    func generateText(request _: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Text generation not supported for embedding models")
    }

    func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Streaming not supported for embedding models")
    }

    func generateEmbedding(request _: EmbeddingRequest) async throws -> EmbeddingResult {
        throw TachikomaError.unsupportedOperation("Voyage embeddings not yet implemented")
    }
}
