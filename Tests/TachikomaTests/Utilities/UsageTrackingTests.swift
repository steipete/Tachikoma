import Foundation
import Testing
@testable import Tachikoma

struct UsageTrackingTests {
    // MARK: - Session Management Tests

    @Test
    func `Session Creation and Management`() {
        let tracker = UsageTracker(forTesting: true)

        // Create a session
        let sessionId = tracker.startSession()
        #expect(!sessionId.isEmpty)

        // Session should exist and be active
        let session = tracker.getSession(sessionId)
        #expect(session != nil)
        #expect(session?.isComplete == false)
        #expect(tracker.activeSessions.count == 1)
        #expect(tracker.completedSessions.isEmpty)

        // End the session
        let endedSession = tracker.endSession(sessionId)
        #expect(endedSession != nil)
        #expect(endedSession?.isComplete == true)
        #expect(tracker.activeSessions.isEmpty)
        #expect(tracker.completedSessions.count == 1)
    }

    @Test
    func `Custom Session ID`() {
        let tracker = UsageTracker(forTesting: true)

        let customId = "my-custom-session-123"
        let sessionId = tracker.startSession(customId)

        #expect(sessionId == customId)

        let session = tracker.getSession(customId)
        #expect(session?.id == customId)
    }

    // MARK: - Usage Recording Tests

    @Test
    func `Usage Recording`() {
        let tracker = UsageTracker(forTesting: true)

        let sessionId = tracker.startSession()
        let model = LanguageModel.openai(.gpt5Mini)
        let usage = Usage(inputTokens: 100, outputTokens: 50)

        // Record usage
        tracker.recordUsage(
            sessionId: sessionId,
            model: model,
            usage: usage,
            operation: .textGeneration,
        )

        // Check that usage was recorded
        let session = tracker.getSession(sessionId)
        #expect(session?.operations.count == 1)
        #expect(session?.totalTokens == 150)

        let operation = session?.operations.first
        #expect(operation?.modelId == "gpt-5-mini")
        #expect(operation?.providerName == "OpenAI")
        #expect(operation?.usage.inputTokens == 100)
        #expect(operation?.usage.outputTokens == 50)
        #expect(operation?.type == .textGeneration)

        // Check that cost was calculated
        #expect(operation?.usage.cost != nil)
        if let cost = operation?.usage.cost {
            #expect(cost.total > 0)
        }
    }

    @Test
    func `Multiple Operations in Session`() {
        let tracker = UsageTracker(forTesting: true)

        let sessionId = tracker.startSession()
        let model = LanguageModel.openai(.gpt5Mini)

        // Record multiple operations
        tracker.recordUsage(
            sessionId: sessionId,
            model: model,
            usage: Usage(inputTokens: 100, outputTokens: 50),
            operation: .textGeneration,
        )

        tracker.recordUsage(
            sessionId: sessionId,
            model: model,
            usage: Usage(inputTokens: 200, outputTokens: 100),
            operation: .imageAnalysis,
        )

        let session = tracker.getSession(sessionId)
        #expect(session?.operations.count == 2)
        #expect(session?.totalTokens == 450) // 100+50 + 200+100

        let costs = session?.operations.compactMap { $0.usage.cost?.total } ?? []
        #expect(costs.count == 2)
        #expect(costs.reduce(0, +) > 0)
    }

    // MARK: - Cost Calculation Tests

    @Test
    func `Cost Calculation for Different Models`() {
        let calculator = ModelCostCalculator()
        let usage = Usage(inputTokens: 1_000_000, outputTokens: 1_000_000) // 1M tokens each for easy calculation

        // Test OpenAI pricing
        let gpt5MiniCost = calculator.calculateCost(for: .openai(.gpt5Mini), usage: usage)
        #expect(gpt5MiniCost.input == 1.00)
        #expect(gpt5MiniCost.output == 4.00)
        #expect(gpt5MiniCost.total == 5.00)

        // Test Anthropic pricing
        let claudeFableCost = calculator.calculateCost(for: .anthropic(.fable5), usage: usage)
        #expect(claudeFableCost.input == 10.00)
        #expect(claudeFableCost.output == 50.00)
        #expect(claudeFableCost.total == 60.00)

        let customClaudeFableCost = calculator.calculateCost(for: .anthropic(.custom("claude-fable-5")), usage: usage)
        #expect(customClaudeFableCost.input == 10.00)
        #expect(customClaudeFableCost.output == 50.00)
        #expect(customClaudeFableCost.total == 60.00)

        let claudeOpusCost = calculator.calculateCost(for: .anthropic(.opus48), usage: usage)
        #expect(claudeOpusCost.input == 5.00)
        #expect(claudeOpusCost.output == 25.00)
        #expect(claudeOpusCost.total == 30.00)

        let claudeHaikuCost = calculator.calculateCost(for: .anthropic(.haiku45), usage: usage)
        #expect(claudeHaikuCost.input == 1.20) // $1.20 per million input tokens
        #expect(claudeHaikuCost.output == 6.00) // $6.00 per million output tokens
        #expect(claudeHaikuCost.total == 7.20)

        // Test Google pricing
        let geminiFlashCost = calculator.calculateCost(for: .google(.gemini35Flash), usage: usage)
        #expect(geminiFlashCost.input == 1.50)
        #expect(geminiFlashCost.output == 9.00)
        #expect(geminiFlashCost.total == 10.50)

        // Test Grok pricing
        let grokCost = calculator.calculateCost(for: .grok(.grok43), usage: usage)
        #expect(grokCost.input == 1.25)
        #expect(grokCost.output == 2.50)
        #expect(grokCost.total == 3.75)

        let grok420Cost = calculator.calculateCost(for: .grok(.grok420Reasoning), usage: usage)
        #expect(grok420Cost.input == 1.25)
        #expect(grok420Cost.output == 2.50)
        #expect(grok420Cost.total == 3.75)

        // Test Ollama (should be free)
        let ollamaCost = calculator.calculateCost(for: .ollama(.llama33), usage: usage)
        #expect(ollamaCost.input == 0.0)
        #expect(ollamaCost.output == 0.0)
        #expect(ollamaCost.total == 0.0)
    }

