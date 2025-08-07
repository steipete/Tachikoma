//
//  TypeConversions.swift
//  TachikomaMCP
//

import Foundation
import Tachikoma
import MCP

// MARK: - Type Conversion Extensions for TachikomaMCP

// MARK: ToolArguments Extensions
public extension ToolArguments {
    /// Initialize from Tachikoma's AgentToolArguments
    init(from arguments: AgentToolArguments) {
        var dict: [String: Any] = [:]
        for key in arguments.keys {
            if let value = arguments[key] {
                dict[key] = try! value.toJSON()
            }
        }
        self.init(raw: dict)
    }
}

// MARK: AnyAgentToolValue Extensions
public extension AnyAgentToolValue {
    /// Initialize from Any type
    static func from(_ any: Any) -> AnyAgentToolValue {
        switch any {
        case let str as String:
            return AnyAgentToolValue(string: str)
        case let num as Int:
            return AnyAgentToolValue(int: num)
        case let num as Double:
            return AnyAgentToolValue(double: num)
        case let bool as Bool:
            return AnyAgentToolValue(bool: bool)
        case let array as [Any]:
            return AnyAgentToolValue(array: array.map { AnyAgentToolValue.from($0) })
        case let dict as [String: Any]:
            return AnyAgentToolValue(object: dict.mapValues { AnyAgentToolValue.from($0) })
        case is NSNull:
            return AnyAgentToolValue(null: ())
        default:
            // Fallback: convert to string representation
            return AnyAgentToolValue(string: String(describing: any))
        }
    }
    
    /// Convert to MCP Value
    func toValue() -> Value {
        if let str = stringValue {
            return .string(str)
        } else if let num = intValue {
            return .int(num)
        } else if let num = doubleValue {
            return .double(num)
        } else if let bool = boolValue {
            return .bool(bool)
        } else if let array = arrayValue {
            return .array(array.map { $0.toValue() })
        } else if let dict = objectValue {
            return .object(dict.mapValues { $0.toValue() })
        } else if isNull {
            return .null
        } else {
            // Fallback to null
            return .null
        }
    }
}

// MARK: Value Extensions
public extension Value {
    /// Convert from Any type
    static func from(_ any: Any) -> Value {
        switch any {
        case let str as String:
            return .string(str)
        case let num as Int:
            return .int(num)
        case let num as Double:
            return .double(num)
        case let bool as Bool:
            return .bool(bool)
        case let array as [Any]:
            return .array(array.map { Value.from($0) })
        case let dict as [String: Any]:
            return .object(dict.mapValues { Value.from($0) })
        case is NSNull:
            return .null
        default:
            // Fallback: convert to string representation
            return .string(String(describing: any))
        }
    }
    
    /// Convert to Tachikoma's AnyAgentToolValue
    func toAnyAgentToolValue() -> AnyAgentToolValue {
        switch self {
        case .string(let str):
            return AnyAgentToolValue(string: str)
        case .int(let num):
            return AnyAgentToolValue(int: num)
        case .double(let num):
            return AnyAgentToolValue(double: num)
        case .bool(let bool):
            return AnyAgentToolValue(bool: bool)
        case .array(let array):
            return AnyAgentToolValue(array: array.map { $0.toAnyAgentToolValue() })
        case .object(let dict):
            return AnyAgentToolValue(object: dict.mapValues { $0.toAnyAgentToolValue() })
        case .null:
            return AnyAgentToolValue(null: ())
        case .data(let mimeType, let data):
            // Convert data to a special object representation
            // Note: mimeType is optional, data is Data type
            return AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "data"),
                "mimeType": AnyAgentToolValue(string: mimeType ?? "application/octet-stream"),
                "dataSize": AnyAgentToolValue(int: data.count)
            ])
        }
    }
}

// MARK: ToolResponse Extensions
public extension ToolResponse {
    /// Convert to Tachikoma's AnyAgentToolValue (which is what AgentTool.execute returns)
    func toAgentToolResult() -> AnyAgentToolValue {
        // If there's an error, return error message
        if isError {
            let errorMessage = content.compactMap { content -> String? in
                if case .text(let text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")
            
            return AnyAgentToolValue(string: "Error: \(errorMessage)")
        }
        
        // Convert the first content item to a result
        if let firstContent = content.first {
            switch firstContent {
            case .text(let text):
                return AnyAgentToolValue(string: text)
            case .image(let data, let mimeType, _):
                // For images, return a descriptive string
                return AnyAgentToolValue(string: "[Image: \(mimeType), size: \(data.count) bytes]")
            case .resource(let uri, _, let text):
                // For resources, return the text content if available
                return AnyAgentToolValue(string: text ?? "[Resource: \(uri)]")
            case .audio(let data, let mimeType):
                return AnyAgentToolValue(string: "[Audio: \(mimeType), size: \(data.count) bytes]")
            }
        }
        
        // No content
        return AnyAgentToolValue(string: "Success")
    }
    
    /// Convert to Tachikoma's AnyAgentToolValue for more complex results
    func toAnyAgentToolValue() -> AnyAgentToolValue {
        // If there's an error, return it as a string
        if isError {
            let errorMessage = content.compactMap { content -> String? in
                if case .text(let text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")
            
            return AnyAgentToolValue(string: "Error: \(errorMessage)")
        }
        
        // Convert content to appropriate format
        if content.count == 1 {
            // Single content item
            return convertContentToAnyAgentToolValue(content[0])
        } else if content.isEmpty {
            // No content
            return AnyAgentToolValue(null: ())
        } else {
            // Multiple content items - return as array
            return AnyAgentToolValue(array: content.map { convertContentToAnyAgentToolValue($0) })
        }
    }
    
    private func convertContentToAnyAgentToolValue(_ content: MCP.Tool.Content) -> AnyAgentToolValue {
        switch content {
        case .text(let text):
            return AnyAgentToolValue(string: text)
        case .image(let data, let mimeType, _):
            return AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "image"),
                "mimeType": AnyAgentToolValue(string: mimeType),
                "data": AnyAgentToolValue(string: data)
            ])
        case .resource(let uri, let mimeType, let text):
            var resourceDict: [String: AnyAgentToolValue] = [
                "type": AnyAgentToolValue(string: "resource"),
                "uri": AnyAgentToolValue(string: uri),
                "mimeType": AnyAgentToolValue(string: mimeType)
            ]
            if let text = text {
                resourceDict["text"] = AnyAgentToolValue(string: text)
            }
            return AnyAgentToolValue(object: resourceDict)
        case .audio(let data, let mimeType):
            return AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "audio"),
                "mimeType": AnyAgentToolValue(string: mimeType),
                "data": AnyAgentToolValue(string: data)
            ])
        }
    }
}