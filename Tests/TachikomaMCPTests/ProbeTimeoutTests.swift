import Foundation
import Testing
@testable import TachikomaMCP

@Suite("MCP probe timeouts")
@MainActor
struct ProbeTimeoutTests {
    @Test
    func `Probe timeout nanoseconds converts finite positive milliseconds`() {
        #expect(ProbeTimeoutNanoseconds.fromMilliseconds(1) == 1_000_000)
        #expect(ProbeTimeoutNanoseconds.fromMilliseconds(5000) == 5_000_000_000)
    }

    @Test(arguments: [0, -1, Int.min, Int.max])
    func `Probe timeout nanoseconds rejects values that trap UInt64`(timeoutMs: Int) {
        #expect(ProbeTimeoutNanoseconds.fromMilliseconds(timeoutMs) == nil)
    }

    @Test(arguments: [0, -1, Int.max])
    func `probeServer rejects invalid timeoutMs before sleeping`(timeoutMs: Int) async throws {
        let manager = TachikomaMCPClientManager()
        try await manager.addServer(
            name: "probe",
            config: MCPServerConfig(command: "never-executed"),
        )

        let result = await manager.probeServer(name: "probe", timeoutMs: timeoutMs)

        #expect(result.isConnected == false)
        #expect(result.toolCount == 0)
        #expect(result.error?.contains("invalid timeout") == true)
    }
}
