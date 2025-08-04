#!/usr/bin/env swift
import Foundation

// Simulate the TachikomaCore behavior
print("🕷️  Testing Tachikoma with Real API Keys")
print("=" * 40)

// Check environment
let env = ProcessInfo.processInfo.environment
let providers = [
    ("OpenAI", "OPENAI_API_KEY"),
    ("Anthropic", "ANTHROPIC_API_KEY"),
    ("Grok (xAI)", "X_AI_API_KEY"),
]

print("API Keys Status:")
for (name, envVar) in providers {
    if let key = env[envVar] {
        let masked = String(key.prefix(10)) + "..."
        print("  ✅ \(name): \(masked)")
    } else {
        print("  ❌ \(name): Not found (\(envVar))")
    }
}

// Simple HTTP test for OpenAI
if let apiKey = env["OPENAI_API_KEY"] {
    print("\n🤖 Testing OpenAI API call...")

    let url = URL(string: "https://api.openai.com/v1/chat/completions")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let requestBody: [String: Any] = [
        "model": "gpt-4o-mini",
        "messages": [
            ["role": "user", "content": "What is 2+2? Answer with just the number."],
        ],
        "max_tokens": 10,
    ]

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let semaphore = DispatchSemaphore(value: 0)
        var result = ""

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error {
                result = "❌ Error: \(error.localizedDescription)"
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                result = "❌ No HTTP response"
                return
            }

            guard let data else {
                result = "❌ No data received"
                return
            }

            if httpResponse.statusCode == 200 {
                do {
                    if
                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let choices = json["choices"] as? [[String: Any]],
                        let firstChoice = choices.first,
                        let message = firstChoice["message"] as? [String: Any],
                        let content = message["content"] as? String
                    {
                        result = "✅ OpenAI API working! Response: \(content.trimmingCharacters(in: .whitespacesAndNewlines))"
                    } else {
                        result = "✅ OpenAI API responded but couldn't parse content"
                    }
                } catch {
                    result = "✅ OpenAI API responded but JSON parse failed: \(error)"
                }
            } else {
                let responseText = String(data: data, encoding: .utf8) ?? "No response text"
                result = "❌ HTTP \(httpResponse.statusCode): \(responseText)"
            }
        }.resume()

        semaphore.wait()
        print("  \(result)")

    } catch {
        print("  ❌ Failed to create request: \(error)")
    }
}

// Simple HTTP test for Anthropic
if let apiKey = env["ANTHROPIC_API_KEY"] {
    print("\n🧠 Testing Anthropic API call...")

    let url = URL(string: "https://api.anthropic.com/v1/messages")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

    let requestBody: [String: Any] = [
        "model": "claude-3-haiku-20240307",
        "max_tokens": 10,
        "messages": [
            ["role": "user", "content": "What is 2+2? Answer with just the number."],
        ],
    ]

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let semaphore = DispatchSemaphore(value: 0)
        var result = ""

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error {
                result = "❌ Error: \(error.localizedDescription)"
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                result = "❌ No HTTP response"
                return
            }

            guard let data else {
                result = "❌ No data received"
                return
            }

            if httpResponse.statusCode == 200 {
                do {
                    if
                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let content = json["content"] as? [[String: Any]],
                        let firstContent = content.first,
                        let text = firstContent["text"] as? String
                    {
                        result = "✅ Anthropic API working! Response: \(text.trimmingCharacters(in: .whitespacesAndNewlines))"
                    } else {
                        result = "✅ Anthropic API responded but couldn't parse content"
                    }
                } catch {
                    result = "✅ Anthropic API responded but JSON parse failed: \(error)"
                }
            } else {
                let responseText = String(data: data, encoding: .utf8) ?? "No response text"
                result = "❌ HTTP \(httpResponse.statusCode): \(responseText)"
            }
        }.resume()

        semaphore.wait()
        print("  \(result)")

    } catch {
        print("  ❌ Failed to create request: \(error)")
    }
}

print("\n✅ Real API integration test completed!")
print("🕷️  Tachikoma - Ready for action with live APIs!")

extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
