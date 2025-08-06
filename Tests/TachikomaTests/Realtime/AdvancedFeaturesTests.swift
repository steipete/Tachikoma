//
//  AdvancedFeaturesTests.swift
//  Tachikoma
//

import Testing
@testable import Tachikoma
import Foundation

@Suite("Realtime Advanced Features Tests")
struct AdvancedFeaturesTests {
    
    @Test("Turn Detection Configuration")
    func turnDetectionConfiguration() {
        // Test server VAD configuration
        let serverVAD = EnhancedTurnDetection.serverVAD
        #expect(serverVAD.type == .serverVad)
        #expect(serverVAD.threshold == 0.5)
        #expect(serverVAD.silenceDurationMs == 200)
        #expect(serverVAD.prefixPaddingMs == 300)
        #expect(serverVAD.createResponse == true)
        
        // Test disabled configuration
        let disabled = EnhancedTurnDetection.disabled
        #expect(disabled.type == .none)
        #expect(disabled.threshold == nil)
        #expect(disabled.silenceDurationMs == nil)
        #expect(disabled.createResponse == false)
    }
    
    @Test("Response Modality Options")
    func responseModalityOptions() {
        // Test individual modalities
        let textOnly = ResponseModality.text
        #expect(textOnly.contains(.text))
        #expect(!textOnly.contains(.audio))
        #expect(textOnly.toArray == ["text"])
        
        let audioOnly = ResponseModality.audio
        #expect(!audioOnly.contains(.text))
        #expect(audioOnly.contains(.audio))
        #expect(audioOnly.toArray == ["audio"])
        
        // Test combined modalities
        let both = ResponseModality.all
        #expect(both.contains(.text))
        #expect(both.contains(.audio))
        let array = both.toArray
        #expect(array.contains("text"))
        #expect(array.contains("audio"))
        
        // Test creation from array
        let fromArray = ResponseModality(from: ["text", "audio"])
        #expect(fromArray == .all)
    }
    
    @Test("Input Audio Transcription")
    func inputAudioTranscription() {
        // Test Whisper configuration
        let whisper = InputAudioTranscription.whisper
        #expect(whisper.model == "whisper-1")
        
        // Test none configuration
        let none = InputAudioTranscription.none
        #expect(none.model == nil)
        
        // Test custom model
        let custom = InputAudioTranscription(model: "custom-model")
        #expect(custom.model == "custom-model")
    }
    
    @Test("Enhanced Session Configuration")
    func enhancedSessionConfiguration() {
        // Test voice conversation configuration
        let voiceConfig = EnhancedSessionConfiguration.voiceConversation()
        #expect(voiceConfig.model == "gpt-4o-realtime-preview")
        #expect(voiceConfig.voice == .alloy)
        #expect(voiceConfig.turnDetection?.type == .serverVad)
        #expect(voiceConfig.modalities == .all)
        
        // Test text-only configuration
        let textConfig = EnhancedSessionConfiguration.textOnly()
        #expect(textConfig.turnDetection?.type == .none)
        #expect(textConfig.modalities == .text)
        
        // Test configuration with tools
        let tools = [
            RealtimeTool(
                name: "testTool",
                description: "Test tool",
                parameters: ToolParameters(properties: [:], required: [])
            )
        ]
        let toolsConfig = EnhancedSessionConfiguration.withTools(tools: tools)
        #expect(toolsConfig.tools?.count == 1)
        #expect(toolsConfig.toolChoice == .auto)
    }
    
    @Test("Tool Choice Options")
    func toolChoiceOptions() throws {
        // Test encoding/decoding of different tool choices
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // Auto
        let auto = EnhancedSessionConfiguration.ToolChoice.auto
        let autoData = try encoder.encode(auto)
        let autoDecoded = try decoder.decode(EnhancedSessionConfiguration.ToolChoice.self, from: autoData)
        #expect(autoDecoded == .auto)
        
        // None
        let none = EnhancedSessionConfiguration.ToolChoice.none
        let noneData = try encoder.encode(none)
        let noneDecoded = try decoder.decode(EnhancedSessionConfiguration.ToolChoice.self, from: noneData)
        #expect(noneDecoded == .none)
        
        // Required
        let required = EnhancedSessionConfiguration.ToolChoice.required
        let requiredData = try encoder.encode(required)
        let requiredDecoded = try decoder.decode(EnhancedSessionConfiguration.ToolChoice.self, from: requiredData)
        #expect(requiredDecoded == .required)
        
        // Function
        let function = EnhancedSessionConfiguration.ToolChoice.function(name: "myFunction")
        let functionData = try encoder.encode(function)
        let functionDecoded = try decoder.decode(EnhancedSessionConfiguration.ToolChoice.self, from: functionData)
        if case .function(let name) = functionDecoded {
            #expect(name == "myFunction")
        } else {
            Issue.record("Expected function tool choice")
        }
    }
    
    @Test("Conversation Settings")
    func conversationSettings() {
        // Test production settings
        let production = ConversationSettings.production
        #expect(production.autoReconnect == true)
        #expect(production.maxReconnectAttempts == 3)
        #expect(production.reconnectDelay == 2.0)
        #expect(production.bufferWhileDisconnected == true)
        #expect(production.enableEchoCancellation == true)
        #expect(production.enableNoiseSuppression == true)
        
        // Test development settings
        let development = ConversationSettings.development
        #expect(development.autoReconnect == false)
        #expect(development.maxReconnectAttempts == 1)
        #expect(development.reconnectDelay == 1.0)
        #expect(development.bufferWhileDisconnected == false)
        #expect(development.enableEchoCancellation == false)
        #expect(development.enableNoiseSuppression == false)
        #expect(development.showAudioLevels == true)
    }
    
    @Test("Session Configuration with Modalities")
    func sessionConfigurationWithModalities() {
        var config = EnhancedSessionConfiguration()
        
        // Test setting text-only modality
        config.modalities = .text
        #expect(config.modalities?.toArray == ["text"])
        
        // Test setting audio-only modality
        config.modalities = .audio
        #expect(config.modalities?.toArray == ["audio"])
        
        // Test setting both modalities
        config.modalities = .all
        let array = config.modalities?.toArray ?? []
        #expect(array.contains("text"))
        #expect(array.contains("audio"))
    }
    
    @Test("Configuration Temperature and Tokens")
    func configurationTemperatureAndTokens() {
        var config = EnhancedSessionConfiguration()
        
        // Default temperature
        #expect(config.temperature == 0.8)
        
        // Custom temperature
        config.temperature = 0.5
        #expect(config.temperature == 0.5)
        
        // Max response tokens
        config.maxResponseOutputTokens = 1000
        #expect(config.maxResponseOutputTokens == 1000)
    }
}