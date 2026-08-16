import Foundation
import Tachikoma
import Testing
@testable import TachikomaAudio

@Suite("Realtime tool executor timeouts")
struct RealtimeToolExecutorTimeoutTests {
    private actor ToolProbe {
        private var started = false
        private var waiters: [CheckedContinuation<Void, Never>] = []
        private var cancellationObserved = false
        private var cancellationWaiters: [CheckedContinuation<Void, Never>] = []
        private var cleanupReleased = false
        private var cleanupWaiters: [CheckedContinuation<Void, Never>] = []

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

        func markCancellationObserved() {
            self.cancellationObserved = true
            let waiters = self.cancellationWaiters
            self.cancellationWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }

        func waitUntilCancellationObserved() async {
            guard !self.cancellationObserved else { return }
            await withCheckedContinuation { continuation in
                self.cancellationWaiters.append(continuation)
            }
        }

        func waitForCleanupRelease() async {
            guard !self.cleanupReleased else { return }
            await withCheckedContinuation { continuation in
                self.cleanupWaiters.append(continuation)
            }
        }

        func releaseCleanup() {
            self.cleanupReleased = true
            let waiters = self.cleanupWaiters
            self.cleanupWaiters.removeAll()
            waiters.forEach { $0.resume() }
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

    private struct SlowCancellationTool: RealtimeExecutableTool {
        let probe: ToolProbe
        let metadata = RealtimeToolExecutor.ToolMetadata(
            name: "slow-cancellation",
            description: "Pauses cleanup after observing cancellation",
            parameters: AgentToolParameters(properties: [:], required: []),
        )

        func execute(_: RealtimeToolArguments) async -> String {
            await self.probe.markStarted()
            while !Task.isCancelled {
                await Task.yield()
            }
            await self.probe.markCancellationObserved()
            await self.probe.waitForCleanupRelease()
            return "done"
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

    @Test
    func `Deadline returns while delayed cleanup remains owned`() async {
        let probe = ToolProbe()
        let executor = RealtimeToolExecutor()
        await executor.register(SlowCancellationTool(probe: probe))
        let work = Task {
            await executor.execute(toolName: "slow-cancellation", arguments: "{}", timeout: 0.02)
        }

        await probe.waitUntilCancellationObserved()
        guard let execution = await Self.waitForExecution(executor) else {
            await probe.releaseCleanup()
            _ = await work.value
            Issue.record("Expected the elapsed deadline to return before delayed tool cleanup")
            return
        }

        if case .timeout = execution.result {
            // Expected.
        } else {
            Issue.record("Expected elapsed deadline to remain a timeout, got \(execution.result)")
        }
        #expect(await executor.pendingToolTaskCount() == 1)
        _ = await work.value

        await probe.releaseCleanup()
        #expect(await Self.waitForPendingTaskDrain(executor))
    }

    @Test
    func `Caller cancellation returns while delayed cleanup remains owned`() async {
        let probe = ToolProbe()
        let executor = RealtimeToolExecutor()
        await executor.register(SlowCancellationTool(probe: probe))
        let work = Task {
            await executor.execute(toolName: "slow-cancellation", arguments: "{}", timeout: 30)
        }

        await probe.waitUntilStarted()
        work.cancel()
        await probe.waitUntilCancellationObserved()
        guard let execution = await Self.waitForExecution(executor) else {
            await probe.releaseCleanup()
            _ = await work.value
            Issue.record("Expected caller cancellation to return before delayed tool cleanup")
            return
        }

        if case let .failure(message) = execution.result {
            #expect(message == "cancelled")
        } else {
            Issue.record("Expected caller cancellation failure, got \(execution.result)")
        }
        #expect(await executor.pendingToolTaskCount() == 1)
        _ = await work.value

        await probe.releaseCleanup()
        #expect(await Self.waitForPendingTaskDrain(executor))
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

    private static func waitForExecution(
        _ executor: RealtimeToolExecutor,
    ) async
        -> RealtimeToolExecutor.ToolExecution?
    {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while clock.now < deadline {
            if let execution = await executor.getHistory(limit: 1).last {
                return execution
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return nil
    }

    private static func waitForPendingTaskDrain(_ executor: RealtimeToolExecutor) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while clock.now < deadline {
            if await executor.pendingToolTaskCount() == 0 {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
}
