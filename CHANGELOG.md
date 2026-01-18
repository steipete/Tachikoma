# Changelog

All notable changes to the Tachikoma project will be documented in this file.

## [0.1.0] - 2026-01-18

### Added
- Core Swift 6 AI SDK with strict concurrency, streaming responses, and typed tool calling.
- Unified message/content model (text, images, audio) with structured tool results.
- Provider support for OpenAI (Chat + Responses), Anthropic, xAI (Grok), Google Gemini, Ollama, and OpenAI-compatible endpoints (OpenRouter/Together/Replicate).
- Config system with credential store + env overrides, model registry, and capability lookup helpers.
- Test helpers and mock infrastructure for deterministic provider/unit coverage.
