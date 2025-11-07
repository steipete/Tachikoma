# Agent CLI

An advanced AI agent command-line interface with conversation support, MCP tool calling, and a fancy status bar UI.

## Features

- **Multi-turn Conversations**: Maintain context across multiple interactions
- **MCP Tool Support**: Connect to Model Context Protocol servers for extended capabilities
- **Status Bar UI**: Real-time status updates with spinners and progress indicators
- **Thinking Display**: Show reasoning process for models that support it (O3, GPT-5)
- **Interactive Mode**: Continuous conversation with history management
- **Multiple Output Formats**: Normal, JSON, or Markdown formatting
- **Tool Visualization**: See tool calls with timing and results

## Building

```bash
# Build the agent
swift build --product agent-cli

# Install globally (optional)
swift build -c release --product agent-cli
cp .build/release/agent-cli /usr/local/bin/
```

## Usage

### Basic Query

```bash
agent-cli "What is the weather like today?"
```

### Interactive Mode

```bash
agent-cli --interactive
# or just
agent-cli -i
```

In interactive mode:
- Type your queries naturally
- Type `exit` or `quit` to leave
- Type `clear` to reset conversation
- Type `history` to see conversation history

### With Specific Model

```bash
agent-cli --model gpt-5 "Explain quantum computing"
agent-cli --model claude "Write a haiku"
agent-cli --model o3 --thinking "Solve this step by step: ..."
```

### With MCP Tools

```bash
# Add filesystem access
agent-cli --mcp-server "fs -- npx @modelcontextprotocol/server-filesystem /tmp" \
          "List all files in the temp directory"

# Add multiple servers
agent-cli --mcp-server "github -- npx @modelcontextprotocol/server-github" \
          --mcp-server "db -- npx @modelcontextprotocol/server-sqlite ./data.db" \
          "Query the database for user statistics"
```

### Advanced Options

```bash
# Show thinking/reasoning process
agent-cli --thinking "Complex problem..."

# Verbose mode with debug info
agent-cli --verbose "Debug this..."

# Quiet mode - minimal output
agent-cli --quiet "Quick query"

# JSON output format
agent-cli --format json "API request"

# Save/load conversations
agent-cli --save conversation.json "Start of discussion"
agent-cli --load conversation.json "Continue from before"

# Limit conversation turns
agent-cli --max-turns 5 --interactive
```

## Command Reference

| Option | Description |
|--------|-------------|
| `[query]` | Query or task for the agent |
| `-m, --model <MODEL>` | AI model to use (default: gpt-5) |
| `-i, --interactive` | Interactive conversation mode |
| `--thinking` | Show thinking/reasoning process |
| `-v, --verbose` | Verbose output with debug info |
| `-q, --quiet` | Quiet mode - minimal output |
| `--format <FORMAT>` | Output format: normal, json, markdown |
| `--max-turns <N>` | Maximum conversation turns (default: 10) |
| `--mcp-server <SPEC>` | Add MCP server (format: name -- command) |
| `--load <FILE>` | Load conversation from JSON file |
| `--save <FILE>` | Save conversation to JSON file |
| `--list-servers` | List available MCP servers |
| `--show-config` | Show current configuration |
| `--help` | Show help message |
| `--version` | Show version |

## Status Bar UI

The agent provides real-time status updates:

```
🤖 Agent CLI - Interactive Mode
─────────────────────────────────
ℹ️  Model: gpt-5
ℹ️  Type 'exit' to quit, 'clear' to reset conversation

> What can you help me with?

⠙ Thinking...                    [Animated spinner]
🔧 get_current_time ✓ (125ms)    [Tool execution]
💭 Let me check...                [Thinking display]

I can help you with various tasks...

───────────────────────────────────────
📊 Stats: 2 tools, 542 tokens, 2.3s
```

### UI Elements

- **Spinners**: Animated indicators during processing
- **Tool Calls**: Shows tool name, arguments, and execution time
- **Thinking**: Displays reasoning for capable models
- **Statistics**: Token usage, tool count, and total duration
- **Terminal Title**: Updates with current status

## MCP (Model Context Protocol)

