//
//  ProviderFeatureParity.swift
//  Tachikoma
//

import Foundation

// MARK: - Enhanced Provider Protocol

/// Enhanced provider protocol with full feature support
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol EnhancedModelProvider: ModelProvider {
    /// Generate text with full feature support
    func generateText(request: ProviderRequest) async throws -> ProviderResponse
    
    /// Stream text with proper backpressure handling
    func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error>
    
    /// Validate and transform messages for provider-specific requirements
    func validateMessages(_ messages: [ModelMessage]) throws -> [ModelMessage]
    
    /// Check if a specific feature is supported
    func isFeatureSupported(_ feature: ProviderFeature) -> Bool
    
    /// Get provider-specific configuration
    var configuration: ProviderConfiguration { get }
}

// MARK: - Provider Features

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum ProviderFeature: String, Sendable, CaseIterable {
    case streaming
    case toolCalling
    case systemMessages
    case visionInputs
    case multiModal
    case jsonMode
    case functionCalling
    case parallelToolCalls
    case contextCaching
    case longContext
}

// MARK: - Provider Configuration

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ProviderConfiguration: Sendable {
    public let maxTokens: Int
    public let maxContextLength: Int
    public let supportedImageFormats: [String]
    public let maxImageSize: Int?
    public let maxToolCalls: Int
    public let supportsSystemRole: Bool
    public let requiresAlternatingRoles: Bool
    public let customHeaders: [String: String]
    
    public init(
        maxTokens: Int = 4096,
        maxContextLength: Int = 128000,
        supportedImageFormats: [String] = ["jpeg", "png", "gif", "webp"],
        maxImageSize: Int? = 20 * 1024 * 1024, // 20MB
        maxToolCalls: Int = 10,
        supportsSystemRole: Bool = true,
        requiresAlternatingRoles: Bool = false,
        customHeaders: [String: String] = [:]
    ) {
        self.maxTokens = maxTokens
        self.maxContextLength = maxContextLength
        self.supportedImageFormats = supportedImageFormats
        self.maxImageSize = maxImageSize
        self.maxToolCalls = maxToolCalls
        self.supportsSystemRole = supportsSystemRole
        self.requiresAlternatingRoles = requiresAlternatingRoles
        self.customHeaders = customHeaders
    }
    
    // Common configurations for providers
    public static let openAI = ProviderConfiguration(
        maxTokens: 4096,
        maxContextLength: 128000,
        supportsSystemRole: true
    )
    
    public static let anthropic = ProviderConfiguration(
        maxTokens: 4096,
        maxContextLength: 200000,
        supportsSystemRole: true,
        requiresAlternatingRoles: true
    )
    
    public static let google = ProviderConfiguration(
        maxTokens: 8192,
        maxContextLength: 1048576, // 1M tokens for Gemini 1.5
        supportsSystemRole: false, // Uses "user" role for system
        requiresAlternatingRoles: true
    )
    
    public static let ollama = ProviderConfiguration(
        maxTokens: 2048,
        maxContextLength: 32000,
        maxToolCalls: 0, // No tool support by default
        supportsSystemRole: true
    )
}

// MARK: - Provider Adapter

