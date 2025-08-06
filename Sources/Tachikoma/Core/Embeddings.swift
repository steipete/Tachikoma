//
//  Embeddings.swift
//  Tachikoma
//

import Foundation

// MARK: - Embeddings API

/// Generate embeddings for text or batch of texts
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func generateEmbedding(
    model: EmbeddingModel,
    input: EmbeddingInput,
    settings: EmbeddingSettings = .default,
    configuration: TachikomaConfiguration = TachikomaConfiguration()
) async throws -> EmbeddingResult {
    let provider = try EmbeddingProviderFactory.createProvider(for: model, configuration: configuration)
    
    let request = EmbeddingRequest(
        input: input,
        settings: settings
    )
    
    let response = try await provider.generateEmbedding(request: request)
    
    // Track usage
    let sessionId = "embedding-\(UUID().uuidString)"
    _ = UsageTracker.shared.startSession(sessionId)
    
    if let usage = response.usage {
        UsageTracker.shared.recordUsage(
            sessionId: sessionId,
            model: model.toLanguageModel(),
            usage: usage,
            operation: .embedding
        )
    }
    
    _ = UsageTracker.shared.endSession(sessionId)
    
    return response
}

/// Batch generate embeddings with concurrency control
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func generateEmbeddingsBatch(
    model: EmbeddingModel,
    inputs: [EmbeddingInput],
    settings: EmbeddingSettings = .default,
    concurrency: Int = 5,
    configuration: TachikomaConfiguration = TachikomaConfiguration()
) async throws -> [EmbeddingResult] {
    let provider = try EmbeddingProviderFactory.createProvider(for: model, configuration: configuration)
    
    // Use TaskGroup for controlled concurrency
    return try await withThrowingTaskGroup(of: (Int, EmbeddingResult).self) { group in
        // Limit concurrent requests
        let semaphore = EmbeddingAsyncSemaphore(value: concurrency)
        
        for (index, input) in inputs.enumerated() {
            group.addTask {
                await semaphore.wait()
                defer { Task { await semaphore.signal() } }
                
                let request = EmbeddingRequest(input: input, settings: settings)
                let result = try await provider.generateEmbedding(request: request)
                return (index, result)
            }
        }
        
        // Collect results in order
        var results: [(Int, EmbeddingResult)] = []
        for try await result in group {
            results.append(result)
        }
        
        // Sort by index and extract results
        return results.sorted { $0.0 < $1.0 }.map { $0.1 }
    }
}

// MARK: - Embedding Types

/// Embedding model selection
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum EmbeddingModel: Sendable {
    case openai(OpenAIEmbedding)
    case cohere(CohereEmbedding)
    case voyage(VoyageEmbedding)
    case custom(String)
    
    public enum OpenAIEmbedding: String, Sendable, CaseIterable {
        case ada002 = "text-embedding-ada-002"
        case small3 = "text-embedding-3-small"
        case large3 = "text-embedding-3-large"
    }
    
    public enum CohereEmbedding: String, Sendable, CaseIterable {
        case english3 = "embed-english-v3.0"
        case multilingual3 = "embed-multilingual-v3.0"
        case englishLight3 = "embed-english-light-v3.0"
        case multilingualLight3 = "embed-multilingual-light-v3.0"
    }
    
    public enum VoyageEmbedding: String, Sendable, CaseIterable {
        case voyage2 = "voyage-2"
        case voyage2Code = "voyage-code-2"
        case voyage2Large = "voyage-large-2"
    }
    
    /// Convert to LanguageModel for usage tracking
    func toLanguageModel() -> LanguageModel {
        switch self {
        case .openai:
            return .openai(.gpt4o) // Placeholder for tracking
        case .cohere, .voyage, .custom:
            // Return a dummy model for tracking purposes
            return .openai(.gpt4o)
        }
    }
}

/// Input for embedding generation
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum EmbeddingInput: Sendable {
    case text(String)
    case texts([String])
    case tokens([Int])
    
    var asTexts: [String] {
        switch self {
        case .text(let string):
            return [string]
        case .texts(let strings):
            return strings
        case .tokens:
            return [] // Provider will handle token conversion
        }
    }
}

/// Settings for embedding generation
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct EmbeddingSettings: Sendable, Codable {
    public let dimensions: Int?
    public let normalizeEmbeddings: Bool
    public let truncate: TruncationStrategy?
    
    public enum TruncationStrategy: String, Sendable, Codable {
        case start
        case end
        case none
    }
    
    public init(
        dimensions: Int? = nil,
        normalizeEmbeddings: Bool = true,
        truncate: TruncationStrategy? = nil
    ) {
        self.dimensions = dimensions
        self.normalizeEmbeddings = normalizeEmbeddings
        self.truncate = truncate
    }
    
    public static let `default` = EmbeddingSettings()
}

/// Result from embedding generation
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct EmbeddingResult: Sendable {
    public let embeddings: [[Double]]
    public let model: String
    public let usage: Usage?
    public let metadata: EmbeddingMetadata?
    
    public init(
        embeddings: [[Double]],
        model: String,
        usage: Usage? = nil,
        metadata: EmbeddingMetadata? = nil
    ) {
        self.embeddings = embeddings
        self.model = model
        self.usage = usage
        self.metadata = metadata
    }
    
    /// Get first embedding (convenience for single text input)
    public var embedding: [Double]? {
        embeddings.first
    }
    
    /// Number of dimensions in embeddings
    public var dimensions: Int? {
        embeddings.first?.count
    }
}

/// Metadata for embedding results
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct EmbeddingMetadata: Sendable, Codable {
    public let truncated: Bool
    public let normalizedL2: Bool
    
    public init(truncated: Bool = false, normalizedL2: Bool = false) {
        self.truncated = truncated
        self.normalizedL2 = normalizedL2
    }
}

// MARK: - Provider Protocol

/// Protocol for embedding providers
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
protocol EmbeddingProvider: Sendable {
    func generateEmbedding(request: EmbeddingRequest) async throws -> EmbeddingResult
}

/// Request for embedding generation
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
struct EmbeddingRequest: Sendable {
    let input: EmbeddingInput
    let settings: EmbeddingSettings
}

// MARK: - Provider Factory

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
struct EmbeddingProviderFactory {
    static func createProvider(
        for model: EmbeddingModel,
        configuration: TachikomaConfiguration
    ) throws -> EmbeddingProvider {
        switch model {
        case .openai(let openAIModel):
            return OpenAIEmbeddingProvider(
                model: openAIModel,
                apiKey: configuration.getAPIKey(for: "openai"),
                baseURL: configuration.getBaseURL(for: "openai")
            )
        case .cohere(let cohereModel):
            return CohereEmbeddingProvider(
                model: cohereModel,
                apiKey: configuration.getAPIKey(for: "cohere") ?? ProcessInfo.processInfo.environment["COHERE_API_KEY"]
            )
        case .voyage(let voyageModel):
            return VoyageEmbeddingProvider(
                model: voyageModel,
                apiKey: configuration.getAPIKey(for: "voyage") ?? ProcessInfo.processInfo.environment["VOYAGE_API_KEY"]
            )
        case .custom(let modelId):
            throw TachikomaError.unsupportedOperation("Custom embedding model '\(modelId)' not implemented")
        }
    }
}

// MARK: - Async Semaphore Helper

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
private actor EmbeddingAsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        if value > 0 {
            value -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }
    
    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}