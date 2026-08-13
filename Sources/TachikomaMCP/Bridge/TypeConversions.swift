import Foundation
import MCP
import Tachikoma

// MARK: - Type Conversion Extensions for TachikomaMCP

// MARK: AgentToolArguments Extensions

extension AgentToolArguments {
    func toMCPValue() -> Value {
        var values: [String: Value] = [:]
        for key in self.keys {
            if let value = self[key] {
                values[key] = value.toValue()
            }
        }
        return .object(values)
    }
}

// MARK: ToolArguments Extensions

extension ToolArguments {
    /// Initialize from Tachikoma's AgentToolArguments
    public init(from arguments: AgentToolArguments) {
        self.init(value: arguments.toMCPValue())
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
        AnyAgentToolValue.from(any).toValue()
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
        if self.isError {
            return self.legacyErrorValue()
        }

        return self.successValue(contentValues: self.convertedContent())
    }

    /// Convert a response for AgentTool execution, throwing typed MCP failures instead of returning success values.
    public func toAgentToolExecutionValue() throws -> AnyAgentToolValue {
        let contentValues = self.convertedContent()
        guard !self.isError else {
            throw AgentToolExecutionFailure(
                message: self.failureMessage(),
                content: contentValues,
                structuredValue: self.structuredContent?.toAnyAgentToolValue(),
                metadata: self.meta?.toAnyAgentToolValue(dataLengthKey: "size"),
            )
        }
        return self.successValue(contentValues: contentValues)
    }

    private func convertedContent() -> [AnyAgentToolValue] {
        self.content.map { MCPContentBridge.convert($0) }
    }

    private func successValue(contentValues: [AnyAgentToolValue]) -> AnyAgentToolValue {
        let contentValue: AnyAgentToolValue = if contentValues.isEmpty {
            AnyAgentToolValue(null: ())
        } else if contentValues.count == 1 {
            contentValues[0]
        } else {
            AnyAgentToolValue(array: contentValues)
        }

        guard self.meta != nil || self.structuredContent != nil else {
            return contentValue
        }

        var payload: [String: AnyAgentToolValue] = ["result": contentValue]
        if let meta = self.meta {
            payload["meta"] = meta.toAnyAgentToolValue(dataLengthKey: "size")
        }
        if let structuredContent = self.structuredContent {
            payload["structuredContent"] = structuredContent.toAnyAgentToolValue()
        }

        if let text = contentValue.stringValue {
            payload["text"] = AnyAgentToolValue(string: text)
        }

        return AnyAgentToolValue(object: payload)
    }

    private func legacyErrorValue() -> AnyAgentToolValue {
        let errorMessage = self.content.compactMap { content -> String? in
            if case let .text(text, _, _) = content {
                return text
            }
            return nil
        }.joined(separator: "\n")
        return AnyAgentToolValue(string: "Error: \(errorMessage)")
    }

    private func failureMessage() -> String {
        let errorMessage = self.content.compactMap { content -> String? in
            switch content {
            case let .text(text, _, _):
                text
            case let .resource(resource, _, _):
                resource.text
            default:
                nil
            }
        }.joined(separator: "\n")
        return errorMessage.isEmpty ? "Tool execution failed" : errorMessage
    }
}
