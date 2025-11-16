import Foundation
import Tachikoma
import TachikomaAgent

/// Terminal colors for fancy output
enum TerminalColor {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"

    // Foreground colors
    static let black = "\u{001B}[30m"
    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let blue = "\u{001B}[34m"
    static let magenta = "\u{001B}[35m"
    static let cyan = "\u{001B}[36m"
    static let white = "\u{001B}[37m"
    static let gray = "\u{001B}[90m"

    // Background colors
    static let bgRed = "\u{001B}[41m"
    static let bgGreen = "\u{001B}[42m"
    static let bgYellow = "\u{001B}[43m"
    static let bgBlue = "\u{001B}[44m"
    static let bgMagenta = "\u{001B}[45m"
    static let bgCyan = "\u{001B}[46m"
}

/// Manages the terminal UI with status bar, spinners, and fancy output
final class StatusBarUI: @unchecked Sendable {
    private let outputFormat: OutputFormat
    private let verbose: Bool
    private let quiet: Bool
    private var spinner: Spinner?
    private var currentTask: String?
    private let startTime = Date()

    init(outputFormat: OutputFormat, verbose: Bool, quiet: Bool) {
        self.outputFormat = outputFormat
        self.verbose = verbose
        self.quiet = quiet
    }

    // MARK: - Headers and Info

    func showHeader(_ text: String) {
        guard !self.quiet else { return }

        let separator = String(repeating: "─", count: 50)
        print("\n\(TerminalColor.cyan)\(TerminalColor.bold)\(text)\(TerminalColor.reset)")
        print("\(TerminalColor.dim)\(separator)\(TerminalColor.reset)")
    }

    func showInfo(_ text: String) {
        guard !self.quiet else { return }
        print("\(TerminalColor.gray)ℹ️  \(text)\(TerminalColor.reset)")
    }

    func showSuccess(_ text: String) {
        guard !self.quiet else { return }
        print("\(TerminalColor.green)✅ \(text)\(TerminalColor.reset)")
    }

    func showWarning(_ text: String) {
        guard !self.quiet else { return }
        print("\(TerminalColor.yellow)⚠️  \(text)\(TerminalColor.reset)")
    }

    func showError(_ text: String) {
        print("\(TerminalColor.red)❌ \(text)\(TerminalColor.reset)")
    }

    // MARK: - Task Management

