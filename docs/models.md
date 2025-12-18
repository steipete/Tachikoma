# Models

Tachikoma ships with a built-in model catalog (`CaseIterable` enums) plus support for arbitrary model ids via `.custom(...)` and compatible/custom endpoints.

## Default

- `LanguageModel.default`: `claude-opus-4-5`

## OpenAI (`LanguageModel.OpenAI`)

- `o4-mini`
- `gpt-5.2`, `gpt-5.1`
- `gpt-5`, `gpt-5-pro`, `gpt-5-mini`, `gpt-5-nano`
- `gpt-5-thinking`, `gpt-5-thinking-mini`, `gpt-5-thinking-nano`
- `gpt-5-chat-latest`
- `gpt-4.1`, `gpt-4.1-mini`
- `gpt-4o`, `gpt-4o-mini`, `gpt-4o-realtime-preview`
- `gpt-4-turbo`, `gpt-3.5-turbo`

Notes:
- Mini/Nano variants exist only for **GPT‑5** (not for GPT‑5.1 / GPT‑5.2).

## Anthropic (`LanguageModel.Anthropic`)

- `claude-opus-4-5`
- `claude-opus-4-1-20250805`, `claude-opus-4-1-20250805-thinking`
- `claude-sonnet-4-20250514`, `claude-sonnet-4-20250514-thinking`
- `claude-sonnet-4-5-20250929`
- `claude-haiku-4.5`

## Google (`LanguageModel.Google`)

- `gemini-3-flash` (API id currently maps to `gemini-3-flash-preview`)
- `gemini-2.5-pro`, `gemini-2.5-flash`, `gemini-2.5-flash-lite`

## xAI Grok (`LanguageModel.Grok`)

- `grok-4-0709`
- `grok-4-fast-reasoning`, `grok-4-fast-non-reasoning`
- `grok-code-fast-1`
- `grok-3`, `grok-3-mini`
- `grok-2-1212`, `grok-2-vision-1212`, `grok-2-image-1212`
- `grok-vision-beta`, `grok-beta`

## Mistral (`LanguageModel.Mistral`)

- `mistral-large-2`, `mistral-large`, `mistral-medium`, `mistral-small`, `mistral-nemo`, `codestral`

## Groq (`LanguageModel.Groq`)

- `llama-3.1-70b`, `llama-3.1-8b`
- `llama-3-70b`, `llama-3-8b`
- `mixtral-8x7b`
- `gemma2-9b`

## Local (`LanguageModel.Ollama`, `LanguageModel.LMStudio`)

Local providers ship curated enums plus `.custom("<model-id>")` for anything your server exposes.

## Aggregators / custom endpoints

- `.openRouter(modelId:)`, `.together(modelId:)`, `.replicate(modelId:)`
- `.openaiCompatible(modelId:baseURL:)`, `.anthropicCompatible(modelId:baseURL:)`, `.custom(provider:)`
