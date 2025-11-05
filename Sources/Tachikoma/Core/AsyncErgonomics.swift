import Foundation

// MARK: - Cancellation Token

/// Token for coordinating cancellation across multiple async operations
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor CancellationToken: Sendable {
    private var isCancelled = false
    private var handlers: [@Sendable () -> Void] = []

    public init() {}

    /// Check if cancelled
    public var cancelled: Bool {
        get async { self.isCancelled }
    }

    /// Cancel all operations
    public func cancel() {
        guard !self.isCancelled else { return }
        self.isCancelled = true

        // Call all handlers
        for handler in self.handlers {
            handler()
        }
        self.handlers.removeAll()
    }

    /// Register a cancellation handler
    public func onCancel(_ handler: @escaping @Sendable () -> Void) {
        if self.isCancelled {
            handler()
        } else {
            self.handlers.append(handler)
        }
    }
}

// MARK: - Cancellable Task

/// A task that can be cancelled via token
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct CancellableTask<Success: Sendable> {
    public let task: Task<Success, Error>
    public let token: CancellationToken
}

// MARK: - Timeout Extensions

// MARK: - Timeout Functions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func withTimeout<T: Sendable>(
    _ timeout: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws
-> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task<Never, Never>.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw TimeoutError(timeout: timeout)
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

/// Timeout error
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct TimeoutError: Error, LocalizedError, Sendable {
    public let timeout: TimeInterval

    public var errorDescription: String? {
        "Operation timed out after \(self.timeout) seconds"
    }
}

// MARK: - Retry Configuration

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct RetryConfiguration: Sendable {
    public let maxAttempts: Int
    public let delay: TimeInterval
    public let backoffMultiplier: Double
    public let maxDelay: TimeInterval
    public let timeout: TimeInterval?

    public init(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        maxDelay: TimeInterval = 60.0,
        timeout: TimeInterval? = nil
    ) {
        self.maxAttempts = maxAttempts
        self.delay = delay
        self.backoffMultiplier = backoffMultiplier
        self.maxDelay = maxDelay
        self.timeout = timeout
    }

    public static let `default` = RetryConfiguration()
    public static let aggressive = RetryConfiguration(
        maxAttempts: 5,
        delay: 0.5,
        backoffMultiplier: 1.5,
        maxDelay: 30.0
    )
    public static let conservative = RetryConfiguration(
        maxAttempts: 3,
        delay: 2.0,
        backoffMultiplier: 3.0,
        maxDelay: 120.0
    )
}

// MARK: - Retry with Cancellation

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func retryWithCancellation<T: Sendable>(
    configuration: RetryConfiguration = .default,
    cancellationToken: CancellationToken? = nil,
    operation: @escaping @Sendable () async throws -> T
) async throws
-> T {
    var lastError: Error?
    var currentDelay = configuration.delay

    for attempt in 1...configuration.maxAttempts {
        // Check cancellation
        if let token = cancellationToken, await token.cancelled {
            throw CancellationError()
        }

        do {
            if let timeout = configuration.timeout {
                return try await withTimeout(timeout, operation: operation)
            } else {
                return try await operation()
            }
        } catch {
            lastError = error

            // Don't retry on cancellation
            if error is CancellationError {
                throw error
            }

            // Don't retry on last attempt
            if attempt == configuration.maxAttempts {
                break
            }

            // Wait with backoff
            try await Task<Never, Never>.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
            currentDelay = min(currentDelay * configuration.backoffMultiplier, configuration.maxDelay)
        }
    }

    throw lastError ?? TimeoutError(timeout: configuration.timeout ?? 0)
}

// MARK: - Async Stream Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension AsyncThrowingStream where Failure == Error {
    /// Collect all elements into an array
    public func collect() async throws -> [Element] {
        var elements: [Element] = []
        for try await element in self {
            elements.append(element)
        }
        return elements
    }
}

// MARK: - Task Group Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func withAutoCancellationTaskGroup<T: Sendable, Result>(
    of type: T.Type,
    returning returnType: Result.Type = Result.self,
    body: (inout ThrowingTaskGroup<T, Error>) async throws -> Result
) async throws
-> Result {
    try await withThrowingTaskGroup(of: type) { group in
        defer { group.cancelAll() }
        return try await body(&group)
    }
}
