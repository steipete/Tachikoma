# Models

Tachikoma ships with a built-in model catalog (`CaseIterable` enums) plus support for arbitrary model ids via `.custom(...)` and compatible/custom endpoints.

## Default

- `LanguageModel.default`: `claude-opus-4-8`
- `LanguageModel.defaultStreaming`: `gpt-5.5`

## OpenAI (`LanguageModel.OpenAI`)

- `gpt-5.5`
- `gpt-5.4`, `gpt-5.4-mini`, `gpt-5.4-nano`
- `gpt-5`, `gpt-5-pro`, `gpt-5-mini`, `gpt-5-nano`

Notes:
- Older `gpt-5.1`, `gpt-5.2`, `gpt-5-thinking*`, and `gpt-5-chat-latest` ids are not first-class catalog entries.

## Anthropic (`LanguageModel.Anthropic`)

- `claude-fable-5` (1M context, 128K max output, non-streaming, explicit opt-in)
- `claude-opus-4-8` (1M context, 128K max output, non-streaming until refusal rollback is streaming-safe)
- `claude-opus-4-7`
- `claude-opus-4-5`
- `claude-opus-4-1-20250805`
- `claude-sonnet-4-6`
- `claude-sonnet-4-5-20250929`
- `claude-haiku-4-5`

## Google (`LanguageModel.Google`)

- `gemini-3.1-pro-preview`
- `gemini-3.1-flash-lite`
- `gemini-3-flash` (API id currently maps to `gemini-3-flash-preview`)
- `gemini-2.5-pro`, `gemini-2.5-flash`, `gemini-2.5-flash-lite`

## MiniMax (`LanguageModel.MiniMax`)

- `MiniMax-M3` (1M context, multimodal image input)
- `MiniMax-M2.7`
- `MiniMax-M2.7-highspeed`

## Kimi / Moonshot AI (`LanguageModel.Kimi`)

- `kimi-k2.6`
- `kimi-k2.7-code`
- `kimi-k2.7-code-highspeed`

Kimi uses Moonshot's OpenAI-compatible endpoint at `https://api.moonshot.ai/v1`. Configure
`MOONSHOT_API_KEY` (or `KIMI_API_KEY`); override the endpoint with `MOONSHOT_BASE_URL`. K2.7 tool-call
turns preserve Moonshot's provider-native `reasoning_content` when replaying assistant history.

## xAI Grok (`LanguageModel.Grok`)

- `grok-4.3`
- `grok-4.20-0309-reasoning`, `grok-4.20-0309-non-reasoning`

## Mistral (`LanguageModel.Mistral`)

- `mistral-large-latest`, `mistral-medium-latest`, `mistral-medium-3-5`
- `mistral-small-latest`, `open-mistral-nemo-2407`, `codestral-latest`

## Groq (`LanguageModel.Groq`)

- `openai/gpt-oss-120b`, `openai/gpt-oss-20b`
- `llama-3.3-70b-versatile`, `llama-3.1-8b-instant`
- `meta-llama/llama-4-maverick-17b-128e-instruct`
- `meta-llama/llama-4-scout-17b-16e-instruct`

## Local (`LanguageModel.Ollama`, `LanguageModel.LMStudio`)

Local providers ship curated enums plus `.custom("<model-id>")` for anything your server exposes.

## Aggregators / custom endpoints

- `.openRouter(modelId:)`, `.together(modelId:)`, `.replicate(modelId:)`
- `.openaiCompatible(modelId:baseURL:)`, `.anthropicCompatible(modelId:baseURL:)`, `.custom(provider:)`
