import Testing
@testable import Tachikoma

struct ModelParsingTests {
    @Test
    func `parse GPT-5 mini alias`() {
        let parsed = LanguageModel.parse(from: "gpt-5-mini")
        #expect(parsed == .openai(.gpt5Mini))
    }

    @Test
    func `parse GPT-5.5 base model`() {
        let parsed = LanguageModel.parse(from: "gpt-5.5")
        #expect(parsed == .openai(.gpt55))
    }

    @Test
    func `parse chat latest OpenAI alias`() throws {
        #expect(LanguageModel.parse(from: "chat-latest") == .openai(.chatLatest))
        #expect(LanguageModel.parse(from: "gpt-5-chat-latest") == .openai(.gpt5ChatLatest))
        #expect(LanguageModel.parse(from: "openai/chat-latest") == .openai(.chatLatest))
        #expect(LanguageModel.parse(from: "openai/gpt-5-chat-latest") == .openai(.gpt5ChatLatest))
        #expect(try ModelSelector.parseModel("openai/chat-latest") == .openai(.chatLatest))
        #expect(try ModelSelector.parseModel("openai/gpt-5-chat-latest") == .openai(.gpt5ChatLatest))
    }

    @Test
    func `parse GPT-5.4 base model`() {
        let parsed = LanguageModel.parse(from: "gpt-5.4")
        #expect(parsed == .openai(.gpt54))
    }

    @Test
    func `parse GPT-5.4 nano alias`() {
        let parsed = LanguageModel.parse(from: "gpt54-nano")
        #expect(parsed == .openai(.gpt54Nano))
    }

    @Test
    func `LanguageModel rejects retired OpenAI ids`() {
        for model in ["gpt-4o", "gpt-4.1", "gpt-5.1", "gpt-5.2", "gpt-5-thinking"] {
            #expect(LanguageModel.parse(from: model) == nil)
        }
    }

    @Test
    func `parse Claude Fable 5 model id`() throws {
        #expect(LanguageModel.parse(from: "claude-fable-5") == .anthropic(.fable5))
        #expect(LanguageModel.parse(from: "fable") == .anthropic(.fable5))
        #expect(try ModelSelector.parseModel("fable5") == .anthropic(.fable5))
        #expect(LanguageModel.parse(from: "my-fable5-7b") == nil)
    }

    @Test
    func `parse Claude Opus 4.8 model id`() {
        let parsed = LanguageModel.parse(from: "claude-opus-4-8")
        #expect(parsed == .anthropic(.opus48))
        #expect(LanguageModel.parse(from: "my-opus48-distill") == nil)
    }

    @Test
    func `parse Claude Sonnet 4.5 snapshot id`() {
        let parsed = LanguageModel.parse(from: "claude-sonnet-4-5-20250929")
        #expect(parsed == .anthropic(.sonnet45))
    }

    @Test
    func `parse shorthand Claude alias`() throws {
        let parsed = LanguageModel.parse(from: "claude")
        #expect(parsed == .anthropic(.opus48))
        #expect(try ModelSelector.parseModel("anthropic") == .anthropic(.opus48))
    }

    @Test
    func `parse Gemini 3.5 Flash model id`() {
        let parsed = LanguageModel.parse(from: "gemini-3.5-flash")
        #expect(parsed == .google(.gemini35Flash))
    }

    @Test
    func `parse shorthand Gemini alias`() {
        let parsed = LanguageModel.parse(from: "gemini")
        #expect(parsed == .google(.gemini35Flash))
    }

    @Test
    func `parse provider qualified latest hosted models`() throws {
        #expect(LanguageModel.parse(from: "anthropic/claude-fable-5") == .anthropic(.fable5))
        #expect(LanguageModel.parse(from: "anthropic/claude-opus-4-8") == .anthropic(.opus48))
        #expect(LanguageModel.parse(from: "google/gemini-3.5-flash") == .google(.gemini35Flash))
        #expect(LanguageModel.parse(from: "xai/grok-4.3-latest") == .grok(.grok43))
        #expect(LanguageModel.parse(from: "grok-4-latest") == .grok(.grok43))
        #expect(LanguageModel.parse(from: "grok-4") == .grok(.grok43))
        #expect(LanguageModel.parse(from: "xai/grok-code-fast-1") == .grok(.custom("grok-code-fast-1")))
        #expect(try ModelSelector.parseModel("grok-4") == .grok(.grok43))
    }

