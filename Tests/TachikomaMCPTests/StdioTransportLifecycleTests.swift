import Foundation
import Testing
@testable import TachikomaMCP

@Suite("Stdio transport lifecycle", .serialized)
struct StdioTransportLifecycleTests {
    @Test(.timeLimit(.minutes(1)))
    func `Child EOF fails concurrent pending requests and clears timeout state once`() async throws {
        let closeCounter = CloseCounter()
        let transport = StdioTransport { error in
            await closeCounter.record(error)
        }
        try await transport.connect(config: Self.exitAfterRequestCountConfig(count: 12, timeout: 5))

        let started = ContinuousClock.now
        let errors = await withTaskGroup(of: MCPError?.self, returning: [MCPError?].self) { group in
            for _ in 0..<12 {
                group.addTask {
                    do {
                        let _: FixtureResponse = try await transport.sendRequest(
                            method: "fixture/pending",
                            params: EmptyParams(),
                        )
                        return nil
                    } catch let error as MCPError {
                        return error
                    } catch {
                        return nil
                    }
                }
            }

            var results: [MCPError?] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        #expect(started.duration(to: .now) < .seconds(1))
        #expect(errors.count == 12)
        #expect(errors.allSatisfy { $0 == .transportClosed })
        #expect(await transport.debugSnapshot == .disconnected)
        #expect(await closeCounter.snapshot == [.transportClosed])

        let refusedAt = ContinuousClock.now
        await #expect(throws: MCPError.transportClosed) {
            let _: FixtureResponse = try await transport.sendRequest(
                method: "fixture/late",
                params: EmptyParams(),
            )
        }
        await #expect(throws: MCPError.transportClosed) {
            try await transport.sendNotification(
                method: "notifications/late",
                params: EmptyParams(),
            )
        }
        #expect(refusedAt.duration(to: .now) < .milliseconds(500))

