//
//  AsyncErgonomics.swift
//  Tachikoma
//

import Foundation

// MARK: - Task Cancellation Support

/// Cancellable task wrapper with timeout support
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class CancellableTask<T: Sendable>: Sendable {
    private let task: Task<T, Error>
    private let timeoutTask: Task<Void, Never>?
    
    public init(
        timeout: TimeInterval? = nil,
        operation: @escaping @Sendable () async throws -> T
    ) {
        var timeoutTask: Task<Void, Never>?
        
        self.task = Task {
            try await operation()
        }
        
        if let timeout = timeout {
            timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                task.cancel()
            }
        }
        
        self.timeoutTask = timeoutTask
    }
    
    /// Wait for the task result
    public func value() async throws -> T {
        defer { timeoutTask?.cancel() }
        return try await task.value
    }
    
    /// Cancel the task
    public func cancel() {
        task.cancel()
        timeoutTask?.cancel()
    }
    
    /// Check if the task is cancelled
    public var isCancelled: Bool {
        task.isCancelled
    }
}

// MARK: - Timeout Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension Task where Failure == Error {
    /// Execute with timeout
    static func withTimeout<T>(
        _ timeout: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T where Success == T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError(timeout: timeout)
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

/// Timeout error
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct TimeoutError: Error, LocalizedError, Sendable {
    public let timeout: TimeInterval
    
    public var errorDescription: String? {
        "Operation timed out after \(timeout) seconds"
    }
}

// MARK: - Enhanced Generation Functions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension TachikomaCore {
    /// Generate text with timeout and cancellation support
    @discardableResult
    static func generateTextWithTimeout(
        model: LanguageModel,
        messages: [ModelMessage],
        tools: [AgentTool]? = nil,
        settings: GenerationSettings = .default,
        timeout: TimeInterval = 30,
        cancellationToken: CancellationToken? = nil
    ) async throws -> GenerateTextResult {
        let task = CancellableTask(timeout: timeout) {
            // Check for cancellation periodically
            if let token = cancellationToken {
                try await token.checkCancellation()
            }
            
            return try await generateText(
                model: model,
                messages: messages,
                tools: tools,
                settings: settings
            )
        }
        
        // Register task with cancellation token
        cancellationToken?.register(task)
        
        defer {
            cancellationToken?.unregister(task)
        }
        
        return try await task.value()
    }
    
    /// Stream text with timeout and cancellation
    static func streamTextWithTimeout(
        model: LanguageModel,
        messages: [ModelMessage],
        tools: [AgentTool]? = nil,
        settings: GenerationSettings = .default,
        timeout: TimeInterval = 60,
        cancellationToken: CancellationToken? = nil
    ) async throws -> StreamTextResult {
        let provider = try ProviderFactory.createProvider(for: model, configuration: .current)
        
        let request = ProviderRequest(
            messages: messages,
            tools: tools,
            settings: settings
        )
        
        // Create stream with timeout
        let baseStream = try await Task.withTimeout(timeout) {
            try await provider.streamText(request: request)
        }
        
        // Wrap stream with cancellation support
        let cancellableStream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                do {
                    for try await delta in baseStream {
                        // Check cancellation
                        if let token = cancellationToken, await token.isCancelled {
                            continuation.finish(throwing: CancellationError())
                            return
                        }
                        continuation.yield(delta)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        
        return StreamTextResult(
            stream: cancellableStream,
            model: model,
            settings: settings
        )
    }
}

// MARK: - Cancellation Token

/// Token for coordinating cancellation across multiple tasks
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor CancellationToken {
    private var isCancelled = false
    private var tasks: [ObjectIdentifier: AnyObject] = [:]
    private var callbacks: [@Sendable () -> Void] = []
    
    public init() {}
    
    /// Cancel all associated tasks
    public func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        
        // Cancel all registered tasks
        for (_, task) in tasks {
            if let cancellable = task as? any CancellableTaskProtocol {
                cancellable.cancel()
            }
        }
        
        // Execute callbacks
        for callback in callbacks {
            callback()
        }
        
        tasks.removeAll()
        callbacks.removeAll()
    }
    
    /// Check if cancelled
    public var cancelled: Bool {
        isCancelled
    }
    
    /// Check cancellation and throw if cancelled
    public func checkCancellation() throws {
        if isCancelled {
            throw CancellationError()
        }
    }
    
    /// Register a task for cancellation
    func register<T>(_ task: CancellableTask<T>) {
        let id = ObjectIdentifier(task)
        tasks[id] = task
    }
    
    /// Unregister a task
    func unregister<T>(_ task: CancellableTask<T>) {
        let id = ObjectIdentifier(task)
        tasks.removeValue(forKey: id)
    }
    
    /// Add cancellation callback
    public func onCancel(_ callback: @escaping @Sendable () -> Void) {
        callbacks.append(callback)
    }
}

// Protocol for type erasure
protocol CancellableTaskProtocol {
    func cancel()
}

extension CancellableTask: CancellableTaskProtocol {}

// MARK: - Async Stream Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension AsyncThrowingStream {
    /// Create a stream with timeout for each element
    static func withElementTimeout<T>(
        _ timeout: TimeInterval,
        bufferingPolicy: Continuation.BufferingPolicy = .unbounded,
        build: (Continuation) -> Void
    ) -> AsyncThrowingStream<T, Error> where Element == T {
        AsyncThrowingStream<T, Error>(bufferingPolicy: bufferingPolicy) { continuation in
            let wrappedContinuation = TimeoutContinuation(
                base: continuation,
                timeout: timeout
            )
            build(wrappedContinuation.continuation)
        }
    }
}

