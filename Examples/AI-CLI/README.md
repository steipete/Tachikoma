# AI CLI - Universal AI Assistant

A comprehensive command-line interface for interacting with multiple AI providers through the Tachikoma library. Supporting OpenAI, Anthropic, Google, Mistral, Groq, Grok (xAI), and Ollama models.

## Features

- ✨ **Universal Support**: Works with 7+ AI providers
- 🚀 **Smart Model Selection**: Intelligent model parsing with shortcuts
- 🔐 **Secure**: API key validation and masking
- 📊 **Detailed Output**: Usage statistics and cost estimates
- 🌊 **Streaming**: Real-time response streaming (where supported)
- 🛠 **Production Ready**: Comprehensive error handling and user guidance

## Installation

### Build from Source

```bash
# Clone the Tachikoma repository
git clone https://github.com/steipete/tachikoma.git
cd tachikoma

# Build the AI CLI
swift build --product ai-cli

# The binary will be at .build/debug/ai-cli
```

### Optional: Install Globally

```bash
# Build in release mode
swift build -c release --product ai-cli

# Copy to your PATH (optional)
cp .build/release/ai-cli /usr/local/bin/ai-cli
```

## Quick Start

### 1. Set up API Keys

**The AI CLI automatically loads API keys from environment variables.** No configuration files needed!

Choose your preferred provider(s) and set the corresponding environment variable:

```bash
# OpenAI (GPT models)
export OPENAI_API_KEY='sk-your-key-here'

# Anthropic (Claude models)
export ANTHROPIC_API_KEY='sk-ant-your-key-here'

# Google (Gemini models)
export GOOGLE_API_KEY='your-key-here'

# Other providers...
export MISTRAL_API_KEY='your-key-here'
export GROQ_API_KEY='gsk_your-key-here'
export X_AI_API_KEY='xai-your-key-here'  # For Grok
```

**Note:** The CLI automatically detects and uses any API keys present in your environment. For persistent setup, add these to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.).

### 2. Basic Usage

```bash
# Default model (GPT-5)
ai-cli "What is the capital of France?"

# Use a specific model
ai-cli --model claude "Explain quantum computing in simple terms"

# Stream responses
ai-cli --stream --model gpt-4o "Write a short story about AI"
```

## Usage Examples

### OpenAI Models

```bash
# GPT-5 series (latest, August 2025)
ai-cli --model gpt-5 "Help me debug this Python code"
ai-cli --model gpt-5-mini "Quick question about JavaScript"
ai-cli --model gpt-5-nano "Fast response needed"

# Choose API type (GPT-5 defaults to Responses API)
ai-cli --model gpt-5 --api chat "Use Chat Completions API"
ai-cli --model gpt-5 --api responses "Use Responses API"

# Other OpenAI models
ai-cli --model o3 "Complex reasoning task"
ai-cli --model gpt-4o "Analyze this image and text"
ai-cli --model gpt-4.1 "General purpose query"
```

### Anthropic (Claude) Models

```bash
# Claude 4 series (best performance)
ai-cli --model claude "Write a technical document"
ai-cli --model opus "Complex analysis task"
ai-cli --model sonnet "Balanced performance query"

# Specific models
ai-cli --model claude-opus-4-1-20250805 "Using exact model ID"
ai-cli --model claude-sonnet-4-20250514 "Latest Sonnet model"
```

### Google Gemini Models

```bash
# Gemini 2.0 (latest)
ai-cli --model gemini-2.0-flash "Fast multimodal query"
ai-cli --model gemini-2.0-flash-thinking "Reasoning task"

# Gemini 1.5
ai-cli --model gemini-1.5-pro "Long context analysis"
ai-cli --model gemini-1.5-flash "Quick response"
```

### Other Providers

```bash
# Grok (xAI) - Known for humor and current events
ai-cli --model grok "Tell me a joke about programming"
ai-cli --model grok-2-image-1212 "Analyze this image"

# Groq (Ultra-fast inference)
ai-cli --model llama-3.1-70b "Fast response needed"
ai-cli --model mixtral-8x7b "Quick coding help"

# Mistral
ai-cli --model mistral-large-2 "French language query"
ai-cli --model codestral "Help with code review"

# Ollama (Local models)
ai-cli --model llama3.3 "Local inference"
ai-cli --model llava "Analyze image locally"
```

