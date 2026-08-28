import Foundation

/// A typed recursive view of a tool's JSON Schema.
///
/// `AgentToolParameters.sourceSchema` retains the exact adapter-owned schema. This typed view uses
/// JSON-semantic numeric canonicalization so natural `Codable` round trips remain stable, while
/// exposing the constraints Agent runtimes need without flattening conditional request shapes.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct AgentToolJSONSchema: Sendable, Equatable, Codable {
    public enum NumericValue: Sendable, Equatable {
        case integer(Int)
        case number(Double)

        public var rawValue: AnyAgentToolValue {
            switch self {
            case let .integer(value):
                AnyAgentToolValue(int: value)
            case let .number(value):
                AnyAgentToolValue(double: value)
            }
        }
    }

    public indirect enum Items: Sendable, Equatable {
        case schema(AgentToolJSONSchema)
        case tuple([AgentToolJSONSchema])
    }

    public indirect enum LegacyDependency: Sendable, Equatable {
        case requiredProperties([String])
        case schema(AgentToolJSONSchema)
    }

    public indirect enum Form: Sendable, Equatable {
        case boolean(Bool)
        case keywords(Keywords)
    }

    public struct Keywords: Sendable, Equatable {
        public let identifier: String?
        public let reference: String?
        public let anchor: String?
        public let types: [AgentValueType]?
        public let title: String?
        public let description: String?
        public let format: String?
        public let defaultValue: AnyAgentToolValue?
        public let constantValue: AnyAgentToolValue?
        public let enumValues: [AnyAgentToolValue]?
        public let examples: [AnyAgentToolValue]?

        public let properties: [String: AgentToolJSONSchema]?
        public let patternProperties: [String: AgentToolJSONSchema]?
        public let required: [String]?
        public let additionalProperties: AgentToolJSONSchema?
        public let unevaluatedProperties: AgentToolJSONSchema?
        public let propertyNames: AgentToolJSONSchema?
        public let dependentSchemas: [String: AgentToolJSONSchema]?
        public let dependentRequired: [String: [String]]?
        public let legacyDependencies: [String: LegacyDependency]?
        public let definitions: [String: AgentToolJSONSchema]?
        public let legacyDefinitions: [String: AgentToolJSONSchema]?

        public let items: Items?
        public let additionalItems: AgentToolJSONSchema?
        public let prefixItems: [AgentToolJSONSchema]?
        public let contains: AgentToolJSONSchema?
        public let unevaluatedItems: AgentToolJSONSchema?

        public let allOf: [AgentToolJSONSchema]?
        public let anyOf: [AgentToolJSONSchema]?
        public let oneOf: [AgentToolJSONSchema]?
        public let negated: AgentToolJSONSchema?
        public let condition: AgentToolJSONSchema?
        public let thenSchema: AgentToolJSONSchema?
        public let elseSchema: AgentToolJSONSchema?

        public let minimum: NumericValue?
        public let maximum: NumericValue?
        public let exclusiveMinimum: NumericValue?
        public let exclusiveMaximum: NumericValue?
        public let multipleOf: NumericValue?
        public let minLength: Int?
        public let maxLength: Int?
        public let pattern: String?
        public let minItems: Int?
        public let maxItems: Int?
        public let uniqueItems: Bool?
        public let minContains: Int?
        public let maxContains: Int?
        public let minProperties: Int?
        public let maxProperties: Int?
        public let readOnly: Bool?
        public let writeOnly: Bool?
        public let deprecated: Bool?

        /// Keywords outside the typed surface remain available here and in `rawValue`.
        public let unrecognizedKeywords: [String: AnyAgentToolValue]

        fileprivate init(_ object: [String: AnyAgentToolValue], path: String) throws {
            self.identifier = try AgentToolJSONSchema.string(object["$id"], path: "\(path).$id")
            self.reference = try AgentToolJSONSchema.string(object["$ref"], path: "\(path).$ref")
            self.anchor = try AgentToolJSONSchema.string(object["$anchor"], path: "\(path).$anchor")
            self.types = try AgentToolJSONSchema.types(object["type"], path: "\(path).type")
            self.title = try AgentToolJSONSchema.string(object["title"], path: "\(path).title")
            self.description = try AgentToolJSONSchema.string(object["description"], path: "\(path).description")
            self.format = try AgentToolJSONSchema.string(object["format"], path: "\(path).format")
            self.defaultValue = object["default"]
            self.constantValue = object["const"]
            self.enumValues = try AgentToolJSONSchema.values(object["enum"], path: "\(path).enum")
            self.examples = try AgentToolJSONSchema.values(object["examples"], path: "\(path).examples")

            self.properties = try AgentToolJSONSchema.schemaMap(
                object["properties"],
                path: "\(path).properties",
            )
            self.patternProperties = try AgentToolJSONSchema.schemaMap(
                object["patternProperties"],
                path: "\(path).patternProperties",
            )
            self.required = try AgentToolJSONSchema.strings(object["required"], path: "\(path).required")
            self.additionalProperties = try AgentToolJSONSchema.schema(
                object["additionalProperties"],
                path: "\(path).additionalProperties",
            )
            self.unevaluatedProperties = try AgentToolJSONSchema.schema(
                object["unevaluatedProperties"],
                path: "\(path).unevaluatedProperties",
            )
            self.propertyNames = try AgentToolJSONSchema.schema(
                object["propertyNames"],
                path: "\(path).propertyNames",
            )
            self.dependentSchemas = try AgentToolJSONSchema.schemaMap(
                object["dependentSchemas"],
                path: "\(path).dependentSchemas",
            )
            self.dependentRequired = try AgentToolJSONSchema.stringArrayMap(
                object["dependentRequired"],
                path: "\(path).dependentRequired",
            )
            self.legacyDependencies = try AgentToolJSONSchema.legacyDependencies(
                object["dependencies"],
                path: "\(path).dependencies",
            )
            self.definitions = try AgentToolJSONSchema.schemaMap(object["$defs"], path: "\(path).$defs")
            self.legacyDefinitions = try AgentToolJSONSchema.schemaMap(
                object["definitions"],
                path: "\(path).definitions",
            )

            self.items = try AgentToolJSONSchema.items(object["items"], path: "\(path).items")
            self.additionalItems = try AgentToolJSONSchema.schema(
                object["additionalItems"],
                path: "\(path).additionalItems",
            )
            self.prefixItems = try AgentToolJSONSchema.schemas(
                object["prefixItems"],
                path: "\(path).prefixItems",
            )
            self.contains = try AgentToolJSONSchema.schema(object["contains"], path: "\(path).contains")
            self.unevaluatedItems = try AgentToolJSONSchema.schema(
                object["unevaluatedItems"],
                path: "\(path).unevaluatedItems",
            )

            self.allOf = try AgentToolJSONSchema.schemas(object["allOf"], path: "\(path).allOf")
            self.anyOf = try AgentToolJSONSchema.schemas(object["anyOf"], path: "\(path).anyOf")
            self.oneOf = try AgentToolJSONSchema.schemas(object["oneOf"], path: "\(path).oneOf")
            self.negated = try AgentToolJSONSchema.schema(object["not"], path: "\(path).not")
            self.condition = try AgentToolJSONSchema.schema(object["if"], path: "\(path).if")
            self.thenSchema = try AgentToolJSONSchema.schema(object["then"], path: "\(path).then")
            self.elseSchema = try AgentToolJSONSchema.schema(object["else"], path: "\(path).else")

            self.minimum = try AgentToolJSONSchema.number(object["minimum"], path: "\(path).minimum")
            self.maximum = try AgentToolJSONSchema.number(object["maximum"], path: "\(path).maximum")
            self.exclusiveMinimum = try AgentToolJSONSchema.number(
                object["exclusiveMinimum"],
                path: "\(path).exclusiveMinimum",
            )
            self.exclusiveMaximum = try AgentToolJSONSchema.number(
                object["exclusiveMaximum"],
                path: "\(path).exclusiveMaximum",
            )
            self.multipleOf = try AgentToolJSONSchema.number(object["multipleOf"], path: "\(path).multipleOf")
            self.minLength = try AgentToolJSONSchema.integer(object["minLength"], path: "\(path).minLength")
            self.maxLength = try AgentToolJSONSchema.integer(object["maxLength"], path: "\(path).maxLength")
            self.pattern = try AgentToolJSONSchema.string(object["pattern"], path: "\(path).pattern")
            self.minItems = try AgentToolJSONSchema.integer(object["minItems"], path: "\(path).minItems")
            self.maxItems = try AgentToolJSONSchema.integer(object["maxItems"], path: "\(path).maxItems")
            self.uniqueItems = try AgentToolJSONSchema.boolean(object["uniqueItems"], path: "\(path).uniqueItems")
            self.minContains = try AgentToolJSONSchema.integer(object["minContains"], path: "\(path).minContains")
            self.maxContains = try AgentToolJSONSchema.integer(object["maxContains"], path: "\(path).maxContains")
            self.minProperties = try AgentToolJSONSchema.integer(
                object["minProperties"],
                path: "\(path).minProperties",
            )
            self.maxProperties = try AgentToolJSONSchema.integer(
                object["maxProperties"],
                path: "\(path).maxProperties",
            )
            self.readOnly = try AgentToolJSONSchema.boolean(object["readOnly"], path: "\(path).readOnly")
            self.writeOnly = try AgentToolJSONSchema.boolean(object["writeOnly"], path: "\(path).writeOnly")
            self.deprecated = try AgentToolJSONSchema.boolean(object["deprecated"], path: "\(path).deprecated")

            self.unrecognizedKeywords = object.filter { !AgentToolJSONSchema.knownKeywords.contains($0.key) }
        }
    }

    public let rawValue: AnyAgentToolValue
    public let form: Form

    public var booleanValue: Bool? {
        guard case let .boolean(value) = self.form else { return nil }
        return value
    }

    public var keywords: Keywords? {
        guard case let .keywords(value) = self.form else { return nil }
        return value
    }

    public init(_ value: AnyAgentToolValue) throws {
        try self.init(value, path: "$")
    }

    private init(_ value: AnyAgentToolValue, path: String) throws {
        let canonicalValue = Self.canonicalValue(value)
        self.rawValue = canonicalValue
        if let boolean = canonicalValue.boolValue {
            self.form = .boolean(boolean)
            return
        }
        guard let object = canonicalValue.objectValue else {
            throw TachikomaError.invalidInput("JSON Schema at \(path) must be an object or boolean")
        }
        self.form = try .keywords(Keywords(object, path: path))
    }

    public init(from decoder: any Decoder) throws {
        try self.init(AnyAgentToolValue(from: decoder))
    }

    public func encode(to encoder: any Encoder) throws {
        try self.rawValue.encode(to: encoder)
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension AgentToolParameters {
    /// Returns the Agent-facing schema after root normalization as a typed recursive tree.
    public func typedSchema() throws -> AgentToolJSONSchema {
        try AgentToolJSONSchema(self.schemaValue())
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension AgentToolJSONSchema {
    private static let knownKeywords: Set<String> = [
        "$id", "$ref", "$anchor", "$defs", "definitions",
        "type", "title", "description", "format", "default", "const", "enum", "examples",
        "properties", "patternProperties", "required", "additionalProperties", "unevaluatedProperties",
        "propertyNames", "dependentSchemas", "dependentRequired", "dependencies", "items", "additionalItems",
        "prefixItems", "contains", "unevaluatedItems", "allOf", "anyOf", "oneOf", "not", "if", "then", "else",
        "minimum",
        "maximum", "exclusiveMinimum", "exclusiveMaximum", "multipleOf", "minLength", "maxLength",
        "pattern", "minItems", "maxItems", "uniqueItems", "minContains", "maxContains", "minProperties",
        "maxProperties", "readOnly", "writeOnly", "deprecated",
    ]

    private static func schema(_ value: AnyAgentToolValue?, path: String) throws -> AgentToolJSONSchema? {
        guard let value else { return nil }
        return try AgentToolJSONSchema(value, path: path)
    }

    private static func items(_ value: AnyAgentToolValue?, path: String) throws -> Items? {
        guard let value else { return nil }
        if value.arrayValue != nil {
            return try .tuple(self.requiredSchemas(value, path: path))
        }
        guard let schema = try self.schema(value, path: path) else {
            preconditionFailure("A present items value cannot produce an absent schema")
        }
        return .schema(schema)
    }

    private static func schemas(_ value: AnyAgentToolValue?, path: String) throws -> [AgentToolJSONSchema]? {
        guard let value else { return nil }
        return try self.requiredSchemas(value, path: path)
    }

    private static func requiredSchemas(_ value: AnyAgentToolValue, path: String) throws -> [AgentToolJSONSchema] {
        guard let values = value.arrayValue else {
            throw TachikomaError.invalidInput("JSON Schema at \(path) must be an array")
        }
        return try values.enumerated().map { index, value in
            guard let schema = try self.schema(value, path: "\(path)[\(index)]") else {
                preconditionFailure("An enumerated schema value cannot be absent")
            }
            return schema
        }
    }

    private static func schemaMap(
        _ value: AnyAgentToolValue?,
        path: String,
    ) throws
        -> [String: AgentToolJSONSchema]?
    {
        guard let value else { return nil }
        guard let object = value.objectValue else {
            throw TachikomaError.invalidInput("JSON Schema at \(path) must be an object")
        }
        var schemas: [String: AgentToolJSONSchema] = [:]
        for (name, value) in object {
            guard let schema = try self.schema(value, path: "\(path).\(name)") else {
                preconditionFailure("A schema-map value cannot be absent")
            }
            schemas[name] = schema
        }
        return schemas
    }

    private static func stringArrayMap(
        _ value: AnyAgentToolValue?,
        path: String,
    ) throws
        -> [String: [String]]?
    {
        guard let value else { return nil }
        guard let object = value.objectValue else {
            throw TachikomaError.invalidInput("JSON Schema at \(path) must be an object")
        }
        var values: [String: [String]] = [:]
        for (name, value) in object {
            values[name] = try self.requiredStrings(value, path: "\(path).\(name)")
        }
        return values
    }

    private static func legacyDependencies(
        _ value: AnyAgentToolValue?,
        path: String,
    ) throws
        -> [String: LegacyDependency]?
    {
        guard let value else { return nil }
        guard let object = value.objectValue else {
            throw TachikomaError.invalidInput("JSON Schema at \(path) must be an object")
        }
        var dependencies: [String: LegacyDependency] = [:]
        for (name, value) in object {
            let dependencyPath = "\(path).\(name)"
            if value.arrayValue != nil {
                dependencies[name] = try .requiredProperties(self.requiredStrings(value, path: dependencyPath))
            } else {
                guard let schema = try self.schema(value, path: dependencyPath) else {
                    preconditionFailure("A dependency schema value cannot be absent")
                }
                dependencies[name] = .schema(schema)
            }
        }
        return dependencies
    }

    private static func types(_ value: AnyAgentToolValue?, path: String) throws -> [AgentValueType]? {
        guard let value else { return nil }
        let rawTypes: [String] = if let type = value.stringValue {
            [type]
        } else {
            try self.requiredStrings(value, path: path)
        }
        guard !rawTypes.isEmpty else {
            throw TachikomaError.invalidInput("JSON Schema at \(path) must contain at least one type")
        }
        guard Set(rawTypes).count == rawTypes.count else {
            throw TachikomaError.invalidInput("JSON Schema at \(path) contains duplicate types")
        }
        return try rawTypes.map { rawValue in
            guard let type = AgentValueType(rawValue: rawValue) else {
                throw TachikomaError.invalidInput("Unsupported JSON Schema type '\(rawValue)' at \(path)")
            }
            return type
        }
    }

    private static func string(_ value: AnyAgentToolValue?, path: String) throws -> String? {
        guard let value else { return nil }
        guard let string = value.stringValue else {
            throw TachikomaError.invalidInput("JSON Schema at \(path) must be a string")
        }
        return string
    }

    private static func strings(_ value: AnyAgentToolValue?, path: String) throws -> [String]? {
        guard let value else { return nil }
        return try self.requiredStrings(value, path: path)
    }

    private static func requiredStrings(_ value: AnyAgentToolValue, path: String) throws -> [String] {
        guard let values = value.arrayValue else {
            throw TachikomaError.invalidInput("JSON Schema at \(path) must be an array of strings")
        }
        return try values.enumerated().map { index, value in
            guard let string = value.stringValue else {
                throw TachikomaError.invalidInput("JSON Schema at \(path)[\(index)] must be a string")
            }
            return string
        }
    }

    private static func values(_ value: AnyAgentToolValue?, path: String) throws -> [AnyAgentToolValue]? {
        guard let value else { return nil }
        guard let values = value.arrayValue else {
            throw TachikomaError.invalidInput("JSON Schema at \(path) must be an array")
        }
        return values
    }

    private static func number(_ value: AnyAgentToolValue?, path: String) throws -> NumericValue? {
        guard let value else { return nil }
        if let integer = value.intValue {
            return .integer(integer)
        }
        if let number = value.doubleValue, number.isFinite {
            return .number(number)
        }
        throw TachikomaError.invalidInput("JSON Schema at \(path) must be a finite number")
    }

    private static func integer(_ value: AnyAgentToolValue?, path: String) throws -> Int? {
        guard let value else { return nil }
        guard let integer = value.intValue else {
            throw TachikomaError.invalidInput("JSON Schema at \(path) must be an integer")
        }
        return integer
    }

    private static func boolean(_ value: AnyAgentToolValue?, path: String) throws -> Bool? {
        guard let value else { return nil }
        guard let boolean = value.boolValue else {
            throw TachikomaError.invalidInput("JSON Schema at \(path) must be a boolean")
        }
        return boolean
    }

    private static func canonicalValue(_ value: AnyAgentToolValue) -> AnyAgentToolValue {
        if value.isNull {
            return AnyAgentToolValue(null: ())
        }
        if let boolean = value.boolValue {
            return AnyAgentToolValue(bool: boolean)
        }
        if let integer = value.intValue {
            return AnyAgentToolValue(int: integer)
        }
        if let number = value.doubleValue {
            if let integer = Int(exactly: number) {
                return AnyAgentToolValue(int: integer)
            }
            return AnyAgentToolValue(double: number)
        }
        if let string = value.stringValue {
            return AnyAgentToolValue(string: string)
        }
        if let values = value.arrayValue {
            return AnyAgentToolValue(array: values.map(self.canonicalValue))
        }
        if let object = value.objectValue {
            return AnyAgentToolValue(object: object.mapValues(self.canonicalValue))
        }
        preconditionFailure("AnyAgentToolValue contains an unsupported storage case")
    }
}
