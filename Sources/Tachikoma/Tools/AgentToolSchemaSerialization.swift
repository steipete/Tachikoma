import Foundation

struct AgentToolSchemaSerializationOptions: OptionSet, Sendable {
    let rawValue: Int

    static let omitEmptyRequired = Self(rawValue: 1 << 0)
    static let defaultStringArrayItems = Self(rawValue: 1 << 1)
    static let filterUndeclaredRequired = Self(rawValue: 1 << 2)
}

extension AgentToolParameters {
    func jsonSchema(
        options: AgentToolSchemaSerializationOptions = [],
    ) throws
        -> [String: Any]
    {
        guard self.type == "object" else {
            throw TachikomaError.invalidInput("Tool parameter schema root must be an object")
        }
        if let sourceSchema {
            guard var schema = try sourceSchema.toJSON() as? [String: Any] else {
                throw TachikomaError.invalidInput("Source tool parameter schema root must be an object")
            }
            let permitsObject = switch schema["type"] {
            case nil:
                true
            case let type as String:
                type == "object"
            case let types as [String]:
                types.contains("object")
            default:
                false
            }
            guard permitsObject else {
                throw TachikomaError.invalidInput("Source tool parameter schema root must be an object")
            }
            schema["type"] = "object"
            let declaredNames = Self.declaredPropertyNames(in: schema)
            let required = try Self.serializedRequired(
                self.required,
                declaredNames: declaredNames,
                options: options,
                path: "required",
            )
            if required.isEmpty, options.contains(.omitEmptyRequired) {
                schema.removeValue(forKey: "required")
            } else {
                schema["required"] = required
            }
            return Self.applying(options, to: schema)
        }
        var serializedProperties: [String: Any] = [:]
        for (name, property) in self.properties {
            serializedProperties[name] = try AgentToolSchemaNode(property).jsonSchema(
                options: options,
                path: "properties.\(name)",
            )
        }

        let required = try Self.serializedRequired(
            self.required,
            declaredNames: Set(self.properties.keys),
            options: options,
            path: "required",
        )
        var schema: [String: Any] = [
            "type": self.type,
            "properties": serializedProperties,
        ]
        if !required.isEmpty || !options.contains(.omitEmptyRequired) {
            schema["required"] = required
        }
        return schema
    }

    private static func applying(
        _ options: AgentToolSchemaSerializationOptions,
        to schema: [String: Any],
        inheritedPropertyNames: Set<String> = [],
    )
        -> [String: Any]
    {
        var schema = schema
        let visiblePropertyNames = inheritedPropertyNames.union(self.declaredPropertyNames(in: schema))
        if
            options.contains(.defaultStringArrayItems),
            self.isArraySchema(schema),
            schema["items"] == nil
        {
            schema["items"] = ["type": "string"]
        }
        if let required = schema["required"] as? [String] {
            let normalized: [String] = if
                options.contains(.filterUndeclaredRequired),
                !visiblePropertyNames.isEmpty
            {
                required.filter(visiblePropertyNames.contains)
            } else {
                required
            }
            if normalized.isEmpty, options.contains(.omitEmptyRequired) {
                schema.removeValue(forKey: "required")
            } else {
                schema["required"] = normalized
            }
        }

        for key in ["properties", "patternProperties", "$defs", "definitions"] {
            guard let children = schema[key] as? [String: Any] else { continue }
            schema[key] = children.mapValues { value in
                guard let child = value as? [String: Any] else { return value }
                return self.applying(options, to: child)
            }
        }
        if let children = schema["dependentSchemas"] as? [String: Any] {
            schema["dependentSchemas"] = children.mapValues { value in
                guard let child = value as? [String: Any] else { return value }
                return self.applying(options, to: child, inheritedPropertyNames: visiblePropertyNames)
            }
        }
        for key in [
            "additionalProperties",
            "unevaluatedProperties",
            "propertyNames",
            "items",
            "unevaluatedItems",
            "contains",
        ] {
            guard let child = schema[key] as? [String: Any] else { continue }
            schema[key] = self.applying(options, to: child)
        }
        for key in ["not", "if", "then", "else"] {
            guard let child = schema[key] as? [String: Any] else { continue }
            schema[key] = self.applying(
                options,
                to: child,
                inheritedPropertyNames: visiblePropertyNames,
            )
        }
        for key in ["allOf", "anyOf", "oneOf"] {
            guard let alternatives = schema[key] as? [Any] else { continue }
            schema[key] = alternatives.map { value in
                guard let child = value as? [String: Any] else { return value }
                return self.applying(
                    options,
                    to: child,
                    inheritedPropertyNames: visiblePropertyNames,
                )
            }
        }
        if let prefixItems = schema["prefixItems"] as? [Any] {
            schema["prefixItems"] = prefixItems.map { value in
                guard let child = value as? [String: Any] else { return value }
                return self.applying(options, to: child)
            }
        }
        return schema
    }

