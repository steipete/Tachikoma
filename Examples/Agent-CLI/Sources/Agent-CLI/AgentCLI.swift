import Algorithms
import Commander
import Foundation
import Tachikoma
import TachikomaAgent
import TachikomaMCP

/// Main CLI command for the AI agent
@main
struct AgentCLI: AsyncParsableCommand {
    static let commandDescription = CommandDescription(
        commandName: "agent-cli",
        abstract: "AI Agent with conversation and tool support",
        discussion: """
        An interactive AI agent that supports multi-turn conversations, MCP tool calling,
        and displays thinking/reasoning with a fancy status bar.

        Examples:
          agent-cli "What files are in the current directory?"
          agent-cli --model claude --thinking "Solve this step by step: ..."
          agent-cli --interactive
          agent-cli --mcp-server my-tools -- npx my-mcp-server
        """,
        version: "1.0.0",
    )

    @Argument(help: "Query or task for the agent")
    var query: String?

    @Option(name: .shortAndLong, help: "AI model to use (e.g., gpt-5, claude, o3)")
    var model: String = "gpt-5"

    @Flag(name: .shortAndLong, help: "Interactive conversation mode")
    var interactive: Bool = false

    @Flag(help: "Show thinking/reasoning process")
    var thinking: Bool = false

    @Flag(name: .shortAndLong, help: "Verbose output with debug information")
    var verbose: Bool = false

    @Flag(name: .shortAndLong, help: "Quiet mode - minimal output")
    var quiet: Bool = false

    @Option(help: "Output format: normal, json, markdown")
    var format: OutputFormat = .normal

    @Option(help: "Maximum conversation turns (default: 10)")
    var maxTurns: Int = 10

    @Option(help: "Add MCP server (format: name -- command args)")
    var mcpServer: [String] = []

    @Option(help: "Load conversation from JSON file")
    var load: String?

    @Option(help: "Save conversation to JSON file")
    var save: String?

    @Flag(help: "List available MCP servers")
    var listServers: Bool = false

    @Flag(help: "Show current configuration")
    var showConfig: Bool = false

    func run() async throws {
        // Initialize configuration
        let config = TachikomaConfiguration.current
        if self.verbose {
            config.verbose = true
        }

        // Handle special commands
        if self.showConfig {
            await self.showConfiguration()
            return
        }

        if self.listServers {
            await self.listMCPServers()
            return
        }

        // Parse and validate model
        let languageModel = try ModelSelector.parseModel(self.model)

        // Validate API key
        try self.validateAPIKey(for: languageModel)

        // Initialize UI system
        let ui = StatusBarUI(outputFormat: format, verbose: verbose, quiet: quiet)

        // Initialize MCP if servers are configured
        let mcpManager = try await initializeMCP(ui: ui)

        // Load or create messages
        var messages = try await loadOrCreateMessages()

        // Create agent
        let agent = try await createAgent(
            model: languageModel,
            mcpManager: mcpManager,
            ui: ui,
        )

        // Run in interactive or single-query mode
        if self.interactive || self.query == nil {
            try await self.runInteractiveMode(
                agent: agent,
                messages: &messages,
                ui: ui,
            )
        } else {
            try await self.runSingleQuery(
                agent: agent,
                messages: &messages,
                query: self.query!,
                ui: ui,
            )
        }

        // Save conversation if requested
        if let savePath = save {
            try await self.saveMessages(messages, to: savePath)
            ui.showInfo("Conversation saved to \(savePath)")
        }
    }

    // MARK: - Configuration Display

    private func showConfiguration() async {
        print("🔧 Agent CLI Configuration")
        print("─────────────────────────")

        let config = TachikomaConfiguration.current

        // Show API keys status
        print("\n🔑 API Keys:")
        for provider in Provider.allStandard {
            if let key = config.getAPIKey(for: provider) {
                let masked = self.maskAPIKey(key)
                print("  • \(provider.displayName): \(masked)")
            } else {
                print("  • \(provider.displayName): Not configured")
            }
        }

        // Show model info
        print("\n🤖 Default Model: \(self.model)")
        if let parsed = try? ModelSelector.parseModel(model) {
            print("  • Provider: \(parsed.providerName)")
            print("  • Capabilities:")
            print("    - Vision: \(parsed.supportsVision ? "✓" : "✗")")
            print("    - Tools: \(parsed.supportsTools ? "✓" : "✗")")
            print("    - Streaming: \(parsed.supportsStreaming ? "✓" : "✗")")
        }

        print("\n📦 MCP Servers: \(self.mcpServer.isEmpty ? "None configured" : "\(self.mcpServer.count) configured")")
    }