        try await Task.sleep(for: .milliseconds(250))
        #expect(await transport.debugSnapshot == .disconnected)
        #expect(await closeCounter.snapshot == [.transportClosed])
        await transport.disconnect()
        await transport.disconnect()
        #expect(await closeCounter.snapshot == [.transportClosed])
    }

    @Test(.timeLimit(.minutes(1)))
    func `Request timeout removes its task without disconnecting live child`() async throws {
        let transport = StdioTransport()
        try await transport.connect(config: Self.sleepingServerConfig(timeout: 0.05))

        await #expect(throws: MCPError.self) {
            let _: FixtureResponse = try await transport.sendRequest(
                method: "fixture/timeout",
                params: EmptyParams(),
            )
        }

        #expect(await transport.debugSnapshot == .connectedIdle)
        await transport.disconnect()
        #expect(await transport.debugSnapshot == .disconnected)
    }

    @Test(.timeLimit(.minutes(1)))
    func `Client clears cached tools after child loss and reconnects with a new session`() async throws {
        let marker = FileManager.default.temporaryDirectory
            .appendingPathComponent("tachikoma-stdio-reconnect-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: marker) }
        let client = MCPClient(
            name: "stdio-reconnect",
            config: MCPServerConfig(
                command: "/bin/sh",
                args: ["-c", Self.reconnectingMCPServerScript],
                env: ["MARKER_PATH": marker.path],
                timeout: 5,
                autoReconnect: false,
            ),
        )

        try await client.connect()
        #expect(await client.isConnected)
        #expect(await client.tools.map(\.name) == ["fixture_tool"])

        await #expect(throws: MCPError.transportClosed) {
            _ = try await client.executeTool(name: "fixture_tool", arguments: [:])
        }
        #expect(await !(client.isConnected))
        #expect(await client.tools.isEmpty)

        let refusedAt = ContinuousClock.now
        await #expect(throws: MCPError.transportClosed) {
            _ = try await client.executeTool(name: "fixture_tool", arguments: [:])
        }
        #expect(refusedAt.duration(to: .now) < .milliseconds(500))

        try await client.connect()
        #expect(await client.isConnected)
        #expect(await client.tools.map(\.name) == ["fixture_tool"])
        let response = try await client.executeTool(name: "fixture_tool", arguments: [:])
        #expect(!response.isError)

        try await Task.sleep(for: .milliseconds(100))
        #expect(await client.isConnected)
        #expect(await client.tools.map(\.name) == ["fixture_tool"])
        await client.disconnect()
        await client.disconnect()
        #expect(await !(client.isConnected))
        #expect(await client.tools.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func `Client never publishes connected state when child exits during tool discovery`() async throws {
        let client = MCPClient(
            name: "stdio-discovery-eof",
            config: MCPServerConfig(
                command: "/bin/sh",
                args: ["-c", Self.discoveryEOFServerScript],
                timeout: 5,
                autoReconnect: false,
            ),
        )

        await #expect(throws: MCPError.transportClosed) {
            try await client.connect()
        }
        #expect(await !(client.isConnected))
        #expect(await client.tools.isEmpty)
        await #expect(throws: MCPError.transportClosed) {
            _ = try await client.executeTool(name: "missing", arguments: [:])
        }
        await client.disconnect()
    }

    private static func exitAfterRequestCountConfig(count: Int, timeout: TimeInterval) -> MCPServerConfig {
        let reads = Array(repeating: "IFS= read -r line || exit 0", count: count).joined(separator: "\n")
        return MCPServerConfig(
            command: "/bin/sh",
            args: ["-c", "\(reads)\nexit 0"],
            timeout: timeout,
            autoReconnect: false,
        )
    }

    private static func sleepingServerConfig(timeout: TimeInterval) -> MCPServerConfig {
        MCPServerConfig(
            command: "/bin/sh",
            args: ["-c", "IFS= read -r line || exit 0\nsleep 5"],
            timeout: timeout,
            autoReconnect: false,
        )
    }

    private static let reconnectingMCPServerScript = #"""
    while IFS= read -r line; do
      id=$(printf '%s\n' "$line" | sed -n 's/.*"id":\([0-9][0-9]*\).*/\1/p')
      case "$line" in
        *'"method":"initialize"'*)
          response='{"jsonrpc":"2.0","id":'
          response=$response"$id"
          response=$response',"result":{"protocolVersion":"2025-03-26","capabilities":{"tools":{}},'
          response=$response'"serverInfo":{"name":"fixture","version":"1.0"}}}'
          printf '%s\n' "$response"
          ;;
        *tools*list*)
          response='{"jsonrpc":"2.0","id":'
          response=$response"$id"
          response=$response',"result":{"tools":[{"name":"fixture_tool","description":"Fixture",'
          response=$response'"inputSchema":{"type":"object"}}]}}'
          printf '%s\n' "$response"
          ;;
        *tools*call*)
          if [ ! -e "$MARKER_PATH" ]; then
            : > "$MARKER_PATH"
            exit 0
          fi
          response='{"jsonrpc":"2.0","id":'
          response=$response"$id"
          response=$response',"result":{"content":[{"type":"text","text":"ok"}],"isError":false}}'
          printf '%s\n' "$response"
          ;;
      esac
    done
    """#

    private static let discoveryEOFServerScript = #"""
    while IFS= read -r line; do
      id=$(printf '%s\n' "$line" | sed -n 's/.*"id":\([0-9][0-9]*\).*/\1/p')
      case "$line" in
        *'"method":"initialize"'*)
          response='{"jsonrpc":"2.0","id":'
          response=$response"$id"
          response=$response',"result":{"protocolVersion":"2025-03-26","capabilities":{"tools":{}},'
          response=$response'"serverInfo":{"name":"fixture","version":"1.0"}}}'
          printf '%s\n' "$response"
          ;;
        *tools*list*)
          exit 0
          ;;
      esac
    done
    """#
}

private struct FixtureResponse: Decodable {
    let ok: Bool?
}

private actor CloseCounter {
    private var errors: [MCPError] = []

    func record(_ error: MCPError) {
        self.errors.append(error)
    }

    var snapshot: [MCPError] {
        self.errors
    }
}

extension StdioTransportDebugSnapshot {
    fileprivate static let disconnected = StdioTransportDebugSnapshot(
        isConnected: false,
        pendingRequestCount: 0,
        timeoutTaskCount: 0,
    )
    fileprivate static let connectedIdle = StdioTransportDebugSnapshot(
        isConnected: true,
        pendingRequestCount: 0,
        timeoutTaskCount: 0,
    )
}
