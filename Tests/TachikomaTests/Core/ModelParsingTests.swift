import Testing
@testable import Tachikoma

@Suite("LanguageModel parsing")
struct ModelParsingTests {
    @Test("parse GPT-5 mini alias")
    func parseGPT5Mini() {
        let parsed = LanguageModel.parse(from: "gpt-5-mini")
        #expect(parsed == .openai(.gpt5Mini))
    }

    @Test("parse GPT-5.1 base model")
    func parseGPT51() {
        let parsed = LanguageModel.parse(from: "gpt-5.1")
        #expect(parsed == .openai(.gpt51))
    }

    @Test("parse GPT-5.2 base model")
    func parseGPT52() {
        let parsed = LanguageModel.parse(from: "gpt-5.2")
        #expect(parsed == .openai(.gpt52))
    }

    @Test("parse GPT-5.1 nano alias")
    func parseGPT51Nano() {
        let parsed = LanguageModel.parse(from: "gpt51-nano")
        #expect(parsed == .openai(.gpt5Nano))
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

    @Test("parse Gemini 3 Flash model id")
    func parseGemini3Flash() {
        let parsed = LanguageModel.parse(from: "gemini-3-flash")
        #expect(parsed == .google(.gemini3Flash))
    }

    @Test("parse shorthand Gemini alias")
    func parseGeminiAlias() {
        let parsed = LanguageModel.parse(from: "gemini")
        #expect(parsed == .google(.gemini3Flash))
    }
}
