//
//  StopConditions.swift
//  Tachikoma
//

import Foundation

// MARK: - Stop Conditions for Generation Control

/// Protocol for conditions that can stop generation
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol StopCondition: Sendable {
    /// Check if generation should stop based on the current text
    func shouldStop(text: String, delta: String?) async -> Bool
    
    /// Reset any internal state
    func reset() async
}

// MARK: - Built-in Stop Conditions

/// Stop when a specific string is encountered
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct StringStopCondition: StopCondition {
    public let stopString: String
    public let caseSensitive: Bool
    
    public init(_ stopString: String, caseSensitive: Bool = true) {
        self.stopString = stopString
        self.caseSensitive = caseSensitive
    }
    
    public func shouldStop(text: String, delta: String?) async -> Bool {
        if caseSensitive {
            return text.contains(stopString) || (delta?.contains(stopString) ?? false)
        } else {
            return text.lowercased().contains(stopString.lowercased()) || 
                   (delta?.lowercased().contains(stopString.lowercased()) ?? false)
        }
    }
    
    public func reset() async {}
}

/// Stop when a regex pattern is matched
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct RegexStopCondition: StopCondition {
    private let pattern: String
    private let regex: NSRegularExpression?
    
    public init(pattern: String) {
        self.pattern = pattern
        self.regex = try? NSRegularExpression(pattern: pattern, options: [])
    }
    
    public func shouldStop(text: String, delta: String?) async -> Bool {
        guard let regex else { return false }
        
        let range = NSRange(location: 0, length: text.utf16.count)
        if regex.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }
        
        if let delta {
            let deltaRange = NSRange(location: 0, length: delta.utf16.count)
            return regex.firstMatch(in: delta, options: [], range: deltaRange) != nil
        }
        
        return false
    }
    
    public func reset() async {}
}

/// Stop after a certain number of tokens
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor TokenCountStopCondition: StopCondition {
    private let maxTokens: Int
    private var currentTokens: Int = 0
    
    public init(maxTokens: Int) {
        self.maxTokens = maxTokens
    }
    
    public func shouldStop(text: String, delta: String?) async -> Bool {
        // Approximate token counting (4 chars ≈ 1 token)
        if let delta {
            currentTokens += max(1, delta.count / 4)
        } else {
            currentTokens = max(1, text.count / 4)
        }
        return currentTokens >= maxTokens
    }
    
    public func reset() async {
        currentTokens = 0
    }
}

/// Stop after a certain duration
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor TimeoutStopCondition: StopCondition {
    private let timeout: TimeInterval
    private var startTime: Date?
    
    public init(timeout: TimeInterval) {
        self.timeout = timeout
    }
    
    public func shouldStop(text: String, delta: String?) async -> Bool {
        if startTime == nil {
            startTime = Date()
        }
        
        guard let startTime else { return false }
        return Date().timeIntervalSince(startTime) >= timeout
    }
    
    public func reset() async {
        startTime = nil
    }
}

/// Stop when a custom predicate returns true
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct PredicateStopCondition: StopCondition {
    private let predicate: @Sendable (String, String?) async -> Bool
    
    public init(predicate: @escaping @Sendable (String, String?) async -> Bool) {
        self.predicate = predicate
    }
    
    public func shouldStop(text: String, delta: String?) async -> Bool {
        await predicate(text, delta)
    }
    
    public func reset() async {}
}

// MARK: - Composite Stop Conditions

/// Stop when any of the conditions are met
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AnyStopCondition: StopCondition {
    private let conditions: [any StopCondition]
    
    public init(_ conditions: [any StopCondition]) {
        self.conditions = conditions
    }
    
    public init(_ conditions: any StopCondition...) {
        self.conditions = conditions
    }
    
    public func shouldStop(text: String, delta: String?) async -> Bool {
        for condition in conditions {
            if await condition.shouldStop(text: text, delta: delta) {
                return true
            }
        }
        return false
    }
    
    public func reset() async {
        for condition in conditions {
            await condition.reset()
        }
    }
}

/// Stop when all conditions are met
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AllStopCondition: StopCondition {
    private let conditions: [any StopCondition]
    
    public init(_ conditions: [any StopCondition]) {
        self.conditions = conditions
    }
    
    public init(_ conditions: any StopCondition...) {
        self.conditions = conditions
    }
    
    public func shouldStop(text: String, delta: String?) async -> Bool {
        for condition in conditions {
            if await !condition.shouldStop(text: text, delta: delta) {
                return false
            }
        }
        return true
    }
    
    public func reset() async {
        for condition in conditions {
            await condition.reset()
        }
    }
}

// MARK: - Stateful Stop Conditions

/// Stop when a pattern appears consecutively N times
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor ConsecutivePatternStopCondition: StopCondition {
    private let pattern: String
    private let requiredCount: Int
    private var currentCount: Int = 0
    private var lastText: String = ""
    
    public init(pattern: String, count: Int) {
        self.pattern = pattern
        self.requiredCount = count
    }
    
    public func shouldStop(text: String, delta: String?) async -> Bool {
        // Count new occurrences in the delta
        if let delta {
            let newOccurrences = delta.components(separatedBy: pattern).count - 1
            currentCount += newOccurrences
        } else {
            // Full text check
            let occurrences = text.components(separatedBy: pattern).count - 1
            currentCount = occurrences
        }
        
        lastText = text
        return currentCount >= requiredCount
    }
    
    public func reset() async {
        currentCount = 0
        lastText = ""
    }
}

