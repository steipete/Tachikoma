# AI CLI

A command-line interface for querying AI models through the Tachikoma library.

## Building

```bash
# Clone and build
git clone https://github.com/steipete/tachikoma.git
cd tachikoma
swift build --product ai-cli

# Install globally (optional)
swift build -c release --product ai-cli
cp .build/release/ai-cli /usr/local/bin/ai-cli
```

## Usage

```bash
# Basic usage
ai-cli "What is the capital of France?"

# Specify a model
ai-cli --model claude "Explain quantum computing"

# Stream the response
ai-cli --stream --model gpt-4o "Write a short story"
```

## Parameters

| Option | Description |
|--------|-------------|
| `-m, --model <MODEL>` | Specify the AI model to use |
| `--api <chat\|responses>` | For OpenAI models: select API type (default: responses for GPT-5) |
| `-s, --stream` | Stream the response in real-time |
| `--thinking` | Show reasoning process (O3, O4, GPT-5 - note: API currently doesn't expose actual reasoning) |
| `--verbose, -v` | Show detailed debug output |
| `--config` | Show current configuration and API key status |
| `--help, -h` | Show help message |
| `--version` | Show version information |

## Environment Variables

Set API keys for your providers:

```bash
export OPENAI_API_KEY='sk-...'         # OpenAI models
export ANTHROPIC_API_KEY='sk-ant-...'  # Claude models
export GEMINI_API_KEY='...'            # Gemini models (legacy GOOGLE_API_KEY or GOOGLE_APPLICATION_CREDENTIALS also accepted)
export MISTRAL_API_KEY='...'           # Mistral models
export GROQ_API_KEY='gsk-...'          # Groq models
export X_AI_API_KEY='xai-...'          # Grok models
# Ollama runs locally, no API key needed
```

Add to your shell profile (`~/.zshrc`, `~/.bashrc`) for persistence.

## Supported Models

### OpenAI
- **GPT-5 Series**: `gpt-5`, `gpt-5-mini`, `gpt-5-nano`
- **O-Series**: `o3`, `o3-mini`, `o3-pro`, `o4-mini`
- **GPT-4**: `gpt-4.1`, `gpt-4.1-mini`, `gpt-4o`, `gpt-4o-mini`, `gpt-4-turbo`
- **Legacy**: `gpt-3.5-turbo`

### Anthropic
- **Claude 4**: `claude-opus-4-1-20250805`, `claude-sonnet-4-20250514`
- **Claude 3.7**: `claude-3-7-sonnet`
- **Claude 3.5**: `claude-3-5-opus`, `claude-3-5-sonnet`, `claude-3-5-haiku`

### Google
- **Gemini 2.5**: `gemini-2.5-pro`, `gemini-2.5-flash`, `gemini-2.5-flash-lite`

### Others
- **Mistral**: `mistral-large-2`, `mistral-small`, `codestral`
- **Groq**: `llama-3.1-70b`, `llama-3.1-8b`, `mixtral-8x7b`
* **Grok**: `grok-4-0709`, `grok-4-fast-reasoning`, `grok-4-fast-non-reasoning`, `grok-code-fast-1`, `grok-3`, `grok-3-mini`, `grok-2-1212`, `grok-2-vision-1212`, `grok-2-image-1212`
- **Ollama** (local): `llama3.3`, `llava`, `codellama`, any installed model

### Model Shortcuts
- `claude` → claude-opus-4-1-20250805
- `gpt` → gpt-4.1
- `gemini` → gemini-2.5-flash
- `grok` → grok-4-fast-reasoning
- `llama` → llama3.3

## Examples

```bash
# Quick queries
ai-cli "What is 2+2?"
ai-cli --model claude "Write a haiku about coding"

# Streaming
ai-cli --stream --model gpt-5 "Explain the theory of relativity"

# API selection for OpenAI
ai-cli --model gpt-5 --api chat "Use Chat Completions API"
ai-cli --model o3 --api responses "Use Responses API"

# Debug mode
ai-cli --verbose --model opus "Debug this request"

# Check configuration
ai-cli --config
```

## License

MIT License - See [LICENSE](../../LICENSE) file for details.
