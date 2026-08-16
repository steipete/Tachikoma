import Foundation
import Tachikoma
import TachikomaAudio
import Testing

@Suite("Realtime tool executor timeouts")
struct RealtimeToolExecutorTimeoutTests {
    private struct HangTool: RealtimeExecutableTool {
        let metadata = RealtimeToolExecutor.ToolMetadata(
            name: "hang",
            description: "Blocks until cancelled",
            parameters: AgentToolParameters(properties: [:], required: []),
        )

        func execute(_: RealtimeToolArguments) async -> String {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            return "done"
        }
    }

    @Test
    func `Parent cancel is not reported as a tool timeout`() async {
        let executor = RealtimeToolExecutor()
        await executor.register(HangTool())
        let work = Task {
            await executor.execute(toolName: "hang", arguments: "{}", timeout: 30)
        }
        try? await Task.sleep(nanoseconds: 30_000_000)
        work.cancel()
        let execution = await work.value
        if case .timeout = execution.result {
            Issue.record("parent cancel was reported as timeout")
        }
    }
}
