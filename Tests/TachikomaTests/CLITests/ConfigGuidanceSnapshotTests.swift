import Foundation
import Testing
@testable import Tachikoma

@Suite("Tachikoma config guidance snapshot")
struct TachikomaConfigGuidanceSnapshotTests {
    @Test("init guidance matches snapshot")
    func initGuidanceMatchesSnapshot() {
        let rendered = TKConfigMessages.initGuidance
            .map { $0.replacingOccurrences(of: "{path}", with: "/tmp/config.json") }
            .joined(separator: "\n")

        let snapshot = try! String(contentsOfFile: "Tests/TachikomaTests/CLITests/__snapshots__/config_init.txt")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(rendered.trimmingCharacters(in: .whitespacesAndNewlines) == snapshot)
    }
}
