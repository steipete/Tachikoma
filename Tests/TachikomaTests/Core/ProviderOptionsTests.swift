//
//  ProviderOptionsTests.swift
//  TachikomaTests
//

import Testing
import Foundation
@testable import Tachikoma

@Suite("Provider Options Tests")
struct ProviderOptionsTests {
    
    @Suite("Provider Options Creation")
    struct CreationTests {
        
        @Test("Create OpenAI options")
        func testOpenAIOptions() {
            let options = OpenAIOptions(
                parallelToolCalls: false,
                responseFormat: .json,
                seed: 42,
                verbosity: .high,
                reasoningEffort: .medium,
                previousResponseId: "prev-123",
                frequencyPenalty: 0.5,
                presencePenalty: 0.3,
                n: 2,
                logprobs: true,
                topLogprobs: 5
            )
            
            #expect(options.parallelToolCalls == false)
            #expect(options.responseFormat == .json)
            #expect(options.seed == 42)
            #expect(options.verbosity == .high)
            #expect(options.reasoningEffort == .medium)
            #expect(options.previousResponseId == "prev-123")
            #expect(options.frequencyPenalty == 0.5)
            #expect(options.presencePenalty == 0.3)
            #expect(options.n == 2)
            #expect(options.logprobs == true)
            #expect(options.topLogprobs == 5)
        }
        
        @Test("Create Anthropic options")
        func testAnthropicOptions() {
            let options = AnthropicOptions(
                thinking: .enabled(budgetTokens: 5000),
                cacheControl: .persistent,
                maxTokensToSample: 2000,
                stopSequences: ["END", "STOP"],
                metadata: ["key": "value"]
            )
            
            if case .enabled(let budget) = options.thinking {
                #expect(budget == 5000)
            } else {
                Issue.record("Expected thinking to be enabled")
            }
            
            #expect(options.cacheControl == .persistent)
            #expect(options.maxTokensToSample == 2000)
            #expect(options.stopSequences == ["END", "STOP"])
            #expect(options.metadata?["key"] == "value")
        }
        
        @Test("Create Google options")
        func testGoogleOptions() {
            let options = GoogleOptions(
                thinkingConfig: .init(budgetTokens: 3000, includeThoughts: true),
                safetySettings: .moderate,
                candidateCount: 3,
                stopSequences: ["###"]
            )
            
            #expect(options.thinkingConfig?.budgetTokens == 3000)
            #expect(options.thinkingConfig?.includeThoughts == true)
            #expect(options.safetySettings == .moderate)
            #expect(options.candidateCount == 3)
            #expect(options.stopSequences == ["###"])
        }
        
        @Test("Create Mistral options")
        func testMistralOptions() {
            let options = MistralOptions(
                safeMode: true,
                randomSeed: 12345
            )
            
            #expect(options.safeMode == true)
            #expect(options.randomSeed == 12345)
        }
        
        @Test("Create Groq options")
        func testGroqOptions() {
            let options = GroqOptions(speed: .ultraFast)
            #expect(options.speed == .ultraFast)
        }
        
        @Test("Create Grok options")
        func testGrokOptions() {
            let options = GrokOptions(
                funMode: true,
                includeCurrentEvents: true
            )
            
            #expect(options.funMode == true)
            #expect(options.includeCurrentEvents == true)
        }
    }
    
    @Suite("Provider Options Container")
    struct ContainerTests {
        
        @Test("Create provider options container")
        func testProviderOptionsContainer() {
            let options = ProviderOptions(
                openai: .init(verbosity: .high),
                anthropic: .init(thinking: .disabled),
                google: .init(safetySettings: .strict),
                mistral: .init(safeMode: true),
                groq: .init(speed: .fast),
                grok: .init(funMode: false)
            )
            
            #expect(options.openai?.verbosity == .high)
            #expect(options.anthropic?.thinking != nil)
            #expect(options.google?.safetySettings == .strict)
            #expect(options.mistral?.safeMode == true)
            #expect(options.groq?.speed == .fast)
            #expect(options.grok?.funMode == false)
        }
        
        @Test("Empty provider options")
        func testEmptyProviderOptions() {
            let options = ProviderOptions()
            
            #expect(options.openai == nil)
            #expect(options.anthropic == nil)
            #expect(options.google == nil)
            #expect(options.mistral == nil)
            #expect(options.groq == nil)
            #expect(options.grok == nil)
        }
    }
    
    @Suite("GenerationSettings Integration")
    struct SettingsIntegrationTests {
        
        @Test("Settings with provider options")
        func testSettingsWithProviderOptions() {
            let settings = GenerationSettings(
                maxTokens: 1000,
                temperature: 0.7,
                providerOptions: .init(
                    openai: .init(
                        parallelToolCalls: true,
                        verbosity: .medium
                    )
                )
            )
            
            #expect(settings.maxTokens == 1000)
            #expect(settings.temperature == 0.7)
            #expect(settings.providerOptions.openai?.verbosity == .medium)
            #expect(settings.providerOptions.openai?.parallelToolCalls == true)
        }
        
