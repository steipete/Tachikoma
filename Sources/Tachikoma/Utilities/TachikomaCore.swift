import Foundation
@_exported import Logging

// MARK: - TachikomaCore Module

/// TachikomaCore provides the fundamental types and generation functions for AI model interaction.
/// It builds on top of the existing Tachikoma implementation while providing a modern, Swift-native API.
public enum TachikomaCore {}

// Re-export legacy components that are still needed
// These are kept for compatibility and gradual migration

// Import types we need from the legacy implementation
// Since these are in the same module now, we can access them directly

/// Check if the modern API is available
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public var modernAPIAvailable: Bool {
    true
}

// MARK: - Modern API Re-exports

// Re-export the modern types from ModernTypes.swift
// These provide the public API for the new TachikomaCore module

// We'll implement these from scratch
// public typealias Model = NewModel
// public typealias Conversation = NewConversation

// Import the legacy implementations we need to reference
// These files are now in the Legacy subdirectory within this module
