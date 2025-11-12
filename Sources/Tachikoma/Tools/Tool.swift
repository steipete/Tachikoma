@_exported import Foundation

// Re-export all tool functionality from organized files
// The @_exported attribute makes these imports available to consumers of this module
// without requiring them to import each file individually

// Note: Swift automatically includes all .swift files in the module,
// so the types from ToolTypes.swift, ToolBuilder.swift, and ToolCompatibility.swift
// are automatically available when importing the Tachikoma module.

// This file serves as documentation of the tool system organization:
// - ToolTypes.swift: Core tool definitions and types
// - ToolBuilder.swift: Result builder and convenience functions
// - ToolCompatibility.swift: Legacy compatibility and common tools
