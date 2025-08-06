# GPT-OSS-120B Integration Guide

GPT-OSS-120B is OpenAI's open-source 120 billion parameter model, designed for high-quality text generation with advanced reasoning capabilities. Tachikoma provides seamless integration with this model through both Ollama and LMStudio.

## Overview

GPT-OSS-120B offers:
- **120B parameters** for nuanced understanding
- **128K context window** for long conversations
- **Chain-of-thought reasoning** with multi-channel responses
- **Tool calling** support for function execution
- **Multiple quantizations** from Q4 (65GB) to FP16 (240GB)

## Hardware Requirements

### Minimum Requirements
- **RAM**: 32GB (Q4_0), 64GB (Q4_K_M)
- **GPU**: 8GB VRAM (partial offload)
- **Storage**: 70GB free space
- **CPU**: 8-core modern processor

### Recommended Setup
- **RAM**: 64GB or more
- **GPU**: 24GB VRAM (RTX 3090/4090, M2 Max/Ultra)
- **Storage**: NVMe SSD with 150GB free
- **CPU**: Apple Silicon or recent Intel/AMD

### Optimal Performance
- **RAM**: 128GB
- **GPU**: 48GB VRAM or dual GPUs
- **Storage**: 2TB NVMe SSD
- **Platform**: Apple M2 Ultra or dual RTX 4090

## Installation

### Via Ollama

```bash
# Method 1: Pull pre-built model
ollama pull gpt-oss-120b:q4_k_m

# Method 2: Import from GGUF
ollama create gpt-oss-120b -f ./Modelfile
```

#### Modelfile Configuration
```dockerfile
FROM ./gpt-oss-120b-q4_k_m.gguf

# Model parameters
PARAMETER temperature 0.7
PARAMETER top_p 0.95
PARAMETER top_k 40
PARAMETER num_ctx 32768      # Start with 32K context
PARAMETER num_gpu 999         # Use all available GPU layers
PARAMETER repeat_penalty 1.1
PARAMETER stop "<|endoftext|>"
PARAMETER stop "<|im_end|>"

# System prompt for Harmony features
SYSTEM """
You are GPT-OSS-120B, an advanced language model with reasoning capabilities.

When solving complex problems or answering questions:
- Use <thinking> tags for your internal reasoning process
- Use <analysis> tags for breaking down complex issues
- Use <commentary> tags for meta-level observations
- Use <final> tags for your conclusive response

Always structure your responses clearly and think step-by-step.
"""

# Template for conversations
TEMPLATE """{{ if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}{{ if .Prompt }}<|im_start|>user
{{ .Prompt }}<|im_end|>
<|im_start|>assistant
{{ end }}"""
```

### Via LMStudio

1. **Download the model**:
   - Open LMStudio
   - Search for "gpt-oss-120b"
   - Select quantization (Q4_K_M recommended)
   - Click Download

2. **Configure settings**:
   ```json
   {
     "context_length": 16384,
     "gpu_layers": -1,
     "temperature": 0.7,
     "top_p": 0.95,
     "repeat_penalty": 1.1,
     "batch_size": 512
   }
   ```

## Usage Examples

### Basic Generation

```swift
import Tachikoma

// Simple generation
let response = try await generate(
    "Explain the theory of relativity",
    using: .gptOSS120B
)
print(response)
```

### With Reasoning Chains

```swift
// High-effort reasoning for complex problems
let detailed = try await generateText(
    model: .gptOSS120B,
    messages: [
        .system("You are a helpful assistant that shows your reasoning."),
        .user("What would happen if we could travel faster than light?")
    ],
    settings: GenerationSettings(
        reasoningEffort: .high,
        maxTokens: 4096,
        temperature: 0.8
    )
)

// Access different reasoning channels
if let thinking = detailed.channels[.thinking] {
    print("Internal reasoning:", thinking)
}
if let analysis = detailed.channels[.analysis] {
    print("Analysis:", analysis)
}
print("Final answer:", detailed.channels[.final] ?? detailed.text)
```

### Tool Calling

```swift
@ToolKit
struct MathTools {
    func calculate(expression: String) -> Double {
        // Implementation
    }
    
    func plotGraph(function: String, range: ClosedRange<Double>) -> String {
        // Implementation
    }
}

let response = try await generateText(
    model: .gptOSS120B,
    messages: [.user("Calculate the area under the curve y=x² from 0 to 5")],
    tools: MathTools(),
    settings: GenerationSettings(reasoningEffort: .medium)
)
```

### Streaming Responses

```swift
// Stream with buffering for better performance
for try await delta in streamText(
    model: .gptOSS120B,
    messages: conversation,
    settings: GenerationSettings(
        streamingBufferSize: 10  // Buffer 10 tokens
    )
) {
    switch delta.type {
    case .channelStart(let channel):
        print("Starting \(channel):")
    case .textDelta(let text):
        print(text, terminator: "")
    case .channelEnd(let channel):
        print("\nFinished \(channel)")
    default:
        break
    }
}
```

### With Caching

```swift
// Use aggressive caching for local models
let cachedProvider = ResponseCache.localModelCache.wrap(
    OllamaProvider(model: "gpt-oss-120b")
)

// Repeated queries will be instant
let response1 = try await generateText(
    model: .gptOSS120B,
    messages: [.user("What is Swift?")],
    provider: cachedProvider
)

// This will use the cache
let response2 = try await generateText(
    model: .gptOSS120B,
    messages: [.user("What is Swift?")],
    provider: cachedProvider
)
```

