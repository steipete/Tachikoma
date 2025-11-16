import Foundation
import Tachikoma

// Using shared OpenAIAPIMode enum from Tachikoma

@main
struct GPT5CLI {
    static func main() async {
        // Parse command line arguments
        let args = CommandLine.arguments
        var apiMode = OpenAIAPIMode.responses // Default to Responses API for GPT-5
        var modelName = "gpt-5" // Default model
        var queryArgs: [String] = []

        var i = 1
        while i < args.count {
            if args[i] == "--api", i + 1 < args.count {
                if let mode = OpenAIAPIMode(rawValue: args[i + 1]) {
                    apiMode = mode
                    i += 2
                } else {
                    print("Error: Invalid API mode. Use 'chat' or 'responses'")
                    exit(1)
                }
            } else if args[i] == "--model", i + 1 < args.count {
                modelName = args[i + 1]
                i += 2
            } else if args[i].starts(with: "--") {
                print("Unknown option: \(args[i])")
                print("Usage: \(args[0]) [--api chat|responses] [--model gpt-5|gpt-5-mini|gpt-5-nano] <query>")
                exit(1)
            } else {
                queryArgs.append(args[i])
                i += 1
            }
        }

        guard !queryArgs.isEmpty else {
            print("Usage: \(args[0]) [--api chat|responses] [--model gpt-5|gpt-5-mini|gpt-5-nano] <query>")
            print("Example: \(args[0]) --api chat \"What is the capital of France?\"")
            print("Example: \(args[0]) --api responses --model gpt-5-mini \"Explain quantum computing\"")
            exit(1)
        }

        let query = queryArgs.joined(separator: " ")

        // Check for API key
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            print("Error: OPENAI_API_KEY environment variable not set")
            print("Set it with: export OPENAI_API_KEY='your-api-key'")
            exit(1)
        }

        // Display configuration
        let maskedKey = self.maskAPIKey(apiKey)
        print("🔐 API Key: \(maskedKey)")
        print("🤖 Model: \(modelName)")
        print("🌐 API: \(apiMode.displayName)")
        print("---")

        do {
            print("🚀 Sending query...")
            print("📝 Query: \(query)")
            print("---")

            // Determine the model
            let openAIModel: LanguageModel.OpenAI
            switch modelName.lowercased() {
            case "gpt-5", "gpt5":
                openAIModel = .gpt5
            case "gpt-5-mini", "gpt5-mini":
                openAIModel = .gpt5Mini
            case "gpt-5-nano", "gpt5-nano":
                openAIModel = .gpt5Nano
            default:
                print("Warning: Unknown model '\(modelName)', using gpt-5")
                openAIModel = .gpt5
            }

            // Generate response based on API mode
            let config = TachikomaConfiguration.current
            let messages: [ModelMessage] = [.user(query)]
            let request = ProviderRequest(
                messages: messages,
                tools: nil,
                settings: GenerationSettings(maxTokens: 2000),
            )

            let providerResponse: ProviderResponse

            if apiMode == .chat {
                // Force Chat Completions API by creating OpenAIProvider directly
                let provider = try OpenAIProvider(model: openAIModel, configuration: config)
                providerResponse = try await provider.generateText(request: request)
                print("✅ Using Chat Completions API")
            } else {
                // Force Responses API by creating OpenAIResponsesProvider directly
                let provider = try OpenAIResponsesProvider(model: openAIModel, configuration: config)
                providerResponse = try await provider.generateText(request: request)
                print("✅ Using Responses API")
            }

            // Create a simple response object for display
            let response = GenerateTextResult(
                text: providerResponse.text,
                usage: providerResponse.usage,
                finishReason: providerResponse.finishReason,
                steps: [],
                messages: messages,
            )

            // Print the response
            print("\n💬 Response:")
            print(response.text)

            // Print usage information if available
            if let usage = response.usage {
                print("\n📊 Usage:")
                print("  Input tokens: \(usage.inputTokens)")
                print("  Output tokens: \(usage.outputTokens)")
                print("  Total tokens: \(usage.totalTokens)")
            }
        } catch {
            print("\n❌ Error: \(error)")
            exit(1)
        }
    }

    static func maskAPIKey(_ key: String) -> String {
        guard key.count > 10 else { return "***" }
        let prefix = key.prefix(5)
        let suffix = key.suffix(5)
        return "\(prefix)...\(suffix)"
    }
}
