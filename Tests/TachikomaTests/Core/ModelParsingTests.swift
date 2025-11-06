import Testing
@testable import Tachikoma

@Suite("LanguageModel parsing")
struct ModelParsingTests {
    @Test("parse GPT-5 mini alias")
    func parseGPT5Mini() {
        let parsed = LanguageModel.parse(from: "gpt-5-mini")
        #expect(parsed == .openai(.gpt5Mini))
    }

    @Test("parse Claude Sonnet 4.5 snapshot id")
    func parseClaudeSonnetSnapshot() {
        let parsed = LanguageModel.parse(from: "claude-sonnet-4-5-20250929")
        #expect(parsed == .anthropic(.sonnet45))
    }

    @Test("parse shorthand Claude alias")
    func parseClaudeAlias() {
        let parsed = LanguageModel.parse(from: "claude")
        #expect(parsed == .anthropic(.sonnet45))
    }
}