    private func listMCPServers() async {
        print("📦 Available MCP Servers")
        print("────────────────────────")
        print("""

        To add an MCP server, use:
          agent-cli --mcp-server "name -- command args"

        Examples:
          --mcp-server "filesystem -- npx @modelcontextprotocol/server-filesystem /tmp"
          --mcp-server "github -- npx @modelcontextprotocol/server-github"
          --mcp-server "postgres -- npx @modelcontextprotocol/server-postgres postgresql://localhost/db"

        Popular MCP servers:
          • filesystem - File system operations
          • github - GitHub API access
          • postgres - PostgreSQL database
          • sqlite - SQLite database
          • puppeteer - Browser automation
          • slack - Slack integration

        Find more at: https://github.com/modelcontextprotocol/servers
        """)
    }

    // MARK: - Agent Creation

    private func createAgent(
        model: LanguageModel,
        mcpManager: MCPManager?,
        ui: StatusBarUI,
    ) async throws
        -> Agent
    {
        // Get available tools
        var tools: [AgentTool] = []

        // Add MCP tools if available
        if let mcpTools = await mcpManager?.getTools() {
            tools.append(contentsOf: mcpTools)
            ui.showInfo("Loaded \(mcpTools.count) MCP tools")
        }

        // Add built-in tools
        tools.append(contentsOf: self.createBuiltInTools())

        // Create agent configuration
        let agentConfig = AgentConfiguration(
            model: model,
            systemPrompt: generateSystemPrompt(),
            tools: tools,
            maxIterations: maxTurns,
            temperature: 0.7,
            showThinking: thinking,
        )

        // Create agent with event delegate
        let eventDelegate = AgentEventHandler(ui: ui, showThinking: thinking)

        return Agent(
            configuration: agentConfig,
            eventDelegate: eventDelegate,
        )
    }

    private func generateSystemPrompt() -> String {
        """
        You are a helpful AI assistant with access to various tools.

        Guidelines:
        - Be concise and direct in your responses
        - Use tools when they would be helpful
        - Think step-by-step for complex problems
        - Admit when you don't know something
        - Provide clear explanations when asked

        Available capabilities:
        - Multi-turn conversations with context
        - Tool calling via MCP servers
        - File system operations
        - Code analysis and generation
        - Data processing and analysis
        """
    }

    private func createBuiltInTools() -> [AgentTool] {
        var tools: [AgentTool] = []

        // Add current time tool
        tools.append(AgentTool(
            name: "get_current_time",
            description: "Get the current date and time",
            parameters: AgentToolParameters(
                properties: [:],
                required: [],
            ),
        ) { _ in
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .long
            let now = formatter.string(from: Date())
            return AnyAgentToolValue(string: now)
        })

        // Add basic calculator tool
        tools.append(AgentTool(
            name: "calculate",
            description: "Perform mathematical calculations",
            parameters: AgentToolParameters(
                properties: [
                    "expression": AgentToolParameterProperty(
                        name: "expression",
                        type: .string,
                        description: "Mathematical expression to evaluate",
                    ),
                ],
                required: ["expression"],
            ),
        ) { args in
            guard let expression = args["expression"]?.stringValue else {
                return AnyAgentToolValue(string: "Error: No expression provided")
            }
            // Simple expression evaluation (in real app, use proper parser)
            let result = "Result: \(expression) = [calculation would go here]"
            return AnyAgentToolValue(string: result)
        })

        return tools
    }

    // MARK: - Message Management

    private func loadOrCreateMessages() async throws -> [ModelMessage] {
        if let loadPath = load {
            try await self.loadMessages(from: loadPath)
        } else {
            []
        }
    }

    private func loadMessages(from path: String) async throws -> [ModelMessage] {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let messages = try JSONDecoder().decode([ModelMessage].self, from: data)
        return messages
    }

    private func saveMessages(_ messages: [ModelMessage], to path: String) async throws {
        let url = URL(fileURLWithPath: path)
        let data = try JSONEncoder().encode(messages)
        try data.write(to: url)
    }

    // MARK: - Execution Modes

    private func runSingleQuery(
        agent: Agent,
        messages: inout [ModelMessage],
        query: String,
        ui: StatusBarUI,
    ) async throws {
        ui.showHeader("🤖 Agent CLI - Single Query Mode")
        ui.showInfo("Model: \(self.model)")

        // Add user message
        messages.append(.user(query))

        // Execute agent
        ui.startTask("Processing query...")

        let result = try await agent.execute(
            messages: messages,
            maxTurns: 1,
        )

        // Add assistant response
        messages.append(.assistant(result.content))

        ui.completeTask()

        // Show final response
        if self.format == .markdown {
            ui.showMarkdown(result.content)
        } else {
            ui.showResponse(result.content)
        }

        // Show usage stats
        if let usage = result.usage {
            ui.showStats(
                toolCalls: result.toolCalls.count,
                tokens: usage.totalTokens,
                duration: result.duration,
            )
        }
    }

