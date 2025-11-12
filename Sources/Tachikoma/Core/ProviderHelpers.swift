import Foundation

// MARK: - Provider Helper Types

/// A coding key that can represent any string
public struct AnyCodingKey: CodingKey {
    public let stringValue: String
    public let intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Dynamic coding key for encoding arbitrary JSON structures
public struct DynamicCodingKey: CodingKey {
    public let stringValue: String
    public let intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }

    public init(stringLiteral value: String) {
        self.stringValue = value
        self.intValue = nil
    }
}

// MARK: - JSON Encoding Helpers

/// Encode any value into a nested container
public func encodeAnyValue(
    _ value: Any,
    to container: inout KeyedEncodingContainer<DynamicCodingKey>,
) throws {
    // Encode any value into a nested container
    if let dict = value as? [String: Any] {
        for (key, val) in dict {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            try encodeAnyValueRecursive(val, to: &container, forKey: codingKey)
        }
    }
}

/// Recursively encode any value type
private func encodeAnyValueRecursive(
    _ value: Any,
    to container: inout KeyedEncodingContainer<DynamicCodingKey>,
    forKey key: DynamicCodingKey,
) throws {
    // Recursively encode any value type
    switch value {
    case let stringValue as String:
        try container.encode(stringValue, forKey: key)
    case let intValue as Int:
        try container.encode(intValue, forKey: key)
    case let doubleValue as Double:
        try container.encode(doubleValue, forKey: key)
    case let boolValue as Bool:
        try container.encode(boolValue, forKey: key)
    case let arrayValue as [Any]:
        // Encode arrays properly as arrays, not as JSON strings
        var arrayContainer = container.nestedUnkeyedContainer(forKey: key)
        for element in arrayValue {
            try encodeAnyElement(element, to: &arrayContainer)
        }
    case let dictValue as [String: Any]:
        // For nested objects, create a nested container
        var nestedContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: key)
        for (nestedKey, nestedValue) in dictValue {
            guard let nestedCodingKey = DynamicCodingKey(stringValue: nestedKey) else { continue }
            try encodeAnyValueRecursive(nestedValue, to: &nestedContainer, forKey: nestedCodingKey)
        }
    default:
        // Fallback: convert to string
        try container.encode(String(describing: value), forKey: key)
    }
}

/// Encode any element into an unkeyed container (for arrays)
private func encodeAnyElement(
    _ value: Any,
    to container: inout UnkeyedEncodingContainer,
) throws {
    // Encode any element into an unkeyed container (for arrays)
    switch value {
    case let stringValue as String:
        try container.encode(stringValue)
    case let intValue as Int:
        try container.encode(intValue)
    case let doubleValue as Double:
        try container.encode(doubleValue)
    case let boolValue as Bool:
        try container.encode(boolValue)
    case let arrayValue as [Any]:
        // Nested arrays
        var nestedContainer = container.nestedUnkeyedContainer()
        for element in arrayValue {
            try encodeAnyElement(element, to: &nestedContainer)
        }
    case let dictValue as [String: Any]:
        // Dictionary within array
        var nestedContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self)
        for (key, val) in dictValue {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            try encodeAnyValueRecursive(val, to: &nestedContainer, forKey: codingKey)
        }
    default:
        // Fallback: convert to string
        try container.encode(String(describing: value))
    }
}
