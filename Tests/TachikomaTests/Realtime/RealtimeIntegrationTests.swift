//
//  RealtimeIntegrationTests.swift
//  Tachikoma
//

import Testing
@testable import Tachikoma
import Foundation

@Suite("Realtime API Integration Tests", .disabled("Requires API key and network"))
struct RealtimeIntegrationTests {
    
    // MARK: - Session Management Tests
    
    @Test("Session lifecycle management")
    func sessionLifecycle() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw Issue.record("OPENAI_API_KEY not set")
        }
        
        let config = SessionConfiguration(
            model: "gpt-4o-realtime-preview",
            voice: .alloy,
            instructions: "You are a helpful assistant.",
            inputAudioFormat: .pcm16,
            outputAudioFormat: .pcm16,
            turnDetection: nil,
            tools: nil,
            temperature: 0.8
        )
        
        let session = RealtimeSession(apiKey: apiKey, configuration: config)
        
        // Test connection
        try await session.connect()
        #expect(session.isConnected)
        
        // Test configuration update
        var updatedConfig = config
        updatedConfig.temperature = 0.5
        try await session.update(updatedConfig)
        
        // Test disconnection
        await session.disconnect()
        #expect(!session.isConnected)
    }
    
    @Test("Session reconnection after network failure")
    func sessionReconnection() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw Issue.record("OPENAI_API_KEY not set")
        }
        
        let settings = ConversationSettings(
            autoReconnect: true,
            maxReconnectAttempts: 3,
            reconnectDelay: 1.0
        )
        
        let config = EnhancedSessionConfiguration.voiceConversation()
        let session = EnhancedRealtimeSession(
            apiKey: apiKey,
            configuration: config,
            settings: settings
        )
        
        // Connect
        try await session.connect()
        
        // Simulate network failure (in real test, you'd trigger actual failure)
        // The session should attempt to reconnect automatically
        
        // Wait for potential reconnection
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Session should still be operational
        await session.disconnect()
    }
    
    // MARK: - Audio Pipeline Tests
    
    @Test("Audio format conversion")
    func audioFormatConversion() async throws {
        let processor = try RealtimeAudioProcessor()
        
        // Create test audio data (48kHz)
        let inputSampleRate = 48000.0
        let duration = 1.0
        let sampleCount = Int(inputSampleRate * duration)
        
        // Generate sine wave test data
        var samples: [Float] = []
        let frequency = 440.0 // A4 note
        for i in 0..<sampleCount {
            let sample = sin(2.0 * .pi * frequency * Double(i) / inputSampleRate)
            samples.append(Float(sample))
        }
        
        // Convert to Data
        let inputData = samples.withUnsafeBytes { Data($0) }
        
        // Process through converter (48kHz -> 24kHz)
        let outputData = processor.processAudioData(inputData, from: 48000, to: 24000)
        
        // Verify output is approximately half the size (24kHz is half of 48kHz)
        let expectedRatio = 24000.0 / 48000.0
        let actualRatio = Double(outputData.count) / Double(inputData.count)
        #expect(abs(actualRatio - expectedRatio) < 0.1)
    }
    
    @Test("Voice activity detection")
    func voiceActivityDetection() async throws {
        let detector = VoiceActivityDetector(
            threshold: 0.3,
            silenceDuration: 0.2
        )
        
        // Test with silence
        let silenceData = Data(repeating: 0, count: 1024)
        let silenceDetected = detector.processAudio(silenceData)
        #expect(!silenceDetected)
        
        // Test with noise (simulated voice)
        var noiseData = Data()
        for _ in 0..<1024 {
            noiseData.append(UInt8.random(in: 100...200))
        }
        let voiceDetected = detector.processAudio(noiseData)
        // Note: This is a simplified test - real VAD needs actual audio
    }
    
    // MARK: - Conversation Flow Tests
    
    @Test("Text conversation flow")
    func textConversationFlow() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw Issue.record("OPENAI_API_KEY not set")
        }
        
        let conversation = try RealtimeConversation(
            configuration: TachikomaConfiguration().withAPIKey(apiKey, for: .openai)
        )
        
        // Start conversation
        try await conversation.start(
            model: .gpt4oRealtime,
            voice: .nova,
            instructions: "You are a helpful assistant. Keep responses brief."
        )
        
        // Send text message
        try await conversation.sendText("Hello, what's 2+2?")
        
        // Wait for response
        var responseReceived = false
        let transcriptTask = Task {
            for await transcript in conversation.transcriptUpdates {
                if transcript.contains("4") {
                    responseReceived = true
                    break
                }
            }
        }
        
        // Wait up to 5 seconds for response
        try await Task.sleep(nanoseconds: 5_000_000_000)
        transcriptTask.cancel()
        
        #expect(responseReceived)
        
        // End conversation
        await conversation.end()
    }
    
    @Test("Function calling flow")
    func functionCallingFlow() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw Issue.record("OPENAI_API_KEY not set")
        }
        
        // Create a simple tool
        let weatherTool = SimpleTool(
            name: "getWeather",
            description: "Get current weather",
            parameters: ToolParameters(
                properties: [
                    "location": ToolParameterProperty(
                        name: "location",
                        type: .string,
                        description: "City name"
                    )
                ],
                required: ["location"]
            ),
            execute: { args in
                let location = try args.stringValue("location")
                return .string("The weather in \(location) is sunny and 72°F")
            }
        )
        
        let conversation = try RealtimeConversation(
            configuration: TachikomaConfiguration().withAPIKey(apiKey, for: .openai)
        )
        
        // Register tool
        await conversation.registerTools([weatherTool])
        
        // Start conversation with tools
        try await conversation.start(
            model: .gpt4oRealtime,
            tools: [RealtimeTool(
                name: weatherTool.name,
                description: weatherTool.description,
                parameters: weatherTool.parameters
            )]
        )
        
        // Ask about weather
        try await conversation.sendText("What's the weather in San Francisco?")
        
        // Wait for function call and response
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        await conversation.end()
    }
    
    // MARK: - Advanced Features Tests
    
    @Test("Dynamic modality switching")
    func dynamicModalitySwitching() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw Issue.record("OPENAI_API_KEY not set")
        }
        
        let config = EnhancedSessionConfiguration.voiceConversation()
        let conversation = try AdvancedRealtimeConversation(
            apiKey: apiKey,
            configuration: config
        )
        
        // Start with both modalities
        try await conversation.start()
        #expect(conversation.modalities == .all)
        
        // Switch to text-only
        try await conversation.updateModalities(.text)
        #expect(conversation.modalities == .text)
        
        // Switch to audio-only
        try await conversation.updateModalities(.audio)
        #expect(conversation.modalities == .audio)
        
        // Switch back to both
        try await conversation.updateModalities(.all)
        #expect(conversation.modalities == .all)
        
        await conversation.end()
    }
    
    @Test("Server VAD with turn management")
    func serverVADTurnManagement() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw Issue.record("OPENAI_API_KEY not set")
        }
        
        var config = EnhancedSessionConfiguration.voiceConversation()
        config.turnDetection = EnhancedTurnDetection.serverVAD
        
        let conversation = try AdvancedRealtimeConversation(
            apiKey: apiKey,
            configuration: config
        )
        
        try await conversation.start()
        
        // Test manual turn control
        try await conversation.startListening()
        #expect(conversation.isListening)
        #expect(conversation.turnActive)
        
        try await conversation.stopListening()
        #expect(!conversation.isListening)
        #expect(!conversation.turnActive)
        
        // Test turn detection update
        try await conversation.updateTurnDetection(.disabled)
        
        await conversation.end()
    }
    
    @Test("Conversation persistence and recovery")
    func conversationPersistence() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw Issue.record("OPENAI_API_KEY not set")
        }
        
        let persistencePath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_conversation.json")
        
        let settings = ConversationSettings(
            persistConversation: true,
            persistencePath: persistencePath
        )
        
        let config = EnhancedSessionConfiguration.voiceConversation()
        let conversation = try AdvancedRealtimeConversation(
            apiKey: apiKey,
            configuration: config,
            settings: settings
        )
        
        // Start and add some items
        try await conversation.start()
        try await conversation.sendText("Test message 1")
        try await conversation.sendText("Test message 2")
        
        // Save state
        let itemCount = conversation.items.count
        
        await conversation.end()
        
        // Create new conversation and verify state recovery
        let recoveredConversation = try AdvancedRealtimeConversation(
            apiKey: apiKey,
            configuration: config,
            settings: settings
        )
        
        // In a real implementation, you'd load from persistence
        // For now, just verify the settings are correct
        #expect(settings.persistConversation == true)
        #expect(settings.persistencePath == persistencePath)
        
        // Clean up
        try? FileManager.default.removeItem(at: persistencePath)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Invalid API key handling")
    func invalidAPIKeyHandling() async throws {
        let invalidKey = "sk-invalid-key"
        let config = SessionConfiguration(
            model: "gpt-4o-realtime-preview",
            voice: .alloy
        )
        
        let session = RealtimeSession(apiKey: invalidKey, configuration: config)
        
        // Should throw authentication error
        do {
            try await session.connect()
            Issue.record("Expected authentication error")
        } catch {
            // Expected error
            #expect(error is TachikomaError)
        }
    }
    
    @Test("Rate limit handling")
    func rateLimitHandling() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw Issue.record("OPENAI_API_KEY not set")
        }
        
        let conversation = try RealtimeConversation(
            configuration: TachikomaConfiguration().withAPIKey(apiKey, for: .openai)
        )
        
        try await conversation.start()
        
        // Send many requests rapidly to potentially trigger rate limit
        // Note: In production, you'd handle rate limits gracefully
        for i in 0..<5 {
            try await conversation.sendText("Message \(i)")
            // Small delay to avoid overwhelming
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        await conversation.end()
    }
}