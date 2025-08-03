import Foundation

/// Helper functions for creating tools with Tachikoma
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createTool<Context>(
    name: String,
    description: String,
    parameters: LegacyToolParameters? = nil,
    execute: @escaping (LegacyToolInput, Context) async throws -> LegacyToolOutput
) -> LegacyTool<Context> {
    return LegacyTool<Context>(
        name: name,
        description: description,
        parameters: parameters ?? LegacyToolParameters.object(properties: [:], required: []),
        execute: execute
    )
}

/// Create a simple tool with basic parameter handling
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createSimpleTool<Context>(
    name: String,
    description: String,
    parameters: [String: LegacyParameterSchema] = [:],
    required: [String] = [],
    execute: @escaping (LegacyToolInput, Context) async throws -> LegacyToolOutput
) -> LegacyTool<Context> {
    return createTool(
        name: name,
        description: description,
        parameters: LegacyToolParameters.object(properties: parameters, required: required),
        execute: execute
    )
}

/// Create a string parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func stringParam(
    description: String,
    enumValues _: [String]? = nil,
    pattern: String? = nil
) -> LegacyParameterSchema {
    LegacyParameterSchema.string(description: description, pattern: pattern)
}

/// Create a number parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func numberParam(
    description: String,
    minimum: Double? = nil,
    maximum: Double? = nil
) -> LegacyParameterSchema {
    LegacyParameterSchema.number(description: description, minimum: minimum, maximum: maximum)
}

/// Create an integer parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func integerParam(
    description: String,
    minimum: Int? = nil,
    maximum: Int? = nil
) -> LegacyParameterSchema {
    LegacyParameterSchema.integer(description: description, minimum: minimum?.double, maximum: maximum?.double)
}

/// Create a boolean parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func boolParam(description: String) -> LegacyParameterSchema {
    LegacyParameterSchema.boolean(description: description)
}

/// Create an array parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func arrayParam(
    description: String,
    items: LegacyParameterSchema
) -> LegacyParameterSchema {
    LegacyParameterSchema.array(of: items, description: description)
}

/// Create an object parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func objectParam(
    description: String,
    properties: [String: LegacyParameterSchema],
    required _: [String] = []
) -> LegacyParameterSchema {
    LegacyParameterSchema.object(properties: properties, description: description)
}

// MARK: - Type Extensions

extension Int {
    var double: Double {
        Double(self)
    }
}