    func startTask(_ description: String) {
        guard !self.quiet else { return }

        self.currentTask = description

        if self.outputFormat == .json {
            print(#"{"event": "task_start", "description": "\#(description)"}"#)
        } else {
            // Start spinner animation
            self.spinner = Spinner(pattern: .dots, text: description)
            self.spinner?.start()
        }

        self.updateTerminalTitle(description)
    }

    func updateTask(_ status: String) {
        guard !self.quiet else { return }

        if self.outputFormat == .json {
            print(#"{"event": "task_update", "status": "\#(status)"}"#)
        } else if let spinner {
            spinner.text = status
        }

        self.updateTerminalTitle(status)
    }

    func completeTask() {
        guard !self.quiet else { return }

        self.spinner?.stop()
        self.spinner = nil

        if self.outputFormat == .json {
            print(#"{"event": "task_complete"}"#)
        }

        self.updateTerminalTitle("Ready")
    }

    // MARK: - Content Display

    func showResponse(_ text: String) {
        if self.outputFormat == .json {
            let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
            print(#"{"response": "\#(escaped)"}"#)
        } else {
            print(text)
        }
    }

    func showMarkdown(_ text: String) {
        // Simple markdown rendering for terminal
        let lines = text.split(separator: "\n")

        for line in lines {
            if line.starts(with: "# ") {
                // H1 header
                print("\n\(TerminalColor.bold)\(TerminalColor.cyan)\(line.dropFirst(2))\(TerminalColor.reset)")
            } else if line.starts(with: "## ") {
                // H2 header
                print("\n\(TerminalColor.bold)\(TerminalColor.blue)\(line.dropFirst(3))\(TerminalColor.reset)")
            } else if line.starts(with: "### ") {
                // H3 header
                print("\n\(TerminalColor.bold)\(line.dropFirst(4))\(TerminalColor.reset)")
            } else if line.starts(with: "- ") || line.starts(with: "* ") {
                // List item
                print("  • \(line.dropFirst(2))")
            } else if line.starts(with: "```") {
                // Code block marker
                print("\(TerminalColor.gray)───────────────\(TerminalColor.reset)")
            } else if line.starts(with: "    ") || line.starts(with: "\t") {
                // Code line
                print("\(TerminalColor.gray)\(line)\(TerminalColor.reset)")
            } else if line.starts(with: "> ") {
                // Quote
                print("\(TerminalColor.dim)│ \(line.dropFirst(2))\(TerminalColor.reset)")
            } else {
                // Regular text
                print(line)
            }
        }
    }

    func showThinking(_ text: String) {
        guard !self.quiet else { return }

        if self.verbose {
            print("\n\(TerminalColor.magenta)💭 Thinking: \(text)\(TerminalColor.reset)")
        } else {
            // Show subtle thinking indicator
            print("\(TerminalColor.gray)💭 \(text)\(TerminalColor.reset)", terminator: "")
            fflush(stdout)
        }
    }

    // MARK: - Tool Display

    func showToolCall(name: String, arguments: String) {
        guard !self.quiet else { return }

        if self.outputFormat == .json {
            print(#"{"event": "tool_call", "name": "\#(name)", "arguments": \#(arguments)}"#)
        } else if self.verbose {
            print("\n\(TerminalColor.blue)🔧 Calling tool: \(name)\(TerminalColor.reset)")
            if let formattedArgs = formatJSON(arguments) {
                print("\(TerminalColor.gray)Arguments:\(TerminalColor.reset)")
                print(formattedArgs)
            }
        } else {
            print("\n\(TerminalColor.blue)🔧 \(name)\(TerminalColor.reset)", terminator: "")
            fflush(stdout)
        }
    }

    func showToolResult(name: String, result: String, duration: TimeInterval) {
        guard !self.quiet else { return }

        let durationStr = self.formatDuration(duration)

        if self.outputFormat == .json {
            print(#"{"event": "tool_result", "name": "\#(name)", "duration": \#(duration)}"#)
        } else if self.verbose {
            print("\(TerminalColor.green)✓ Completed in \(durationStr)\(TerminalColor.reset)")
            if let formattedResult = formatJSON(result) {
                print("\(TerminalColor.gray)Result:\(TerminalColor.reset)")
                print(formattedResult)
            }
        } else {
            print(
                " \(TerminalColor.green)✓\(TerminalColor.reset) \(TerminalColor.gray)(\(durationStr))\(TerminalColor.reset)",
            )
        }
    }

    func showToolUsage(_ tools: [String]) {
        guard !self.quiet, !tools.isEmpty else { return }

        let toolList = tools.joined(separator: ", ")
        print("\n\(TerminalColor.gray)🔧 Tools used: \(toolList)\(TerminalColor.reset)")
    }

    // MARK: - Statistics

    func showStats(toolCalls: Int, tokens: Int, duration: TimeInterval) {
        guard !self.quiet else { return }

        let durationStr = self.formatDuration(duration)
        let toolStr = toolCalls == 1 ? "1 tool" : "\(toolCalls) tools"

        print("\n\(TerminalColor.gray)───────────────────────────────────────\(TerminalColor.reset)")
        print("\(TerminalColor.gray)📊 Stats: \(toolStr), \(tokens) tokens, \(durationStr)\(TerminalColor.reset)")
    }

    // MARK: - Private Helpers

    private func updateTerminalTitle(_ text: String) {
        // Update terminal title with current status
        print("\u{001B}]0;Agent CLI - \(text)\u{0007}", terminator: "")
        fflush(stdout)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 0.001 {
            return String(format: "%.0fµs", seconds * 1_000_000)
        } else if seconds < 1.0 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60.0 {
            return String(format: "%.1fs", seconds)
        } else {
            let minutes = Int(seconds / 60)
            let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
            return String(format: "%dm %ds", minutes, remainingSeconds)
        }
    }

    private func formatJSON(_ json: String) -> String? {
        guard
            let data = json.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data),
            let formatted = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
            let result = String(data: formatted, encoding: .utf8) else
        {
            return nil
        }

        // Add gray coloring to JSON
        let lines = result.split(separator: "\n")
        return lines.map { "\(TerminalColor.gray)  \($0)\(TerminalColor.reset)" }.joined(separator: "\n")
    }
}

// MARK: - Spinner Animation

/// Simple spinner animation for terminal
final class Spinner {
    enum Pattern {
        case dots
        case line
        case circle

        var frames: [String] {
            switch self {
            case .dots:
                ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
            case .line:
                ["-", "\\", "|", "/"]
            case .circle:
                ["◐", "◓", "◑", "◒"]
            }
        }
    }

    private let pattern: Pattern
    var text: String
    private var timer: Timer?
    private var frameIndex = 0
    private var isRunning = false

    init(pattern: Pattern = .dots, text: String) {
        self.pattern = pattern
        self.text = text
    }

    func start() {
        guard !self.isRunning else { return }
        self.isRunning = true

        // Hide cursor
        print("\u{001B}[?25l", terminator: "")

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.render()
        }

        // Ensure timer runs
        if let timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    func stop() {
        guard self.isRunning else { return }
        self.isRunning = false

        self.timer?.invalidate()
        self.timer = nil

        // Clear line and show cursor
        print("\r\u{001B}[K", terminator: "")
        print("\u{001B}[?25h", terminator: "")
        fflush(stdout)
    }

    private func render() {
        let frames = self.pattern.frames
        let frame = frames[frameIndex % frames.count]
        self.frameIndex += 1

        // Clear line and print new frame
        print("\r\u{001B}[K\(TerminalColor.cyan)\(frame)\(TerminalColor.reset) \(self.text)", terminator: "")
        fflush(stdout)
    }
}
