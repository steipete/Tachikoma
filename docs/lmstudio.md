# LMStudio Provider Documentation

LMStudio is a cross-platform desktop application for running large language models locally with a user-friendly interface. Tachikoma provides native integration with LMStudio's OpenAI-compatible API server.

## Overview

LMStudio offers:
- **Cross-platform support** on macOS and Linux (Windows builds exist upstream but aren’t supported in Tachikoma)
- **GUI for model management** with easy downloads
- **OpenAI-compatible API** at `http://localhost:1234/v1`
- **Hardware acceleration** (Metal, CUDA, ROCm)
- **Model quantization** support (GGUF, GGML)
- **Built-in performance monitoring**

## Installation

### Step 1: Install LMStudio

Download from [https://lmstudio.ai](https://lmstudio.ai) or use Homebrew:

```bash
# macOS
brew install --cask lmstudio

# Linux (AppImage)
wget https://releases.lmstudio.ai/linux/LMStudio.AppImage
chmod +x LMStudio.AppImage
./LMStudio.AppImage
```

### Step 2: Download Models

1. Open LMStudio
2. Navigate to "Discover" tab
3. Search for models (e.g., "gpt-oss-120b", "llama", "mistral")
4. Select quantization and click "Download"

### Step 3: Start Server

1. Go to "Local Server" tab
2. Select your model
3. Configure settings
4. Click "Start Server"

## Configuration

### Server Settings

```json
{
  "host": "localhost",
  "port": 1234,
  "cors": true,
  "verbose": true,
  "models": {
    "gpt-oss-120b": {
      "path": "~/.cache/lm-studio/models/openai/gpt-oss-120b-q4_k_m.gguf",
      "context_length": 16384,
      "gpu_layers": -1,
      "use_mlock": true,
      "batch_size": 512
    }
  }
}
```

### Model Configuration

In LMStudio's UI or via config file:

```yaml
# Model Settings
context_length: 16384      # Context window size
n_gpu_layers: -1          # -1 for all layers on GPU
n_batch: 512              # Batch size for prompt processing
threads: 8                # CPU threads (if not fully on GPU)
use_mlock: true           # Lock model in RAM
use_mmap: true            # Memory-map model file

# Inference Settings
temperature: 0.7
top_p: 0.95
top_k: 40
repeat_penalty: 1.1
presence_penalty: 0.0
frequency_penalty: 0.0
mirostat: 0               # 0=disabled, 1=Mirostat, 2=Mirostat 2.0
```

## Usage with Tachikoma

### Basic Setup

```swift
import Tachikoma

// Initialize LMStudio provider
let provider = LMStudioProvider(
    baseURL: "http://localhost:1234/v1",  // Default LMStudio URL
    apiKey: nil  // No API key needed for local
)

// Use with Tachikoma's generation functions
let response = try await generateText(
    model: .lmstudio("gpt-oss-120b"),
    messages: [.user("Hello, how are you?")],
    provider: provider
)
```

### Auto-Detection

```swift
// Automatically detect if LMStudio is running
if let provider = try await LMStudioProvider.autoDetect() {
    print("LMStudio found at: \(provider.baseURL)")
    print("Available models: \(provider.availableModels)")
} else {
    print("LMStudio not running. Please start the server.")
}
```

### Model Management

```swift
// List available models
let models = try await provider.listModels()
for model in models {
    print("\(model.id): \(model.sizeGB)GB, \(model.quantization)")
}

// Load a specific model
try await provider.loadModel("gpt-oss-120b-q4_k_m")

// Check model status
let status = try await provider.modelStatus("gpt-oss-120b")
print("Loaded: \(status.isLoaded)")
print("Memory: \(status.memoryUsageGB)GB")
print("GPU: \(status.gpuLayers)/\(status.totalLayers) layers")
```

### Advanced Generation

```swift
// With custom parameters
let response = try await provider.generateText(
    request: ProviderRequest(
        messages: [
            .system("You are a helpful coding assistant."),
            .user("Write a Swift function to sort an array.")
        ],
        tools: nil,
        settings: GenerationSettings(
            maxTokens: 2048,
            temperature: 0.7,
            topP: 0.95,
            stopSequences: ["```", "// End"],
            reasoningEffort: .medium
        )
    )
)

// Access multi-channel responses
if let thinking = response.channels[.thinking] {
    print("Reasoning: \(thinking)")
}
print("Code: \(response.text)")
```

### Streaming

```swift
// Stream responses for better UX
for try await delta in provider.streamText(
    request: ProviderRequest(
        messages: [.user("Explain quantum computing")],
        settings: GenerationSettings(streamingBufferSize: 5)
    )
) {
    switch delta.type {
    case .textDelta(let text):
        print(text, terminator: "")
    case .channelStart(let channel):
        print("\n[\(channel)]", terminator: " ")
    case .usage(let usage):
        print("\n\nTokens: \(usage.totalTokens)")
    default:
        break
    }
}
```

### Function Calling

```swift
// LMStudio supports OpenAI-style function calling
@ToolKit
struct Tools {
    func getCurrentWeather(location: String) -> String {
        return "Sunny, 22°C"
    }
    
