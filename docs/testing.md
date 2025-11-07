# Tachikoma Testing Guide

This repository ships with multiple tiers of tests so we can move fast locally while still validating live provider behavior on demand. This document explains what each tier covers, which environment variables it depends on, and how to run it.

## 1. Hermetic default suite (unit + mocked E2E)

- **Command**: `TACHIKOMA_TEST_MODE=mock swift test --parallel`
- **What runs**: every unit test plus `ProviderEndToEndTests`, `GenerationTests`, audio helpers, etc.
- **Network**: fully mocked via `MockURLProtocol` and the provider `URLSession` injection plumbing; no internet access or API keys required.
- **When to use**: day-to-day development, CI, and coverage collection (`--enable-code-coverage`).

### Coverage pass

```bash
tmux new-session -d -s tachicoverage 'cd Tachikoma && \
  TACHIKOMA_TEST_MODE=mock swift test --parallel --enable-code-coverage \
  2>&1 | tee /tmp/tachikoma-swift-test.log'

# After the run finishes:
xcrun llvm-cov report \
  .build/debug/TachikomaPackageTests.xctest/Contents/MacOS/TachikomaPackageTests \
  -instr-profile=.build/debug/codecov/default.profdata
```

## 2. Live provider smoke tests

- **Command**: `INTEGRATION_TESTS=1 swift test --parallel -Xswiftc -DLIVE_PROVIDER_TESTS`
- **Shortcut**: `pnpm run tachikoma:test:integration` from the repo root (exports `INTEGRATION_TESTS=1`, sources `~/.profile`, and adds the compile flag).
- **What runs**: `ProviderIntegrationTests` (OpenAI, Anthropic, Google, Groq, Grok, Mistral) plus any suites that check `ProcessInfo.processInfo.environment` for real keys.
- **Required env vars**:
  - `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` (legacy `GOOGLE_API_KEY` / `GOOGLE_APPLICATION_CREDENTIALS`), `MISTRAL_API_KEY`, `GROQ_API_KEY`, `X_AI_API_KEY` / `XAI_API_KEY`, etc.
- **Notes**: wields actual HTTP calls and tool invocations, so only run when keys are set and you’re ready to burn quota. Requires the compile-time flag `-DLIVE_PROVIDER_TESTS`; without it the integration suite is excluded from the test build. Use `tmux` as described in `AGENTS.md` to avoid lost logs.

### Example

```bash
source ~/.profile  # ensure keys are exported
tmux new-session -d -s tachitest 'cd Tachikoma && \
  INTEGRATION_TESTS=1 swift test --parallel \
  2>&1 | tee /tmp/tachikoma-swift-test.log'
```

## 3. Provider-specific real workflows

Some suites rely on live credentials even without `INTEGRATION_TESTS`, e.g. CLI workflows or manual reproduction of regressions.

- `Tests/TachikomaTests/GrokDebugTest.swift` only runs fully when `TACHIKOMA_TEST_MODE` is not `mock` *and* a Grok key is set.
- Audio/transcription suites honor `TACHIKOMA_TEST_MODE=mock`; unset it if you explicitly want to hit OpenAI’s audio endpoints.

## 4. Environment knobs

| Variable | Purpose |
| --- | --- |
| `TACHIKOMA_TEST_MODE=mock` | Forces provider factory overrides and mock audio providers; default in CI. |
| `INTEGRATION_TESTS=1` | Enables the live-provider suite. |
| `TACHIKOMA_DISABLE_API_TESTS=true` | Hard-disables real providers even if keys are present (useful on shared CI runners). |
| `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, etc. | Standard per-provider keys pulled by `TestHelpers.resolve` (Gemini also accepts `GOOGLE_API_KEY` / `GOOGLE_APPLICATION_CREDENTIALS`). |
| `OPENROUTER_REFERER`, `OPENROUTER_TITLE` | Optional headers for OpenRouter (defaults provided). |
| `REPLICATE_PREFERRED_OUTPUT=turbo` | Adds `Prefer: wait=false` to Replicate calls during tests. |

## 5. Troubleshooting tips

- **Missing API key errors**: confirm `source ~/.profile` (or your secrets manager) before launching `swift test`. The helper prints the provider name in the exception message.
- **Hanging tests**: rerun inside `tmux` and watch `/tmp/tachikoma-swift-test.log`. The `AGENTS.md` file in the parent repo outlines the approved tmux workflow (`tmux new-session ... | tee ...`).
- **Coverage gaps**: run the coverage command above; the report lists the lowest-covered files so you can target new tests.

## 6. File map

- `Tests/TachikomaTests/Providers/ProviderEndToEndTests.swift` – mocked request/response coverage for every provider, including OpenRouter/Together/Replicate and the OpenAI/Anthropic compatible adapters.
- `Tests/TachikomaTests/Providers/Integration/ProviderIntegrationTests.swift` – live smoke tests gated by `INTEGRATION_TESTS` & env keys.
- `Tests/TachikomaTests/TestHelpers/TestHelpers.swift` – central helper that prepares configurations, injects mock providers, and toggles `TACHIKOMA_TEST_MODE`.
- `Tests/TachikomaTests/Support/MockURLProtocol.swift` – URLProtocol shim used by hermetic suites.