### Advanced Usage

```bash
# Check configuration
ai-cli --config

# Streaming responses
ai-cli --stream --model claude "Write a long article about AI"

# Model shortcuts
ai-cli --model claude "Use default Claude model"
ai-cli --model gpt "Use default GPT model"
ai-cli --model llama "Use default Llama model"
```

## Supported Models

### OpenAI
- **GPT-5 Series** (August 2025): `gpt-5`, `gpt-5-mini`, `gpt-5-nano`
- **O-Series**: `o3`, `o3-mini`, `o3-pro`, `o4-mini`
- **GPT-4.1**: `gpt-4.1`, `gpt-4.1-mini`
- **GPT-4o** (Multimodal): `gpt-4o`, `gpt-4o-mini`
- **Legacy**: `gpt-4-turbo`, `gpt-3.5-turbo`

### Anthropic (Claude)
- **Claude 4**: `claude-opus-4-1-20250805`, `claude-sonnet-4-20250514`
- **Claude 3.7**: `claude-3-7-sonnet`
- **Claude 3.5**: `claude-3-5-opus`, `claude-3-5-sonnet`, `claude-3-5-haiku`

### Google
- **Gemini 2.0**: `gemini-2.0-flash`, `gemini-2.0-flash-thinking`
- **Gemini 1.5**: `gemini-1.5-pro`, `gemini-1.5-flash`, `gemini-1.5-flash-8b`

### Mistral
- `mistral-large-2`, `mistral-large`, `mistral-small`
- `mistral-nemo`, `codestral`

### Groq (Ultra-fast)
- `llama-3.1-70b`, `llama-3.1-8b`
- `mixtral-8x7b`, `gemma2-9b`

### Grok (xAI)
- `grok-4-0709`, `grok-3`, `grok-3-mini`
- `grok-2-image-1212` (Vision support)

### Ollama (Local)
- **Recommended**: `llama3.3`, `llama3.2`, `llama3.1`
- **Vision**: `llava`, `bakllava`, `llama3.2-vision:11b`, `qwen2.5vl:7b`
- **Specialized**: `codellama`, `mistral-nemo`, `deepseek-r1`
- **Custom**: Any model available in your Ollama installation

## Model Shortcuts

For convenience, you can use these shortcuts:

- `claude`, `opus` → `claude-opus-4-1-20250805`
- `gpt`, `gpt4` → `gpt-4.1`
- `grok` → `grok-4-0709`
- `llama`, `llama3` → `llama3.3`

## API Key Setup

### How API Keys Work

**The AI CLI automatically loads API keys from environment variables** - no configuration files or manual setup required! Simply export the appropriate environment variable for your provider, and the CLI will detect and use it automatically.

```bash
# Once you export a key, it's immediately available
export OPENAI_API_KEY='sk-...'  
ai-cli "This will now work with OpenAI models!"

# Check which keys are configured
ai-cli --config
```

### Get API Keys

