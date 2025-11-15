import Foundation

// MARK: - Tool Creation Helper

/// Creates a simple tool with basic parameters (legacy API)
public func createTool(
    name: String,
    description: String,
    parameters: [AgentToolParameterProperty] = [],
    required: [String] = [],
    execute: @escaping @Sendable (AgentToolArguments) async throws -> AnyAgentToolValue,
)
    -> AgentTool
{
    // Convert array of properties to dictionary keyed by name
    var properties: [String: AgentToolParameterProperty] = [:]
    for param in parameters {
        properties[param.name] = param
    }

    return AgentTool(
        name: name,
        description: description,
        parameters: AgentToolParameters(properties: properties, required: required),
        execute: execute,
    )
}

// MARK: - Convenience Functions

extension AgentTool {
    /// Convert to a AgentToolDefinition for external APIs
    public var definition: AgentToolDefinition {
        AgentToolDefinition(
            name: name,
            description: description,
            parameters: parameters,
        )
    }
}

// MARK: - Common Tools

/// Built-in calculator tool
public let calculatorTool = createTool(
    name: "calculate",
    description: "Perform mathematical calculations",
    parameters: [
        AgentToolParameterProperty(
            name: "expression",
            type: .string,
            description: "Mathematical expression to evaluate (e.g., '2 + 2', 'sqrt(16)', 'sin(pi/2)')",
        ),
    ],
    required: ["expression"],
) { args in
    let expression = try args.stringValue("expression")

    // Basic math evaluation - cross-platform implementation
    let result = try evaluateExpression(expression)
    return AnyAgentToolValue(string: "Result: \(result)")
}

/// Built-in time tool
public let timeTool = createTool(
    name: "get_current_time",
    description: "Get the current date and time",
    parameters: [],
    required: [],
) { _ in
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    formatter.timeStyle = .full
    let timeString = formatter.string(from: Date())
    return AnyAgentToolValue(string: timeString)
}

/// Built-in weather tool (mock implementation)
public let weatherTool = createTool(
    name: "get_weather",
    description: "Get weather information for a location",
    parameters: [
        AgentToolParameterProperty(
            name: "location",
            type: .string,
            description: "The city or location to get weather for",
        ),
    ],
    required: ["location"],
) { args in
    let location = try args.stringValue("location")
    // This is a mock implementation - replace with real weather API
    return AnyAgentToolValue(string: "Weather in \(location): Sunny, 22°C")
}

// MARK: - Helper Functions

/// Convert AgentToolParameters to JSON schema format
public func toolParametersToJSON(_ parameters: AgentToolParameters) throws -> [String: Any] {
    // Convert AgentToolParameters to JSON schema format
    var schema: [String: Any] = [
        "type": "object",
        "properties": [:],
        "required": parameters.required,
    ]

    var properties: [String: Any] = [:]
    for (propertyName, property) in parameters.properties {
        var propSchema: [String: Any] = [
            "type": property.type.rawValue,
            "description": property.description,
        ]

        if let enumValues = property.enumValues {
            propSchema["enum"] = enumValues
        }

        // Handle array items if present
        if property.type == .array, let items = property.items {
            let itemsSchema: [String: Any] = [
                "type": items.type,
            ]
            propSchema["items"] = itemsSchema
        }

        properties[propertyName] = propSchema
    }

    schema["properties"] = properties
    return schema
}

/// Convert JSON arguments to AgentToolArguments
public func jsonToToolArguments(_ json: [String: Any]) -> AgentToolArguments {
    // Convert JSON arguments to AgentToolArguments
    var arguments: [String: AnyAgentToolValue] = [:]

    for (key, value) in json {
        arguments[key] = jsonValueToToolArgument(value)
    }

    return AgentToolArguments(arguments)
}

/// Convert a JSON value to AnyAgentToolValue
public func jsonValueToToolArgument(_ value: Any) -> AnyAgentToolValue {
    // Convert a JSON value to AnyAgentToolValue
    do {
        return try AnyAgentToolValue.fromJSON(value)
    } catch {
        // Fallback to string representation if conversion fails
        return AnyAgentToolValue(string: String(describing: value))
    }
}

