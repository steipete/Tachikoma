//
//  RealtimeComprehensiveTests.swift
//  Tachikoma
//

import Testing
@testable import Tachikoma
import Foundation

@Suite("Realtime API Comprehensive Tests")
struct RealtimeComprehensiveTests {
    
    // MARK: - Configuration Tests
    
    @Test("Session Configuration Creation")
    func testSessionConfiguration() {
        // Test voice conversation preset
        let voiceConfig = EnhancedSessionConfiguration.voiceConversation(
            model: "gpt-4o-realtime-preview",
            voice: .nova
        )
        
        #expect(voiceConfig.model == "gpt-4o-realtime-preview")
        #expect(voiceConfig.voice == .nova)
        #expect(voiceConfig.turnDetection?.type == .serverVad)
        #expect(voiceConfig.modalities == .all)
        #expect(voiceConfig.inputAudioFormat == .pcm16)
        #expect(voiceConfig.outputAudioFormat == .pcm16)
        
        // Test text-only preset
        let textConfig = EnhancedSessionConfiguration.textOnly()
        #expect(textConfig.turnDetection?.type == .none)
        #expect(textConfig.modalities == .text)
        
        // Test with tools preset
        let tools = [
            RealtimeTool(
                name: "test_tool",
                description: "Test tool",
                parameters: AgentToolParameters(properties: [:], required: [])
            )
        ]
        let toolConfig = EnhancedSessionConfiguration.withTools(
            tools: tools
        )
        #expect(toolConfig.tools?.count == 1)
        #expect(toolConfig.toolChoice == .auto)
    }
    
    @Test("Turn Detection Configuration")
    func testTurnDetectionConfiguration() {
        // Test server VAD configuration
        let serverVAD = RealtimeTurnDetection.serverVAD
        #expect(serverVAD.type == .serverVad)
        #expect(serverVAD.threshold == 0.5)
        #expect(serverVAD.silenceDurationMs == 200)
        #expect(serverVAD.prefixPaddingMs == 300)
        #expect(serverVAD.createResponse == true)
        
        // Test disabled configuration
        let disabled = RealtimeTurnDetection.disabled
        #expect(disabled.type == .none)
        #expect(disabled.threshold == nil)
        #expect(disabled.createResponse == false)
        
        // Test custom configuration
        let custom = RealtimeTurnDetection(
            type: .serverVad,
            threshold: 0.7,
            silenceDurationMs: 500,
            prefixPaddingMs: 100,
            createResponse: false
        )
        #expect(custom.threshold == 0.7)
        #expect(custom.silenceDurationMs == 500)
    }
    
    @Test("Response Modality Configuration")
    func testResponseModality() {
        // Test individual modalities
        let text = ResponseModality.text
        #expect(text.contains(.text))
        #expect(!text.contains(.audio))
        #expect(text.toArray == ["text"])
        
        let audio = ResponseModality.audio
        #expect(!audio.contains(.text))
        #expect(audio.contains(.audio))
        #expect(audio.toArray == ["audio"])
        
        // Test combined modalities
        let all = ResponseModality.all
        #expect(all.contains(.text))
        #expect(all.contains(.audio))
        #expect(all.toArray.contains("text"))
        #expect(all.toArray.contains("audio"))
        
        // Test creation from array
        let fromArray = ResponseModality(from: ["text", "audio"])
        #expect(fromArray == .all)
        
        let textOnly = ResponseModality(from: ["text"])
        #expect(textOnly == .text)
    }
    
