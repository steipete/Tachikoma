import Foundation

// MARK: - Usage Tracking and Cost Calculation

/// Usage tracking and cost calculation system for Tachikoma AI SDK
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class UsageTracker: @unchecked Sendable {
    
    /// Shared usage tracker instance
    public static let shared = UsageTracker()
    
    private let lock = NSLock()
    private var _sessions: [String: UsageSession] = [:]
    private var _totalUsage = TotalUsage()
    private var _costCalculator = ModelCostCalculator()
    
    private init() {}
    
    // MARK: - Session Management
    
    /// Start a new usage session
    /// - Parameter sessionId: Optional session ID. If nil, generates a new UUID
    /// - Returns: The session ID for tracking
    public func startSession(_ sessionId: String? = nil) -> String {
        let id = sessionId ?? UUID().uuidString
        let session = UsageSession(id: id, startTime: Date())
        
        lock.withLock {
            _sessions[id] = session
        }
        
        return id
    }
    
    /// End a usage session
    /// - Parameter sessionId: The session ID to end
    /// - Returns: The final session usage data
    @discardableResult
    public func endSession(_ sessionId: String) -> UsageSession? {
        return lock.withLock {
            guard let session = _sessions[sessionId] else { return nil }
            
            let finalSession = session.ended()
            _sessions[sessionId] = finalSession
            
            // Add to total usage
            _totalUsage.addSession(finalSession)
            
            return finalSession
        }
    }
    
    /// Record usage for a session
    /// - Parameters:
    ///   - sessionId: The session ID
    ///   - model: The model used
    ///   - usage: The usage statistics
    ///   - operation: The type of operation performed
    public func recordUsage(
        sessionId: String,
        model: LanguageModel,
        usage: Usage,
        operation: OperationType = .textGeneration
    ) {
        lock.withLock {
            guard let session = _sessions[sessionId] else { return }
            
            let cost = _costCalculator.calculateCost(for: model, usage: usage)
            let enhancedUsage = Usage(
                inputTokens: usage.inputTokens,
                outputTokens: usage.outputTokens,
                cost: cost
            )
            
            let updatedSession = session.addingUsage(
                model: model,
                usage: enhancedUsage,
                operation: operation
            )
            
            _sessions[sessionId] = updatedSession
        }
    }
    
    /// Get current session data
    /// - Parameter sessionId: The session ID
    /// - Returns: The current session data if it exists
    public func getSession(_ sessionId: String) -> UsageSession? {
        return lock.withLock {
            return _sessions[sessionId]
        }
    }
    
    /// Get all active sessions
    public var activeSessions: [UsageSession] {
        return lock.withLock {
            return Array(_sessions.values.filter { !$0.isComplete })
        }
    }
    
    /// Get all completed sessions
    public var completedSessions: [UsageSession] {
        return lock.withLock {
            return Array(_sessions.values.filter { $0.isComplete })
        }
    }
    
    // MARK: - Total Usage
    
    /// Get total usage across all sessions
    public var totalUsage: TotalUsage {
        return lock.withLock {
            return _totalUsage
        }
    }
    
    /// Reset all usage data
    public func reset() {
        lock.withLock {
            _sessions.removeAll()
            _totalUsage = TotalUsage()
        }
    }
    
    // MARK: - Reporting
    
    /// Generate a usage report for a date range
    /// - Parameters:
    ///   - startDate: Start date for the report
    ///   - endDate: End date for the report
    /// - Returns: Usage report for the specified period
    public func generateReport(from startDate: Date, to endDate: Date) -> UsageReport {
        let sessions = lock.withLock {
            return Array(_sessions.values.filter { session in
                session.startTime >= startDate && session.startTime <= endDate
            })
        }
        
        return UsageReport(
            startDate: startDate,
            endDate: endDate,
            sessions: sessions,
            costCalculator: _costCalculator
        )
    }
    
    /// Generate a usage report for today
    public func generateTodayReport() -> UsageReport {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? today
        
        return generateReport(from: startOfDay, to: endOfDay)
    }
    
    /// Generate a usage report for this month
    public func generateMonthReport() -> UsageReport {
        let calendar = Calendar.current
        let today = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        let endOfMonth = calendar.dateInterval(of: .month, for: today)?.end ?? today
        
        return generateReport(from: startOfMonth, to: endOfMonth)
    }
}

