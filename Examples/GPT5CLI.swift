//
//  GPT5CLI.swift
//  Tachikoma
//

// Simple CLI for querying GPT-5
// Compile with: swift build --product gpt5cli
// Run with: .build/debug/gpt5cli "Your question here"

import Foundation
import Tachikoma

@main
struct GPT5CLI {
    static func main() async {
        // Get query from command line arguments
        let args = CommandLine.arguments
        guard args.count > 1 else {
            print("Usage: \(args[0]) <query>")
            print("Example: \(args[0]) \"What is the capital of France?\"")
            exit(1)
        }
        
        // Join all arguments after the program name as the query
        let query = args.dropFirst().joined(separator: " ")
        
        // Check for API key
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            print("Error: OPENAI_API_KEY environment variable not set")
            print("Set it with: export OPENAI_API_KEY='your-api-key'")
            exit(1)
        }
        
        do {
            print("🤖 Querying GPT-5...")
            print("📝 Query: \(query)")
            print("---")
            
            // Generate response using GPT-5
            let response = try await generateText(
                model: .openai(.gpt5),
                messages: [
                    .user(query)
                ],
                settings: GenerationSettings(
                    maxTokens: 2000,
                    temperature: 0.7
                )
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
}