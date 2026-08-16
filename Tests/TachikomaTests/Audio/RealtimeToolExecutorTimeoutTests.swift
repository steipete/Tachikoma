import Foundation
import Tachikoma
import TachikomaAudio
import Testing

@Suite("Realtime tool executor timeouts")
struct RealtimeToolExecutorTimeoutTests {
    private actor ToolProbe {
        private var started = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func markStarted() {
            self.started = true
            let waiters = self.waiters
            self.waiters.removeAll()
            waiters.forEach { $0.resume() }
        }

        func waitUntilStarted() async {
            guard !self.started else { return }
            await withCheckedContinuation { continuation in
                self.waiters.append(continuation)
            }
        }

        func didStart() -> Bool {
            self.started
        }
    }

    private struct HangTool: RealtimeExecutableTool {
        let probe: ToolProbe
        let metadata = RealtimeToolExecutor.ToolMetadata(
            name: "hang",
            description: "Blocks until cancelled",
            parameters: AgentToolParameters(properties: [:], required: []),
        )

        func execute(_: RealtimeToolArguments) async -> String {
            await self.probe.markStarted()
            while !Task.isCancelled {
                await Task.yield()
            }
            return "done"
        }
    }

    private struct ImmediateTool: RealtimeExecutableTool {
        let metadata = RealtimeToolExecutor.ToolMetadata(
            name: "immediate",
            description: "Returns immediately",
            parameters: AgentToolParameters(properties: [:], required: []),
        )

        func execute(_: RealtimeToolArguments) async -> String {
            "done"
        }
    }

    @Test(arguments: [30, Double(Int64.max / 2)])
    func `Completed tool is not reclassified when its deadline is cancelled`(timeout: TimeInterval) async {
        let executor = RealtimeToolExecutor()
        await executor.register(ImmediateTool())

        let execution = await executor.execute(toolName: "immediate", arguments: "{}", timeout: timeout)

        guard case let .success(result) = execution.result else {
            Issue.record("Expected completed tool to succeed, got \(execution.result)")
            return
        }
        #expect(result == "done")
    }

    @Test
    func `Parent cancel is not reported as a tool timeout`() async {
        let probe = ToolProbe()
        let executor = RealtimeToolExecutor()
        await executor.register(HangTool(probe: probe))
        let work = Task {
            await executor.execute(toolName: "hang", arguments: "{}", timeout: 30)
        }
        await probe.waitUntilStarted()
        work.cancel()
        let execution = await work.value

        guard case let .failure(message) = execution.result else {
            Issue.record("Expected parent cancellation to be recorded as a failure, got \(execution.result)")
            return
        }
        #expect(message == "cancelled")
    }

    @Test
    func `Elapsed deadline is still reported as a tool timeout`() async {
        let probe = ToolProbe()
        let executor = RealtimeToolExecutor()
        await executor.register(HangTool(probe: probe))

        let execution = await executor.execute(toolName: "hang", arguments: "{}", timeout: 0.02)

        guard case .timeout = execution.result else {
            Issue.record("Expected elapsed deadline to be recorded as timeout, got \(execution.result)")
            return
        }
    }

    @Test(arguments: [0, -1, .infinity, .nan, Double(Int64.max / 2).nextUp, .greatestFiniteMagnitude])
    func `Invalid deadlines fail closed as timeouts`(timeout: TimeInterval) async {
        let probe = ToolProbe()
        let executor = RealtimeToolExecutor()
        await executor.register(HangTool(probe: probe))

        let execution = await executor.execute(toolName: "hang", arguments: "{}", timeout: timeout)

        guard case .timeout = execution.result else {
            Issue.record("Expected invalid deadline to be recorded as timeout, got \(execution.result)")
            return
        }
        #expect(await probe.didStart() == false)
    }
}