    @Test("Conversation Settings")
    func testConversationSettings() {
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
        #expect(development.bufferWhileDisconnected == false)
        
        // Test custom settings
        let custom = ConversationSettings(
            autoReconnect: true,
            maxReconnectAttempts: 5,
            reconnectDelay: 5.0,
            bufferWhileDisconnected: true,
            maxAudioBufferSize: 2 * 1024 * 1024,
            enableEchoCancellation: false,
            enableNoiseSuppression: false,
            localVADThreshold: 0.4,
            showAudioLevels: true,
            persistConversation: true,
            persistencePath: URL(fileURLWithPath: "/tmp/conversation")
        )
        #expect(custom.maxReconnectAttempts == 5)
        #expect(custom.maxAudioBufferSize == 2 * 1024 * 1024)
        #expect(custom.localVADThreshold == 0.4)
    }
    
    // MARK: - Event Tests
    
    @Test("Client Event Creation")
    func testClientEventCreation() throws {
        // Test session update event
        let sessionUpdate = RealtimeClientEvent.sessionUpdate(
            SessionUpdateEvent(
                modalities: ["text", "audio"],
                instructions: "Test instructions",
                voice: .nova,
                inputAudioFormat: .pcm16,
                outputAudioFormat: .pcm16,
                turnDetection: RealtimeTurnDetection.serverVAD,
                tools: nil,
                toolChoice: nil,
                temperature: 0.8,
                maxResponseOutputTokens: 4096
            )
        )
        
        if case .sessionUpdate(let event) = sessionUpdate {
            #expect(event.modalities == ["text", "audio"])
            #expect(event.voice == .nova)
            #expect(event.temperature == 0.8)
        } else {
            Issue.record("Expected sessionUpdate event")
        }
        
        // Test audio buffer append
        let audioData = Data(repeating: 0, count: 1024)
        let audioAppend = RealtimeClientEvent.inputAudioBufferAppend(
            InputAudioBufferAppendEvent(audio: audioData.base64EncodedString())
        )
        
        if case .inputAudioBufferAppend(let event) = audioAppend {
            #expect(event.audio == audioData.base64EncodedString())
        } else {
            Issue.record("Expected inputAudioBufferAppend event")
        }
        
        // Test response create
        let responseCreate = RealtimeClientEvent.responseCreate(
            ResponseCreateEvent(
                modalities: ["text"],
                instructions: "Be brief",
                voice: .echo,
                temperature: 0.5
            )
        )
        
        if case .responseCreate(let event) = responseCreate {
            #expect(event.modalities == ["text"])
            #expect(event.temperature == 0.5)
        } else {
            Issue.record("Expected responseCreate event")
        }
    }
    
    @Test("Server Event Types")
    func testServerEventTypes() {
        // Test session created
        let sessionCreated = RealtimeServerEvent.sessionCreated(
            SessionCreatedEvent(session: SessionObject(
                id: "test-session-123",
                object: "realtime.session",
                model: "gpt-4o-realtime-preview",
                modalities: ["text", "audio"],
                instructions: "Test",
                voice: .nova,
                inputAudioFormat: .pcm16,
                outputAudioFormat: .pcm16,
                inputAudioTranscription: nil,
                turnDetection: nil,
                tools: [],
                toolChoice: nil,
                temperature: 0.8,
                maxResponseOutputTokens: nil
            ))
        )
        
        if case .sessionCreated(let event) = sessionCreated {
            #expect(event.session.id == "test-session-123")
            #expect(event.session.model == "gpt-4o-realtime-preview")
        } else {
            Issue.record("Expected sessionCreated event")
        }
        
        // Test error event
        let errorEvent = RealtimeServerEvent.error(
            RealtimeErrorEvent(error: RealtimeError(
                type: "invalid_request_error",
                code: "invalid_api_key",
                message: "Invalid API key provided",
                param: nil,
                eventId: "error-123"
            ))
        )
        
        if case .error(let event) = errorEvent {
            #expect(event.error.type == "invalid_request_error")
            #expect(event.error.message == "Invalid API key provided")
        } else {
            Issue.record("Expected error event")
        }
    }
    
    // MARK: - Audio Tests
    