        @Test("Settings with empty provider options")
        func testSettingsWithEmptyProviderOptions() {
            let settings = GenerationSettings(
                maxTokens: 500,
                temperature: 0.5
            )
            
            #expect(settings.maxTokens == 500)
            #expect(settings.temperature == 0.5)
            #expect(settings.providerOptions.openai == nil)
        }
    }
    
    @Suite("Codable Conformance")
    struct CodableTests {
        
        @Test("Encode and decode OpenAI options")
        func testOpenAIOptionsCodable() throws {
            let original = OpenAIOptions(
                parallelToolCalls: true,
                seed: 42,
                verbosity: .high,
                reasoningEffort: .medium
            )
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(OpenAIOptions.self, from: data)
            
            #expect(decoded.verbosity == original.verbosity)
            #expect(decoded.reasoningEffort == original.reasoningEffort)
            #expect(decoded.parallelToolCalls == original.parallelToolCalls)
            #expect(decoded.seed == original.seed)
        }
        
        @Test("Encode and decode Anthropic thinking mode")
        func testAnthropicThinkingCodable() throws {
            let original = AnthropicOptions(
                thinking: .enabled(budgetTokens: 3000)
            )
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(AnthropicOptions.self, from: data)
            
            if case .enabled(let budget) = decoded.thinking {
                #expect(budget == 3000)
            } else {
                Issue.record("Expected thinking to be enabled")
            }
        }
        
        @Test("Encode and decode provider options container")
        func testProviderOptionsCodable() throws {
            let original = ProviderOptions(
                openai: .init(verbosity: .low),
                anthropic: .init(cacheControl: .ephemeral),
                google: .init(safetySettings: .relaxed)
            )
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(ProviderOptions.self, from: data)
            
            #expect(decoded.openai?.verbosity == .low)
            #expect(decoded.anthropic?.cacheControl == .ephemeral)
            #expect(decoded.google?.safetySettings == .relaxed)
        }
        
        @Test("Encode and decode GenerationSettings with provider options")
        func testGenerationSettingsCodable() throws {
            let original = GenerationSettings(
                maxTokens: 2000,
                temperature: 0.8,
                providerOptions: .init(
                    openai: .init(
                        verbosity: .high,
                        reasoningEffort: .low
                    )
                )
            )
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(GenerationSettings.self, from: data)
            
            #expect(decoded.maxTokens == 2000)
            #expect(decoded.temperature == 0.8)
            #expect(decoded.providerOptions.openai?.verbosity == .high)
            #expect(decoded.providerOptions.openai?.reasoningEffort == .low)
        }
    }
    
    @Suite("Enum Value Tests")
    struct EnumValueTests {
        
        @Test("OpenAI verbosity values")
        func testOpenAIVerbosityValues() {
            #expect(OpenAIOptions.Verbosity.low.rawValue == "low")
            #expect(OpenAIOptions.Verbosity.medium.rawValue == "medium")
            #expect(OpenAIOptions.Verbosity.high.rawValue == "high")
        }
        
        @Test("OpenAI reasoning effort values")
        func testOpenAIReasoningEffortValues() {
            #expect(OpenAIOptions.ReasoningEffort.minimal.rawValue == "minimal")
            #expect(OpenAIOptions.ReasoningEffort.low.rawValue == "low")
            #expect(OpenAIOptions.ReasoningEffort.medium.rawValue == "medium")
            #expect(OpenAIOptions.ReasoningEffort.high.rawValue == "high")
        }
        
        @Test("OpenAI response format values")
        func testOpenAIResponseFormatValues() {
            #expect(OpenAIOptions.ResponseFormat.text.rawValue == "text")
            #expect(OpenAIOptions.ResponseFormat.json.rawValue == "json_object")
            #expect(OpenAIOptions.ResponseFormat.jsonSchema.rawValue == "json_schema")
        }
        
        @Test("Anthropic cache control values")
        func testAnthropicCacheControlValues() {
            #expect(AnthropicOptions.CacheControl.ephemeral.rawValue == "ephemeral")
            #expect(AnthropicOptions.CacheControl.persistent.rawValue == "persistent")
        }
        
        @Test("Google safety settings values")
        func testGoogleSafetySettingsValues() {
            #expect(GoogleOptions.SafetySettings.strict.rawValue == "strict")
            #expect(GoogleOptions.SafetySettings.moderate.rawValue == "moderate")
            #expect(GoogleOptions.SafetySettings.relaxed.rawValue == "relaxed")
        }
        
        @Test("Groq speed level values")
        func testGroqSpeedLevelValues() {
            #expect(GroqOptions.SpeedLevel.normal.rawValue == "normal")
            #expect(GroqOptions.SpeedLevel.fast.rawValue == "fast")
            #expect(GroqOptions.SpeedLevel.ultraFast.rawValue == "ultra_fast")
        }
    }
}