// MARK: - Usage Session

/// Represents a single usage session
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct UsageSession: Sendable, Codable {
    public let id: String
    public let startTime: Date
    public let endTime: Date?
    public let operations: [UsageOperation]
    
    public var isComplete: Bool {
        return endTime != nil
    }
    
    public var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    public var totalTokens: Int {
        return operations.reduce(0) { $0 + $1.usage.totalTokens }
    }
    
    public var totalCost: Double {
        return operations.compactMap { $0.usage.cost?.total }.reduce(0, +)
    }
    
    init(id: String, startTime: Date) {
        self.id = id
        self.startTime = startTime
        self.endTime = nil
        self.operations = []
    }
    
    private init(id: String, startTime: Date, endTime: Date?, operations: [UsageOperation]) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.operations = operations
    }
    
    /// Create a new session with an operation added
    func addingUsage(model: LanguageModel, usage: Usage, operation: OperationType) -> UsageSession {
        let newOperation = UsageOperation(
            timestamp: Date(),
            model: model,
            usage: usage,
            type: operation
        )
        
        return UsageSession(
            id: id,
            startTime: startTime,
            endTime: endTime,
            operations: operations + [newOperation]
        )
    }
    
    /// Create a new session marked as ended
    func ended() -> UsageSession {
        return UsageSession(
            id: id,
            startTime: startTime,
            endTime: Date(),
            operations: operations
        )
    }
}

// MARK: - Usage Operation

/// Represents a single operation within a session
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct UsageOperation: Sendable, Codable {
    public let timestamp: Date
    public let modelId: String
    public let providerName: String
    public let usage: Usage
    public let type: OperationType
    
    public init(timestamp: Date, model: LanguageModel, usage: Usage, type: OperationType) {
        self.timestamp = timestamp
        self.modelId = model.modelId
        self.providerName = model.providerName
        self.usage = usage
        self.type = type
    }
    
    // For backward compatibility, provide a computed property to reconstruct model info
    public var modelDescription: String {
        return "\(providerName)/\(modelId)"
    }
}

// MARK: - Operation Type

/// Types of operations that can be tracked
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum OperationType: String, Sendable, Codable, CaseIterable {
    case textGeneration = "text_generation"
    case textStreaming = "text_streaming"
    case imageAnalysis = "image_analysis"
    case objectGeneration = "object_generation"
    case toolCall = "tool_call"
    case embedding = "embedding"
    case transcription = "transcription"
    case speechSynthesis = "speech_synthesis"
    
    public var displayName: String {
        switch self {
        case .textGeneration: return "Text Generation"
        case .textStreaming: return "Text Streaming"
        case .imageAnalysis: return "Image Analysis"
        case .objectGeneration: return "Object Generation"
        case .toolCall: return "Tool Call"
        case .embedding: return "Embedding"
        case .transcription: return "Transcription"
        case .speechSynthesis: return "Speech Synthesis"
        }
    }
}

// MARK: - Total Usage

/// Aggregated usage statistics across all sessions
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct TotalUsage: Sendable, Codable {
    public var totalSessions: Int = 0
    public var totalOperations: Int = 0
    public var totalTokens: Int = 0
    public var totalCost: Double = 0.0
    public var providerBreakdown: [String: ProviderUsage] = [:]
    public var modelBreakdown: [String: ModelUsage] = [:]
    public var operationBreakdown: [String: OperationUsage] = [:]
    
    mutating func addSession(_ session: UsageSession) {
        totalSessions += 1
        totalOperations += session.operations.count
        totalTokens += session.totalTokens
        totalCost += session.totalCost
        
        for operation in session.operations {
            let providerName = operation.providerName
            let modelName = operation.modelId
            let operationType = operation.type.rawValue
            
            // Update provider breakdown
            var providerUsage = providerBreakdown[providerName] ?? ProviderUsage()
            providerUsage.addOperation(operation)
            providerBreakdown[providerName] = providerUsage
            
            // Update model breakdown
            var modelUsage = modelBreakdown[modelName] ?? ModelUsage()
            modelUsage.addOperation(operation)
            modelBreakdown[modelName] = modelUsage
            
            // Update operation type breakdown
            var opUsage = operationBreakdown[operationType] ?? OperationUsage()
            opUsage.addOperation(operation)
            operationBreakdown[operationType] = opUsage
        }
    }
}

