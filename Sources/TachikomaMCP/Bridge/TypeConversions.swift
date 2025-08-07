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
                dict[key] = value.toAny()
            }
        }
        self.init(raw: dict)
    }
}

// MARK: AgentToolArgument Extensions
public extension AgentToolArgument {
    /// Convert to Any type for interop
    func toAny() -> Any {
        switch self {
        case .string(let str):
            return str
        case .int(let num):
            return num
        case .double(let num):
            return num
        case .bool(let bool):
            return bool
        case .array(let array):
            return array.map { $0.toAny() }
        case .object(let dict):
            return dict.mapValues { $0.toAny() }
        case .null:
            return NSNull()
        }
    }
    
    /// Initialize from Any type
    static func from(_ any: Any) -> AgentToolArgument {
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
            return .array(array.map { AgentToolArgument.from($0) })
        case let dict as [String: Any]:
            return .object(dict.mapValues { AgentToolArgument.from($0) })
        case is NSNull:
            return .null
        default:
            // Fallback: convert to string representation
            return .string(String(describing: any))
        }
    }
    
    /// Convert to MCP Value
    func toValue() -> Value {
        switch self {
        case .string(let str):
            return .string(str)
        case .int(let num):
            return .int(num)
        case .double(let num):
            return .double(num)
        case .bool(let bool):
            return .bool(bool)
        case .array(let array):
            return .array(array.map { $0.toValue() })
        case .object(let dict):
            return .object(dict.mapValues { $0.toValue() })
        case .null:
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
    
    /// Convert to Tachikoma's AgentToolArgument
    func toAgentToolArgument() -> AgentToolArgument {
        switch self {
        case .string(let str):
            return .string(str)
        case .int(let num):
            return .int(num)
        case .double(let num):
            return .double(num)
        case .bool(let bool):
            return .bool(bool)
        case .array(let array):
            return .array(array.map { $0.toAgentToolArgument() })
        case .object(let dict):
            return .object(dict.mapValues { $0.toAgentToolArgument() })
        case .null:
            return .null
        case .data(let mimeType, let data):
            // Convert data to a special object representation
            // Note: mimeType is optional, data is Data type
            return .object([
                "type": .string("data"),
                "mimeType": .string(mimeType ?? "application/octet-stream"),
                "dataSize": .int(data.count)
            ])
        }
    }
}

// MARK: ToolResponse Extensions
public extension ToolResponse {
    /// Convert to Tachikoma's AgentToolArgument (which is what AgentTool.execute returns)
    func toAgentToolResult() -> AgentToolArgument {
        // If there's an error, return error message
        if isError {
            let errorMessage = content.compactMap { content -> String? in
                if case .text(let text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")
            
            return .string("Error: \(errorMessage)")
        }
        
        // Convert the first content item to a result
        if let firstContent = content.first {
            switch firstContent {
            case .text(let text):
                return .string(text)
            case .image(let data, let mimeType, _):
                // For images, return a descriptive string
                return .string("[Image: \(mimeType), size: \(data.count) bytes]")
            case .resource(let uri, _, let text):
                // For resources, return the text content if available
                return .string(text ?? "[Resource: \(uri)]")
            case .audio(let data, let mimeType):
                return .string("[Audio: \(mimeType), size: \(data.count) bytes]")
            }
        }
        
        // No content
        return .string("Success")
    }
    
    /// Convert to Tachikoma's AgentToolArgument for more complex results
    func toAgentToolArgument() -> AgentToolArgument {
        // If there's an error, return it as a string
        if isError {
            let errorMessage = content.compactMap { content -> String? in
                if case .text(let text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")
            
            return .string("Error: \(errorMessage)")
        }
        
        // Convert content to appropriate format
        if content.count == 1 {
            // Single content item
            return convertContentToArgument(content[0])
        } else if content.isEmpty {
            // No content
            return .null
        } else {
            // Multiple content items - return as array
            return .array(content.map { convertContentToArgument($0) })
        }
    }
    
    private func convertContentToArgument(_ content: MCP.Tool.Content) -> AgentToolArgument {
        switch content {
        case .text(let text):
            return .string(text)
        case .image(let data, let mimeType, _):
            return .object([
                "type": .string("image"),
                "mimeType": .string(mimeType),
                "data": .string(data)
            ])
        case .resource(let uri, let mimeType, let text):
            var resourceDict: [String: AgentToolArgument] = [
                "type": .string("resource"),
                "uri": .string(uri),
                "mimeType": .string(mimeType)
            ]
            if let text = text {
                resourceDict["text"] = .string(text)
            }
            return .object(resourceDict)
        case .audio(let data, let mimeType):
            return .object([
                "type": .string("audio"),
                "mimeType": .string(mimeType),
                "data": .string(data)
            ])
        }
    }
}