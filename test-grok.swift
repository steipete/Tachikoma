#!/usr/bin/env swift

import Foundation

// Simple test to debug Grok API

let apiKey = "placeholder"

guard !apiKey.isEmpty else {
    print("Error: X_AI_API_KEY or XAI_API_KEY not set")
    exit(1)
}

let url = URL(string: "https://api.x.ai/v1/chat/completions")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")

let body = """
{
    "model": "grok-3",
    "messages": [
        {"role": "user", "content": "Say hello"}
    ],
    "stream": true
}
"""

request.httpBody = body.data(using: .utf8)

print("🔵 Testing Grok-3 with streaming...")
print("Request URL: \(url)")
print("Request body: \(body)")

let semaphore = DispatchSemaphore(value: 0)

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    if let error {
        print("❌ Error: \(error)")
    } else if let httpResponse = response as? HTTPURLResponse {
        print("Response status: \(httpResponse.statusCode)")
        if let data, let responseText = String(data: data, encoding: .utf8) {
            print("Response body: \(responseText)")
        }
    }
    semaphore.signal()
}

task.resume()
semaphore.wait()

print("\n🔵 Now testing with stream: false...")

let body2 = """
{
    "model": "grok-3",
    "messages": [
        {"role": "user", "content": "Say hello"}
    ],
    "stream": false
}
"""

request.httpBody = body2.data(using: .utf8)

let task2 = URLSession.shared.dataTask(with: request) { data, response, error in
    if let error {
        print("❌ Error: \(error)")
    } else if let httpResponse = response as? HTTPURLResponse {
        print("Response status: \(httpResponse.statusCode)")
        if let data, let responseText = String(data: data, encoding: .utf8) {
            print("Response body: \(responseText)")
        }
    }
    semaphore.signal()
}

task2.resume()
semaphore.wait()
