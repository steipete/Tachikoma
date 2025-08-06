//
//  SimpleToolWrapper.swift
//  Tachikoma
//

import Foundation

// MARK: - SimpleTool to RealtimeExecutableTool Adapter

/// Wraps a SimpleTool to make it compatible with RealtimeExecutableTool
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct SimpleToolWrapper: RealtimeExecutableTool {
    private let tool: SimpleTool
    
    public var metadata: RealtimeToolExecutor.ToolMetadata {
        RealtimeToolExecutor.ToolMetadata(
            name: tool.name,
            description: tool.description,
            parameters: tool.parameters
        )
    }
    
    public init(tool: SimpleTool) {
        self.tool = tool
    }
    
    public func execute(_ arguments: RealtimeToolArguments) async -> String {
        // Convert RealtimeToolArgument to ToolArgument (from Types.swift)
        var convertedArgs: [String: ToolArgument] = [:]
        
        for (key, value) in arguments {
            switch value {
            case .string(let str):
                convertedArgs[key] = .string(str)
            case .number(let num):
                convertedArgs[key] = .double(num)
            case .integer(let int):
                convertedArgs[key] = .int(int)
            case .boolean(let bool):
                convertedArgs[key] = .bool(bool)
            case .array(let arr):
                // Convert array elements
                let converted = arr.compactMap { element -> ToolArgument? in
                    switch element {
                    case .string(let s): return .string(s)
                    case .number(let n): return .double(n)
                    case .integer(let i): return .int(i)
                    case .boolean(let b): return .bool(b)
                    default: return nil
                    }
                }
                convertedArgs[key] = .array(converted)
            case .object(let jsonString):
                // Parse JSON string to dictionary
                if let data = jsonString.data(using: .utf8) {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data)
                        if let dict = json as? [String: Any] {
                            // Convert to nested ToolArgument structure
                            var objectArgs: [String: ToolArgument] = [:]
                            for (k, v) in dict {
                                objectArgs[k] = convertAnyToToolArgument(v)
                            }
                            convertedArgs[key] = .object(objectArgs)
                        } else {
                            // If not a dictionary, store as string
                            convertedArgs[key] = .string(jsonString)
                        }
                    } catch {
                        // If parsing fails, store as string
                        convertedArgs[key] = .string(jsonString)
                    }
                } else {
                    convertedArgs[key] = .string(jsonString)
                }
            }
        }
        
        // Execute the tool
        do {
            let result = try await tool.execute(ToolArguments(convertedArgs))
            
            // Convert result to string
            switch result {
            case .string(let text):
                return text
            case .int(let value):
                return String(value)
            case .double(let value):
                return String(value)
            case .bool(let value):
                return String(value)
            case .object(let dict):
                // Convert object to JSON string
                var jsonDict: [String: Any] = [:]
                for (k, v) in dict {
                    jsonDict[k] = convertToolArgumentToAny(v)
                }
                if let data = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted),
                   let jsonString = String(data: data, encoding: .utf8) {
                    return jsonString
                }
                return "Object result"
            case .array(let array):
                return "Array: \(array)"
            case .null:
                return "null"
            }
        } catch {
            return "Error executing tool: \(error)"
        }
    }
    
    // Helper function to convert Any to ToolArgument
    private func convertAnyToToolArgument(_ value: Any) -> ToolArgument {
        if value is NSNull {
            return .null
        } else if let bool = value as? Bool {
            return .bool(bool)
        } else if let int = value as? Int {
            return .int(int)
        } else if let double = value as? Double {
            return .double(double)
        } else if let string = value as? String {
            return .string(string)
        } else if let array = value as? [Any] {
            return .array(array.map(convertAnyToToolArgument))
        } else if let dict = value as? [String: Any] {
            var objectArgs: [String: ToolArgument] = [:]
            for (k, v) in dict {
                objectArgs[k] = convertAnyToToolArgument(v)
            }
            return .object(objectArgs)
        } else {
            return .string(String(describing: value))
        }
    }
    
    // Helper function to convert ToolArgument to Any
    private func convertToolArgumentToAny(_ arg: ToolArgument) -> Any {
        switch arg {
        case .null:
            return NSNull()
        case .bool(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .string(let value):
            return value
        case .array(let array):
            return array.map(convertToolArgumentToAny)
        case .object(let dict):
            var result: [String: Any] = [:]
            for (k, v) in dict {
                result[k] = convertToolArgumentToAny(v)
            }
            return result
        }
    }
}

// MARK: - ConversationItem Extension

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension ConversationItem {
    /// Create a function call result item
    public init(
        id: String = UUID().uuidString,
        type: String,
        role: String? = nil,
        content: [ConversationContent]? = nil,
        callId: String? = nil,
        name: String? = nil,
        arguments: String? = nil,
        output: String? = nil
    ) {
        self.id = id
        self.type = type
        self.role = role
        self.content = content
        self.callId = callId
        self.name = name
        self.arguments = arguments
        self.output = output
    }
}