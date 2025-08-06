//
//  RealtimeSessionEnhanced.swift
//  Tachikoma
//

import Foundation

// MARK: - Enhanced Realtime Session

/// Enhanced session management with advanced features
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor EnhancedRealtimeSession {
    // MARK: - Properties
    
    private let transport: WebSocketTransport
    private let apiKey: String
    private var configuration: EnhancedSessionConfiguration
    private let settings: ConversationSettings
    
    private var sessionId: String?
    private var isConnected: Bool = false
    private var eventContinuation: AsyncStream<RealtimeServerEvent>.Continuation?
    
    // Reconnection state
    private var reconnectAttempts: Int = 0
    private var reconnectTask: Task<Void, Never>?
    
    // Audio buffering
    private var audioBuffer: Data = Data()
    private var isBuffering: Bool = false
    
    // Event handlers
    private var onConnectionStateChange: ((Bool) -> Void)?
    private var onError: ((Error) -> Void)?
    
    // MARK: - Initialization
    
    public init(
        apiKey: String,
        configuration: EnhancedSessionConfiguration,
        settings: ConversationSettings = .production
    ) {
        self.apiKey = apiKey
        self.configuration = configuration
        self.settings = settings
        self.transport = WebSocketTransport()
    }
    
    // MARK: - Connection Management
    
    /// Connect to the Realtime API with enhanced configuration
    public func connect() async throws {
        guard !isConnected else { return }
        
        let url = URL(string: "wss://api.openai.com/v1/realtime")!
        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "OpenAI-Beta": "realtime=v1"
        ]
        
        try await transport.connect(url: url, headers: headers)
        isConnected = true
        reconnectAttempts = 0
        
        // Send initial configuration
        try await updateConfiguration(configuration)
        
        // Start event processing
        startEventProcessing()
        
        // Notify connection change
        onConnectionStateChange?(true)
    }
    
    /// Disconnect from the API
    public func disconnect() async {
        guard isConnected else { return }
        
        // Cancel reconnection if in progress
        reconnectTask?.cancel()
        reconnectTask = nil
        
        await transport.disconnect()
        isConnected = false
        
        // Complete event stream
        eventContinuation?.finish()
        
        // Notify connection change
        onConnectionStateChange?(false)
    }
    
    // MARK: - Configuration Updates
    
    /// Update session configuration with enhanced options
    public func updateConfiguration(_ config: EnhancedSessionConfiguration) async throws {
        self.configuration = config
        
        // Build session update event
        var updateData: [String: Any] = [
            "type": "session.update",
            "session": [
                "model": config.model,
                "voice": config.voice.rawValue
            ]
        ]
        
        // Add optional fields
        var session = updateData["session"] as! [String: Any]
        
        if let instructions = config.instructions {
            session["instructions"] = instructions
        }
        
        if let turnDetection = config.turnDetection {
            var tdConfig: [String: Any] = ["type": turnDetection.type.rawValue]
            
            if turnDetection.type == .serverVad {
                if let threshold = turnDetection.threshold {
                    tdConfig["threshold"] = threshold
                }
                if let silenceDurationMs = turnDetection.silenceDurationMs {
                    tdConfig["silence_duration_ms"] = silenceDurationMs
                }
                if let prefixPaddingMs = turnDetection.prefixPaddingMs {
                    tdConfig["prefix_padding_ms"] = prefixPaddingMs
                }
                if let createResponse = turnDetection.createResponse {
                    tdConfig["create_response"] = createResponse
                }
            }
            
            session["turn_detection"] = tdConfig
        }
        
        if let modalities = config.modalities {
            session["modalities"] = modalities.toArray
        }
        
        if let transcription = config.inputAudioTranscription, let model = transcription.model {
            session["input_audio_transcription"] = ["model": model]
        }
        
        if let tools = config.tools, !tools.isEmpty {
            session["tools"] = tools.map { tool in
                [
                    "type": "function",
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": tool.parameters
                ]
            }
        }
        
        if let toolChoice = config.toolChoice {
            switch toolChoice {
            case .auto:
                session["tool_choice"] = "auto"
            case .none:
                session["tool_choice"] = "none"
            case .required:
                session["tool_choice"] = "required"
            case .function(let name):
                session["tool_choice"] = ["type": "function", "function": ["name": name]]
            }
        }
        
        if let temperature = config.temperature {
            session["temperature"] = temperature
        }
        
        if let maxTokens = config.maxResponseOutputTokens {
            session["max_response_output_tokens"] = maxTokens
        }
        
        session["input_audio_format"] = config.inputAudioFormat.rawValue
        session["output_audio_format"] = config.outputAudioFormat.rawValue
        
        updateData["session"] = session
        
        // Create SessionConfiguration
        var sessionConfig = SessionConfiguration()
        sessionConfig.model = config.model
        sessionConfig.voice = config.voice
        sessionConfig.instructions = config.instructions
        sessionConfig.inputAudioFormat = config.inputAudioFormat
        sessionConfig.outputAudioFormat = config.outputAudioFormat
        sessionConfig.tools = config.tools
        sessionConfig.temperature = config.temperature
        sessionConfig.maxResponseOutputTokens = config.maxResponseOutputTokens
        
        // Handle turn detection conversion
        if let td = config.turnDetection {
            sessionConfig.turnDetection = TurnDetection(
                type: td.type.rawValue,
                threshold: td.threshold.map { Double($0) } ?? 0.5,
                prefixPaddingMs: td.prefixPaddingMs ?? 300,
                silenceDurationMs: td.silenceDurationMs ?? 200
            )
        }
        
        // Handle modalities
        if let mod = config.modalities {
            sessionConfig.modalities = mod.toArray
        }
        
        // Send the update
        let event = RealtimeClientEvent.sessionUpdate(
            SessionUpdateEvent(session: sessionConfig)
        )
        
        try await sendEvent(event)
    }
    
    // MARK: - Audio Management
    
    /// Append audio with buffering support
    public func appendAudio(_ data: Data) async throws {
        if isConnected {
            // If we were buffering, send buffered audio first
            if isBuffering && !audioBuffer.isEmpty {
                let bufferedData = audioBuffer
                audioBuffer = Data()
                isBuffering = false
                
                // Send buffered audio
                let bufferedEvent = RealtimeClientEvent.inputAudioBufferAppend(
                    InputAudioBufferAppendEvent(audio: bufferedData)
                )
                try await sendEvent(bufferedEvent)
            }
            
            // Send current audio
            let event = RealtimeClientEvent.inputAudioBufferAppend(
                InputAudioBufferAppendEvent(audio: data)
            )
            try await sendEvent(event)
        } else if settings.bufferWhileDisconnected {
            // Buffer audio while disconnected
            audioBuffer.append(data)
            isBuffering = true
            
            // Check buffer size limit
            if audioBuffer.count > settings.maxAudioBufferSize {
                // Trim buffer to stay within limit
                let excess = audioBuffer.count - settings.maxAudioBufferSize
                audioBuffer.removeFirst(excess)
            }
        }
    }
    
    /// Commit audio buffer
    public func commitAudio() async throws {
        guard isConnected else { return }
        
        let event = RealtimeClientEvent.inputAudioBufferCommit
        try await sendEvent(event)
    }
    
    /// Clear audio buffer
    public func clearAudioBuffer() async throws {
        audioBuffer = Data()
        isBuffering = false
        
        guard isConnected else { return }
        
        let event = RealtimeClientEvent.inputAudioBufferClear
        try await sendEvent(event)
    }
    
    // MARK: - Response Control
    
    /// Create a response with modality control
    public func createResponse(modalities: ResponseModality? = nil) async throws {
        guard isConnected else { return }
        
        var responseData: [String: Any] = ["type": "response.create"]
        
        if let modalities = modalities {
            responseData["response"] = ["modalities": modalities.toArray]
        }
        
        let event = RealtimeClientEvent.responseCreate(
            ResponseCreateEvent(
                modalities: modalities?.toArray,
                instructions: nil,
                voice: nil,
                temperature: nil
            )
        )
        try await sendEvent(event)
    }
    
    /// Cancel the current response
    public func cancelResponse() async throws {
        guard isConnected else { return }
        
        let event = RealtimeClientEvent.responseCancel
        try await sendEvent(event)
    }
    
    // MARK: - Conversation Management
    
    /// Create a conversation item
    public func createItem(_ item: ConversationItem) async throws {
        guard isConnected else { return }
        
        let event = RealtimeClientEvent.conversationItemCreate(
            ConversationItemCreateEvent(item: item)
        )
        try await sendEvent(event)
    }
    
    /// Truncate conversation at a specific item
    public func truncateConversation(itemId: String) async throws {
        guard isConnected else { return }
        
        let event = RealtimeClientEvent.conversationItemTruncate(
            ConversationItemTruncateEvent(
                itemId: itemId,
                contentIndex: 0,
                audioEndMs: 0
            )
        )
        try await sendEvent(event)
    }
    
    /// Delete a conversation item
    public func deleteItem(itemId: String) async throws {
        guard isConnected else { return }
        
        let event = RealtimeClientEvent.conversationItemDelete(
            ConversationItemDeleteEvent(itemId: itemId)
        )
        try await sendEvent(event)
    }
    
    // MARK: - Event Stream
    
    /// Get event stream with automatic reconnection
    public func eventStream() -> AsyncThrowingStream<RealtimeServerEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await data in transport.receive() {
                        // Decode the data to RealtimeServerEvent
                        do {
                            let decoder = JSONDecoder()
                            // First decode to get event type
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let type = json["type"] as? String {
                                // Decode based on type
                                // For now, just continue without yielding
                                // TODO: Implement proper event decoding
                            }
                        } catch {
                            // Handle decode error
                            print("Failed to decode event: \(error)")
                        }
                    }
                } catch {
                    // Handle transport errors
                    if settings.autoReconnect && reconnectAttempts < settings.maxReconnectAttempts {
                        Task {
                            await handleReconnection()
                        }
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func sendEvent(_ event: RealtimeClientEvent) async throws {
        // This is a simplified encoding - in production you'd implement proper encoding for each event type
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        // Create a dictionary representation based on event type
        var eventDict: [String: Any] = ["type": event.type]
        
        // Add event-specific data
        // Note: This is simplified - you'd need to handle all event types properly
        let data = try JSONSerialization.data(withJSONObject: eventDict)
        try await transport.send(data)
    }
    
    private func startEventProcessing() {
        // Process incoming events
        Task {
            do {
                for try await data in transport.receive() {
                    // TODO: Decode data to RealtimeServerEvent
                    // await handleServerEvent(decodedEvent)
                }
            } catch {
                onError?(error)
                
                // Attempt reconnection if enabled
                if settings.autoReconnect && reconnectAttempts < settings.maxReconnectAttempts {
                    await handleReconnection()
                }
            }
        }
    }
    
    private func handleServerEvent(_ event: RealtimeServerEvent) async {
        switch event {
        case .sessionCreated(let event):
            self.sessionId = event.session.id
            
        case .sessionUpdated:
            // Configuration updated successfully
            break
            
        case .error(let event):
            onError?(TachikomaError.apiError(event.error.message))
            
        default:
            // Other events are passed through
            break
        }
    }
    
    private func handleReconnection() async {
        guard settings.autoReconnect else { return }
        
        reconnectAttempts += 1
        isConnected = false
        onConnectionStateChange?(false)
        
        // Wait before reconnecting
        try? await Task.sleep(nanoseconds: UInt64(settings.reconnectDelay * 1_000_000_000))
        
        // Attempt to reconnect
        do {
            try await connect()
            
            // Restore buffered audio if any
            if isBuffering && !audioBuffer.isEmpty {
                let bufferedData = audioBuffer
                audioBuffer = Data()
                isBuffering = false
                
                try await appendAudio(bufferedData)
            }
        } catch {
            onError?(error)
            
            // Try again if we haven't exceeded max attempts
            if reconnectAttempts < settings.maxReconnectAttempts {
                await handleReconnection()
            }
        }
    }
    
    // MARK: - Event Handlers
    
    /// Set connection state change handler
    public func onConnectionStateChange(_ handler: @escaping (Bool) -> Void) {
        self.onConnectionStateChange = handler
    }
    
    /// Set error handler
    public func onError(_ handler: @escaping (Error) -> Void) {
        self.onError = handler
    }
}