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
    func `parse GPT-5.6 preview models`() throws {
        #expect(LanguageModel.parse(from: "gpt-5.6") == .openai(.gpt56Sol))
        #expect(LanguageModel.parse(from: "gpt-5.6-sol") == .openai(.gpt56Sol))
        #expect(LanguageModel.parse(from: "openai/gpt-5.6-terra") == .openai(.gpt56Terra))
        #expect(LanguageModel.parse(from: "gpt56luna") == .openai(.gpt56Luna))
        #expect(LanguageModel.parse(from: "my-gpt56-distill") == nil)
        #expect(LanguageModel.parse(from: "gpt-5.60") == nil)
        #expect(LanguageModel.parse(from: "vendor-gpt-5-6-model") == nil)
        #expect(try ModelSelector.parseModel("gpt-5.6-sol") == .openai(.gpt56Sol))
        #expect(try ModelSelector.parseModel("openai/gpt-5.6-terra") == .openai(.gpt56Terra))
    }

    @Test
    func `infer GPT-5.6 models through OpenRouter routing suffixes`() throws {
        let models: [(id: String, expected: LanguageModel.OpenAI)] = [
            ("gpt-5.6-sol", .gpt56Sol),
            ("gpt-5.6-terra", .gpt56Terra),
            ("gpt-5.6-luna", .gpt56Luna),
        ]
        let variants = ["online", "nitro", "floor", "exacto"]

        for model in models {
            for variant in variants {
                let routedModelId = "openai/\(model.id):\(variant)"
                #expect(LanguageModel.OpenAI.gpt56Model(for: routedModelId) == model.expected)
                #expect(LanguageModel.OpenAI.gpt56Model(for: "openrouter/\(routedModelId)") == model.expected)
                #expect(
                    try ModelSelector.parseModel("openrouter/\(routedModelId)") ==
                        .openRouter(modelId: routedModelId),
                )
            }
        }

        #expect(LanguageModel.OpenAI.gpt56Model(for: "openai/gpt-5.60:online") == nil)
        #expect(LanguageModel.OpenAI.gpt56Model(for: "openai/not-gpt-5.6-sol:nitro") == nil)
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
    func `parse Claude Opus 5 aliases and properties`() throws {
        let aliases = [
            "claude-opus-5",
            "claude-opus5",
            "opus-5",
            "opus5",
            "claude-opus-5-latest",
        ]

        for alias in aliases {
            #expect(LanguageModel.parse(from: alias) == .anthropic(.opus5))
            #expect(try ModelSelector.parseModel(alias) == .anthropic(.opus5))
            #expect(ProviderParser.determineDefaultModel(
                from: "anthropic/\(alias)",
                hasOpenAI: false,
                hasAnthropic: true,
            ) == .anthropic(.opus5))
        }

        #expect(LanguageModel.Anthropic.opus5.modelId == "claude-opus-5")
        #expect(LanguageModel.Anthropic.opus5.contextLength == 1_000_000)
        #expect(LanguageModel.Anthropic.opus5.maxOutputTokens == 128_000)
        #expect(LanguageModel.Anthropic.opus5.supportsVision)
        #expect(LanguageModel.Anthropic.opus5.supportsTools)
        #expect(LanguageModel.Anthropic.allCases.first == .opus5)
        #expect(LanguageModel.Anthropic.allCases.contains(.opus5))
    }

    @Test
    func `parse Claude Sonnet 5 model id`() throws {
        #expect(LanguageModel.parse(from: "claude-sonnet-5") == .anthropic(.sonnet5))
        #expect(LanguageModel.parse(from: "anthropic/claude-sonnet-5") == .anthropic(.sonnet5))
        #expect(try ModelSelector.parseModel("sonnet5") == .anthropic(.sonnet5))
        #expect(try ModelSelector.parseModel("sonnet") == .anthropic(.sonnet5))
        #expect(LanguageModel.parse(from: "claude-sonnet-5-latest") == nil)
        #expect(LanguageModel.parse(from: "my-sonnet5-distill") == nil)
    }

    @Test
    func `parse Claude Opus 4.8 model id`() throws {
        for alias in ["claude-opus-4-8", "claude-opus-4.8", "opus-4-8", "opus-4.8", "opus48"] {
            #expect(LanguageModel.parse(from: alias) == .anthropic(.opus48))
            #expect(try ModelSelector.parseModel(alias) == .anthropic(.opus48))
            #expect(ProviderParser.determineDefaultModel(
                from: "anthropic/\(alias)",
                hasOpenAI: false,
                hasAnthropic: true,
            ) == .anthropic(.opus48))
        }
        #expect(LanguageModel.parse(from: "my-opus48-distill") == nil)
    }

    @Test
    func `parse Claude Sonnet 4.5 snapshot id`() {
        let parsed = LanguageModel.parse(from: "claude-sonnet-4-5-20250929")
        #expect(parsed == .anthropic(.sonnet45))
    }

    @Test
    func `parse shorthand Claude alias`() throws {
        for alias in ["claude", "opus", "claude-latest", "claude-default"] {
            #expect(LanguageModel.parse(from: alias) == .anthropic(.opus5))
            #expect(try ModelSelector.parseModel(alias) == .anthropic(.opus5))
        }
        #expect(try ModelSelector.parseModel("anthropic") == .anthropic(.opus5))
        #expect(LanguageModel.default == .anthropic(.opus5))
        #expect(LanguageModel.claude == .anthropic(.opus5))
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
    func `parse Kimi (Moonshot) model ids`() throws {
        #expect(LanguageModel.parse(from: "kimi/MiniMax-K2.6") == nil)
        #expect(LanguageModel.parse(from: "kimi/kimi-k2.6") == .kimi(.k26))
        #expect(LanguageModel.parse(from: "kimi/kimi-k2.7-code") == .kimi(.k27Code))
        #expect(LanguageModel.parse(from: "moonshot/kimi-k2.7-code") == .kimi(.k27Code))
        #expect(LanguageModel.parse(from: "kimi/kimi-k2.7-code-highspeed") == .kimi(.k27CodeHighspeed))
        #expect(LanguageModel.parse(from: "kimi-k2.6") == .kimi(.k26))
        #expect(LanguageModel.parse(from: "kimi-k2.7-code") == .kimi(.k27Code))
        #expect(LanguageModel.parse(from: "kimi") == .kimi(.k26))
        #expect(try ModelSelector.parseModel("kimi/kimi-k2.6") == .kimi(.k26))
        #expect(try ModelSelector.parseModel("moonshot/kimi-k2.7-code") == .kimi(.k27Code))
        #expect(LanguageModel.Kimi.k26.supportsVision == true)
        #expect(LanguageModel.Kimi.k27Code.supportsVision == true)
        #expect(LanguageModel.Kimi.k27Code.modelId == "kimi-k2.7-code")
        #expect(LanguageModel.Kimi.k27CodeHighspeed.contextLength == 262_144)
        #expect(ModelSelector.availableModels(for: "moonshot") == [
            "kimi-k2.7-code",
            "kimi-k2.7-code-highspeed",
            "kimi-k2.6",
        ])
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
    func `ModelSelector strips the ollama prefix from provider-qualified custom models`() throws {
        // Regression: parseModel fell through to the bare-name fallback with the
        // prefix still attached, producing .custom("ollama/qwen2.5vl:latest") —
        // a model id that does not exist on the Ollama server.
        #expect(try ModelSelector.parseModel("ollama/qwen2.5vl:latest") == .ollama(.custom("qwen2.5vl:latest")))
        #expect(try ModelSelector
            .parseModel("ollama/some-future-model:tag") == .ollama(.custom("some-future-model:tag")))
        // Known shortcut names keep resolving to their typed cases.
        #expect(try ModelSelector.parseModel("ollama/llama3.3") == .ollama(.llama33))
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
    func `ProviderParser accepts GPT-5.6 and Claude Sonnet 5`() {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            let openAI = ProviderParser.determineDefaultModel(
                from: "openai/gpt-5.6-luna",
                hasOpenAI: true,
                hasAnthropic: false,
            )
            let anthropic = ProviderParser.determineDefaultModel(
                from: "anthropic/claude-sonnet-5",
                hasOpenAI: false,
                hasAnthropic: true,
            )

            #expect(openAI == .openai(.gpt56Luna))
            #expect(anthropic == .anthropic(.sonnet5))
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
    func `ProviderParser accepts Kimi provider aliases`() {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            for provider in ["kimi", "moonshot"] {
                let model = ProviderParser.determineDefaultModel(
                    from: "\(provider)/kimi-k2.7-code",
                    hasOpenAI: false,
                    hasAnthropic: false,
                    hasKimi: true,
                )

                #expect(model == .kimi(.k27Code))
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
