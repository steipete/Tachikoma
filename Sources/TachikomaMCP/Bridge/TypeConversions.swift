import Foundation
import MCP
import Tachikoma

// MARK: - Type Conversion Extensions for TachikomaMCP

// MARK: ToolArguments Extensions

extension ToolArguments {
    /// Initialize from Tachikoma's AgentToolArguments
    public init(from arguments: AgentToolArguments) {
        var dict: [String: Any] = [:]
        for key in arguments.keys {
            guard let value = arguments[key] else { continue }
            if let json = try? value.toJSON() {
                dict[key] = json
            } else {
                dict[key] = ["serializationFailure": String(describing: value)]
            }
        }
        self.init(raw: dict)
    }
}

// MARK: AnyAgentToolValue Extensions

extension AnyAgentToolValue {
    /// Convert to MCP Value
    public func toValue() -> Value {
        // Convert to MCP Value
        if let str = stringValue {
            .string(str)
        } else if let num = intValue {
            .int(num)
        } else if let num = doubleValue {
            .double(num)
        } else if let bool = boolValue {
            .bool(bool)
        } else if let array = arrayValue {
            .array(array.map { $0.toValue() })
        } else if let dict = objectValue {
            .object(dict.mapValues { $0.toValue() })
        } else if isNull {
            .null
        } else {
            // Fallback to null
            .null
        }
    }
}

// MARK: Value Extensions

extension Value {
    /// Convert from Any type
    public static func from(_ any: Any) -> Value {
        // Convert from Any type
        switch any {
        case let str as String:
            .string(str)
        case let num as Int:
            .int(num)
        case let num as Double:
            .double(num)
        case let bool as Bool:
            .bool(bool)
        case let array as [Any]:
            .array(array.map { Value.from($0) })
        case let dict as [String: Any]:
            .object(dict.mapValues { Value.from($0) })
        case is NSNull:
            .null
        default:
            // Fallback: convert to string representation
            .string(String(describing: any))
        }
    }

    /// Convert to Tachikoma's AnyAgentToolValue
    public func toAnyAgentToolValue() -> AnyAgentToolValue {
        self.toAnyAgentToolValue(dataLengthKey: "dataSize")
    }

    fileprivate func toAnyAgentToolValue(dataLengthKey: String) -> AnyAgentToolValue {
        // Convert to Tachikoma's AnyAgentToolValue
        switch self {
        case let .string(str):
            AnyAgentToolValue(string: str)
        case let .int(num):
            AnyAgentToolValue(int: num)
        case let .double(num):
            AnyAgentToolValue(double: num)
        case let .bool(bool):
            AnyAgentToolValue(bool: bool)
        case let .array(array):
            AnyAgentToolValue(array: array.map { $0.toAnyAgentToolValue(dataLengthKey: dataLengthKey) })
        case let .object(dict):
            AnyAgentToolValue(object: dict.mapValues { $0.toAnyAgentToolValue(dataLengthKey: dataLengthKey) })
        case .null:
            AnyAgentToolValue(null: ())
        case let .data(mimeType, data):
            // Convert data to a special object representation
            // Note: mimeType is optional, data is Data type
            AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "data"),
                "mimeType": AnyAgentToolValue(string: mimeType ?? "application/octet-stream"),
                dataLengthKey: AnyAgentToolValue(int: data.count),
            ])
        }
    }
}

// MARK: ToolResponse Extensions

extension ToolResponse {
    /// Convert to Tachikoma's AnyAgentToolValue (which is what AgentTool.execute returns)
    public func toAgentToolResult() -> AnyAgentToolValue {
        // If there's an error, return error message
        if isError {
            let errorMessage = content.compactMap { content -> String? in
                if case let .text(text, _, _) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")

            return AnyAgentToolValue(string: "Error: \(errorMessage)")
        }

        // Convert the first content item to a result
        if let firstContent = content.first {
            return AnyAgentToolValue(string: MCPContentBridge.summary(for: firstContent))
        }

        // No content
        return AnyAgentToolValue(string: "Success")
    }

    /// Convert to Tachikoma's AnyAgentToolValue for more complex results
    public func toAnyAgentToolValue() -> AnyAgentToolValue {
        // If there's an error, return it as a string
        if isError {
            let errorMessage = content.compactMap { content -> String? in
                if case let .text(text, _, _) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")

            return AnyAgentToolValue(string: "Error: \(errorMessage)")
        }

        let contentValue: AnyAgentToolValue = if content.isEmpty {
            AnyAgentToolValue(null: ())
        } else if content.count == 1 {
            MCPContentBridge.convert(content[0])
        } else {
            AnyAgentToolValue(array: content.map { MCPContentBridge.convert($0) })
        }

        guard let meta else {
            return contentValue
        }

        var payload: [String: AnyAgentToolValue] = [
            "result": contentValue,
            "meta": meta.toAnyAgentToolValue(dataLengthKey: "size"),
        ]

        if let text = contentValue.stringValue {
            payload["text"] = AnyAgentToolValue(string: text)
        }

        return AnyAgentToolValue(object: payload)
    }
}
