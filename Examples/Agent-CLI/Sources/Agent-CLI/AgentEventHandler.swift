import Foundation
import Tachikoma
import TachikomaAgent

/// Handles agent events and updates the UI accordingly
final class AgentEventHandler: AgentEventDelegate {
    private let ui: StatusBarUI
    private let showThinking: Bool
    private var toolStartTimes: [String: Date] = [:]

    init(ui: StatusBarUI, showThinking: Bool) {
        self.ui = ui
        self.showThinking = showThinking
    }

    func agentDidEmitEvent(_ event: AgentEvent) {
        switch event {
        case let .started(task):
            self.handleStarted(task)

        case let .thinking(content):
            self.handleThinking(content)

        case let .toolCallStarted(name, arguments):
            self.handleToolCallStarted(name: name, arguments: arguments)

        case let .toolCallCompleted(name, result):
            self.handleToolCallCompleted(name: name, result: result)

        case let .toolCallFailed(name, error):
            self.handleToolCallFailed(name: name, error: error)

        case let .streamingContent(content):
            self.handleStreamingContent(content)

        case let .completed(summary):
            self.handleCompleted(summary)

        case let .error(error):
            self.handleError(error)

        case let .statusUpdate(status):
            self.handleStatusUpdate(status)
        }
    }

    private func handleStarted(_ task: String) {
        self.ui.startTask(task)
    }

    private func handleThinking(_ content: String) {
        if self.showThinking {
            self.ui.showThinking(content)
        }
    }

    private func handleToolCallStarted(name: String, arguments: String) {
        self.toolStartTimes[name] = Date()
        self.ui.showToolCall(name: name, arguments: arguments)
    }

    private func handleToolCallCompleted(name: String, result: String) {
        let duration: TimeInterval
        if let startTime = toolStartTimes[name] {
            duration = Date().timeIntervalSince(startTime)
            self.toolStartTimes.removeValue(forKey: name)
        } else {
            duration = 0
        }

        self.ui.showToolResult(name: name, result: result, duration: duration)
    }

    private func handleToolCallFailed(name: String, error: Error) {
        self.ui.showError("Tool '\(name)' failed: \(error.localizedDescription)")
    }

    private func handleStreamingContent(_ content: String) {
        // For streaming, print directly without newline
        print(content, terminator: "")
        fflush(stdout)
    }

    private func handleCompleted(_ summary: String) {
        self.ui.completeTask()
        if !summary.isEmpty {
            self.ui.showInfo("Summary: \(summary)")
        }
    }

    private func handleError(_ error: Error) {
        self.ui.showError(error.localizedDescription)
    }

    private func handleStatusUpdate(_ status: String) {
        self.ui.updateTask(status)
    }
}

// MARK: - Agent Event Types

enum AgentEvent {
    case started(String)
    case thinking(String)
    case toolCallStarted(name: String, arguments: String)
    case toolCallCompleted(name: String, result: String)
    case toolCallFailed(name: String, error: Error)
    case streamingContent(String)
    case completed(String)
    case error(Error)
    case statusUpdate(String)
}

protocol AgentEventDelegate: AnyObject {
    func agentDidEmitEvent(_ event: AgentEvent)
}