| Provider | Get Key At | Environment Variable |
|----------|------------|---------------------|
| OpenAI | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) | `OPENAI_API_KEY` |
| Anthropic | [console.anthropic.com](https://console.anthropic.com/) | `ANTHROPIC_API_KEY` |
| Google | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) | `GOOGLE_API_KEY` |
| Mistral | [console.mistral.ai](https://console.mistral.ai/) | `MISTRAL_API_KEY` |
| Groq | [console.groq.com/keys](https://console.groq.com/keys) | `GROQ_API_KEY` |
| Grok (xAI) | [console.x.ai](https://console.x.ai/) | `X_AI_API_KEY` or `XAI_API_KEY` |
| Ollama | Local installation | None required |

### Set Environment Variables

#### Temporary (current session)
```bash
export OPENAI_API_KEY='sk-your-key-here'
export ANTHROPIC_API_KEY='sk-ant-your-key-here'
# ... other keys
```

#### Permanent (add to shell profile)
```bash
# Add to ~/.zshrc, ~/.bashrc, or ~/.profile
echo 'export OPENAI_API_KEY="sk-your-key-here"' >> ~/.zshrc
echo 'export ANTHROPIC_API_KEY="sk-ant-your-key-here"' >> ~/.zshrc
source ~/.zshrc
```

#### Using a .env file (recommended)
```bash
# Create .env file
cat > .env << EOF
OPENAI_API_KEY=sk-your-key-here
ANTHROPIC_API_KEY=sk-ant-your-key-here
GOOGLE_API_KEY=your-key-here
MISTRAL_API_KEY=your-key-here
GROQ_API_KEY=gsk-your-key-here
X_AI_API_KEY=xai-your-key-here
EOF

# Load before using AI CLI
source .env
ai-cli "Now I can use any provider!"
```

## Ollama Setup

For local models through Ollama:

```bash
# Install Ollama
brew install ollama  # macOS
# or download from https://ollama.ai

# Start Ollama service
ollama serve

# Pull recommended models
ollama pull llama3.3        # Best overall
ollama pull llava          # Vision support
ollama pull codellama      # Code specialist
ollama pull mistral-nemo   # Alternative

# Use with AI CLI (no API key needed)
ai-cli --model llama3.3 "Local AI query"
ai-cli --model llava "Analyze this image locally"
```

## Tested Models

These models have been specifically tested and verified to work with the AI CLI:

### ✅ Successfully Tested

| Provider | Model | Command | Status |
|----------|-------|---------|--------|
| OpenAI | GPT-5 | `ai-cli --model gpt-5 "test"` | ✅ Working (Chat & Responses API) |
| OpenAI | GPT-5 Mini | `ai-cli --model gpt-5-mini "test"` | ✅ Working |
| OpenAI | GPT-4o | `ai-cli --model gpt-4o "test"` | ✅ Working |
| Anthropic | Claude Opus 4 | `ai-cli --model claude "test"` | ✅ Working |
| xAI | Grok 4 | `ai-cli --model grok "test"` | ✅ Working (great for jokes!) |
| OpenAI | GPT-5 + Streaming | `ai-cli --stream --model gpt-5 "test"` | ✅ Real-time streaming |
| OpenAI | GPT-4o + Streaming | `ai-cli --stream --model gpt-4o "test"` | ✅ Real-time streaming |

### 🔍 Test Results

- **GPT-5 Series**: Both Chat Completions and Responses APIs tested successfully
- **Claude Opus 4**: Fast responses with excellent reasoning
- **Grok 4**: Unique personality, great for creative and humorous queries
- **Streaming**: Verified working with OpenAI models for real-time output
- **Error Handling**: Missing API keys properly detected and reported
- **Model Shortcuts**: `claude` → Claude Opus 4, `grok` → Grok 4 verified working

### 📝 Sample Test Outputs

```bash
# GPT-5 with Responses API
$ ai-cli --api responses "What is 2+2?"
🔐 API Key: sk-pr...EqfAA
🤖 Model: gpt-5
🌐 API: Responses API
✅ Using Responses API
💬 Response: 4
📊 Usage: Input: 13, Output: 71, Total: 84

# Claude Opus 4
$ ai-cli --model claude "Explain quantum entanglement"
🔐 API Key: sk-an...3456
🤖 Model: claude-opus-4-1-20250805
🌐 Provider: Anthropic
💬 Response: [Detailed explanation...]

# Grok with humor
$ ai-cli --model grok "Tell me a programming joke"
🔐 API Key: xai-...abcd
🤖 Model: grok-4-0709
💬 Response: Why do programmers prefer dark mode? Because light attracts bugs!
```

## Command Reference

### Options
- `-m, --model <MODEL>`: Specify AI model
- `--api <chat|responses>`: OpenAI API type (default: responses for GPT-5)
- `-s, --stream`: Stream responses
- `--thinking`: Show reasoning/thinking process (O3, O4, GPT-5 via Responses API)
- `--config`: Show configuration and API key status
- `-h, --help`: Show help message
- `-v, --version`: Show version

### Examples by Use Case

#### Code Review
```bash
ai-cli --model gpt-5 "Review this Python function for bugs and improvements"
ai-cli --model codestral "Analyze this JavaScript code for performance issues"
```

#### Creative Writing
```bash
ai-cli --stream --model claude "Write a short sci-fi story about time travel"
ai-cli --model grok "Write a humorous take on programming languages"
```

#### Technical Explanation
```bash
ai-cli --model sonnet "Explain how blockchain consensus algorithms work"
ai-cli --model gemini-1.5-pro "Compare different database architectures"
```

#### Reasoning & Problem Solving (with --thinking)
```bash
ai-cli --thinking --model gpt-5 "Solve this logic puzzle step by step"
ai-cli --thinking --model o3-mini --api responses "What's the optimal algorithm for this problem?"
```
Note: The `--thinking` flag attempts to show the model's reasoning process, but currently most models (including GPT-5 and O3) don't expose their internal reasoning through the API.

#### Image Analysis (Vision models)
```bash
ai-cli --model gpt-4o "Describe what's in this image: /path/to/image.jpg"
ai-cli --model llava "Analyze this screenshot locally"
```

## Troubleshooting

### Common Issues

#### API Key Not Found
```
❌ Error: Missing API key: OPENAI_API_KEY environment variable not set
```
**Solution**: Set the appropriate environment variable for your provider.

#### Model Not Found
```
❌ Error parsing model: Invalid model 'gpt-6'
```
**Solution**: Check model name spelling or use `--help` to see available models.

#### Rate Limit Exceeded
```
❌ Rate limit exceeded
```
**Solution**: Wait a moment and retry, or switch to a different model/provider.

#### Network Issues
```
❌ Error: Network error
```
**Solution**: Check internet connection and provider service status.

### Debug Configuration

Check your current setup:
```bash
ai-cli --config
```

This shows:
- Currently selected model and capabilities
- API key status (masked for security)
- Available providers and their key status
- Current options

### Getting Help

- Use `ai-cli --help` for detailed usage information
- Check model availability with `ai-cli --config`
- Visit [Tachikoma documentation](https://github.com/steipete/tachikoma) for more details

## Cost Estimates

The CLI provides approximate cost estimates for supported providers:

```bash
ai-cli --model gpt-4o "Expensive query"
# Shows:
# 📊 Usage:
#   Input tokens: 100
#   Output tokens: 500
#   Total tokens: 600
#   Estimated cost: $0.008500
```

*Note: Estimates are approximate and based on public pricing as of 2025. Actual costs may vary.*

## Advanced Configuration

### Custom Models

You can use custom model IDs:

```bash
# Custom OpenAI model
ai-cli --model "your-custom-gpt-model" "Query"

# Custom Anthropic model
ai-cli --model "custom-claude-model" "Query"

# Custom Ollama model
ai-cli --model "your-local-model:tag" "Query"
```

### Environment Variables

All supported environment variables:

```bash
# Primary API keys
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_API_KEY=...
MISTRAL_API_KEY=...
GROQ_API_KEY=gsk-...
X_AI_API_KEY=xai-...      # Primary for Grok
XAI_API_KEY=xai-...       # Alternative for Grok

# Ollama configuration (optional)
OLLAMA_HOST=http://localhost:11434  # Default
```

## Integration

The AI CLI is built on [Tachikoma](https://github.com/steipete/tachikoma), a universal AI integration library for Swift. You can use Tachikoma directly in your Swift applications for the same multi-provider support.

```swift
import Tachikoma

// Same functionality in Swift code
let result = try await generateText(
    model: .anthropic(.opus4),
    messages: [.user("Hello, AI!")],
    settings: GenerationSettings(maxTokens: 1000)
)
```

## License

This project is licensed under the MIT License. See the [LICENSE](../../LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Changelog

### v1.0.0 (2025)
- ✨ Initial release with support for 7+ AI providers
- 🚀 Smart model parsing and shortcuts
- 🔐 Secure API key handling
- 📊 Usage statistics and cost estimates
- 🌊 Streaming response support
- 🛠 Comprehensive error handling and user guidance