    private static func declaredPropertyNames(in schema: [String: Any]) -> Set<String> {
        var names = Set((schema["properties"] as? [String: Any]).map { Array($0.keys) } ?? [])
        for value in schema["allOf"] as? [Any] ?? [] {
            guard let child = value as? [String: Any] else { continue }
            names.formUnion(self.declaredPropertyNames(in: child))
        }
        return names
    }

    private static func isArraySchema(_ schema: [String: Any]) -> Bool {
        if schema["type"] as? String == "array" {
            return true
        }
        return (schema["type"] as? [String])?.contains("array") == true
    }

    private static func serializedRequired(
        _ required: [String],
        declaredNames: Set<String>,
        options: AgentToolSchemaSerializationOptions,
        path: String,
    ) throws
        -> [String]
    {
        guard Set(required).count == required.count else {
            throw TachikomaError.invalidInput("Duplicate property name in tool schema \(path)")
        }

        let undeclared = required.filter { !declaredNames.contains($0) }
        if !undeclared.isEmpty, options.contains(.filterUndeclaredRequired) {
            return required.filter(declaredNames.contains)
        }
        return required
    }

    fileprivate static func serializedRequired(
        _ required: [String]?,
        properties: [String: AgentToolParameterProperty]?,
        options: AgentToolSchemaSerializationOptions,
        path: String,
    ) throws
        -> [String]?
    {
        guard let required else { return nil }
        return try Self.serializedRequired(
            required,
            declaredNames: Set(properties?.keys.map(\.self) ?? []),
            options: options,
            path: path,
        )
    }
}

private struct AgentToolSchemaNode {
    let type: AgentToolParameterProperty.ParameterType
    let description: String?
    let enumValues: [String]?
    let items: AgentToolParameterItems?
    let properties: [String: AgentToolParameterProperty]?
    let required: [String]?
    let format: String?
    let minimum: Double?
    let maximum: Double?
    let minLength: Int?
    let maxLength: Int?

    init(_ property: AgentToolParameterProperty) {
        self.type = property.type
        self.description = property.description
        self.enumValues = property.enumValues
        self.items = property.items
        self.properties = property.properties
        self.required = property.required
        self.format = property.format
        self.minimum = property.minimum
        self.maximum = property.maximum
        self.minLength = property.minLength
        self.maxLength = property.maxLength
    }

    init(_ items: AgentToolParameterItems, path: String = "items") throws {
        guard let type = AgentToolParameterProperty.ParameterType(rawValue: items.type) else {
            throw TachikomaError.invalidInput("Unsupported tool schema type '\(items.type)' at \(path)")
        }
        self.type = type
        self.description = items.description
        self.enumValues = items.enumValues
        self.items = items.items
        self.properties = items.properties
        self.required = items.required
        self.format = items.format
        self.minimum = items.minimum
        self.maximum = items.maximum
        self.minLength = items.minLength
        self.maxLength = items.maxLength
    }

