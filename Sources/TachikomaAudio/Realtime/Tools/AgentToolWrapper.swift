import Foundation
import Tachikoma

// MARK: - AgentTool to RealtimeExecutableTool Adapter

/// Wraps an AgentTool to make it compatible with RealtimeExecutableTool
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentToolWrapper: RealtimeExecutableTool {
    private let tool: AgentTool

    public var metadata: RealtimeToolExecutor.ToolMetadata {
        RealtimeToolExecutor.ToolMetadata(
            name: self.tool.name,
            description: self.tool.description,
            parameters: self.tool.parameters,
        )
    }

    public init(tool: AgentTool) {
        self.tool = tool
    }

    public func execute(_ arguments: RealtimeToolArguments) async -> String {
        // Convert RealtimeToolArgument to AgentToolArgument (from Types.swift)
        var convertedArgs: [String: AnyAgentToolValue] = [:]

        for (key, value) in arguments {
            switch value {
            case let .string(str):
                convertedArgs[key] = AnyAgentToolValue(string: str)
            case let .number(num):
                convertedArgs[key] = AnyAgentToolValue(double: num)
            case let .integer(int):
                convertedArgs[key] = AnyAgentToolValue(int: int)
            case let .boolean(bool):
                convertedArgs[key] = AnyAgentToolValue(bool: bool)
            case let .array(arr):
                // Convert array elements
                let converted = arr.compactMap { element -> AnyAgentToolValue? in
                    switch element {
                    case let .string(s): return AnyAgentToolValue(string: s)
                    case let .number(n): return AnyAgentToolValue(double: n)
                    case let .integer(i): return AnyAgentToolValue(int: i)
                    case let .boolean(b): return AnyAgentToolValue(bool: b)
                    default: return nil
                    }
                }
                convertedArgs[key] = AnyAgentToolValue(array: converted)
            case let .object(jsonString):
                // Parse JSON string to dictionary
                if let data = jsonString.data(using: .utf8) {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data)
                        if let dict = json as? [String: Any] {
                            // Convert to nested AnyAgentToolValue structure
                            var objectArgs: [String: AnyAgentToolValue] = [:]
                            for (k, v) in dict {
                                objectArgs[k] = self.convertAnyToToolArgument(v)
                            }
                            convertedArgs[key] = AnyAgentToolValue(object: objectArgs)
                        } else {
                            // If not a dictionary, store as string
                            convertedArgs[key] = AnyAgentToolValue(string: jsonString)
                        }
                    } catch {
                        // If parsing fails, store as string
                        convertedArgs[key] = AnyAgentToolValue(string: jsonString)
                    }
                } else {
                    convertedArgs[key] = AnyAgentToolValue(string: jsonString)
                }
            }
        }

        // Execute the tool
        do {
            let context = ToolExecutionContext()
            let result = try await tool.execute(AgentToolArguments(convertedArgs), context: context)

            // Convert result to string
            if let text = result.stringValue {
                return text
            } else if let value = result.intValue {
                return String(value)
            } else if let value = result.doubleValue {
                return String(value)
            } else if let value = result.boolValue {
                return String(value)
            } else if let dict = result.objectValue {
                // Convert object to JSON string
                var jsonDict: [String: Any] = [:]
                for (k, v) in dict {
                    jsonDict[k] = self.convertToolArgumentToAny(v)
                }
                if
                    let data = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted),
                    let jsonString = String(data: data, encoding: .utf8)
                {
                    return jsonString
                }
                return "Object result"
            } else if let array = result.arrayValue {
                return "Array: \(array)"
            } else if result.isNull {
                return "null"
            } else {
                return "Unknown result type"
            }
        } catch {
            return "Error executing tool: \(error)"
        }
    }

    // Helper function to convert Any to AnyAgentToolValue
    private func convertAnyToToolArgument(_ value: Any) -> AnyAgentToolValue {
        do {
            return try AnyAgentToolValue.fromJSON(value)
        } catch {
            // Fallback to string representation if conversion fails
            return AnyAgentToolValue(string: String(describing: value))
        }
    }

    // Helper function to convert AnyAgentToolValue to Any
    private func convertToolArgumentToAny(_ arg: AnyAgentToolValue) -> Any {
        do {
            return try arg.toJSON()
        } catch {
            // Fallback to string representation if conversion fails
            return String(describing: arg)
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
        output: String? = nil,
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