MCP servers extend the agent's capabilities with external tools.

### Popular MCP Servers

- `@modelcontextprotocol/server-filesystem` - File system operations
- `@modelcontextprotocol/server-github` - GitHub API access
- `@modelcontextprotocol/server-postgres` - PostgreSQL database
- `@modelcontextprotocol/server-sqlite` - SQLite database
- `@modelcontextprotocol/server-puppeteer` - Browser automation
- `@modelcontextprotocol/server-slack` - Slack integration

### Adding MCP Servers

```bash
# Format: --mcp-server "name -- command args"

# Filesystem with specific directory
agent-cli --mcp-server "fs -- npx @modelcontextprotocol/server-filesystem /Users/me/Documents"

# GitHub with authentication
export GITHUB_TOKEN=your_token
agent-cli --mcp-server "github -- npx @modelcontextprotocol/server-github"

# Database connection
agent-cli --mcp-server "db -- npx @modelcontextprotocol/server-postgres postgresql://localhost/mydb"
```

## Supported Models

### OpenAI
- GPT-5 series: `gpt-5`, `gpt-5-mini`, `gpt-5-nano`
- O-series: `o3`, `o3-mini`, `o3-pro`, `o4-mini`
- GPT-4: `gpt-4.1`, `gpt-4o`, `gpt-4-turbo`

### Anthropic
- Claude 4: `opus-4`, `sonnet-4`
- Claude 3.5: `claude`, `sonnet`, `haiku`

### Others
- Google: `gemini-2.5-pro`, `gemini-2.5-flash`, `gemini-2.5-flash-lite`
- Mistral: `mistral-large`, `codestral`
- Groq: `llama-70b`, `mixtral`
- Ollama: `llama3`, `codellama` (local)

## Examples

### Research Assistant
```bash
agent-cli --model gpt-5 \
          --mcp-server "web -- npx @modelcontextprotocol/server-puppeteer" \
          --interactive
```

### Code Analysis
```bash
agent-cli --model claude \
          --mcp-server "fs -- npx @modelcontextprotocol/server-filesystem ." \
          "Analyze the code structure and suggest improvements"
```

### Database Query
```bash
agent-cli --mcp-server "db -- npx @modelcontextprotocol/server-sqlite ./app.db" \
          "Show me the top 10 users by activity"
```

### Complex Reasoning
```bash
agent-cli --model o3 --thinking \
          "Plan a distributed system architecture for a social media platform"
```

## Environment Variables

Set API keys for providers:

```bash
export OPENAI_API_KEY='sk-...'
export ANTHROPIC_API_KEY='sk-ant-...'
export GEMINI_API_KEY='...'   # Legacy GOOGLE_API_KEY / GOOGLE_APPLICATION_CREDENTIALS still work
export MISTRAL_API_KEY='...'
export GROQ_API_KEY='gsk-...'
export X_AI_API_KEY='xai-...'
```

## Architecture

The agent-cli consists of several components:

1. **AgentCLI**: Main command-line interface and argument parsing
2. **Agent**: Core agent logic with conversation and tool management
3. **StatusBarUI**: Terminal UI with colors, spinners, and formatting
4. **MCPManager**: MCP server connection and tool discovery
5. **AgentEventHandler**: Event processing and UI updates

## Development

### Adding Custom Tools

Create custom tools by implementing the `AgentTool` protocol:

```swift
let customTool = AgentTool(
    name: "my_tool",
    description: "Description of what it does",
    parameters: AgentToolParameters(
        type: "object",
        properties: [
            "param1": AgentToolParameters.Property(
                type: .string,
                description: "First parameter"
            )
        ],
        required: ["param1"]
    ),
    execute: { args, context in
        // Tool implementation
        return AnyAgentToolValue(string: "Result")
    }
)
```

### Extending the UI

The `StatusBarUI` class can be extended with custom display methods:

```swift
extension StatusBarUI {
    func showCustomStatus(_ text: String) {
        print("\(TerminalColor.magenta)✨ \(text)\(TerminalColor.reset)")
    }
}
```

## License

MIT License - See [LICENSE](../../LICENSE) file for details.
