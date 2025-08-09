//
//  AgentEventHandler.swift
//  Tachikoma
//

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
        case .started(let task):
            handleStarted(task)
            
        case .thinking(let content):
            handleThinking(content)
            
        case .toolCallStarted(let name, let arguments):
            handleToolCallStarted(name: name, arguments: arguments)
            
        case .toolCallCompleted(let name, let result):
            handleToolCallCompleted(name: name, result: result)
            
        case .toolCallFailed(let name, let error):
            handleToolCallFailed(name: name, error: error)
            
        case .streamingContent(let content):
            handleStreamingContent(content)
            
        case .completed(let summary):
            handleCompleted(summary)
            
        case .error(let error):
            handleError(error)
            
        case .statusUpdate(let status):
            handleStatusUpdate(status)
        }
    }
    
    private func handleStarted(_ task: String) {
        ui.startTask(task)
    }
    
    private func handleThinking(_ content: String) {
        if showThinking {
            ui.showThinking(content)
        }
    }
    
    private func handleToolCallStarted(name: String, arguments: String) {
        toolStartTimes[name] = Date()
        ui.showToolCall(name: name, arguments: arguments)
    }
    
    private func handleToolCallCompleted(name: String, result: String) {
        let duration: TimeInterval
        if let startTime = toolStartTimes[name] {
            duration = Date().timeIntervalSince(startTime)
            toolStartTimes.removeValue(forKey: name)
        } else {
            duration = 0
        }
        
        ui.showToolResult(name: name, result: result, duration: duration)
    }
    
    private func handleToolCallFailed(name: String, error: Error) {
        ui.showError("Tool '\(name)' failed: \(error.localizedDescription)")
    }
    
    private func handleStreamingContent(_ content: String) {
        // For streaming, print directly without newline
        print(content, terminator: "")
        fflush(stdout)
    }
    
    private func handleCompleted(_ summary: String) {
        ui.completeTask()
        if !summary.isEmpty {
            ui.showInfo("Summary: \(summary)")
        }
    }
    
    private func handleError(_ error: Error) {
        ui.showError(error.localizedDescription)
    }
    
    private func handleStatusUpdate(_ status: String) {
        ui.updateTask(status)
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