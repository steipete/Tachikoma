//
//  EmbeddingsAPITests.swift
//  Tachikoma
//

import Testing
@testable import Tachikoma

@Suite("Embeddings API")
struct EmbeddingsAPITests {
    
    @Test("EmbeddingModel enum cases")
    func testEmbeddingModelCases() {
        // OpenAI models
        let ada = EmbeddingModel.openai(.ada002)
        let small3 = EmbeddingModel.openai(.small3)
        let large3 = EmbeddingModel.openai(.large3)
        
        if case .openai(let model) = ada {
            #expect(model == .ada002)
        }
        if case .openai(let model) = small3 {
            #expect(model == .small3)
        }
        if case .openai(let model) = large3 {
            #expect(model == .large3)
        }
        
        // Cohere models
        let english = EmbeddingModel.cohere(.english3)
        let multilingual = EmbeddingModel.cohere(.multilingual3)
        
        if case .cohere(let model) = english {
            #expect(model == .english3)
        }
        if case .cohere(let model) = multilingual {
            #expect(model == .multilingual3)
        }
        
        // Voyage models
        let voyage2 = EmbeddingModel.voyage(.voyage2)
        let voyageCode = EmbeddingModel.voyage(.voyage2Code)
        
        if case .voyage(let model) = voyage2 {
            #expect(model == .voyage2)
        }
        if case .voyage(let model) = voyageCode {
            #expect(model == .voyage2Code)
        }
    }
    
    @Test("OpenAI embedding model raw values")
    func testOpenAIEmbeddingModelRawValues() {
        #expect(EmbeddingModel.OpenAIEmbedding.ada002.rawValue == "text-embedding-ada-002")
        #expect(EmbeddingModel.OpenAIEmbedding.small3.rawValue == "text-embedding-3-small")
        #expect(EmbeddingModel.OpenAIEmbedding.large3.rawValue == "text-embedding-3-large")
    }
    
    @Test("Cohere embedding model raw values")
    func testCohereEmbeddingModelRawValues() {
        #expect(EmbeddingModel.CohereEmbedding.english3.rawValue == "embed-english-v3.0")
        #expect(EmbeddingModel.CohereEmbedding.multilingual3.rawValue == "embed-multilingual-v3.0")
        #expect(EmbeddingModel.CohereEmbedding.englishLight3.rawValue == "embed-english-light-v3.0")
        #expect(EmbeddingModel.CohereEmbedding.multilingualLight3.rawValue == "embed-multilingual-light-v3.0")
    }
    
    @Test("Voyage embedding model raw values")
    func testVoyageEmbeddingModelRawValues() {
        #expect(EmbeddingModel.VoyageEmbedding.voyage2.rawValue == "voyage-2")
        #expect(EmbeddingModel.VoyageEmbedding.voyage2Code.rawValue == "voyage-code-2")
        #expect(EmbeddingModel.VoyageEmbedding.voyage2Large.rawValue == "voyage-large-2")
    }
    
    @Test("EmbeddingInput text variant")
    func testEmbeddingInputText() {
        let input = EmbeddingInput.text("Hello, world!")
        #expect(input.asTexts == ["Hello, world!"])
    }
    
    @Test("EmbeddingInput texts variant")
    func testEmbeddingInputTexts() {
        let texts = ["First text", "Second text", "Third text"]
        let input = EmbeddingInput.texts(texts)
        #expect(input.asTexts == texts)
    }
    
    @Test("EmbeddingInput tokens variant")
    func testEmbeddingInputTokens() {
        let tokens = [1234, 5678, 9012]
        let input = EmbeddingInput.tokens(tokens)
        #expect(input.asTexts.isEmpty)  // Tokens don't convert to texts
    }
    
    @Test("EmbeddingSettings default values")
    func testEmbeddingSettingsDefaults() {
        let settings = EmbeddingSettings.default
        #expect(settings.dimensions == nil)
        #expect(settings.normalizeEmbeddings == true)
        #expect(settings.truncate == nil)
    }
    
    @Test("EmbeddingSettings custom values")
    func testEmbeddingSettingsCustom() {
        let settings = EmbeddingSettings(
            dimensions: 512,
            normalizeEmbeddings: false,
            truncate: .end
        )
        
        #expect(settings.dimensions == 512)
        #expect(settings.normalizeEmbeddings == false)
        #expect(settings.truncate == .end)
    }
    