/// Continuation wrapper that adds timeout to yields
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct TimeoutContinuation<Element> {
    let base: AsyncThrowingStream<Element, Error>.Continuation
    let timeout: TimeInterval
    private var lastYield = Date()
    
    var continuation: AsyncThrowingStream<Element, Error>.Continuation {
        AsyncThrowingStream<Element, Error>.Continuation { result in
            let now = Date()
            if now.timeIntervalSince(lastYield) > timeout {
                base.finish(throwing: TimeoutError(timeout: timeout))
            } else {
                base.yield(with: result)
            }
        }
    }
}

// MARK: - Retry with Cancellation

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct RetryConfiguration: Sendable {
    public let maxAttempts: Int
    public let delay: TimeInterval
    public let backoffMultiplier: Double
    public let maxDelay: TimeInterval
    public let timeout: TimeInterval?
    
    public init(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1,
        backoffMultiplier: Double = 2,
        maxDelay: TimeInterval = 60,
        timeout: TimeInterval? = nil
    ) {
        self.maxAttempts = maxAttempts
        self.delay = delay
        self.backoffMultiplier = backoffMultiplier
        self.maxDelay = maxDelay
        self.timeout = timeout
    }
    
    public static let `default` = RetryConfiguration()
    public static let aggressive = RetryConfiguration(maxAttempts: 5, delay: 0.5)
    public static let conservative = RetryConfiguration(maxAttempts: 2, delay: 5)
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func retryWithCancellation<T>(
    configuration: RetryConfiguration = .default,
    cancellationToken: CancellationToken? = nil,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    var lastError: Error?
    var currentDelay = configuration.delay
    
    for attempt in 1...configuration.maxAttempts {
        // Check cancellation
        try await cancellationToken?.checkCancellation()
        
        do {
            if let timeout = configuration.timeout {
                return try await Task.withTimeout(timeout) {
                    try await operation()
                }
            } else {
                return try await operation()
            }
        } catch {
            lastError = error
            
            // Don't retry on cancellation
            if error is CancellationError {
                throw error
            }
            
            // Don't retry on the last attempt
            if attempt == configuration.maxAttempts {
                break
            }
            
            // Wait before retrying
            try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
            
            // Update delay with backoff
            currentDelay = min(
                currentDelay * configuration.backoffMultiplier,
                configuration.maxDelay
            )
        }
    }
    
    throw lastError ?? TachikomaError.retryError(
        RetryError(
            reason: "All retry attempts failed",
            lastError: lastError,
            errors: [],
            attempts: configuration.maxAttempts
        )
    )
}

// MARK: - Discardable Result Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension ResponseCache {
    /// Store response (discardable)
    @discardableResult
    func storeWithResult(_ response: ProviderResponse, for request: ProviderRequest) -> Bool {
        store(response, for: request)
        return true
    }
    
    /// Clear cache (discardable)
    @discardableResult
    func clearWithCount() -> Int {
        let count = cache.count
        clear()
        return count
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension EnhancedResponseCache {
    /// Store with result
    @discardableResult
    func storeWithResult(
        _ response: ProviderResponse,
        for request: ProviderRequest,
        ttl: TimeInterval? = nil,
        priority: CachePriority = .normal
    ) async -> Bool {
        await store(response, for: request, ttl: ttl, priority: priority)
        return true
    }
    
    /// Invalidate with count
    @discardableResult
    func invalidateWithCount(
        matching predicate: @escaping (CacheKey, CacheEntry) -> Bool
    ) async -> Int {
        let preCount = cache.count
        await invalidate(matching: predicate)
        return preCount - cache.count
    }
}

// MARK: - Task Group Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension withThrowingTaskGroup {
    /// Execute with automatic cancellation on first error
    static func withAutoCancellation<T: Sendable>(
        of type: T.Type,
        returning returnType: Result.Type = Result.self,
        body: (inout ThrowingTaskGroup<T, Error>) async throws -> Result
    ) async throws -> Result {
        try await withThrowingTaskGroup(of: type) { group in
            defer { group.cancelAll() }
            return try await body(&group)
        }
    }
}

// MARK: - Async Sequence Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension AsyncSequence {
    /// Collect with timeout
    func collect(timeout: TimeInterval) async throws -> [Element] {
        try await Task.withTimeout(timeout) {
            var results: [Element] = []
            for try await element in self {
                results.append(element)
            }
            return results
        }
    }
    
    /// First element with timeout
    func first(timeout: TimeInterval) async throws -> Element? {
        try await Task.withTimeout(timeout) {
            for try await element in self {
                return element
            }
            return nil
        }
    }
}