    // MARK: - Total Usage Tests

    @Test
    func `Total Usage Aggregation`() {
        let tracker = UsageTracker(forTesting: true)

        // Create multiple sessions with different providers
        let session1 = tracker.startSession()
        tracker.recordUsage(
            sessionId: session1,
            model: .openai(.gpt5Mini),
            usage: Usage(inputTokens: 100, outputTokens: 50),
            operation: .textGeneration,
        )
        tracker.endSession(session1)

        let session2 = tracker.startSession()
        tracker.recordUsage(
            sessionId: session2,
            model: .anthropic(.haiku45),
            usage: Usage(inputTokens: 200, outputTokens: 100),
            operation: .imageAnalysis,
        )
        tracker.endSession(session2)

        let totalUsage = tracker.totalUsage
        #expect(totalUsage.totalSessions == 2)
        #expect(totalUsage.totalOperations == 2)
        #expect(totalUsage.totalTokens == 450) // 100+50 + 200+100
        #expect(totalUsage.totalCost > 0)

        // Check provider breakdown
        #expect(totalUsage.providerBreakdown.count == 2)
        #expect(totalUsage.providerBreakdown["OpenAI"] != nil)
        #expect(totalUsage.providerBreakdown["Anthropic"] != nil)

        // Check model breakdown
        #expect(totalUsage.modelBreakdown.count == 2)
        #expect(totalUsage.modelBreakdown[LanguageModel.openai(.gpt5Mini).modelId] != nil)
        #expect(totalUsage.modelBreakdown[LanguageModel.anthropic(.haiku45).modelId] != nil)

        // Check operation breakdown
        #expect(totalUsage.operationBreakdown.count == 2)
        #expect(totalUsage.operationBreakdown["text_generation"] != nil)
        #expect(totalUsage.operationBreakdown["image_analysis"] != nil)
    }

    // MARK: - Report Generation Tests

    @Test
    func `Usage Report Generation`() {
        let tracker = UsageTracker(forTesting: true)

        let sessionId = tracker.startSession()
        tracker.recordUsage(
            sessionId: sessionId,
            model: .openai(.gpt5Mini),
            usage: Usage(inputTokens: 1000, outputTokens: 500),
            operation: .textGeneration,
        )
        tracker.endSession(sessionId)

        // Generate a report for today
        let report = tracker.generateTodayReport()

        #expect(report.totalSessions == 1)
        #expect(report.totalOperations == 1)
        #expect(report.totalTokens == 1500)
        #expect(report.totalCost > 0)

        // Check formatted report
        let formattedReport = report.formattedReport()
        #expect(formattedReport.contains("Usage Report"))
        #expect(formattedReport.contains("Sessions: 1"))
        #expect(formattedReport.contains("Operations: 1"))
        #expect(formattedReport.contains("Total Tokens: 1500"))
        #expect(formattedReport.contains("OpenAI"))
        #expect(formattedReport.contains("gpt-5-mini"))
        #expect(formattedReport.contains("Text Generation"))
    }

    @Test
    func `Date Range Report`() {
        let tracker = UsageTracker(forTesting: true)

        let sessionId = tracker.startSession()
        tracker.recordUsage(
            sessionId: sessionId,
            model: .openai(.gpt5Mini),
            usage: Usage(inputTokens: 100, outputTokens: 50),
            operation: .textGeneration,
        )
        tracker.endSession(sessionId)

        let now = Date()
        let anHourAgo = now.addingTimeInterval(-3600)
        let inAnHour = now.addingTimeInterval(3600)

        // Report that includes the session
        let includeReport = tracker.generateReport(from: anHourAgo, to: inAnHour)
        #expect(includeReport.totalSessions == 1)

        // Report that excludes the session (future time range)
        let excludeReport = tracker.generateReport(from: inAnHour, to: inAnHour.addingTimeInterval(3600))
        #expect(excludeReport.totalSessions == 0)
    }

    // MARK: - Operation Type Tests

    @Test
    func `Operation Type Display Names`() {
        #expect(OperationType.textGeneration.displayName == "Text Generation")
        #expect(OperationType.textStreaming.displayName == "Text Streaming")
        #expect(OperationType.imageAnalysis.displayName == "Image Analysis")
        #expect(OperationType.toolCall.displayName == "Tool Call")
        #expect(OperationType.embedding.displayName == "Embedding")
        #expect(OperationType.transcription.displayName == "Transcription")
        #expect(OperationType.speechSynthesis.displayName == "Speech Synthesis")
    }

    @Test
    func `All Operation Types Available`() {
        let allTypes = OperationType.allCases
        #expect(allTypes.count == 8)
        #expect(allTypes.contains(.textGeneration))
        #expect(allTypes.contains(.textStreaming))
        #expect(allTypes.contains(.imageAnalysis))
        #expect(allTypes.contains(.objectGeneration))
        #expect(allTypes.contains(.toolCall))
        #expect(allTypes.contains(.embedding))
        #expect(allTypes.contains(.transcription))
        #expect(allTypes.contains(.speechSynthesis))
    }
}
