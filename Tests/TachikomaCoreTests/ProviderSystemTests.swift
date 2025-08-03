import Foundation
import Testing
@testable import TachikomaCore

@Suite("Provider System Tests")
struct ProviderSystemTests {
    
    // MARK: - Provider Factory Tests
    
    @Test("Provider Factory - OpenAI Provider Creation")
    func providerFactoryOpenAI() async throws {
        // Mock API key for testing
        setenv("OPENAI_API_KEY", "test-key", 1)
        defer { unsetenv("OPENAI_API_KEY") }
        
        let model = Model.openai(.gpt4o)
        let provider = try ProviderFactory.createProvider(for: model)
        
        #expect(provider.modelId == "gpt-4o")
        #expect(provider.capabilities.supportsVision == true)
        #expect(provider.capabilities.supportsTools == true)
        #expect(provider.capabilities.supportsStreaming == true)
    }
    
    @Test("Provider Factory - Anthropic Provider Creation")
    func providerFactoryAnthropic() async throws {
        // Mock API key for testing
        setenv("ANTHROPIC_API_KEY", "test-key", 1)
        defer { unsetenv("ANTHROPIC_API_KEY") }
        
        let model = Model.anthropic(.opus4)
        let provider = try ProviderFactory.createProvider(for: model)
        
        #expect(provider.modelId == "claude-opus-4-20250514")
        #expect(provider.capabilities.supportsVision == true)
        #expect(provider.capabilities.supportsTools == true)
        #expect(provider.capabilities.supportsStreaming == true)
    }
    
    @Test("Provider Factory - Grok Provider Creation")
    func providerFactoryGrok() async throws {
        // Mock API key for testing
        setenv("X_AI_API_KEY", "test-key", 1)
        defer { unsetenv("X_AI_API_KEY") }
        
        let model = Model.grok(.grok4)
        let provider = try ProviderFactory.createProvider(for: model)
        
        #expect(provider.modelId == "grok-4")
        #expect(provider.capabilities.supportsTools == true)
        #expect(provider.capabilities.supportsStreaming == true)
    }
    
    @Test("Provider Factory - Ollama Provider Creation") 
    func providerFactoryOllama() async throws {
        // No API key needed for Ollama
        let model = Model.ollama(.llama33)
        let provider = try ProviderFactory.createProvider(for: model)
        
        #expect(provider.modelId == "llama3.3")
        #expect(provider.capabilities.supportsTools == true)
        #expect(provider.capabilities.supportsStreaming == true)
    }
    
    @Test("Provider Factory - Missing API Key Error")
    func providerFactoryMissingAPIKey() async throws {
        // Ensure no API key is set
        unsetenv("OPENAI_API_KEY")
        
        let model = Model.openai(.gpt4o)
        
        #expect(throws: TachikomaError.self) {
            try ProviderFactory.createProvider(for: model)
        }
    }
    
    // MARK: - Model Capabilities Tests
    
    @Test("Model Capabilities - Vision Support")
    func modelCapabilitiesVision() {
        #expect(Model.openai(.gpt4o).supportsVision == true)
        #expect(Model.openai(.gpt4oMini).supportsVision == true)
        #expect(Model.openai(.gpt41).supportsVision == false)
        
        #expect(Model.anthropic(.opus4).supportsVision == true)
        #expect(Model.anthropic(.sonnet4).supportsVision == true)
        
        #expect(Model.grok(.grok2Vision).supportsVision == true)
        #expect(Model.grok(.grok4).supportsVision == false)
        
        #expect(Model.ollama(.llava).supportsVision == true)
        #expect(Model.ollama(.llama33).supportsVision == false)
    }
    
    @Test("Model Capabilities - Tool Support")
    func modelCapabilitiesTools() {
        #expect(Model.openai(.gpt4o).supportsTools == true)
        #expect(Model.openai(.gpt41).supportsTools == true)
        
        #expect(Model.anthropic(.opus4).supportsTools == true)
        #expect(Model.anthropic(.sonnet4).supportsTools == true)
        
        #expect(Model.grok(.grok4).supportsTools == true)
        
        #expect(Model.ollama(.llama33).supportsTools == true)
        #expect(Model.ollama(.llava).supportsTools == false) // Vision models don't support tools
    }
    
    @Test("Model Capabilities - Streaming Support")
    func modelCapabilitiesStreaming() {
        #expect(Model.openai(.gpt4o).supportsStreaming == true)
        #expect(Model.anthropic(.opus4).supportsStreaming == true)
        #expect(Model.grok(.grok4).supportsStreaming == true)
        #expect(Model.ollama(.llama33).supportsStreaming == true)
    }
    
    // MARK: - Generation Request Tests
    
    @Test("Generation Request Basic Creation")
    func generationRequestBasic() {
        let request = GenerationRequest(
            prompt: "Hello world",
            system: "You are helpful",
            tools: nil,
            maxTokens: 100,
            temperature: 0.7
        )
        
        #expect(request.prompt == "Hello world")
        #expect(request.system == "You are helpful")
        #expect(request.tools == nil)
        #expect(request.maxTokens == 100)
        #expect(request.temperature == 0.7)
        #expect(request.images == nil)
    }
    
    @Test("Generation Request With Images")
    func generationRequestWithImages() {
        let request = GenerationRequest(
            prompt: "Describe this image",
            images: [.base64("test-base64-data")]
        )
        
        #expect(request.prompt == "Describe this image")
        #expect(request.images?.count == 1)
        
        if case let .base64(data) = request.images?[0] {
            #expect(data == "test-base64-data")
        } else {
            Issue.record("Expected base64 image input")
        }
    }
    
    // MARK: - Stream Token Tests
    
    @Test("Stream Token Types")
    func streamTokenTypes() {
        let textToken = StreamToken(delta: "hello", type: .textDelta)
        #expect(textToken.delta == "hello")
        #expect(textToken.type == .textDelta)
        
        let completeToken = StreamToken(delta: nil, type: .complete)
        #expect(completeToken.delta == nil)
        #expect(completeToken.type == .complete)
        
        let errorToken = StreamToken(delta: nil, type: .error)
        #expect(errorToken.type == .error)
        
        let toolToken = StreamToken(delta: nil, type: .toolCall)
        #expect(toolToken.type == .toolCall)
    }
    
    // MARK: - Usage Statistics Tests
    
    @Test("Usage Statistics")
    func usageStatistics() {
        let usage = Usage(inputTokens: 100, outputTokens: 50)
        
        #expect(usage.inputTokens == 100)
        #expect(usage.outputTokens == 50)
        #expect(usage.totalTokens == 150)
    }
    
    // MARK: - Finish Reason Tests
    
    @Test("Finish Reason Cases")
    func finishReasonCases() {
        #expect(FinishReason.stop.rawValue == "stop")
        #expect(FinishReason.length.rawValue == "length")
        #expect(FinishReason.toolCalls.rawValue == "tool_calls")
        #expect(FinishReason.contentFilter.rawValue == "content_filter")
        #expect(FinishReason.other.rawValue == "other")
    }
}