/// Base adapter that ensures feature parity across all providers
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public class ProviderAdapter: EnhancedModelProvider {
    private let baseProvider: ModelProvider
    public let configuration: ProviderConfiguration
    
    public var modelId: String { baseProvider.modelId }
    public var baseURL: String? { baseProvider.baseURL }
    public var apiKey: String? { baseProvider.apiKey }
    public var capabilities: ModelCapabilities { baseProvider.capabilities }
    
    public init(provider: ModelProvider, configuration: ProviderConfiguration) {
        self.baseProvider = provider
        self.configuration = configuration
    }
    
    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        let validatedRequest = try validateRequest(request)
        return try await baseProvider.generateText(request: validatedRequest)
    }
    
    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        // Check if streaming is supported
        guard capabilities.supportsStreaming else {
            // Fallback to non-streaming and simulate stream
            return simulateStream(from: request)
        }
        
        let validatedRequest = try validateRequest(request)
        return try await baseProvider.streamText(request: validatedRequest)
    }
    
    public func validateMessages(_ messages: [ModelMessage]) throws -> [ModelMessage] {
        var validated = messages
        
        // Handle system messages if not supported
        if !configuration.supportsSystemRole {
            validated = transformSystemMessages(messages)
        }
        
        // Ensure alternating roles if required
        if configuration.requiresAlternatingRoles {
            validated = ensureAlternatingRoles(validated)
        }
        
        // Validate vision inputs
        validated = try validateVisionInputs(validated)
        
        return validated
    }
    
    public func isFeatureSupported(_ feature: ProviderFeature) -> Bool {
        switch feature {
        case .streaming:
            return capabilities.supportsStreaming
        case .toolCalling, .functionCalling:
            return capabilities.supportsTools
        case .systemMessages:
            return configuration.supportsSystemRole
        case .visionInputs, .multiModal:
            return capabilities.supportsVision
        case .parallelToolCalls:
            return capabilities.supportsTools && configuration.maxToolCalls > 1
        case .jsonMode:
            return capabilities.supportsJsonMode ?? false
        case .contextCaching:
            return false // Most providers don't support this yet
        case .longContext:
            return configuration.maxContextLength > 100000
        }
    }
    
    // MARK: - Private Helpers
    
    private func validateRequest(_ request: ProviderRequest) throws -> ProviderRequest {
        var validated = request
        
        // Validate messages
        validated.messages = try validateMessages(request.messages)
        
        // Validate tools
        if let tools = request.tools, !tools.isEmpty {
            guard capabilities.supportsTools else {
                throw TachikomaError.unsupportedOperation("This model doesn't support tool calling")
            }
            
            if tools.count > configuration.maxToolCalls {
                // Truncate to max allowed
                validated.tools = Array(tools.prefix(configuration.maxToolCalls))
            }
        }
        
        // Apply token limits
        if let settings = validated.settings {
            var updatedSettings = settings
            if let maxTokens = settings.maxTokens, maxTokens > configuration.maxTokens {
                updatedSettings.maxTokens = configuration.maxTokens
            }
            validated.settings = updatedSettings
        }
        
        return validated
    }
    
    private func transformSystemMessages(_ messages: [ModelMessage]) -> [ModelMessage] {
        return messages.map { message in
            if message.role == .system {
                // Convert system message to user message with prefix
                var content = message.content
                if case .text(let text) = content.first {
                    content = [.text("System: \(text)")]
                }
                return ModelMessage(role: .user, content: content)
            }
            return message
        }
    }
    
    private func ensureAlternatingRoles(_ messages: [ModelMessage]) -> [ModelMessage] {
        var result: [ModelMessage] = []
        var lastRole: ModelMessage.Role?
        
        for message in messages {
            // Skip consecutive same roles by merging content
            if let last = lastRole, last == message.role, !result.isEmpty {
                var lastMessage = result.removeLast()
                lastMessage.content.append(contentsOf: message.content)
                result.append(lastMessage)
            } else {
                result.append(message)
                lastRole = message.role
            }
        }
        
        return result
    }
    
    private func validateVisionInputs(_ messages: [ModelMessage]) throws -> [ModelMessage] {
        guard capabilities.supportsVision else {
            // Strip image content if not supported
            return messages.map { message in
                let filteredContent = message.content.compactMap { part -> ModelMessage.ContentPart? in
                    if case .image = part {
                        return nil // Remove image parts
                    }
                    return part
                }
                return ModelMessage(role: message.role, content: filteredContent)
            }
        }
        
        // Validate image formats and sizes
        return try messages.map { message in
            let validatedContent = try message.content.map { part -> ModelMessage.ContentPart in
                if case .image(let url) = part {
                    try validateImageURL(url)
                }
                return part
            }
            return ModelMessage(role: message.role, content: validatedContent)
        }
    }
    
    private func validateImageURL(_ url: String) throws {
        if url.starts(with: "data:") {
            // Validate data URL
            let components = url.split(separator: ",", maxSplits: 1)
            guard components.count == 2 else {
                throw TachikomaError.invalidInput("Invalid image data URL")
            }
            
            let metadata = String(components[0])
            let format = metadata
                .replacingOccurrences(of: "data:image/", with: "")
                .replacingOccurrences(of: ";base64", with: "")
            
            guard configuration.supportedImageFormats.contains(format) else {
                throw TachikomaError.invalidInput("Unsupported image format: \(format)")
            }
            
            // Check size if configured
            if let maxSize = configuration.maxImageSize {
                let base64Data = String(components[1])
                let dataSize = base64Data.count * 3 / 4 // Approximate decoded size
                guard dataSize <= maxSize else {
                    throw TachikomaError.invalidInput("Image size exceeds limit: \(dataSize) > \(maxSize)")
                }
            }
        }
    }
    
    private func simulateStream(from request: ProviderRequest) -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await self.generateText(request: request)
                    
                    // Simulate streaming by chunking the response
                    let chunks = response.text.split(by: 20) // Split into word chunks
                    for chunk in chunks {
                        continuation.yield(.text(chunk))
                        try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
                    }
                    
                    if let usage = response.usage {
                        continuation.yield(.usage(usage))
                    }
                    
                    continuation.yield(.finish(response.finishReason ?? .stop))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - String Extension for Chunking

private extension String {
    func split(by wordCount: Int) -> [String] {
        let words = self.split(separator: " ")
        var chunks: [String] = []
        
        for i in stride(from: 0, to: words.count, by: wordCount) {
            let endIndex = min(i + wordCount, words.count)
            let chunk = words[i..<endIndex].joined(separator: " ")
            if !chunk.isEmpty {
                chunks.append(chunk + (endIndex < words.count ? " " : ""))
            }
        }
        
        return chunks
    }
}

// MARK: - Provider Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension ModelProvider {
    /// Wrap any provider with feature parity adapter
    func withFeatureParity(configuration: ProviderConfiguration? = nil) -> EnhancedModelProvider {
        if let enhanced = self as? EnhancedModelProvider {
            return enhanced
        }
        
        // Auto-detect configuration based on provider type
        let config = configuration ?? detectConfiguration()
        return ProviderAdapter(provider: self, configuration: config)
    }
    
    private func detectConfiguration() -> ProviderConfiguration {
        // Try to detect provider type from model ID or base URL
        let modelLower = modelId.lowercased()
        let urlLower = baseURL?.lowercased() ?? ""
        
        if modelLower.contains("gpt") || urlLower.contains("openai") {
            return .openAI
        } else if modelLower.contains("claude") || urlLower.contains("anthropic") {
            return .anthropic
        } else if modelLower.contains("gemini") || urlLower.contains("google") {
            return .google
        } else if urlLower.contains("localhost") || urlLower.contains("ollama") {
            return .ollama
        }
        
        // Default configuration
        return ProviderConfiguration()
    }
}