#!/usr/bin/env swift

import Foundation

// Copy the relevant parts of TachikomaConfiguration for debugging
class DebugConfiguration {
    private var _apiKeys: [String: String] = [:]

    init() {
        self.loadFromEnvironment()
    }

    func loadFromEnvironment() {
        let environment = ProcessInfo.processInfo.environment

        print("Environment variables found:")
        let relevantKeys = ["OPENAI_API_KEY", "ANTHROPIC_API_KEY", "X_AI_API_KEY", "XAI_API_KEY"]
        for key in relevantKeys {
            if let value = environment[key] {
                print("  \(key) = \(value.prefix(10))...")
            } else {
                print("  \(key) = (not found)")
            }
        }

        // Load API keys from environment
        let keyMappings: [String: String] = [
            "openai": "OPENAI_API_KEY",
            "anthropic": "ANTHROPIC_API_KEY",
            "grok": "X_AI_API_KEY",
            "groq": "GROQ_API_KEY",
            "mistral": "MISTRAL_API_KEY",
            "google": "GOOGLE_API_KEY",
            "ollama": "OLLAMA_API_KEY",
        ]

        print("\nLoading API keys:")
        for (provider, envVar) in keyMappings {
            if let key = environment[envVar] {
                self._apiKeys[provider] = key
                print("  \(provider): loaded from \(envVar) (\(key.prefix(10))...)")
            } else {
                print("  \(provider): NOT FOUND (\(envVar))")
            }
        }

        // Also check for alternative Grok API key name
        if self._apiKeys["grok"] == nil, let xaiKey = environment["XAI_API_KEY"] {
            self._apiKeys["grok"] = xaiKey
            print("  grok: loaded from XAI_API_KEY (\(xaiKey.prefix(10))...)")
        }
    }

    func getAPIKey(for provider: String) -> String? {
        self._apiKeys[provider.lowercased()]
    }

    func summary() {
        print("\nFinal configuration:")
        for (provider, key) in self._apiKeys.sorted(by: { $0.key < $1.key }) {
            print("  \(provider): \(key.prefix(10))...")
        }
    }
}

let config = DebugConfiguration()
config.summary()

// Test what TachikomaConfiguration would see
print("\nTesting provider lookups:")
for provider in ["openai", "anthropic", "grok"] {
    if let key = config.getAPIKey(for: provider) {
        print("  \(provider): ✅ Found key (\(key.prefix(10))...)")
    } else {
        print("  \(provider): ❌ No key found")
    }
}