    func searchWeb(query: String) -> [String] {
        return ["Result 1", "Result 2"]
    }
}

let response = try await generateText(
    model: .lmstudio("gpt-oss-120b"),
    messages: [.user("What's the weather in Tokyo?")],
    tools: Tools(),
    provider: provider
)

// Tool calls are automatically executed
print(response.text)  // "The weather in Tokyo is sunny with 22°C"
```

## Performance Optimization

### GPU Acceleration

```swift
// Configure GPU usage
let config = LMStudioConfig(
    gpuLayers: .all,           // Use all layers on GPU
    gpuSplitMode: .layer,      // Split by layers, not rows
    mainGPU: 0,                // Primary GPU index
    tensorSplit: [1.0]         // Single GPU (or [0.5, 0.5] for dual)
)

let provider = LMStudioProvider(config: config)
```

### Memory Management

```swift
// Optimize memory usage
let memoryConfig = LMStudioMemoryConfig(
    useMlock: true,            // Lock model in RAM
    useMmap: true,             // Memory-map files
    offloadKQV: true,          // Offload KQV to GPU
    flashAttention: true,      // Use Flash Attention
    contextSizeReduction: 0.5  // Reduce context if low on memory
)
```

### Batch Processing

```swift
// Process multiple requests efficiently
let requests = [
    "Summarize this text: ...",
    "Translate to Spanish: ...",
    "Answer this question: ..."
]

let responses = try await provider.batchGenerate(
    requests: requests.map { text in
        ProviderRequest(
            messages: [.user(text)],
            settings: GenerationSettings(maxTokens: 500)
        )
    },
    batchSize: 3,  // Process 3 at a time
    parallel: true  // Use parallel processing
)
```

## Model Library

### Recommended Models for LMStudio

| Model | Size | Use Case | Quantization |
|-------|------|----------|--------------|
| GPT-OSS-120B | 65GB | General purpose, reasoning | Q4_K_M |
| Llama-3-70B | 35GB | Chat, coding | Q4_K_M |
| Mixtral-8x7B | 24GB | Fast, versatile | Q4_K_S |
| CodeLlama-34B | 20GB | Code generation | Q5_K_M |
| Mistral-7B | 4GB | Lightweight, fast | Q8_0 |
| Phi-3-mini | 2GB | Ultra-light, mobile | Q4_K_M |

### Model Selection

```swift
// Choose model based on available resources
let selector = ModelSelector(
    maxRAM: ProcessInfo.processInfo.physicalMemory,
    maxVRAM: Metal.Device.default?.recommendedMaxMemory,
    preferredSpeed: .balanced  // .fast, .balanced, .quality
)

let bestModel = try await selector.recommendModel(
    task: .general,  // .chat, .code, .reasoning, .creative
    provider: provider
)

print("Recommended: \(bestModel.name)")
print("Reason: \(bestModel.recommendation)")
```

## Integration Examples

### Chat Interface

```swift
class LMStudioChat {
    let provider = LMStudioProvider()
    var conversation: [ModelMessage] = []
    
    func chat(_ message: String) async throws -> String {
        conversation.append(.user(message))
        
        let response = try await generateText(
            model: .lmstudio("current"),  // Uses currently loaded model
            messages: conversation,
            provider: provider,
            settings: GenerationSettings(
                maxTokens: 1000,
                temperature: 0.7
            )
        )
        
        conversation.append(.assistant(response.text))
        return response.text
    }
    
    func reset() {
        conversation = []
    }
}
```

### Code Assistant

```swift
struct LMStudioCodeAssistant {
    let provider = LMStudioProvider()
    
    func generateCode(
        prompt: String,
        language: String = "swift"
    ) async throws -> String {
        let response = try await generateText(
            model: .lmstudio("codellama-34b"),
            messages: [
                .system("You are an expert \(language) developer. Generate clean, efficient code with comments."),
                .user(prompt)
            ],
            provider: provider,
            settings: GenerationSettings(
                temperature: 0.3,  // Lower temperature for code
                stopSequences: ["```", "// End of code"]
            )
        )
        
        return response.text
    }
    
    func explainCode(_ code: String) async throws -> String {
        let response = try await generateText(
            model: .lmstudio("current"),
            messages: [
                .system("Explain the following code clearly and concisely."),
                .user(code)
            ],
            provider: provider
        )
        
        return response.text
    }
}
```

### Document Analysis

```swift
struct DocumentAnalyzer {
    let provider = LMStudioProvider()
    
