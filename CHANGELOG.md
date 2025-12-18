# Changelog

All notable changes to the Tachikoma project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- First-class Azure OpenAI provider: deployment-based model case `.azureOpenAI`, Azure-specific URL/header/query wiring (api-version, api-key or bearer token), env overrides (`AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_BEARER_TOKEN`, `AZURE_OPENAI_ENDPOINT`/`RESOURCE`, `AZURE_OPENAI_API_VERSION`), and README guidance.
- Azure provider unit tests using URLProtocol stubs to verify path, query, and auth header construction.

### Changed
- Added OpenAI's GPT-5.1 family (flagship/mini/nano) throughout the model enums, selectors, provider factories, capability registry, pricing tables, docs, and test suites. GPT aliases (`gpt`, `gpt-5`, `gpt-4o`) now normalize to `.openai(.gpt51)` so downstream apps inherit the new default seamlessly.
- Expanded xAI Grok support to the full November 2025 catalog (`grok-4-fast-*`, `grok-code-fast-1`, `grok-2-*`, `grok-vision-beta`, etc.), updated the CLI shortcuts so `grok` now maps to `grok-4-fast-reasoning`, and refreshed selectors, provider parsers, capability tables, and docs snippets to match the official API lineup.
- Google/Gemini support now targets the Gemini 2.5 family exclusively (`gemini-2.5-pro`, `gemini-2.5-flash`, `gemini-2.5-flash-lite`), with updated model selectors, parsers, docs, and pricing tables; older 1.5/2.0 IDs are no longer recognized.
- Removed deprecated OpenAI reasoning models (`o1`, `o1-mini`, `o3`, `o3-mini`) in favour of the GPT‑5 family plus `o4-mini`, updating enums, provider factories, capability tables, prompts, and documentation metadata accordingly.
- Google/Gemini integration now uses the documented `x-goog-api-key` header with `alt=sse` streaming, adds fallbacks for `GOOGLE_API_KEY` / `GOOGLE_APPLICATION_CREDENTIALS`, and hardens the SSE decoder so live tests succeed consistently.
- Pruned Anthropic model support to the Claude 4.x line (Opus 4, Sonnet 4 / 4.5, Haiku 4.5) to match current API availability and reduce maintenance burden.
- `TachikomaConfiguration` now loads credentials first and lets environment variables override them so operators can supersede stored settings without editing credentials files.
- `TachikomaConfiguration` can optionally override the provider factory so test harnesses can inject mock providers without affecting production defaults, improving hermetic test runs.
- Implemented OpenRouter, Together, Replicate, and Anthropic-compatible providers on top of the shared helpers so aggregator models no longer throw “not yet implemented” errors and honour custom base URLs/headers.
- `Provider.environmentValue` falls back to classic `getenv` lookups when the modern configuration reader returns no value, ensuring environment overrides succeed on macOS 14 deployments.

### Fixed
- `retryWithCancellation` now registers token handlers per-attempt and cancels in-flight work, resolving hangs when external cancellation should short-circuit retries.
- Audio provider tests and helpers consistently force mock mode when exercising stub audio payloads, preventing accidental live API calls that fail to decode fixtures.
- `TestHelpers` expose discardable configuration helpers and stricter mock-key detection, reducing compiler warnings and flaky skips.
- OpenAI transcription timestamp tests no longer hit the live API and succeed reliably under both mock and real key configurations.
- Anthropic OAuth login token exchange now uses the correct request format (JSON body + `state`). Thanks @jonathanglasmeyer.

### Testing
- Added dedicated Grok catalog tests (selector + capability assertions) plus provider factory/e2e coverage so every supported xAI model is exercised in mock suites without hitting the live API.
- Integration suites now respect real API keys loaded from the environment, covering Anthropic Sonnet 4 tool-calling, OpenAI GPT‑5 responses, Grok/Grok vision flows, and Google/Mistral smoke tests.
- Full `INTEGRATION_TESTS=1 swift test` runs complete without recorded issues, including agent ergonomics and audio suites.
- Added provider-level network E2E coverage using local `URLProtocol` stubs plus new OpenAI Responses API tests (request encoding + streaming) so critical serialization paths are exercised without live traffic.
- `ProviderEndToEndTests` now exercise every provider flavor (OpenRouter/Together/Replicate, OpenAI/Anthropic compatible, etc.), pushing overall line coverage above 40 % while keeping the suite deterministic via URLProtocol stubs.

### Planned Features
- Enhanced caching with persistence and TTL
- Bidirectional streaming support
- Request batching for high-volume usage
- Advanced error recovery mechanisms
- Metrics collection and monitoring
- Distributed caching support

## [1.0.0] - 2025-01-XX

### Added

#### Core Framework
- Initial release of Tachikoma AI integration library
- Unified `ModelInterface` protocol for all AI providers
- Comprehensive message type system with multimodal support
- Real-time streaming response handling with `AsyncThrowingStream`
- Type-safe tool calling system with generic context support
- Actor-based provider registry with intelligent caching
- Swift 6 strict concurrency compliance throughout

#### Provider Support
- **OpenAI Provider**: Complete integration with dual API support
  - Chat Completions API for standard models (GPT-4o, GPT-4.1)
  - Responses API for reasoning models (o3, o4 series)
  - Automatic API selection based on model capabilities
  - Parameter filtering for reasoning models
  - Full streaming support for both APIs
  - Reasoning summary handling for thinking models

