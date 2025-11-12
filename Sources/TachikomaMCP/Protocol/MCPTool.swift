import Foundation
import MCP
import Tachikoma

/// Protocol defining the interface for MCP tools
public protocol MCPTool: Sendable {
    /// The unique name of the tool
    var name: String { get }

    /// A human-readable description of what the tool does
    var description: String { get }

    /// JSON Schema defining the input parameters
    var inputSchema: Value { get }

    /// Execute the tool with the given arguments
    func execute(arguments: ToolArguments) async throws -> ToolResponse
}

/// Wrapper for tool arguments received from MCP
public struct ToolArguments: Sendable {
    // Execute the tool with the given arguments
    private let raw: Value

    public init(raw: [String: Any]) {
        // Convert [String: Any] to Value for Sendable compliance
        self.raw = .object(raw.mapValues { convertToValue($0) })
    }

    public init(value: Value) {
        self.raw = value
    }

    /// Expose arguments as a plain dictionary for bridging to non-Sendable APIs
    public var rawDictionary: [String: Any] {
        guard case let .object(dict) = raw else { return [:] }
        return dict.mapValues { value in
            switch value {
            case let .string(s): s
            case let .int(i): i
            case let .double(d): d
            case let .bool(b): b
            case let .array(arr): arr.map { ValueToAny($0) }
            case let .object(obj): obj.mapValues { ValueToAny($0) }
            case .null: NSNull()
            case let .data(mime, data): ["type": "data", "mimeType": mime ?? "application/octet-stream", "data": data]
            }
        }
    }

    /// Decode arguments into a specific type
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        // Decode arguments into a specific type
        let data = try JSONEncoder().encode(self.raw)
        return try JSONDecoder().decode(type, from: data)
    }

    /// Get a specific value by key
    public func getValue(for key: String) -> Value? {
        // Get a specific value by key
        if case let .object(dict) = raw {
            return dict[key]
        }
        return nil
    }

    /// Check if arguments are empty
    public var isEmpty: Bool {
        if case let .object(dict) = raw {
            return dict.isEmpty
        }
        return true
    }

    // MARK: - Convenience methods for common types

    /// Get a string value
    public func getString(_ key: String) -> String? {
        // Get a string value
        guard let value = getValue(for: key) else { return nil }
        switch value {
        case let .string(str):
            return str
        case let .int(num):
            return String(num)
        case let .double(num):
            return String(num)
        case let .bool(bool):
            return String(bool)
        default:
            return nil
        }
    }

    /// Get a number (Int or Double) as Double
    public func getNumber(_ key: String) -> Double? {
        // Get a number (Int or Double) as Double
        guard let value = getValue(for: key) else { return nil }
        switch value {
        case let .int(num):
            return Double(num)
        case let .double(num):
            return num
        case let .string(str):
            return Double(str)
        default:
            return nil
        }
    }

    /// Get an integer value
    public func getInt(_ key: String) -> Int? {
        // Get an integer value
        guard let value = getValue(for: key) else { return nil }
        switch value {
        case let .int(num):
            return num
        case let .double(num):
            return Int(num)
        case let .string(str):
            return Int(str)
        default:
            return nil
        }
    }

    /// Get a boolean value
    public func getBool(_ key: String) -> Bool? {
        // Get a boolean value
        guard let value = getValue(for: key) else { return nil }
        switch value {
        case let .bool(bool):
            return bool
        case let .string(str):
            return ["true", "yes", "1"].contains(str.lowercased())
        case let .int(num):
            return num != 0
        default:
            return nil
        }
    }

    /// Get an array of strings
    public func getStringArray(_ key: String) -> [String]? {
        // Get an array of strings
        guard let value = getValue(for: key) else { return nil }
        if case let .array(array) = value {
            return array.compactMap { element in
                if case let .string(str) = element {
                    return str
                }
                return nil
            }
        }
        return nil
    }

    /// Get the raw Value
    public var rawValue: Value {
        self.raw
    }
}

private func ValueToAny(_ value: Value) -> Any {
    switch value {
    case let .string(s): s
    case let .int(i): i
    case let .double(d): d
    case let .bool(b): b
    case let .array(arr): arr.map { ValueToAny($0) }
    case let .object(obj): obj.mapValues { ValueToAny($0) }
    case .null: NSNull()
    case let .data(mime, data): ["type": "data", "mimeType": mime ?? "application/octet-stream", "data": data]
    }
}

// Helper function to convert Any to Value
private func convertToValue(_ value: Any) -> Value {
    switch value {
    case let string as String:
        .string(string)
    case let number as Int:
        .int(number)
    case let number as Double:
        .double(number)
    case let bool as Bool:
        .bool(bool)
    case let array as [Any]:
        .array(array.map { convertToValue($0) })
    case let dict as [String: Any]:
        .object(dict.mapValues { convertToValue($0) })
    case is NSNull:
        .null
    default:
        // Fallback for unexpected types
        .string(String(describing: value))
    }
}

/// Response from tool execution
public struct ToolResponse: Sendable {
    public let content: [MCP.Tool.Content]
    public let isError: Bool
    public let meta: Value?

    public init(content: [MCP.Tool.Content], isError: Bool = false, meta: Value? = nil) {
        self.content = content
        self.isError = isError
        self.meta = meta
    }

    /// Create a text response
    public static func text(_ text: String, meta: Value? = nil) -> ToolResponse {
        // Create a text response
        ToolResponse(
            content: [.text(text)],
            isError: false,
            meta: meta,
        )
    }

    /// Create an error response
    public static func error(_ message: String, meta: Value? = nil) -> ToolResponse {
        // Create an error response
        ToolResponse(
            content: [.text(message)],
            isError: true,
            meta: meta,
        )
    }

    /// Create an image response
    public static func image(data: Data, mimeType: String = "image/png", meta: Value? = nil) -> ToolResponse {
        // Create an image response
        ToolResponse(
            content: [.image(data: data.base64EncodedString(), mimeType: mimeType, metadata: nil)],
            isError: false,
            meta: meta,
        )
    }

    /// Create a multi-content response
    public static func multiContent(_ contents: [MCP.Tool.Content], meta: Value? = nil) -> ToolResponse {
        // Create a multi-content response
        ToolResponse(
            content: contents,
            isError: false,
            meta: meta,
        )
    }
}

// Type alias for convenience
public typealias MCPContent = MCP.Tool.Content