## Performance Optimization

### Memory Management

```swift
// Configure memory limits
LocalModelMemoryManager.shared.configure(
    maxMemoryGB: 48,
    autoUnloadMinutes: 10
)

// Preload model for better first-response time
try await LocalModelLoader.preload(.gptOSS120B)

// Explicitly manage model lifecycle
try await LocalModelLoader.load(.gptOSS120B)
defer {
    Task { try await LocalModelLoader.unload(.gptOSS120B) }
}
```

### Context Window Management

```swift
// Adaptive context sizing based on available memory
let optimalContext = LocalModelOptimizer.calculateOptimalContext(
    model: .gptOSS120B,
    availableRAM: ProcessInfo.processInfo.physicalMemory
)

let settings = GenerationSettings(
    maxContextTokens: optimalContext,
    truncationStrategy: .keepRecent  // Keep most recent messages
)
```

### GPU Acceleration

```swift
// Configure GPU usage
let config = LocalModelConfig(
    gpuLayers: .auto,           // Automatically determine
    metalAcceleration: true,    // Use Metal on macOS
    cudaDevices: [0, 1],        // Use multiple GPUs if available
    cpuThreads: 8               // Fallback CPU threads
)
```

## Quantization Guide

| Quantization | Size | RAM Required | Quality | Speed | Use Case |
|-------------|------|--------------|---------|-------|----------|
| Q4_0 | 65GB | 32GB | Good | Fast | General use |
| Q4_K_M | 67GB | 32GB | Better | Fast | **Recommended** |
| Q5_K_M | 82GB | 48GB | Very Good | Medium | Quality focus |
| Q6_K | 98GB | 64GB | Excellent | Slower | Research |
| Q8_0 | 127GB | 96GB | Near Perfect | Slow | Maximum quality |
| FP16 | 240GB | 128GB+ | Perfect | Very Slow | Development only |

## Troubleshooting

### Common Issues

**Model won't load**:
```swift
// Check available memory
let memoryStatus = try await LocalModelDiagnostics.checkMemory()
print("Available RAM: \(memoryStatus.availableGB)GB")
print("Required: \(memoryStatus.requiredGB)GB")

// Try smaller context
let settings = GenerationSettings(maxContextTokens: 4096)
```

**Slow generation**:
```swift
// Enable GPU acceleration
try await OllamaProvider.configure(
    gpuLayers: 60,  // Offload more layers to GPU
    useMlock: true   // Lock model in RAM
)

// Use streaming for better perceived performance
let stream = try await streamText(model: .gptOSS120B, ...)
```

**Out of memory errors**:
```swift
// Use automatic memory management
LocalModelMemoryManager.shared.enableAutoUnload()

// Or manually clear cache
await ResponseCache.localModelCache.clear()
```

### Performance Metrics

Monitor model performance:
```swift
let metrics = try await LocalModelMetrics.measure(model: .gptOSS120B) {
    try await generate("Test prompt", using: .gptOSS120B)
}

print("Time to first token: \(metrics.timeToFirstToken)ms")
print("Tokens per second: \(metrics.tokensPerSecond)")
print("Memory used: \(metrics.memoryUsedGB)GB")
```

## Best Practices

1. **Start with smaller context**: Begin with 8K-16K context and increase gradually
2. **Use appropriate quantization**: Q4_K_M offers best quality/performance balance
3. **Enable caching**: Local models benefit greatly from response caching
4. **Monitor memory**: Keep 20% RAM free for system stability
5. **Adjust reasoning effort**: Use `.low` for simple queries to save resources
6. **Batch similar requests**: Process related queries together
7. **Preload for production**: Load model before user requests

## Advanced Configuration

### Custom Ollama Models

Create specialized variants:
```bash
# High-creativity variant
cat > creative.Modelfile << EOF
FROM gpt-oss-120b:q4_k_m
PARAMETER temperature 1.2
PARAMETER top_p 0.98
PARAMETER repeat_penalty 0.9
EOF

ollama create gpt-oss-creative -f creative.Modelfile
```

### Fine-tuning Integration

```swift
// Use fine-tuned variants
let customModel = LanguageModel.ollama(
    OllamaModel(
        name: "gpt-oss-120b-medical",
        baseModel: "gpt-oss-120b",
        adapterPath: "~/models/medical-adapter.bin"
    )
)
```

## Migration Guide

### From GPT-4
```swift
// Before
let response = try await generateText(
    model: .openai(.gpt4),
    messages: messages,
    apiKey: "sk-..."
)

// After
let response = try await generateText(
    model: .gptOSS120B,
    messages: messages
    // No API key needed!
)
```

### From Claude
```swift
// Before
let response = try await generateText(
    model: .anthropic(.claude3),
    messages: messages
)

// After - with reasoning chains
let response = try await generateText(
    model: .gptOSS120B,
    messages: messages,
    settings: GenerationSettings(
        reasoningEffort: .high  // Similar to Claude's thinking
    )
)
```

## Related Documentation

- [LMStudio Integration](lmstudio.md) - Alternative local hosting
- [OpenAI Harmony Features](openai-harmony.md) - Multi-channel responses
- [Performance Tuning](performance.md) - Optimization guide