// MARK: - Breakdown Structures

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ProviderUsage: Sendable, Codable {
    public var operations: Int = 0
    public var tokens: Int = 0
    public var cost: Double = 0.0
    
    mutating func addOperation(_ operation: UsageOperation) {
        operations += 1
        tokens += operation.usage.totalTokens
        cost += operation.usage.cost?.total ?? 0.0
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModelUsage: Sendable, Codable {
    public var operations: Int = 0
    public var tokens: Int = 0
    public var cost: Double = 0.0
    
    mutating func addOperation(_ operation: UsageOperation) {
        operations += 1
        tokens += operation.usage.totalTokens
        cost += operation.usage.cost?.total ?? 0.0
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OperationUsage: Sendable, Codable {
    public var operations: Int = 0
    public var tokens: Int = 0
    public var cost: Double = 0.0
    
    mutating func addOperation(_ operation: UsageOperation) {
        operations += 1
        tokens += operation.usage.totalTokens
        cost += operation.usage.cost?.total ?? 0.0
    }
}

// MARK: - Usage Report

/// Comprehensive usage report for a specific time period
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct UsageReport: Sendable {
    public let startDate: Date
    public let endDate: Date
    public let sessions: [UsageSession]
    
    public var totalSessions: Int { sessions.count }
    public var totalOperations: Int { sessions.reduce(0) { $0 + $1.operations.count } }
    public var totalTokens: Int { sessions.reduce(0) { $0 + $1.totalTokens } }
    public var totalCost: Double { sessions.reduce(0) { $0 + $1.totalCost } }
    
    public let providerBreakdown: [String: ProviderUsage]
    public let modelBreakdown: [String: ModelUsage]
    public let operationBreakdown: [String: OperationUsage]
    
    init(startDate: Date, endDate: Date, sessions: [UsageSession], costCalculator: ModelCostCalculator) {
        self.startDate = startDate
        self.endDate = endDate
        self.sessions = sessions
        
        // Calculate breakdowns
        var providers: [String: ProviderUsage] = [:]
        var models: [String: ModelUsage] = [:]
        var operations: [String: OperationUsage] = [:]
        
        for session in sessions {
            for operation in session.operations {
                let providerName = operation.providerName
                let modelName = operation.modelId
                let operationType = operation.type.rawValue
                
                var providerUsage = providers[providerName] ?? ProviderUsage()
                providerUsage.addOperation(operation)
                providers[providerName] = providerUsage
                
                var modelUsage = models[modelName] ?? ModelUsage()
                modelUsage.addOperation(operation)
                models[modelName] = modelUsage
                
                var opUsage = operations[operationType] ?? OperationUsage()
                opUsage.addOperation(operation)
                operations[operationType] = opUsage
            }
        }
        
        self.providerBreakdown = providers
        self.modelBreakdown = models
        self.operationBreakdown = operations
    }
    
    /// Generate a formatted text report
    public func formattedReport() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var lines: [String] = []
        lines.append("Usage Report")
        lines.append("============")
        lines.append("Period: \(formatter.string(from: startDate)) - \(formatter.string(from: endDate))")
        lines.append("")
        
        lines.append("Summary:")
        lines.append("  Sessions: \(totalSessions)")
        lines.append("  Operations: \(totalOperations)")
        lines.append("  Total Tokens: \(totalTokens)")
        lines.append("  Total Cost: $\(String(format: "%.4f", totalCost))")
        lines.append("")
        
        if !providerBreakdown.isEmpty {
            lines.append("By Provider:")
            for (provider, usage) in providerBreakdown.sorted(by: { $0.value.cost > $1.value.cost }) {
                lines.append("  \(provider): \(usage.operations) ops, \(usage.tokens) tokens, $\(String(format: "%.4f", usage.cost))")
            }
            lines.append("")
        }
        
        if !modelBreakdown.isEmpty {
            lines.append("By Model:")
            for (model, usage) in modelBreakdown.sorted(by: { $0.value.cost > $1.value.cost }) {
                lines.append("  \(model): \(usage.operations) ops, \(usage.tokens) tokens, $\(String(format: "%.4f", usage.cost))")
            }
            lines.append("")
        }
        
        if !operationBreakdown.isEmpty {
            lines.append("By Operation Type:")
            for (operation, usage) in operationBreakdown.sorted(by: { $0.value.cost > $1.value.cost }) {
                let displayName = OperationType(rawValue: operation)?.displayName ?? operation
                lines.append("  \(displayName): \(usage.operations) ops, \(usage.tokens) tokens, $\(String(format: "%.4f", usage.cost))")
            }
        }
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - Model Cost Calculator

/// Calculates costs for different AI models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ModelCostCalculator: Sendable {
    
    /// Calculate cost for a model usage
    public func calculateCost(for model: LanguageModel, usage: Usage) -> Usage.Cost {
        let pricing = getPricing(for: model)
        
        let inputCost = Double(usage.inputTokens) * pricing.input / 1_000_000.0
        let outputCost = Double(usage.outputTokens) * pricing.output / 1_000_000.0
        
        return Usage.Cost(input: inputCost, output: outputCost)
    }
    
    /// Get pricing information for a model (per million tokens)
    private func getPricing(for model: LanguageModel) -> (input: Double, output: Double) {
        switch model {
        // OpenAI Pricing (as of 2025)
        case .openai(let openaiModel):
            switch openaiModel {
            case .o3: return (60.00, 240.00)
            case .o3Mini: return (1.00, 4.00)
            case .o3Pro: return (120.00, 480.00)
            case .o4Mini: return (1.50, 6.00)
            case .gpt4_1: return (2.50, 10.00)
            case .gpt4_1Mini: return (0.15, 0.60)
            case .gpt4o: return (2.50, 10.00)
            case .gpt4oMini: return (0.15, 0.60)
            case .gpt4Turbo: return (10.00, 30.00)
            case .gpt35Turbo: return (0.50, 1.50)
            case .custom: return (2.50, 10.00) // Default estimate
            }
            
        // Anthropic Pricing (as of 2025)
        case .anthropic(let anthropicModel):
            switch anthropicModel {
            case .opus4, .opus4Thinking: return (15.00, 75.00)
            case .sonnet4, .sonnet4Thinking: return (3.00, 15.00)
            case .sonnet3_7: return (3.00, 15.00)
            case .opus3_5: return (15.00, 75.00)
            case .sonnet3_5: return (3.00, 15.00)
            case .haiku3_5: return (0.80, 4.00)
            case .opus3: return (15.00, 75.00)
            case .sonnet3: return (3.00, 15.00)
            case .haiku3: return (0.25, 1.25)
            case .custom: return (3.00, 15.00) // Default estimate
            }
            
        // Google Pricing (estimates)
        case .google(let googleModel):
            switch googleModel {
            case .gemini2Flash, .gemini2FlashThinking: return (1.00, 4.00)
            case .gemini15Pro: return (7.00, 21.00)
            case .gemini15Flash, .gemini15Flash8B: return (0.35, 1.40)
            case .geminiPro, .geminiProVision: return (0.50, 1.50)
            }
            
        // Other providers - estimates
        case .mistral: return (2.00, 6.00)
        case .groq: return (0.27, 0.27) // Groq has very low pricing
        case .grok: return (2.00, 8.00)
        case .ollama: return (0.00, 0.00) // Local inference
        case .openRouter, .together, .replicate: return (1.00, 3.00) // Typical aggregator pricing
        case .openaiCompatible, .anthropicCompatible: return (2.00, 6.00)
        case .custom: return (2.00, 6.00)
        }
    }
}