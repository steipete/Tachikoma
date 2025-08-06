//
//  RealtimeConfigurationTests.swift
//  Tachikoma
//

import Testing
@testable import Tachikoma
import Foundation

@Suite("Realtime API Configuration Tests")
struct RealtimeConfigurationTests {
    
    @Test("Basic Configuration Creation")
    func testBasicConfiguration() {
        // Test voice conversation preset
        let config = EnhancedSessionConfiguration.voiceConversation()
        #expect(config.model == "gpt-4o-realtime-preview")
        #expect(config.voice == .alloy)
        #expect(config.turnDetection?.type == .serverVad)
        #expect(config.modalities == .all)
    }
    
    @Test("VAD Configuration")
    func testVADConfiguration() {
        let vad = RealtimeTurnDetection.serverVAD
        #expect(vad.type == .serverVad)
        #expect(vad.threshold == 0.5)
        #expect(vad.silenceDurationMs == 200)
        #expect(vad.prefixPaddingMs == 300)
        #expect(vad.createResponse == true)
    }
    
    @Test("Modality Configuration")
    func testModalityConfiguration() {
        let all = ResponseModality.all
        #expect(all.contains(.text))
        #expect(all.contains(.audio))
        #expect(all.toArray.contains("text"))
        #expect(all.toArray.contains("audio"))
    }
    
    @Test("Settings Configuration")
    func testSettingsConfiguration() {
        let settings = ConversationSettings.production
        #expect(settings.autoReconnect == true)
        #expect(settings.maxReconnectAttempts == 3)
        #expect(settings.bufferWhileDisconnected == true)
    }
    
    @Test("Tool Configuration")
    func testToolConfiguration() {
        let tool = RealtimeTool(
            name: "test",
            description: "Test tool",
            parameters: AgentToolParameters(
                properties: [:],
                required: []
            )
        )
        #expect(tool.name == "test")
        #expect(tool.description == "Test tool")
    }
}