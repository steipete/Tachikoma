import MCP
import Tachikoma

enum MCPToolSchemaBridge {
    static func dynamicSchema(from value: Value?) -> DynamicSchema {
        guard case let .object(schema)? = value else {
            return DynamicSchema(type: .object, properties: [:])
        }

        let properties: [String: DynamicSchema.SchemaProperty] = if
            case let .object(rawProperties)? =
            schema["properties"]
        {
            rawProperties.mapValues(Self.schemaProperty)
        } else {
            [:]
        }
        let type: DynamicSchema.SchemaType = if schema["type"] == nil {
            .object
        } else {
            Self.schemaType(schema["type"])
        }

        return DynamicSchema(
            type: type,
            properties: properties,
            required: Self.stringArray(schema["required"]),
        )
    }

    private static func schemaProperty(from value: Value) -> DynamicSchema.SchemaProperty {
        guard case let .object(schema) = value else {
            return DynamicSchema.SchemaProperty(type: .string, description: "String parameter")
        }

        let type = Self.schemaType(schema["type"])
        return DynamicSchema.SchemaProperty(
            type: type,
            description: Self.string(schema["description"]) ?? "Parameter",
            enumValues: Self.optionalStringArray(schema["enum"]),
            items: type == .array ? Self.schemaItems(from: schema["items"]) : nil,
            properties: Self.nestedProperties(schema["properties"]),
            required: Self.optionalStringArray(schema["required"]),
            format: Self.string(schema["format"]),
            minimum: Self.double(schema["minimum"]),
            maximum: Self.double(schema["maximum"]),
            minLength: Self.int(schema["minLength"]),
            maxLength: Self.int(schema["maxLength"]),
        )
    }

    private static func schemaItems(from value: Value?) -> DynamicSchema.SchemaItems {
        guard case let .object(schema)? = value else {
            return DynamicSchema.SchemaItems(type: .string)
        }
        let type = Self.schemaType(schema["type"])
        return DynamicSchema.SchemaItems(
            type: type,
            description: Self.string(schema["description"]),
            enumValues: Self.optionalStringArray(schema["enum"]),
            items: type == .array ? Self.optionalSchemaItems(from: schema["items"]) : nil,
            properties: Self.nestedProperties(schema["properties"]),
            required: Self.optionalStringArray(schema["required"]),
            format: Self.string(schema["format"]),
            minimum: Self.double(schema["minimum"]),
            maximum: Self.double(schema["maximum"]),
            minLength: Self.int(schema["minLength"]),
            maxLength: Self.int(schema["maxLength"]),
        )
    }

    private static func optionalSchemaItems(from value: Value?) -> DynamicSchema.SchemaItems? {
        guard case .object? = value else { return nil }
        return self.schemaItems(from: value)
    }

    private static func nestedProperties(_ value: Value?) -> [String: DynamicSchema.SchemaProperty]? {
        guard case let .object(properties)? = value else { return nil }
        return properties.mapValues(Self.schemaProperty)
    }

    private static func schemaType(_ value: Value?) -> DynamicSchema.SchemaType {
        guard
            let rawValue = string(value),
            let type = DynamicSchema.SchemaType(rawValue: rawValue) else
        {
            return .string
        }
        return type
    }

    private static func string(_ value: Value?) -> String? {
        guard case let .string(value)? = value else { return nil }
        return value
    }

    private static func stringArray(_ value: Value?) -> [String] {
        self.optionalStringArray(value) ?? []
    }

    private static func optionalStringArray(_ value: Value?) -> [String]? {
        guard case let .array(values)? = value else { return nil }
        return values.compactMap(Self.string)
    }

    private static func int(_ value: Value?) -> Int? {
        guard case let .int(value)? = value else { return nil }
        return value
    }

    private static func double(_ value: Value?) -> Double? {
        switch value {
        case let .int(value):
            Double(value)
        case let .double(value):
            value
        default:
            nil
        }
    }
}
