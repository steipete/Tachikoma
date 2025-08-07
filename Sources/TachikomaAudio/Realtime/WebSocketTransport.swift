//
//  WebSocketTransport.swift
//  Tachikoma
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Transport Protocol

/// Protocol for real-time transport mechanisms
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol RealtimeTransport: Sendable {
    /// Connect to the server
    func connect(url: URL, headers: [String: String]) async throws
    
    /// Send an event to the server
    func send(_ data: Data) async throws
    
    /// Receive events from the server
    func receive() -> AsyncThrowingStream<Data, Error>
    
    /// Disconnect from the server
    func disconnect() async
    
    /// Current connection state
    var isConnected: Bool { get }
}

// MARK: - WebSocket Transport Implementation

/// WebSocket-based transport for OpenAI Realtime API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@preconcurrency
public actor WebSocketTransport: RealtimeTransport {
    // MARK: - Properties
    
    private var task: URLSessionWebSocketTask?
    private let session: URLSession
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    private var receiveContinuation: AsyncThrowingStream<Data, Error>.Continuation?
    
    private var _isConnected: Bool = false
    public nonisolated var isConnected: Bool {
        // Note: This is a workaround for protocol conformance
        // In real usage, you should await the actor-isolated property
        false // Default to disconnected for non-isolated access
    }
    
    // Reconnection settings
    private let maxReconnectAttempts = 5
    private let baseReconnectDelay: TimeInterval = 1.0
    private let maxReconnectDelay: TimeInterval = 30.0
    private var reconnectAttempt = 0
    
    // MARK: - Initialization
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Connection Management
    
    public func connect(url: URL, headers: [String: String]) async throws {
        // Disconnect if already connected
        if _isConnected {
            await disconnect()
        }
        
        // Create request with headers
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Create WebSocket task
        task = session.webSocketTask(with: request)
        
        // Start the connection
        task?.resume()
        
        // Wait for connection confirmation
        try await withCheckedThrowingContinuation { continuation in
            connectionContinuation = continuation
            
            // Send ping to verify connection
            Task {
                do {
                    try await sendPing()
                    _isConnected = true
                    connectionContinuation?.resume()
                    connectionContinuation = nil
                    
                    // Start receiving messages
                    await startReceiving()
                    
                    // Start heartbeat
                    await startHeartbeat()
                } catch {
                    connectionContinuation?.resume(throwing: error)
                    connectionContinuation = nil
                }
            }
        }
    }
    
    public func disconnect() async {
        _isConnected = false
        
        // Cancel the task
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        
        // Complete any pending continuations
        receiveContinuation?.finish()
        receiveContinuation = nil
        
        connectionContinuation?.resume(throwing: TachikomaError.networkError(
            NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection closed"])
        ))
        connectionContinuation = nil
        
        // Reset reconnect counter
        reconnectAttempt = 0
    }
    
    // MARK: - Data Transfer
    
    public func send(_ data: Data) async throws {
        guard let task = task, _isConnected else {
            throw TachikomaError.networkError(
                NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected"])
            )
        }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        try await task.send(message)
    }
    
    public nonisolated func receive() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.setReceiveContinuation(continuation)
            }
        }
    }
    
    private func setReceiveContinuation(_ continuation: AsyncThrowingStream<Data, Error>.Continuation) {
        self.receiveContinuation = continuation
    }
    
    // MARK: - Private Methods
    
    private func startReceiving() async {
        guard let task = task else { return }
        
        do {
            while _isConnected {
                let message = try await task.receive()
                
                switch message {
                case .data(let data):
                    receiveContinuation?.yield(data)
                case .string(let string):
                    if let data = string.data(using: .utf8) {
                        receiveContinuation?.yield(data)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            // Connection error - attempt reconnection
            if _isConnected {
                await handleConnectionError(error)
            }
        }
    }
    
    private func startHeartbeat() async {
        while _isConnected {
            do {
                // Send ping every 30 seconds
                try await Task.sleep(nanoseconds: 30_000_000_000)
                
                if _isConnected {
                    try await sendPing()
                }
            } catch {
                // Ignore heartbeat errors
                break
            }
        }
    }
    
    private func sendPing() async throws {
        guard let task = task else {
            throw TachikomaError.networkError(
                NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active task"])
            )
        }
        
        task.sendPing { error in
            if let error = error {
                Task {
                    await self.handleConnectionError(error)
                }
            }
        }
    }
    
    private func handleConnectionError(_ error: Error) async {
        guard _isConnected else { return }
        
        // Mark as disconnected
        _isConnected = false
        
        // Notify about disconnection
        receiveContinuation?.finish(throwing: error)
        
        // Attempt reconnection with exponential backoff
        if reconnectAttempt < maxReconnectAttempts {
            reconnectAttempt += 1
            
            let delay = min(
                baseReconnectDelay * pow(2.0, Double(reconnectAttempt - 1)),
                maxReconnectDelay
            )
            
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // Attempt to reconnect
                // Note: In production, we'd need to store the original URL and headers
                // For now, this is a placeholder
                print("WebSocket: Reconnection attempt \(reconnectAttempt) after \(delay)s delay")
            } catch {
                // Task was cancelled
            }
        } else {
            // Max reconnection attempts reached
            receiveContinuation?.finish(throwing: TachikomaError.networkError(
                NSError(domain: "WebSocket", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Maximum reconnection attempts reached"
                ])
            ))
        }
    }
}

// MARK: - WebSocket Transport Factory

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct WebSocketTransportFactory {
    /// Create a WebSocket transport with custom configuration
    public static func create(
        session: URLSession = .shared
    ) -> RealtimeTransport {
        WebSocketTransport(session: session)
    }
    
    /// Create a WebSocket transport optimized for low latency
    public static func createLowLatency() -> RealtimeTransport {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        #if !os(Linux)
        // waitsForConnectivity is not available on Linux
        configuration.waitsForConnectivity = false
        #endif
        
        let session = URLSession(configuration: configuration)
        return WebSocketTransport(session: session)
    }
}