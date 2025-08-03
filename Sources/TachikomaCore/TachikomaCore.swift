import Foundation
@_exported import Logging

// MARK: - TachikomaCore Module

/// TachikomaCore - Core functionality for the modern Tachikoma AI SDK
///
/// This module provides the fundamental types and generation functions for AI model interaction.
/// It builds on top of the existing Tachikoma implementation while providing a modern, Swift-native API.

// Re-export legacy components that are still needed
// These are kept for compatibility and gradual migration

// Import types we need from the legacy implementation
// Since these are in the same module now, we can access them directly

/// Check if the modern API is available
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public var modernAPIAvailable: Bool {
    true
}

// MARK: - Temporary type aliases for compatibility

// These will be replaced with proper implementations as we continue the refactor
public typealias Message = LegacyMessage
public typealias MessageContent = LegacyMessageContent
public typealias AssistantContent = LegacyAssistantContent
public typealias ImageContent = LegacyImageContent
public typealias ModelRequest = LegacyModelRequest
public typealias ModelResponse = LegacyModelResponse
public typealias ModelSettings = LegacyModelSettings
public typealias ModelInterface = LegacyModelInterface
public typealias ToolDefinition = LegacyToolDefinition
public typealias Tool = LegacyTool
public typealias ToolInput = LegacyToolInput
public typealias ToolOutput = LegacyToolOutput
public typealias ToolParameters = LegacyToolParameters
public typealias ToolError = LegacyToolError
public typealias StreamEvent = LegacyStreamEvent
public typealias TachikomaError = LegacyTachikomaError
public typealias AIConfiguration = LegacyAIConfiguration
public typealias AIModelProvider = LegacyAIModelProvider
public typealias AIModelFactory = LegacyAIModelFactory

// We'll implement these from scratch
// public typealias Model = NewModel
// public typealias Conversation = NewConversation

// Import the legacy implementations we need to reference
// These files are now in the Legacy subdirectory within this module