- **Anthropic Provider**: Native Claude API integration
  - Support for Claude 4 (Opus, Sonnet) with thinking modes
  - Claude 3.5/3.7 series compatibility
  - Content block handling for multimodal inputs
  - System prompt separation
  - Server-Sent Events streaming
  - Extended reasoning capabilities

- **Grok Provider**: xAI integration with OpenAI compatibility
  - Grok 4, Grok 3, Grok 2 series support
  - Vision model capabilities
  - Parameter filtering for Grok 3/4 models
  - Standard streaming implementation
  - OpenAI-compatible Chat Completions API

- **Ollama Provider**: Local model inference support
  - Support for Llama 3.3 (recommended), Mistral, CodeLlama
  - Vision models (llava, bakllava) without tool calling
  - Configurable endpoints for self-hosted deployments
  - Extended timeouts for local model loading
  - Tool calling detection for compatible models

#### Message System
- **Unified Message Types**: Support for system, user, assistant, tool, and reasoning messages
- **Content Types**: Text, images (URL/base64), multimodal, files, audio with transcripts
- **Assistant Content**: Text output, refusals, tool calls with proper typing
- **Image Support**: High/low detail levels, multiple formats, base64 encoding
- **Audio Support**: Transcript extraction, duration metadata

#### Streaming System
- **Event-Based Architecture**: Comprehensive streaming event types
- **Real-Time Processing**: Incremental text deltas, tool call construction
- **Memory Efficiency**: Constant memory usage regardless of response size
- **Error Handling**: Structured error events with recovery information
- **Provider Abstraction**: Unified events across different provider formats

#### Tool Calling
- **Generic Tool System**: Type-safe tool execution with context support
- **Parameter Validation**: JSON Schema-based parameter validation
- **Async Execution**: Non-blocking tool execution with proper error handling
- **Tool Definitions**: Provider-agnostic tool definition format
- **Context Management**: Type-safe context passing to tool functions

#### Error Handling
- **Comprehensive Error Types**: Structured error hierarchy with recovery guidance
- **Provider-Specific Errors**: Tailored error handling for each provider
- **Retry Logic**: Built-in retry detection with exponential backoff support
- **Error Categories**: Client, authentication, network, and provider errors
- **Localized Descriptions**: User-friendly error messages with recovery suggestions

#### Configuration System
- **Environment Variables**: Support for standard API key environment variables
- **Provider Configuration**: Flexible configuration for custom endpoints
- **Model Registration**: Runtime model factory registration
- **Lenient Matching**: Intelligent model name resolution
- **Cache Management**: Configurable caching policies

### Technical Features

#### Swift 6 Compliance
- **Strict Concurrency**: Full Swift 6 strict concurrency mode compliance
- **Sendable Conformance**: All public types conform to Sendable protocol
- **Actor Safety**: Thread-safe operations with proper isolation
- **Memory Safety**: No data races or concurrency issues
- **Performance**: Optimized for concurrent execution

#### Performance Optimizations
- **Intelligent Caching**: Model instance caching with smart invalidation
- **Connection Pooling**: Efficient network connection management
- **Memory Management**: Minimal allocations and efficient garbage collection
- **Streaming Efficiency**: Incremental processing without accumulation
- **JSON Optimization**: Fast encoding/decoding without reflection

#### Type Safety
- **Compile-Time Verification**: Strong typing throughout the API
- **Generic Constraints**: Type-safe tool contexts and parameters
- **Enum-Based Design**: Exhaustive pattern matching for robustness
- **Protocol-Oriented**: Clean abstractions with concrete implementations

### Documentation
- Comprehensive README with quick start guide
- Detailed architecture documentation
- API reference documentation
- Code examples for common usage patterns
- Migration guide from PeekabooCore
- Performance optimization guidelines

### Testing
- Unit tests for all core components
- Integration tests for provider functionality
- Mock providers for testing scenarios
- Performance benchmarks
- Concurrency safety tests

### Platform Support
- macOS 14.0+
- iOS 17.0+
- watchOS 10.0+
- tvOS 17.0+
- Swift 6.0+
- Xcode 16.0+

## Version History

- **v1.0.0**: Initial release extracted from PeekabooCore with Swift 6 compliance
- **v0.x.x**: Development versions (internal)

## Migration Notes

### From PeekabooCore
When migrating from PeekabooCore's AI system:

1. **Error Types**: Replace `PeekabooError` with `TachikomaError`
2. **Import Statements**: Update to `import Tachikoma`
3. **Model Creation**: Use `Tachikoma.shared.getModel()` instead of direct instantiation
4. **Streaming Events**: Update event handling for new event type hierarchy
5. **Message Types**: Adopt new unified message type system
6. **Tool Calling**: Update to generic tool system with context support

### Breaking Changes
This is the initial release, so no breaking changes from previous versions.

## Contributors

- **Extraction Lead**: AI Assistant
- **Original Code**: Peekaboo project contributors
- **Architecture Design**: Based on proven patterns from PeekabooCore
- **Swift 6 Migration**: Complete rewrite for strict concurrency compliance

## License

This project is licensed under the MIT License. See LICENSE file for details.
