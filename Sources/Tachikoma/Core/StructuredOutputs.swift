import Foundation

/// Schema metadata used by providers that support structured outputs.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct StructuredOutputSchema: Sendable, Codable, Equatable {
    public let name: String
    public let description: String?
    public let schema: TypedValue
    public let strict: Bool

    public init(
        name: String,
        description: String? = nil,
        schema: TypedValue,
        strict: Bool = true,
    ) {
        self.name = name
        self.description = description
        self.schema = schema
        self.strict = strict
    }
}

/// Opt-in protocol for strongly-typed structured outputs.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol StructuredOutputSchemaProviding {
    static var structuredOutputSchema: StructuredOutputSchema { get }
}