    private func runInteractiveMode(
        agent: Agent,
        messages: inout [ModelMessage],
        ui: StatusBarUI,
    ) async throws {
        ui.showHeader("🤖 Agent CLI - Interactive Mode")
        ui.showInfo("Model: \(self.model)")
        ui.showInfo("Type 'exit' to quit, 'clear' to reset conversation")

        while true {
            // Get user input
            print("\n> ", terminator: "")
            fflush(stdout)

            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                break
            }

            // Handle special commands
            if input.lowercased() == "exit" || input.lowercased() == "quit" {
                ui.showInfo("Goodbye!")
                break
            }

            if input.lowercased() == "clear" {
                messages = []
                ui.showInfo("Conversation cleared")
                continue
            }

            if input.lowercased() == "history" {
                self.showConversationHistory(messages, ui: ui)
                continue
            }

            if input.isEmpty {
                continue
            }

            // Add user message
            messages.append(.user(input))

            // Execute agent
            ui.startTask("Thinking...")

            let result = try await agent.execute(
                messages: messages,
                maxTurns: self.maxTurns,
            )

            // Add assistant response
            messages.append(.assistant(result.content))

            ui.completeTask()

            // Show response
            print() // New line for clarity
            if self.format == .markdown {
                ui.showMarkdown(result.content)
            } else {
                ui.showResponse(result.content)
            }

            // Show tool usage if any
            if !result.toolCalls.isEmpty {
                ui.showToolUsage(result.toolCalls)
            }
        }
    }

    private func showConversationHistory(_ messages: [ModelMessage], ui: StatusBarUI) {
        ui.showHeader("📜 Conversation History")

        for (index, message) in messages.indexed() {
            let roleStr: String
            let content: String

            switch message.role {
            case .user:
                roleStr = "👤 User"
            case .assistant:
                roleStr = "🤖 Assistant"
            case .system:
                roleStr = "⚙️ System"
            case .tool:
                roleStr = "🔧 Tool"
            }

            // Extract text content from the message
            if
                let firstContent = message.content.first,
                case let .text(text) = firstContent
            {
                content = text
            } else {
                content = "[No text content]"
            }

            print("\n[\(index + 1)] \(roleStr):")
            print(content.prefix(200))
            if content.count > 200 {
                print("... (truncated)")
            }
        }
    }

    // MARK: - MCP Integration

    private func initializeMCP(ui: StatusBarUI) async throws -> MCPManager? {
        guard !self.mcpServer.isEmpty else { return nil }

        ui.showInfo("Initializing MCP servers...")

        let manager = MCPManager()

        for serverSpec in self.mcpServer {
            // Parse server specification
            let parts = serverSpec.split(separator: " -- ", maxSplits: 1)
            guard parts.count == 2 else {
                ui.showWarning("Invalid MCP server format: \(serverSpec)")
                continue
            }

            let name = String(parts[0])
            let command = String(parts[1])

            do {
                try await manager.addServer(name: name, command: command)
                ui.showSuccess("Connected to MCP server: \(name)")
            } catch {
                ui.showError("Failed to connect to \(name): \(error)")
            }
        }

        return manager
    }

    // MARK: - Validation

    private func validateAPIKey(for model: LanguageModel) throws {
        let config = TachikomaConfiguration.current

        let provider: Provider = switch model {
        case .openai: .openai
        case .anthropic: .anthropic
        case .google: .google
        case .mistral: .mistral
        case .groq: .groq
        case .grok: .grok
        case .ollama: .ollama
        default: .custom("unknown")
        }

        if provider.requiresAPIKey, !config.hasAPIKey(for: provider) {
            throw CLIError.missingAPIKey(provider: provider)
        }
    }

    private func maskAPIKey(_ key: String) -> String {
        guard key.count > 10 else { return "***" }
        let prefix = key.prefix(5)
        let suffix = key.suffix(5)
        return "\(prefix)...\(suffix)"
    }
}

// MARK: - Supporting Types

enum OutputFormat: String, ExpressibleFromArgument {
    case normal
    case json
    case markdown
}

enum CLIError: LocalizedError {
    case missingAPIKey(provider: Provider)
    case invalidModel(String)
    case mcpConnectionFailed(String)

    var errorDescription: String? {
        switch self {
        case let .missingAPIKey(provider):
            "Missing API key for \(provider.displayName). Set \(provider.environmentVariable) environment variable."
        case let .invalidModel(model):
            "Invalid model: \(model)"
        case let .mcpConnectionFailed(reason):
            "MCP connection failed: \(reason)"
        }
    }
}

// Extension to add provider helpers
extension Provider {
    static var allStandard: [Provider] {
        [.openai, .anthropic, .google, .mistral, .groq, .grok, .ollama]
    }

    var displayName: String {
        switch self {
        case .openai: "OpenAI"
        case .anthropic: "Anthropic"
        case .google: "Google"
        case .mistral: "Mistral"
        case .groq: "Groq"
        case .grok: "Grok"
        case .ollama: "Ollama"
        case .lmstudio: "LM Studio"
        case let .custom(name): name
        }
    }
}
