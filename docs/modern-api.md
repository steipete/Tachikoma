# Modern AI SDK Refactor Plan - Comprehensive Implementation

<!-- Generated: 2025-01-30 18:45:00 UTC -->

Based on the Vercel AI SDK patterns from `/Users/steipete/Downloads/ai-sdk.md`, this document outlines a complete refactor of the Tachikoma AI SDK to match modern industry standards and idiomatic Swift patterns.

## Analysis of Target Architecture

The Vercel AI SDK provides these core patterns:
- **Provider-specific imports**: `import { openai } from '@ai-sdk/openai'`
- **Core functions**: `generateText()`, `streamText()`, `generateObject()`, `streamObject()`
- **Model specification**: `model: openai('gpt-4o')`, `model: anthropic('claude-sonnet-4')`
- **Unified API**: Same function signatures across all providers
- **Tool integration**: Simple `tools: { toolName: toolDefinition }` object
- **Streaming first**: Built-in streaming support with AsyncSequence patterns
- **Structured output**: Schema-based object generation with Zod-like validation

## Current State Assessment

### ✅ Already Implemented (Previous Refactor)
- [x] Basic TachikomaCore module structure
- [x] LanguageModel enum with provider-specific sub-enums
- [x] generateText() and streamText() function signatures
- [x] Tool system with generic Tool<Context> pattern
- [x] AgentTool pattern for context-free tools
- [x] Array parameter support in tools
- [x] Swift 6.0 compliance and Sendable conformance

### ❌ Needs Complete Redesign
- [ ] Provider architecture (currently uses ProviderFactory, should be provider-specific modules)
- [ ] Model specification API (should match `provider('model')` pattern)
- [ ] Core function APIs (need to match AI SDK exactly)
- [ ] Error handling and result types
- [ ] Streaming implementation
- [ ] Tool system (needs complete redesign to match AI SDK patterns)
- [ ] Testing infrastructure
- [ ] Documentation and examples

---

## 🎯 COMPREHENSIVE REFACTOR TODO LIST

### **PHASE 1: FOUNDATION ARCHITECTURE** (Critical)

#### 1.1 Provider Module Redesign
- [ ] **Create @ai-sdk pattern modules**
  - [ ] Create `TachikomaOpenAI` module with `openai` provider function
  - [ ] Create `TachikomaAnthropic` module with `anthropic` provider function  
  - [ ] Create `TachikomaGrok` module with `grok` provider function
  - [ ] Create `TachikomaOllama` module with `ollama` provider function
  - [ ] Create `TachikomaGoogle` module with `google` provider function
  - [ ] Each module exports: `openai(modelId: String) -> LanguageModel`

#### 1.2 Core Model System Redesign
- [ ] **Replace LanguageModel enum with LanguageModel protocol**
  - [ ] Create `LanguageModel` protocol with provider metadata
  - [ ] Create provider-specific model structs: `OpenAIModel`, `AnthropicModel`, etc.
  - [ ] Implement model creation: `openai("gpt-4o")`, `anthropic("claude-sonnet-4")`
  - [ ] Add model capabilities: `supportsTools`, `supportsStreaming`, `supportsImages`

#### 1.3 Core API Functions Redesign
- [ ] **Redesign generateText() to match AI SDK exactly**
  - [ ] Function signature: `generateText(model:, prompt:, messages:, system:, tools:, maxTokens:, temperature:, ...)`
  - [ ] Support both prompt and messages patterns
  - [ ] Return proper result type with text, usage, finishReason
  - [ ] Handle tool calls within the function
  - [ ] Proper error handling and types

- [ ] **Redesign streamText() to match AI SDK exactly**
  - [ ] Function signature matching generateText but returning stream
  - [ ] Return `StreamTextResult` with `textStream: AsyncSequence`
  - [ ] Support tool calls in streaming
  - [ ] Proper chunk types and streaming events

- [ ] **Implement generateObject() properly**
  - [ ] Schema-based object generation with Swift Codable
  - [ ] Type-safe schema validation
  - [ ] Return structured `GenerateObjectResult<T>`

- [ ] **Implement streamObject() for structured streaming**
  - [ ] Streaming object generation with partial updates
  - [ ] Schema validation during streaming

### **PHASE 2: ADVANCED FEATURES** (High Priority)

#### 2.1 Tool System Complete Redesign
- [ ] **Match AI SDK tool patterns exactly**
  - [ ] Tools as simple dictionaries: `tools: [String: ToolDefinition]`
  - [ ] Remove generic Tool<Context> complexity
  - [ ] Simple tool definition with name, description, parameters, execute
  - [ ] Schema-based parameter validation using Swift property wrappers

- [ ] **Tool Integration in Core Functions**
  - [ ] Tools work seamlessly with generateText/streamText
  - [ ] Automatic tool call detection and execution
  - [ ] Tool results fed back to model automatically
  - [ ] Multi-step tool calling support

#### 2.2 Provider Implementation
- [ ] **Implement actual provider backends**
  - [ ] OpenAI API integration (both Completions and Responses APIs)
  - [ ] Anthropic API integration with streaming
  - [ ] Grok (xAI) API integration
  - [ ] Ollama API integration with tool support
  - [ ] Google Gemini API integration

- [ ] **Provider-specific features**
  - [ ] Reasoning support for GPT-5 and o4-mini models
  - [ ] Vision support for multimodal models
  - [ ] Function calling for compatible models
  - [ ] Streaming optimization per provider

