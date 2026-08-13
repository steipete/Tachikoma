import Foundation
import Testing
@testable import TachikomaMCP

@Suite("Stdio frame writer")
struct StdioFrameWriterTests {
    @Test
    func `Concurrent sends preserve complete JSON lines`() async throws {
        let pipe = Pipe()
        let writer = StdioFrameWriter()
        await writer.install(pipe.fileHandleForWriting)

        let payloads = (0..<512).map { Data("{\"id\":\($0)}".utf8) }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for payload in payloads {
                group.addTask {
                    try await writer.write(payload: payload)
                }
            }
            try await group.waitForAll()
        }

        await writer.removeHandle()
        try pipe.fileHandleForWriting.close()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        let lines = output.split(separator: 0x0A).map(Data.init)

        #expect(output.last == 0x0A)
        #expect(lines.count == payloads.count)
        #expect(Set(lines) == Set(payloads))
    }

    @Test
    func `Writes fail when no request pipe is installed`() async {
        let writer = StdioFrameWriter()

        await #expect(throws: MCPError.self) {
            try await writer.write(payload: Data("{}".utf8))
        }
    }
}
