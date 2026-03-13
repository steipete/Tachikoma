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
            AnyAgentToolValue(array: array.map { $0.toAnyAgentToolValue() })
        case let .object(dict):
            AnyAgentToolValue(object: dict.mapValues { $0.toAnyAgentToolValue() })
        case .null:
            AnyAgentToolValue(null: ())
        case let .data(mimeType, data):
            // Convert data to a special object representation
            // Note: mimeType is optional, data is Data type
            AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "data"),
                "mimeType": AnyAgentToolValue(string: mimeType ?? "application/octet-stream"),
                "dataSize": AnyAgentToolValue(int: data.count),
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
                if case let .text(text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")

            return AnyAgentToolValue(string: "Error: \(errorMessage)")
        }

        // Convert the first content item to a result
        if let firstContent = content.first {
            switch firstContent {
            case let .text(text):
                return AnyAgentToolValue(string: text)
            case let .image(data, mimeType, _):
                // For images, return a descriptive string
                return AnyAgentToolValue(string: "[Image: \(mimeType), size: \(data.count) bytes]")
            case let .resource(resource, _, _):
                // For resources, return the text content if available
                return AnyAgentToolValue(string: resource.text ?? "[Resource: \(resource.uri)]")
            case let .resourceLink(uri, name, _, _, mimeType, _):
                let mimeTypeDescription = mimeType.map { ", mimeType: \($0)" } ?? ""
                return AnyAgentToolValue(string: "[Resource Link: \(name), uri: \(uri)\(mimeTypeDescription)]")
            case let .audio(data, mimeType):
                return AnyAgentToolValue(string: "[Audio: \(mimeType), size: \(data.count) bytes]")
            }
        }

        // No content
        return AnyAgentToolValue(string: "Success")
    }

    /// Convert to Tachikoma's AnyAgentToolValue for more complex results
    public func toAnyAgentToolValue() -> AnyAgentToolValue {
        // If there's an error, return it as a string
        if isError {
            let errorMessage = content.compactMap { content -> String? in
                if case let .text(text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")

            return AnyAgentToolValue(string: "Error: \(errorMessage)")
        }

        // Convert content to appropriate format
        if content.count == 1 {
            // Single content item
            return self.convertContentToAnyAgentToolValue(content[0])
        } else if content.isEmpty {
            // No content
            return AnyAgentToolValue(null: ())
        } else {
            // Multiple content items - return as array
            return AnyAgentToolValue(array: content.map { self.convertContentToAnyAgentToolValue($0) })
        }
    }

    private func convertContentToAnyAgentToolValue(_ content: MCP.Tool.Content) -> AnyAgentToolValue {
        switch content {
        case let .text(text):
            return AnyAgentToolValue(string: text)
        case let .image(data, mimeType, _):
            return AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "image"),
                "mimeType": AnyAgentToolValue(string: mimeType),
                "data": AnyAgentToolValue(string: data),
            ])
        case let .resource(resource, _, _):
            var resourceDict: [String: AnyAgentToolValue] = [
                "type": AnyAgentToolValue(string: "resource"),
                "uri": AnyAgentToolValue(string: resource.uri),
            ]
            if let mimeType = resource.mimeType {
                resourceDict["mimeType"] = AnyAgentToolValue(string: mimeType)
            }
            if let text = resource.text {
                resourceDict["text"] = AnyAgentToolValue(string: text)
            }
            if let blob = resource.blob {
                resourceDict["blob"] = AnyAgentToolValue(string: blob)
            }
            return AnyAgentToolValue(object: resourceDict)
        case let .resourceLink(uri, name, title, description, mimeType, _):
            var resourceLinkDict: [String: AnyAgentToolValue] = [
                "type": AnyAgentToolValue(string: "resourceLink"),
                "uri": AnyAgentToolValue(string: uri),
                "name": AnyAgentToolValue(string: name),
            ]
            if let title {
                resourceLinkDict["title"] = AnyAgentToolValue(string: title)
            }
            if let description {
                resourceLinkDict["description"] = AnyAgentToolValue(string: description)
            }
            if let mimeType {
                resourceLinkDict["mimeType"] = AnyAgentToolValue(string: mimeType)
            }
            return AnyAgentToolValue(object: resourceLinkDict)
        case let .audio(data, mimeType):
            return AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "audio"),
                "mimeType": AnyAgentToolValue(string: mimeType),
                "data": AnyAgentToolValue(string: data),
            ])
        }
    }
}