// MARK: - AgentToolError for TachikomaBuilders Compatibility

/// Extended AgentToolError with additional compatibility cases
extension AgentToolError {
    public static func invalidJSON(_ message: String) -> AgentToolError {
        .invalidInput("Invalid JSON: \(message)")
    }

    public static func networkError(_ message: String) -> AgentToolError {
        .executionFailed("Network error: \(message)")
    }

    public static func authenticationError(_ message: String) -> AgentToolError {
        .executionFailed("Authentication error: \(message)")
    }

    public static func toolNotFound(_ toolName: String) -> AgentToolError {
        .invalidInput("Tool not found: \(toolName)")
    }
}

// MARK: - Parameter Schema for TachikomaBuilders Compatibility

/// Helper for creating parameter schemas
public enum ParameterSchema {
    public static func string(
        name: String,
        description: String,
        required _: Bool = false,
        enumValues: [String]? = nil,
    )
        -> AgentToolParameterProperty
    {
        AgentToolParameterProperty(
            name: name,
            type: .string,
            description: description,
            enumValues: enumValues,
        )
    }

    public static func number(
        name: String,
        description: String,
        required _: Bool = false,
    )
        -> AgentToolParameterProperty
    {
        AgentToolParameterProperty(
            name: name,
            type: .number,
            description: description,
        )
    }

    public static func integer(
        name: String,
        description: String,
        required _: Bool = false,
    )
        -> AgentToolParameterProperty
    {
        AgentToolParameterProperty(
            name: name,
            type: .integer,
            description: description,
        )
    }

    public static func boolean(
        name: String,
        description: String,
        required _: Bool = false,
    )
        -> AgentToolParameterProperty
    {
        AgentToolParameterProperty(
            name: name,
            type: .boolean,
            description: description,
        )
    }

    public static func array(
        name: String,
        description: String,
        required _: Bool = false,
    )
        -> AgentToolParameterProperty
    {
        AgentToolParameterProperty(
            name: name,
            type: .array,
            description: description,
        )
    }

    public static func object(
        name: String,
        description: String,
    )
        -> AgentToolParameterProperty
    {
        AgentToolParameterProperty(
            name: name,
            type: .object,
            description: description,
        )
    }
}

// MARK: - Cross-Platform Math Evaluator

/// Simple cross-platform math expression evaluator
private func evaluateExpression(_ expression: String) throws -> Double {
    // Simple cross-platform math expression evaluator
    let cleanExpression = expression.trimmingCharacters(in: .whitespacesAndNewlines)

    // Parse simple binary operations using string manipulation
    let operators = [
        ("+", { (a: Double, b: Double) in a + b }),
        ("-", { (a: Double, b: Double) in a - b }),
        ("*", { (a: Double, b: Double) in a * b }),
        ("/", { (a: Double, b: Double) in a / b }),
    ]

    for (op, operation) in operators {
        // Split by operator
        let components = cleanExpression.split(separator: Character(op), maxSplits: 1)
        if components.count == 2 {
            let leftStr = components[0].trimmingCharacters(in: .whitespaces)
            let rightStr = components[1].trimmingCharacters(in: .whitespaces)

            // Check if both sides are valid numbers
            if let leftNum = Double(leftStr), let rightNum = Double(rightStr) {
                return operation(leftNum, rightNum)
            }
        }
    }

    // Handle single numbers
    if let number = Double(cleanExpression) {
        return number
    }

    // Handle basic functions
    if cleanExpression.hasPrefix("sqrt("), cleanExpression.hasSuffix(")") {
        let inner = String(cleanExpression.dropFirst(5).dropLast(1))
        if let number = Double(inner) {
            return sqrt(number)
        }
    }

    throw AgentToolError
        .executionFailed(
            "Unsupported mathematical expression: \(cleanExpression). Supported: basic arithmetic (+, -, *, /), sqrt()",
        )
}
