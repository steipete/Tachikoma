#!/usr/bin/env swift

import Foundation

// Test Grok API with streaming and tools

let apiKey = ProcessInfo.processInfo.environment["X_AI_API_KEY"] ?? ProcessInfo.processInfo
    .environment["XAI_API_KEY"] ?? ""

guard !apiKey.isEmpty else {
    print("Error: X_AI_API_KEY or XAI_API_KEY not set")
    exit(1)
}

let url = URL(string: "https://api.x.ai/v1/chat/completions")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")

// Try with a simpler tool first
let body = """
{
    "model": "grok-3",
    "messages": [
        {"role": "user", "content": "What is 2 + 2?"}
    ],
    "tools": [
        {
            "type": "function",
            "function": {
                "name": "calculator",
                "description": "Perform mathematical calculations",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "expression": {
                            "type": "string",
                            "description": "The mathematical expression to evaluate"
                        }
                    },
                    "required": ["expression"]
                }
            }
        }
    ],
    "stream": true
}
"""

request.httpBody = body.data(using: .utf8)

print("🔵 Testing Grok-3 with streaming and tools...")
print("Request URL: \(url)")

let semaphore = DispatchSemaphore(value: 0)

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    if let error {
        print("❌ Error: \(error)")
    } else if let httpResponse = response as? HTTPURLResponse {
        print("Response status: \(httpResponse.statusCode)")
        if let data, let responseText = String(data: data, encoding: .utf8) {
            print("Response (first 2000 chars):")
            print(String(responseText.prefix(2000)))
        }
    }
    semaphore.signal()
}

task.resume()
semaphore.wait()
