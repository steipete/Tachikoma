import Foundation
import TachikomaCore

// MARK: - @ToolKit Result Builder

/// Result builder for creating tool collections using closure-based definitions
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@resultBuilder
public struct ToolKitBuilder {
    public static func buildBlock<Context>(_ tools: Tool<Context>...) -> [Tool<Context>] {
        Array(tools)
    }

    public static func buildOptional<Context>(_ component: [Tool<Context>]?) -> [Tool<Context>] {
        component ?? []
    }

    public static func buildEither<Context>(first component: [Tool<Context>]) -> [Tool<Context>] {
        component
    }

    public static func buildEither<Context>(second component: [Tool<Context>]) -> [Tool<Context>] {
        component
    }

    public static func buildArray<Context>(_ components: [[Tool<Context>]]) -> [Tool<Context>] {
        components.flatMap(\.self)
    }
}

// MARK: - Tool Function Builders

/// Create a tool from a simple async function
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createTool<Context>(
    name: String,
    description: String,
    parameters: ParameterSchema = .object(properties: [:]),
    _ handler: @escaping @Sendable (ToolInput, Context) async throws -> String
)
-> Tool<Context> {
    Tool(
        name: name,
        description: description
    ) { input, context in
        let result = try await handler(input, context)
        return .string(result)
    }
}

/// Create a tool with structured output
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createTool<Context>(
    name: String,
    description: String,
    parameters: ParameterSchema = .object(properties: [:]),
    _ handler: @escaping @Sendable (ToolInput, Context) async throws -> ToolOutput
)
-> Tool<Context> {
    Tool(
        name: name,
        description: description,
        execute: handler
    )
}

/// Create a tool from a throwing function
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createTool<Context>(
    name: String,
    description: String,
    parameters: ParameterSchema = .object(properties: [:]),
    _ handler: @escaping @Sendable (ToolInput, Context) throws -> String
)
-> Tool<Context> {
    Tool(
        name: name,
        description: description
    ) { input, context in
        let result = try handler(input, context)
        return .string(result)
    }
}

/// Create a tool from a simple synchronous function
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createTool<Context>(
    name: String,
    description: String,
    parameters: ParameterSchema = .object(properties: [:]),
    _ handler: @escaping @Sendable (ToolInput, Context) -> String
)
-> Tool<Context> {
    Tool(
        name: name,
        description: description
    ) { input, context in
        let result = handler(input, context)
        return .string(result)
    }
}

// MARK: - Macro Implementation Placeholder

// MARK: - Macro Placeholder

// ToolKit macro would be implemented as a Swift macro in a real implementation
// For now, we provide a protocol-based approach only

// MARK: - Manual ToolKit Implementation

/// Base struct for manual ToolKit implementations
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct BaseToolKit: ToolKit {
    public var tools: [Tool<BaseToolKit>] {
        []
    }

    public init() {}
}

// MARK: - Example ToolKit Implementations

/// Example weather toolkit showing the pattern
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct WeatherToolKit: ToolKit {
    public var tools: [Tool<WeatherToolKit>] {
        [
            createTool(
                name: "get_weather",
                description: "Get current weather for a location"
            ) { input, context in
                let location = try input.stringValue("location")
                let units = input.stringValue("units", default: "celsius")
                return try await context.getWeather(location: location, units: units)
            },

            createTool(
                name: "get_forecast",
                description: "Get weather forecast for a location"
            ) { input, context in
                let location = try input.stringValue("location")
                let days = input.intValue("days", default: 3)
                return try await context.getForecast(location: location, days: days)
            },
        ]
    }

    public init() {}

    // Tool implementations
    func getWeather(location: String, units: String?) async throws -> String {
        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000)
        let temp = units == "fahrenheit" ? "72°F" : "22°C"
        return "The weather in \(location) is sunny with a temperature of \(temp)"
    }

    func getForecast(location: String, days: Int?) async throws -> String {
        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000)
        let dayCount = days ?? 3
        return "The \(dayCount)-day forecast for \(location): Sunny with temperatures ranging from 18-25°C"
    }
}

/// Example math toolkit
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct MathToolKit: ToolKit {
    public var tools: [Tool<MathToolKit>] {
        [
            createTool(
                name: "calculate",
                description: "Perform mathematical calculations"
            ) { input, context in
                let expression = try input.stringValue("expression")
                return try context.calculate(expression)
            },

            createTool(
                name: "convert_units",
                description: "Convert between different units"
            ) { input, context in
                let value = try input.doubleValue("value")
                let fromUnit = try input.stringValue("from_unit")
                let toUnit = try input.stringValue("to_unit")
                return try context.convertUnits(value: value, from: fromUnit, to: toUnit)
            },
        ]
    }

    public init() {}

    // Tool implementations
    func calculate(_ expression: String) throws -> String {
        // Simple expression evaluator using NSExpression
        let expr = NSExpression(format: expression)
        guard let result = expr.expressionValue(with: nil, context: nil) as? NSNumber else {
            throw ToolError.executionFailed("Invalid mathematical expression")
        }
        return "\(result.doubleValue)"
    }

    func convertUnits(value: Double, from fromUnit: String, to toUnit: String) throws -> String {
        // Simple unit conversion examples
        switch (fromUnit.lowercased(), toUnit.lowercased()) {
        case ("celsius", "fahrenheit"):
            let fahrenheit = (value * 9 / 5) + 32
            return "\(value)°C = \(fahrenheit)°F"
        case ("fahrenheit", "celsius"):
            let celsius = (value - 32) * 5 / 9
            return "\(value)°F = \(celsius)°C"
        case ("meters", "feet"):
            let feet = value * 3.280_84
            return "\(value)m = \(feet)ft"
        case ("feet", "meters"):
            let meters = value / 3.280_84
            return "\(value)ft = \(meters)m"
        default:
            throw ToolError.executionFailed("Unsupported unit conversion: \(fromUnit) to \(toUnit)")
        }
    }
}

// EmptyToolKit is available from TachikomaCore

// MARK: - Combined ToolKits

/// Combine multiple toolkits into one
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct CombinedToolKit: ToolKit {
    public let tools: [Tool<CombinedToolKit>]

    public init(_ toolkit1: some ToolKit, _ toolkit2: some ToolKit) {
        // In a real implementation, we'd need to properly convert tool contexts
        // For now, this is a simplified version
        self.tools = []
    }

    public init(_ toolkit1: some ToolKit, _ toolkit2: some ToolKit, _ toolkit3: some ToolKit) {
        // In a real implementation, we'd need to properly convert tool contexts
        // For now, this is a simplified version
        self.tools = []
    }
}

// MARK: - ToolKit Extensions

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension ToolKit {
    /// Get a tool by name
    public func tool(named name: String) -> Tool<Context>? {
        tools.first { $0.name == name }
    }

    /// Get all tool names
    public var toolNames: [String] {
        tools.map(\.name)
    }

    /// Check if toolkit has a specific tool
    public func hasTool(named name: String) -> Bool {
        tools.contains { $0.name == name }
    }
}

// MARK: - Tool Execution Helpers

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension ToolKit where Context == Self {
    /// Execute a tool by name with the given input
    public func execute(toolNamed name: String, input: ToolInput) async throws -> ToolOutput {
        guard let tool = tool(named: name) else {
            throw ToolError.toolNotFound(name)
        }
        return try await tool.execute(input, self)
    }

    /// Execute a tool with JSON string input
    public func execute(toolNamed name: String, jsonInput: String) async throws -> ToolOutput {
        let input = try ToolInput(jsonString: jsonInput)
        return try await self.execute(toolNamed: name, input: input)
    }
}
