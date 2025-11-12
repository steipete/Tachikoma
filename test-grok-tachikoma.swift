#!/usr/bin/env swift

import Foundation
import Tachikoma

// Set up API key
setenv("X_AI_API_KEY", ProcessInfo.processInfo.environment["X_AI_API_KEY"] ?? "", 1)

// Create a simple async function to test
@main
struct TestGrok {
    static func main() async {
        do {
            print("Testing Grok-3 with Tachikoma...")

            // Test simple generation
            let response = try await generate(
                "Say hello",
                using: .grok(.grok3),
            )
            print("Response: \(response)")

            // Test streaming
            print("\nTesting streaming...")
            let stream = try await stream(
                "Count to 3",
                using: .grok(.grok3),
            )

            for try await delta in stream {
                if case let .textDelta(text) = delta.type {
                    print(text ?? "", terminator: "")
                }
            }
            print("\nDone!")

        } catch {
            print("Error: \(error)")
        }
    }
}