    @Test("EmbeddingSettings truncation strategies")
    func testEmbeddingSettingsTruncationStrategies() {
        #expect(EmbeddingSettings.TruncationStrategy.start.rawValue == "start")
        #expect(EmbeddingSettings.TruncationStrategy.end.rawValue == "end")
        #expect(EmbeddingSettings.TruncationStrategy.none.rawValue == "none")
    }
    
    @Test("EmbeddingResult properties")
    func testEmbeddingResultProperties() {
        let embeddings = [
            [0.1, 0.2, 0.3],
            [0.4, 0.5, 0.6]
        ]
        
        let result = EmbeddingResult(
            embeddings: embeddings,
            model: "text-embedding-3-small",
            usage: Usage(inputTokens: 10, outputTokens: 0),
            metadata: EmbeddingMetadata(truncated: false, normalizedL2: true)
        )
        
        #expect(result.embeddings == embeddings)
        #expect(result.model == "text-embedding-3-small")
        #expect(result.usage?.inputTokens == 10)
        #expect(result.metadata?.normalizedL2 == true)
    }
    
    @Test("EmbeddingResult convenience properties")
    func testEmbeddingResultConvenienceProperties() {
        let embeddings = [[0.1, 0.2, 0.3, 0.4]]
        
        let result = EmbeddingResult(
            embeddings: embeddings,
            model: "test-model"
        )
        
        // First embedding
        #expect(result.embedding == [0.1, 0.2, 0.3, 0.4])
        
        // Dimensions
        #expect(result.dimensions == 4)
    }
    
    @Test("EmbeddingResult with empty embeddings")
    func testEmbeddingResultEmpty() {
        let result = EmbeddingResult(
            embeddings: [],
            model: "test-model"
        )
        
        #expect(result.embedding == nil)
        #expect(result.dimensions == nil)
    }
    
    @Test("EmbeddingMetadata properties")
    func testEmbeddingMetadata() {
        let metadata1 = EmbeddingMetadata(truncated: true, normalizedL2: false)
        #expect(metadata1.truncated == true)
        #expect(metadata1.normalizedL2 == false)
        
        let metadata2 = EmbeddingMetadata()
        #expect(metadata2.truncated == false)
        #expect(metadata2.normalizedL2 == false)
    }
    
    @Test("EmbeddingSettings Codable")
    func testEmbeddingSettingsCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let original = EmbeddingSettings(
            dimensions: 256,
            normalizeEmbeddings: true,
            truncate: .start
        )
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(EmbeddingSettings.self, from: data)
        
        #expect(decoded.dimensions == original.dimensions)
        #expect(decoded.normalizeEmbeddings == original.normalizeEmbeddings)
        #expect(decoded.truncate == original.truncate)
    }
    
    @Test("EmbeddingMetadata Codable")
    func testEmbeddingMetadataCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let original = EmbeddingMetadata(truncated: true, normalizedL2: true)
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(EmbeddingMetadata.self, from: data)
        
        #expect(decoded.truncated == original.truncated)
        #expect(decoded.normalizedL2 == original.normalizedL2)
    }
    
    @Test("EmbeddingModel to LanguageModel conversion")
    func testEmbeddingModelToLanguageModel() {
        let openaiModel = EmbeddingModel.openai(.small3)
        let languageModel = openaiModel.toLanguageModel()
        
        // Should convert to a language model for tracking
        if case .openai = languageModel {
            // Success - converted to OpenAI model
        } else {
            Issue.record("Expected OpenAI language model")
        }
        
        // Other providers should also convert
        let cohereModel = EmbeddingModel.cohere(.english3)
        let cohereLanguageModel = cohereModel.toLanguageModel()
        if case .openai = cohereLanguageModel {
            // Currently returns OpenAI as placeholder
        } else {
            Issue.record("Expected placeholder language model")
        }
    }
    
    @Test("EmbeddingRequest structure")
    func testEmbeddingRequest() {
        let request = EmbeddingRequest(
            input: .text("Test input"),
            settings: EmbeddingSettings(dimensions: 128)
        )
        
        #expect(request.input.asTexts == ["Test input"])
        #expect(request.settings.dimensions == 128)
    }
}