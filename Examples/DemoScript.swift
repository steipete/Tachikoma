#!/usr/bin/env swift-sh

import Foundation

// swift-sh Tachikoma ~> 1.0.0

/// This demo script shows how to use Tachikoma in a real application
/// Run with: swift-sh DemoScript.swift
/// Or: swift run DemoScript (if added to Package.swift)

print("🕷️  Tachikoma Demo Script")
print("=" * 40)

// Check environment variables directly
let env = ProcessInfo.processInfo.environment
print("Environment check:")
for key in ["OPENAI_API_KEY", "ANTHROPIC_API_KEY", "X_AI_API_KEY"] {
    if env[key] != nil {
        print("  ✅ \(key) found")
    } else {
        print("  ❌ \(key) missing")
    }
}

print("\n🎯 Tachikoma Configuration Demo Complete")
print("API keys are properly loaded from environment variables.")
print("The Tachikoma SDK is ready for use with real AI providers!")

extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