/// Stop when the model starts repeating itself
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor RepetitionStopCondition: StopCondition {
    private let windowSize: Int
    private let threshold: Double
    private var recentChunks: [String] = []
    
    public init(windowSize: Int = 50, threshold: Double = 0.8) {
        self.windowSize = windowSize
        self.threshold = threshold
    }
    
    public func shouldStop(text: String, delta: String?) async -> Bool {
        guard let delta, !delta.isEmpty else { return false }
        
        // Add new chunk
        recentChunks.append(delta)
        
        // Keep only recent chunks
        if recentChunks.count > 10 {
            recentChunks.removeFirst()
        }
        
        // Check for repetition
        guard recentChunks.count >= 3 else { return false }
        
        // Simple repetition detection: check if recent chunks are similar
        let lastChunk = recentChunks.last!
        var similarCount = 0
        
        for i in 0..<(recentChunks.count - 1) {
            if similarity(recentChunks[i], lastChunk) > threshold {
                similarCount += 1
            }
        }
        
        // Stop if too many similar chunks
        return Double(similarCount) / Double(recentChunks.count - 1) > 0.5
    }
    
    private func similarity(_ s1: String, _ s2: String) -> Double {
        guard !s1.isEmpty && !s2.isEmpty else { return 0 }
        
        // Simple character-based similarity
        let commonChars = Set(s1).intersection(Set(s2)).count
        let totalChars = Set(s1).union(Set(s2)).count
        
        return Double(commonChars) / Double(totalChars)
    }
    
    public func reset() async {
        recentChunks = []
    }
}

// MARK: - Stop Condition Builder

/// Builder for creating stop conditions fluently
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct StopConditionBuilder {
    private var conditions: [any StopCondition] = []
    
    public init() {}
    
    /// Stop when a string is encountered
    public func whenContains(_ text: String, caseSensitive: Bool = true) -> StopConditionBuilder {
        var builder = self
        builder.conditions.append(StringStopCondition(text, caseSensitive: caseSensitive))
        return builder
    }
    
    /// Stop when a regex pattern matches
    public func whenMatches(_ pattern: String) -> StopConditionBuilder {
        var builder = self
        builder.conditions.append(RegexStopCondition(pattern: pattern))
        return builder
    }
    
    /// Stop after N tokens
    public func afterTokens(_ count: Int) -> StopConditionBuilder {
        var builder = self
        builder.conditions.append(TokenCountStopCondition(maxTokens: count))
        return builder
    }
    
    /// Stop after a timeout
    public func afterTime(_ seconds: TimeInterval) -> StopConditionBuilder {
        var builder = self
        builder.conditions.append(TimeoutStopCondition(timeout: seconds))
        return builder
    }
    
    /// Stop when custom predicate is true
    public func when(_ predicate: @escaping @Sendable (String, String?) async -> Bool) -> StopConditionBuilder {
        var builder = self
        builder.conditions.append(PredicateStopCondition(predicate: predicate))
        return builder
    }
    
    /// Build the final condition
    public func build() -> any StopCondition {
        switch conditions.count {
        case 0:
            return NeverStopCondition()
        case 1:
            return conditions[0]
        default:
            return AnyStopCondition(conditions)
        }
    }
}

/// A condition that never stops (used as default)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct NeverStopCondition: StopCondition {
    public init() {}
    
    public func shouldStop(text: String, delta: String?) async -> Bool {
        false
    }
    
    public func reset() async {}
}

// MARK: - Integration with Generation Functions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension GenerationSettings {
    /// Create settings with stop conditions
    static func withStopConditions(
        _ conditions: any StopCondition...,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        seed: Int? = nil
    ) -> GenerationSettings {
        GenerationSettings(
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP,
            stopConditions: conditions.isEmpty ? nil : AnyStopCondition(conditions),
            seed: seed
        )
    }
}

// MARK: - Stream Extensions for Stop Conditions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension AsyncThrowingStream where Element == TextStreamDelta {
    /// Apply stop conditions to a text stream
    func stopWhen(_ condition: any StopCondition) -> AsyncThrowingStream<Element, Error> {
        AsyncThrowingStream<Element, Error> { continuation in
            Task {
                var accumulatedText = ""
                await condition.reset()
                
                do {
                    for try await delta in self {
                        // Accumulate text
                        if case .textDelta = delta.type, let content = delta.content {
                            accumulatedText += content
                            
                            // Check stop condition
                            if await condition.shouldStop(text: accumulatedText, delta: content) {
                                // Yield the current delta then stop
                                continuation.yield(delta)
                                continuation.yield(TextStreamDelta(type: .done))
                                continuation.finish()
                                return
                            }
                        }
                        
                        // Continue streaming
                        continuation.yield(delta)
                        
                        // Check for natural end
                        if case .done = delta.type {
                            continuation.finish()
                            return
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension StreamTextResult {
    /// Apply stop conditions to the stream
    func stopWhen(_ condition: any StopCondition) -> StreamTextResult {
        StreamTextResult(
            stream: textStream.stopWhen(condition),
            model: model,
            settings: settings
        )
    }
    
    /// Convenience method for common stop patterns
    func stopOnString(_ text: String, caseSensitive: Bool = true) -> StreamTextResult {
        stopWhen(StringStopCondition(text, caseSensitive: caseSensitive))
    }
    
    func stopOnPattern(_ pattern: String) -> StreamTextResult {
        stopWhen(RegexStopCondition(pattern: pattern))
    }
    
    func stopAfterTokens(_ count: Int) -> StreamTextResult {
        stopWhen(TokenCountStopCondition(maxTokens: count))
    }
    
    func stopAfterTime(_ seconds: TimeInterval) -> StreamTextResult {
        stopWhen(TimeoutStopCondition(timeout: seconds))
    }
}