    func analyze(document: String) async throws -> Analysis {
        let response = try await generateText(
            model: .lmstudio("mixtral-8x7b"),
            messages: [
                .system("Analyze the document and provide: summary, key points, sentiment, and recommendations."),
                .user(document)
            ],
            provider: provider,
            settings: GenerationSettings(
                reasoningEffort: .high,
                maxTokens: 2000
            )
        )
        
        // Parse structured response
        return Analysis(
            summary: response.channels[.final] ?? response.text,
            reasoning: response.channels[.thinking],
            keyPoints: extractKeyPoints(response.text)
        )
    }
}
```

## Troubleshooting

### Connection Issues

```swift
// Check if LMStudio is running
do {
    let health = try await provider.healthCheck()
    print("Server status: \(health.status)")
} catch {
    print("LMStudio not reachable. Please ensure:")
    print("1. LMStudio is running")
    print("2. Server is started (Local Server tab)")
    print("3. Port 1234 is not blocked")
}
```

### Performance Issues

```swift
// Diagnose performance problems
let diagnostics = try await provider.runDiagnostics()

print("Model: \(diagnostics.model)")
print("Context: \(diagnostics.contextSize)")
print("GPU Layers: \(diagnostics.gpuLayers)/\(diagnostics.totalLayers)")
print("Inference Speed: \(diagnostics.tokensPerSecond) tok/s")
print("Memory Used: \(diagnostics.memoryGB)GB")

if diagnostics.tokensPerSecond < 10 {
    print("Suggestions:")
    print("- Reduce context size")
    print("- Enable GPU acceleration")
    print("- Use smaller quantization")
    print("- Close other applications")
}
```

### Model Loading Errors

```swift
// Handle model loading issues
do {
    try await provider.loadModel("model-name")
} catch LMStudioError.insufficientMemory(required: let req, available: let avail) {
    print("Not enough memory: need \(req)GB, have \(avail)GB")
    print("Try: smaller quantization or reduced context")
} catch LMStudioError.modelNotFound(let name) {
    print("Model '\(name)' not found")
    print("Available models:", try await provider.listModels())
} catch {
    print("Loading error: \(error)")
}
```

## Advanced Features

### Custom Server Endpoints

```swift
// Use custom LMStudio installations
let customProvider = LMStudioProvider(
    baseURL: "http://192.168.1.100:1234/v1",  // Remote LMStudio
    headers: ["X-Custom-Auth": "token"]         // Custom headers
)
```

### Model Switching

```swift
// Switch between models dynamically
let chatbot = MultiModelChat(provider: provider)

// Use fast model for simple queries
chatbot.useModel("mistral-7b")
let quick = try await chatbot.chat("What's 2+2?")

// Switch to powerful model for complex tasks
chatbot.useModel("gpt-oss-120b")
let complex = try await chatbot.chat("Explain quantum entanglement")
```

### Monitoring & Metrics

```swift
// Track usage and performance
let monitor = LMStudioMonitor(provider: provider)

monitor.onGeneration = { metrics in
    print("Model: \(metrics.model)")
    print("Prompt tokens: \(metrics.promptTokens)")
    print("Generation tokens: \(metrics.generationTokens)")
    print("Time: \(metrics.totalTime)s")
    print("Speed: \(metrics.tokensPerSecond) tok/s")
}

// Get aggregated stats
let stats = monitor.getStatistics()
print("Total requests: \(stats.totalRequests)")
print("Average speed: \(stats.averageTokensPerSecond) tok/s")
print("Total tokens: \(stats.totalTokens)")
```

## Best Practices

1. **Start LMStudio before your app**: Ensure the server is running
2. **Use appropriate models**: Match model size to your hardware
3. **Monitor memory usage**: Keep 20% RAM free for stability
4. **Enable GPU acceleration**: Dramatically improves performance
5. **Use streaming for UX**: Better perceived responsiveness
6. **Cache responses**: Avoid regenerating identical queries
7. **Handle errors gracefully**: Network and memory issues can occur
8. **Test model switching**: Different models for different tasks

## FAQ

**Q: Can I use multiple models simultaneously?**
A: LMStudio loads one model at a time, but you can switch models programmatically.

**Q: How do I use LMStudio on a different machine?**
A: Change the baseURL to the remote machine's IP: `http://192.168.1.100:1234/v1`

**Q: Can I fine-tune models in LMStudio?**
A: LMStudio is for inference only. Use other tools for fine-tuning, then import the GGUF.

**Q: What's the maximum context size?**
A: Depends on model and available RAM. Start with 4K-8K and increase gradually.

**Q: How do I enable Flash Attention?**
A: It's automatically enabled on supported hardware (recent NVIDIA GPUs).

## Related Documentation

- [GPT-OSS-120B Guide](gpt-oss.md) - Detailed setup for GPT-OSS
- [Local Model Optimization](performance.md) - Performance tuning
- [OpenAI Harmony Features](openai-harmony.md) - Advanced features
