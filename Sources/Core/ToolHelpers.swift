<<<<<<< HEAD
import Foundation

// MARK: - Tool Helper Functions

/// Create a simple tool with basic parameters
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createSimpleTool<Context>(
    name: String,
    description: String,
    parameters: ToolParameters? = nil,
    execute: @escaping (ToolInput, Context) async throws -> ToolOutput
) -> Tool<Context> {
    return Tool<Context>(
        name: name,
        description: description,
        parameters: parameters ?? ToolParameters(),
        execute: execute
    )
}

/// Create a tool with detailed parameters
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createTool<Context>(
    name: String,
    description: String,
    parameters: ToolParameters,
    strict: Bool = true,
    execute: @escaping (ToolInput, Context) async throws -> ToolOutput
) -> Tool<Context> {
    return Tool<Context>(
        name: name,
        description: description,
        parameters: parameters,
        strict: strict,
        execute: execute
    )
}

/// Create a tool from a tool definition
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createToolFromDefinition<Context>(
    definition: ToolDefinition,
    execute: @escaping (ToolInput, Context) async throws -> ToolOutput
) -> Tool<Context> {
    return Tool<Context>(
        name: definition.function.name,
        description: definition.function.description,
        parameters: definition.function.parameters,
        strict: definition.function.strict ?? true,
        execute: execute
    )
}

// MARK: - Tool Output Helpers

extension ToolOutput {
    /// Create a success result with a message
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    public static func success(_ message: String) -> ToolOutput {
        return .string(message)
    }
    
    /// Create an error result with a message
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    public static func error(_ message: String, code: String? = nil) -> ToolOutput {
        return .error(message: message, code: code)
    }
    
    /// Create a result with structured data
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    public static func data(_ data: [String: ToolOutput]) -> ToolOutput {
        return .object(data)
    }
}
||||||| parent of 69989a9 (fix: Update test suite to match current API)
=======
import Foundation

/// Helper functions for creating tools with Tachikoma
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createTool<Context>(
    name: String,
    description: String,
    parameters: ToolParameters? = nil,
    execute: @escaping (ToolInput, Context) async throws -> ToolOutput
) -> Tool<Context> {
    return Tool<Context>(
        name: name,
        description: description,
        parameters: parameters ?? ToolParameters.object(properties: [:], required: []),
        execute: execute
    )
}

/// Create a simple tool with basic parameter handling
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createSimpleTool<Context>(
    name: String,
    description: String,
    parameters: [String: ParameterSchema] = [:],
    required: [String] = [],
    execute: @escaping (ToolInput, Context) async throws -> ToolOutput
) -> Tool<Context> {
    return createTool(
        name: name,
        description: description,
        parameters: ToolParameters.object(properties: parameters, required: required),
        execute: execute
    )
}

/// Create a string parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func stringParam(
    description: String,
    enumValues _: [String]? = nil,
    pattern: String? = nil
) -> ParameterSchema {
    ParameterSchema.string(description: description, pattern: pattern)
}

/// Create a number parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func numberParam(
    description: String,
    minimum: Double? = nil,
    maximum: Double? = nil
) -> ParameterSchema {
    ParameterSchema.number(description: description, minimum: minimum, maximum: maximum)
}

/// Create an integer parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func integerParam(
    description: String,
    minimum: Int? = nil,
    maximum: Int? = nil
) -> ParameterSchema {
    ParameterSchema.integer(description: description, minimum: minimum?.double, maximum: maximum?.double)
}

/// Create a boolean parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func boolParam(description: String) -> ParameterSchema {
    ParameterSchema.boolean(description: description)
}

/// Create an array parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func arrayParam(
    description: String,
    items: ParameterSchema
) -> ParameterSchema {
    ParameterSchema.array(of: items, description: description)
}

/// Create an object parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func objectParam(
    description: String,
    properties: [String: ParameterSchema],
    required _: [String] = []
) -> ParameterSchema {
    ParameterSchema.object(properties: properties, description: description)
}

// MARK: - Type Extensions

extension Int {
    var double: Double {
        Double(self)
    }
}
>>>>>>> 69989a9 (fix: Update test suite to match current API)