    @Test("Audio Format Configuration")
    func testAudioFormats() {
        // Test PCM16 format
        let pcm16 = RealtimeAudioFormat.pcm16
        #expect(pcm16.rawValue == "pcm16")
        
        // Test G.711 formats
        let ulaw = RealtimeAudioFormat.g711Ulaw
        #expect(ulaw.rawValue == "g711_ulaw")
        
        let alaw = RealtimeAudioFormat.g711Alaw
        #expect(alaw.rawValue == "g711_alaw")
    }
    
    @Test("Audio Pipeline Configuration")
    func testAudioPipelineConfiguration() throws {
        let config = AudioStreamPipeline.PipelineConfiguration(
            enableVAD: true,
            enableEchoCancellation: true,
            enableNoiseSuppression: true,
            vadThreshold: 0.4,
            bufferSize: 2048
        )
        
        #expect(config.enableVAD == true)
        #expect(config.vadThreshold == 0.4)
        #expect(config.bufferSize == 2048)
        
        // Test pipeline creation
        let pipeline = try AudioStreamPipeline(configuration: config)
        #expect(pipeline != nil)
    }
    
    // MARK: - Tool Tests
    
    @Test("Realtime Tool Creation")
    func testRealtimeToolCreation() {
        let tool = RealtimeTool(
            name: "weather",
            description: "Get weather information",
            parameters: AgentToolParameters(
                properties: [
                    "location": AgentToolParameterProperty(
                        name: "location",
                        type: .string,
                        description: "City name"
                    ),
                    "units": AgentToolParameterProperty(
                        name: "units",
                        type: .string,
                        description: "Temperature units",
                        enumValues: ["celsius", "fahrenheit"]
                    )
                ],
                required: ["location"]
            )
        )
        
        #expect(tool.name == "weather")
        #expect(tool.parameters.properties.count == 2)
        #expect(tool.parameters.required == ["location"])
        
        if let locationProp = tool.parameters.properties["location"] {
            #expect(locationProp.type == .string)
            #expect(locationProp.description == "City name")
        } else {
            Issue.record("Missing location property")
        }
        
        if let unitsProp = tool.parameters.properties["units"] {
            #expect(unitsProp.enumValues == ["celsius", "fahrenheit"])
        } else {
            Issue.record("Missing units property")
        }
    }
    
    @Test("Tool Wrapper")
    func testToolWrapper() async throws {
        // Create a simple tool
        let tool = AgentTool(
            name: "test_tool",
            description: "Test tool",
            parameters: AgentToolParameters(
                properties: [
                    "input": AgentToolParameterProperty(
                        name: "input",
                        type: .string,
                        description: "Input value"
                    )
                ],
                required: ["input"]
            ),
            execute: { args in
                let input = try args.stringValue("input")
                return .string("Processed: \(input)")
            }
        )
        
        // Wrap it for Realtime API
        let wrapper = AgentToolWrapper(tool: tool)
        #expect(wrapper.metadata.name == "test_tool")
        #expect(wrapper.metadata.description == "Test tool")
        
        // Test execution
        let args = RealtimeToolArguments(["input": "test"])
        let result = await wrapper.execute(args)
        #expect(result == "Processed: test")
    }
    
    // MARK: - Conversation Item Tests
    
    @Test("Conversation Item Creation")
    func testConversationItemCreation() {
        // Test message item
        let messageItem = ConversationItem(
            id: "msg-123",
            type: "message",
            role: "user",
            content: [
                ConversationContent(type: "text", text: "Hello, world!")
            ]
        )
        
        #expect(messageItem.id == "msg-123")
        #expect(messageItem.type == "message")
        #expect(messageItem.role == "user")
        #expect(messageItem.content?.first?.text == "Hello, world!")
        
        // Test function call item
        let functionItem = ConversationItem(
            id: "func-456",
            type: "function_call",
            role: "assistant",
            content: nil,
            callId: "call-789",
            name: "get_weather",
            arguments: "{\"location\": \"Tokyo\"}",
            output: nil
        )
        
        #expect(functionItem.type == "function_call")
        #expect(functionItem.name == "get_weather")
        #expect(functionItem.arguments == "{\"location\": \"Tokyo\"}")
        
        // Test function result item
        let resultItem = ConversationItem(
            id: "result-789",
            type: "function_call_output",
            role: nil,
            content: nil,
            callId: "call-789",
            name: nil,
            arguments: nil,
            output: "Sunny, 22°C in Tokyo"
        )
        
        #expect(resultItem.type == "function_call_output")
        #expect(resultItem.output == "Sunny, 22°C in Tokyo")
    }
    
