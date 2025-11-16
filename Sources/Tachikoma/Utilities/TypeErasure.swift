import Foundation

// MARK: - Type-Erased Encoding/Decoding Utilities

/// Type-erased encoder for Any values
/// Used when interfacing with APIs that require unstructured JSON
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct AnyEncodable: Encodable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    /// Recursively encode arbitrary JSON-compatible values while preserving type fidelity.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self.value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let int8 as Int8:
            try container.encode(int8)
        case let int16 as Int16:
            try container.encode(int16)
        case let int32 as Int32:
            try container.encode(int32)
        case let int64 as Int64:
            try container.encode(int64)
        case let uint as UInt:
            try container.encode(uint)
        case let uint8 as UInt8:
            try container.encode(uint8)
        case let uint16 as UInt16:
            try container.encode(uint16)
        case let uint32 as UInt32:
            try container.encode(uint32)
        case let uint64 as UInt64:
            try container.encode(uint64)
        case let float as Float:
            try container.encode(float)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map(AnyEncodable.init))
        case let dict as [String: Any]:
            try container.encode(dict.mapValues(AnyEncodable.init))
        case is NSNull:
            try container.encodeNil()
        case let encodable as Encodable:
            try encodable.encode(to: encoder)
        default:
            throw EncodingError.invalidValue(
                self.value,
                .init(
                    codingPath: encoder.codingPath,
                    debugDescription: "Cannot encode value of type \(type(of: self.value))",
                ),
            )
        }
    }
}

/// Type-erased decoder for Any values
/// Used when parsing unstructured JSON from APIs
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct AnyDecodable: Decodable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    /// Recursively decode arbitrary JSON structures into heterogenous Swift values.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyDecodable].self) {
            self.value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyDecodable].self) {
            self.value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode value",
            )
        }
    }
}
