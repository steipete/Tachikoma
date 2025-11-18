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

        let expected = """
        [ok] Configuration file created at: /tmp/config.json

        Next steps (no secrets written yet):
          peekaboo config add openai sk-...    # API key
          peekaboo config add anthropic sk-ant-...
          peekaboo config add grok gsk-...      # aliases: xai
          peekaboo config add gemini ya29-...
          peekaboo config login openai          # OAuth, no key stored
          peekaboo config login anthropic

        Use 'peekaboo config show --effective' to see detected env/creds,
        and 'peekaboo config edit' to tweak the JSONC file if needed.
        """

        #expect(rendered == expected)
    }
}