    // MARK: - Integration Tests
    
    @Test("WebSocket Transport Mock")
    func testWebSocketTransportMock() async throws {
        // Create mock transport
        let transport = MockWebSocketTransport()
        
        // Test connection
        try await transport.connect(to: URL(string: "wss://api.openai.com/v1/realtime")!)
        #expect(transport.isConnected == true)
        
        // Test sending data
        let testData = Data("test message".utf8)
        try await transport.send(testData)
        
        // Test receiving data
        transport.mockReceiveData(Data("response".utf8))
        
        // Test disconnection
        await transport.disconnect()
        #expect(transport.isConnected == false)
    }
    
    @Test("Session Lifecycle")
    func testSessionLifecycle() async throws {
        // This would require a mock or test API key
        // For now, just test the configuration flow
        
        let config = SessionConfiguration(
            model: "gpt-4o-realtime-preview",
            voice: .nova
        )
        
        #expect(config.model == "gpt-4o-realtime-preview")
        #expect(config.voice == .nova)
        
        // Test session with mock transport
        let session = RealtimeSession(
            apiKey: "test-key",
            configuration: config
        )
        
        // Session should be created but not connected
        #expect(session != nil)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Error Event Handling")
    func testErrorEventHandling() {
        let error = RealtimeError(
            type: "rate_limit_error",
            code: "rate_limit_exceeded",
            message: "Rate limit exceeded for requests",
            param: nil,
            eventId: "evt-123"
        )
        
        #expect(error.type == "rate_limit_error")
        #expect(error.code == "rate_limit_exceeded")
        #expect(error.message == "Rate limit exceeded for requests")
        
        let errorEvent = RealtimeErrorEvent(error: error)
        let serverEvent = RealtimeServerEvent.error(errorEvent)
        
        if case .error(let event) = serverEvent {
            #expect(event.error.type == "rate_limit_error")
        } else {
            Issue.record("Expected error event")
        }
    }
    
    @Test("Reconnection Settings")
    func testReconnectionSettings() {
        let settings = ConversationSettings(
            autoReconnect: true,
            maxReconnectAttempts: 5,
            reconnectDelay: 3.0,
            bufferWhileDisconnected: true,
            maxAudioBufferSize: 2 * 1024 * 1024
        )
        
        #expect(settings.autoReconnect == true)
        #expect(settings.maxReconnectAttempts == 5)
        #expect(settings.reconnectDelay == 3.0)
        #expect(settings.maxAudioBufferSize == 2 * 1024 * 1024)
    }
}

// MARK: - Mock Transport for Testing

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
actor MockWebSocketTransport {
    private var _isConnected = false
    private var receiveContinuation: AsyncStream<Data>.Continuation?
    
    var isConnected: Bool {
        _isConnected
    }
    
    func connect(to url: URL) async throws {
        _isConnected = true
    }
    
    func disconnect() async {
        _isConnected = false
        receiveContinuation?.finish()
    }
    
    func send(_ data: Data) async throws {
        guard _isConnected else {
            throw TachikomaError.networkError(URLError(.notConnectedToInternet))
        }
    }
    
    func receive() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            self.receiveContinuation = continuation
        }
    }
    
    func mockReceiveData(_ data: Data) {
        receiveContinuation?.yield(data)
    }
}