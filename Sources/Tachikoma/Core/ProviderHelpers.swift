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
    to container: inout KeyedEncodingContainer<DynamicCodingKey>
) throws {
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
    forKey key: DynamicCodingKey
) throws {
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
        // For arrays, we encode as JSON string for simplicity
        let jsonData = try JSONSerialization.data(withJSONObject: arrayValue)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
        try container.encode(jsonString, forKey: key)
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