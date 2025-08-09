import Foundation
import Testing
@testable import Tachikoma

@Test("Debug Grok streaming issue")
func testGrokStreamingDebug() async throws {
    // Skip if no API key
    guard ProcessInfo.processInfo.environment["X_AI_API_KEY"] != nil ||
          ProcessInfo.processInfo.environment["XAI_API_KEY"] != nil else {
        print("Skipping: No Grok API key")
        return
    }
    
    print("Testing Grok-3 streaming...")
    
    // Enable debug output
    setenv("DEBUG_GROK", "1", 1)
    
    // Test with minimal setup
    let stream = try await stream(
        "Say hello",
        using: .grok(.grok3)
    )
    
    var receivedContent = false
    var content = ""
    
    for try await delta in stream {
        print("Received delta: \(delta.type)")
        if case .textDelta(let text) = delta.type {
            if let text = text {
                content += text
                receivedContent = true
            }
        }
        if case .done = delta.type {
            print("Stream completed")
            break
        }
    }
    
    print("Final content: \(content)")
    #expect(receivedContent, "Should receive some content")
}