    @Test
    func `parse rejects provider-qualified hosted model mismatches`() {
        #expect(LanguageModel.parse(from: "openai/claude") == nil)
        #expect(LanguageModel.parse(from: "google/claude") == nil)
        #expect(LanguageModel.parse(from: "xai/gemini-3.5-flash") == nil)
        #expect(LanguageModel.parse(from: "anthropic/gpt-5.5") == nil)
    }

    @Test
    func `ModelSelector keeps generic slash IDs as OpenRouter models`() throws {
        #expect(try ModelSelector
            .parseModel("anthropic/claude-opus-4-8") == .openRouter(modelId: "anthropic/claude-opus-4-8"))
        #expect(try ModelSelector
            .parseModel("google/gemini-3.5-flash") == .openRouter(modelId: "google/gemini-3.5-flash"))
        #expect(try ModelSelector.parseModel("xai/grok-4.3-latest") == .grok(.grok43))
        #expect(try ModelSelector.parseModel("openai/claude") == .openRouter(modelId: "openai/claude"))
    }

    @Test
    func `parse MiniMax model ids`() throws {
        #expect(LanguageModel.parse(from: "MiniMax-M2.7") == .minimax(.m27))
        #expect(LanguageModel.parse(from: "minimax/m2.7") == .minimax(.m27))
        #expect(try ModelSelector.parseModel("minimax/m2-7") == .minimax(.m27))
        #expect(LanguageModel.parse(from: "minimax/MiniMax-M2.7-highspeed") == .minimax(.m27Highspeed))
        #expect(LanguageModel.parse(from: "minimax/m2.7-highspeed") == .minimax(.m27Highspeed))
        #expect(try ModelSelector.parseModel("minimax/m2-7-highspeed") == .minimax(.m27Highspeed))
        #expect(LanguageModel.parse(from: "minimax") == .minimax(.m27))
        #expect(LanguageModel.parse(from: "MiniMax-M3") == .minimax(.m3))
        #expect(LanguageModel.parse(from: "minimax/MiniMax-M3") == .minimax(.m3))
        #expect(LanguageModel.parse(from: "minimax/m3") == .minimax(.m3))
        #expect(LanguageModel.parse(from: "minimax/minimax-m3") == .minimax(.m3))
        #expect(try ModelSelector.parseModel("minimax/m3") == .minimax(.m3))
        #expect(LanguageModel.MiniMax.m3.supportsVision == true)
        #expect(LanguageModel.MiniMax.m27.supportsVision == false)
        #expect(LanguageModel.MiniMax.m3.contextLength == 1_000_000)
        #expect(LanguageModel.parse(from: "minimax-cn/MiniMax-M2.7") == .minimaxCN(.m27))
        #expect(LanguageModel.parse(from: "minimax-cn/m2.7-highspeed") == .minimaxCN(.m27Highspeed))
        #expect(try ModelSelector.parseModel("minimax-cn/m2-7") == .minimaxCN(.m27))
        #expect(try ModelSelector.parseModel("minimax_cn/m2.7") == .minimaxCN(.m27))
        #expect(LanguageModel.parse(from: "minimaxi/m2.7") == .minimaxCN(.m27))
        #expect(LanguageModel.parse(from: "minimax-cn") == .minimaxCN(.m27))
        #expect(LanguageModel.parse(from: "minimax-cn/m3") == .minimaxCN(.m3))
        #expect(try ModelSelector.parseModel("minimax-cn/m3") == .minimaxCN(.m3))
    }

    @Test
    func `parse OpenRouter model ids`() throws {
        #expect(LanguageModel
            .parse(from: "openrouter/xiaomi/mimo-v2.5-pro") == .openRouter(modelId: "xiaomi/mimo-v2.5-pro"))
        #expect(LanguageModel.parse(from: "xiaomi/mimo-v2.5-pro") == .openRouter(modelId: "xiaomi/mimo-v2.5-pro"))
        #expect(try ModelSelector.parseModel("xiaomi/mimo-v2.5-pro") == .openRouter(modelId: "xiaomi/mimo-v2.5-pro"))
    }

    @Test
    func `parse custom Ollama Qwen vision model without falling back to Llama`() {
        let parsed = LanguageModel.parse(from: "qwen2.5vl:3b")
        #expect(parsed == .ollama(.custom("qwen2.5vl:3b")))
        #expect(parsed?.modelId == "qwen2.5vl:3b")
        #expect(parsed?.supportsVision == true)
        #expect(parsed?.supportsTools == false)
    }

    @Test
    func `parse provider-qualified custom Ollama model`() {
        let parsed = LanguageModel.parse(from: "ollama/qwen2.5vl:3b")
        #expect(parsed == .ollama(.custom("qwen2.5vl:3b")))
        #expect(parsed?.modelId == "qwen2.5vl:3b")
    }

    @Test
    func `parse local provider shortcuts`() {
        #expect(LanguageModel.parse(from: "ollama") == .ollama(.llama33))
        #expect(LanguageModel.parse(from: "lmstudio") == .lmstudio(.gptOSS120B))
        #expect(LanguageModel.parse(from: "lmstudio/openai/gpt-oss-120b") == .lmstudio(.gptOSS120B))
        #expect(LanguageModel.parse(from: "lmstudio/custom-local-model") == .lmstudio(.custom("custom-local-model")))
    }

    @Test
    func `ModelSelector parses local provider selections`() throws {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            #expect(try ModelSelector.parseModel("lmstudio") == .lmstudio(.gptOSS120B))
            #expect(try ModelSelector.parseModel("lmstudio/openai/gpt-oss-120b") == .lmstudio(.gptOSS120B))
            #expect(try ModelSelector.parseModel("lm-studio/custom-local") == .lmstudio(.custom("custom-local")))
            #expect(ModelSelector.availableModels(for: "lmstudio").contains("openai/gpt-oss-120b"))
        }
    }

    @Test
    func `ProviderParser keeps configured Google model behavior`() {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            let model = ProviderParser.determineDefaultModel(
                from: "google/gemini-3.1-pro-preview",
                hasOpenAI: false,
                hasAnthropic: false,
            )

            #expect(model == .google(.gemini31ProPreview))
        }
    }

    @Test
    func `ProviderParser keeps keyless fallback local by default`() {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            let model = ProviderParser.determineDefaultModel(
                from: "",
                hasOpenAI: false,
                hasAnthropic: false,
            )

            #expect(model == .ollama(.llama33))
        }
    }

    @Test
    func `ProviderParser accepts MiniMax China provider aliases`() {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            for provider in ["minimax-cn", "minimax_cn", "minimaxi"] {
                let model = ProviderParser.determineDefaultModel(
                    from: "\(provider)/m2.7",
                    hasOpenAI: false,
                    hasAnthropic: false,
                    hasMiniMax: true,
                )

                #expect(model == .minimaxCN(.m27))
            }
        }
    }

    @Test
    func `ProviderParser accepts MiniMax M3`() {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            let global = ProviderParser.determineDefaultModel(
                from: "minimax/MiniMax-M3",
                hasOpenAI: false,
                hasAnthropic: false,
                hasMiniMax: true,
            )
            let china = ProviderParser.determineDefaultModel(
                from: "minimax-cn/MiniMax-M3",
                hasOpenAI: false,
                hasAnthropic: false,
                hasMiniMax: true,
            )

            #expect(global == .minimax(.m3))
            #expect(china == .minimaxCN(.m3))
        }
    }

    @Test
    func `ModelSelector rejects legacy OpenAI before Ollama fallback`() throws {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            for model in ["gpt-4o", "gpt-4.1", "gpt-3.5-turbo", "o4-mini", "o3-mini", "gpt-5.2"] {
                #expect(throws: ModelValidationError.self) {
                    _ = try ModelSelector.parseModel(model)
                }
            }
        }
    }

    @Test
    func `ModelSelector rejects Claude 3 before Ollama fallback`() throws {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            #expect(throws: ModelValidationError.self) {
                _ = try ModelSelector.parseModel("claude-3-sonnet")
            }
        }
    }
}