#### 2.3 Advanced Streaming
- [ ] **Redesign streaming architecture**
  - [ ] Match AI SDK streaming events exactly
  - [ ] Support text deltas, tool calls, finish reasons
  - [ ] Proper AsyncSequence implementation
  - [ ] Error handling in streams
  - [ ] Stream cancellation and cleanup

### **PHASE 3: DEVELOPER EXPERIENCE** (Medium Priority)

#### 3.1 Modern Swift Patterns
- [ ] **Result builders for complex scenarios**
  - [ ] Conversation builder with fluent syntax
  - [ ] Tool collection builders
  - [ ] Configuration builders

- [ ] **Property wrappers for common use cases**
  - [ ] `@GeneratedText` for SwiftUI integration
  - [ ] `@StreamedText` for real-time updates
  - [ ] `@ModelConfig` for reusable configurations

#### 3.2 Error Handling and Diagnostics
- [ ] **Comprehensive error types**
  - [ ] Provider-specific errors with recovery suggestions
  - [ ] Network errors with retry logic
  - [ ] Model capability errors
  - [ ] Tool execution errors

- [ ] **Debugging and observability**
  - [ ] Request/response logging
  - [ ] Performance metrics
  - [ ] Token usage tracking
  - [ ] Cost estimation

#### 3.3 Configuration and Settings
- [ ] **Global configuration system**
  - [ ] API key management
  - [ ] Default model settings
  - [ ] Retry policies
  - [ ] Timeout configurations

### **PHASE 4: TESTING AND VALIDATION** (High Priority)

#### 4.1 Comprehensive Test Suite
- [ ] **Unit tests for all core functions**
  - [ ] generateText() with all parameter combinations
  - [ ] streamText() with mock streaming
  - [ ] generateObject() with various schemas
  - [ ] Tool execution and integration

- [ ] **Integration tests with real providers**
  - [ ] OpenAI integration tests (with auth checks)
  - [ ] Anthropic integration tests
  - [ ] Mock provider for CI/CD
  - [ ] Performance benchmarks

- [ ] **Property-based testing**
  - [ ] Random model configurations
  - [ ] Random tool combinations
  - [ ] Edge case generation

#### 4.2 Example Projects
- [ ] **Create comprehensive examples**
  - [ ] Simple text generation
  - [ ] Streaming chat application
  - [ ] Tool-based agent
  - [ ] RAG implementation
  - [ ] Structured data extraction

### **PHASE 5: DOCUMENTATION AND POLISH** (Medium Priority)

#### 5.1 API Documentation
- [ ] **DocC documentation for all public APIs**
  - [ ] Complete function references
  - [ ] Usage examples for each function
  - [ ] Migration guides from legacy API
  - [ ] Best practices and patterns

#### 5.2 Migration Tools
- [ ] **Automated migration support**
  - [ ] Legacy API compatibility layer
  - [ ] Migration warnings and suggestions
  - [ ] Codemod tools for bulk updates

### **PHASE 6: PEEKABOO INTEGRATION** (Critical)

#### 6.1 PeekabooCore Migration
- [ ] **Update PeekabooCore to use new API**
  - [ ] Replace all generateText/streamText calls
  - [ ] Update tool definitions to new format
  - [ ] Migrate model specifications
  - [ ] Update error handling

- [ ] **Performance optimization**
  - [ ] Benchmark new vs old performance
  - [ ] Optimize hot paths
  - [ ] Memory usage optimization
  - [ ] Concurrent request handling

#### 6.2 Agent System Integration
- [ ] **Redesign agent system with new patterns**
  - [ ] Use new tool system for agent tools
  - [ ] Streaming agent responses
  - [ ] Multi-step agent execution
  - [ ] Agent state management

---

## 🎯 SUCCESS CRITERIA

### Technical Requirements
- [ ] **100% API compatibility with Vercel AI SDK patterns**
- [ ] **All tests passing (unit + integration)**
- [ ] **Performance equal or better than legacy system**
- [ ] **Memory usage optimized**
- [ ] **Swift 6.0 compliance maintained**

### Developer Experience
- [ ] **Documentation coverage > 95%**
- [ ] **Migration path from legacy API**
- [ ] **Examples for all major use cases**
- [ ] **Error messages are actionable**

### Production Readiness
- [ ] **PeekabooCore fully migrated and working**
- [ ] **All provider integrations functional**
- [ ] **Performance benchmarks meet requirements**
- [ ] **Ready for external adoption**

---

## 🚀 EXECUTION PLAN

This refactor will be executed in **one comprehensive session** with the following approach:

1. **No incremental builds** - Complete all changes before testing
2. **Provider-first approach** - Start with provider modules
3. **Core API redesign** - Match AI SDK exactly
4. **Tool system overhaul** - Simplify and modernize
5. **Integration testing** - Ensure everything works together
6. **PeekabooCore migration** - Update all usages

**Estimated effort**: Large-scale refactor requiring careful attention to API design, performance, and compatibility.

**Target outcome**: Production-ready modern AI SDK that matches industry standards and provides excellent developer experience.

---

## 📊 PROGRESS TRACKING

Tasks will be tracked and updated in this document as work progresses. Each completed item will be marked with ✅ and include implementation notes.

**Started**: 2025-01-30 18:45:00 UTC  
**Target completion**: Single session (no stopping until 100% complete)  
**Current status**: PLANNING COMPLETE - READY TO EXECUTE

---

*This refactor represents the largest improvement to Tachikoma since its inception. The goal is to create a Swift AI SDK that rivals the best in the industry while maintaining the performance and type safety that Swift developers expect.*