    func jsonSchema(
        options: AgentToolSchemaSerializationOptions,
        path: String,
    ) throws
        -> [String: Any]
    {
        try self.validate(path: path)

        var schema: [String: Any] = ["type": self.type.rawValue]
        if let description {
            schema["description"] = description
        }
        if let enumValues {
            schema["enum"] = enumValues
        }
        if let format {
            schema["format"] = format
        }
        if let minimum {
            schema["minimum"] = minimum
        }
        if let maximum {
            schema["maximum"] = maximum
        }
        if let minLength {
            schema["minLength"] = minLength
        }
        if let maxLength {
            schema["maxLength"] = maxLength
        }

        if self.type == .array {
            if let items {
                schema["items"] = try AgentToolSchemaNode(items, path: "\(path).items").jsonSchema(
                    options: options,
                    path: "\(path).items",
                )
            } else if options.contains(.defaultStringArrayItems) {
                schema["items"] = ["type": "string"]
            }
        }

        if self.type == .object {
            var nestedProperties: [String: Any] = [:]
            for (name, property) in self.properties ?? [:] {
                nestedProperties[name] = try Self(property).jsonSchema(
                    options: options,
                    path: "\(path).properties.\(name)",
                )
            }
            if self.properties != nil {
                schema["properties"] = nestedProperties
            }
            if
                let required = try AgentToolParameters.serializedRequired(
                    self.required,
                    properties: self.properties,
                    options: options,
                    path: "\(path).required",
                ),
                !required.isEmpty || !options.contains(.omitEmptyRequired)
            {
                schema["required"] = required
            }
        }
        return schema
    }

    private func validate(path: String) throws {
        if self.items != nil, self.type != .array {
            throw TachikomaError.invalidInput("Tool schema \(path) has items but is not an array")
        }
        if self.properties != nil || self.required != nil, self.type != .object {
            throw TachikomaError.invalidInput("Tool schema \(path) has object fields but is not an object")
        }
        if self.enumValues != nil, self.type != .string {
            throw TachikomaError.invalidInput("Tool schema \(path) has string enum values but is not a string")
        }
        if let enumValues, enumValues.isEmpty {
            throw TachikomaError.invalidInput("Tool schema \(path) has an empty enum")
        }
        if let enumValues, Set(enumValues).count != enumValues.count {
            throw TachikomaError.invalidInput("Tool schema \(path) has duplicate enum values")
        }
        if let format, format.isEmpty {
            throw TachikomaError.invalidInput("Tool schema \(path) has an empty format")
        }
        if
            self.minimum != nil || self.maximum != nil,
            self.type != .number,
            self.type != .integer
        {
            throw TachikomaError.invalidInput("Tool schema \(path) has numeric constraints but is not numeric")
        }
        if let minimum, !minimum.isFinite {
            throw TachikomaError.invalidInput("Tool schema \(path) has a non-finite minimum")
        }
        if let maximum, !maximum.isFinite {
            throw TachikomaError.invalidInput("Tool schema \(path) has a non-finite maximum")
        }
        if let minimum, let maximum, minimum > maximum {
            throw TachikomaError.invalidInput("Tool schema \(path) has minimum greater than maximum")
        }
        if
            self.minLength != nil || self.maxLength != nil,
            self.type != .string
        {
            throw TachikomaError.invalidInput("Tool schema \(path) has length constraints but is not a string")
        }
        if let minLength, minLength < 0 {
            throw TachikomaError.invalidInput("Tool schema \(path) has a negative minLength")
        }
        if let maxLength, maxLength < 0 {
            throw TachikomaError.invalidInput("Tool schema \(path) has a negative maxLength")
        }
        if let minLength, let maxLength, minLength > maxLength {
            throw TachikomaError.invalidInput("Tool schema \(path) has minLength greater than maxLength")
        }
    }
}
