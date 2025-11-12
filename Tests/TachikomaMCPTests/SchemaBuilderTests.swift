import MCP
import Testing
@testable import TachikomaMCP

@Suite("Schema Builder Tests")
struct SchemaBuilderTests {
    @Test("Build string schema")
    func stringSchema() {
        let schema = SchemaBuilder.string(
            description: "User name",
            enum: ["Alice", "Bob"],
            default: "Alice",
            minLength: 2,
            maxLength: 20,
        )

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["type"] == .string("string"))
        #expect(dict["description"] == .string("User name"))
        #expect(dict["default"] == .string("Alice"))
        #expect(dict["minLength"] == .int(2))
        #expect(dict["maxLength"] == .int(20))

        if case let .array(enumValues) = dict["enum"] {
            #expect(enumValues == [.string("Alice"), .string("Bob")])
        } else {
            Issue.record("Expected enum array")
        }
    }

    @Test("Build boolean schema")
    func booleanSchema() {
        let schema = SchemaBuilder.boolean(
            description: "Is active",
            default: true,
        )

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["type"] == .string("boolean"))
        #expect(dict["description"] == .string("Is active"))
        #expect(dict["default"] == .bool(true))
    }

    @Test("Build number schema")
    func numberSchema() {
        let schema = SchemaBuilder.number(
            description: "Temperature",
            minimum: 0.0,
            maximum: 100.0,
            default: 25.0,
        )

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["type"] == .string("number"))
        #expect(dict["description"] == .string("Temperature"))
        #expect(dict["minimum"] == .double(0.0))
        #expect(dict["maximum"] == .double(100.0))
        #expect(dict["default"] == .double(25.0))
    }

    @Test("Build integer schema")
    func integerSchema() {
        let schema = SchemaBuilder.integer(
            description: "Count",
            minimum: 1,
            maximum: 100,
            default: 10,
        )

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["type"] == .string("integer"))
        #expect(dict["description"] == .string("Count"))
        #expect(dict["minimum"] == .int(1))
        #expect(dict["maximum"] == .int(100))
        #expect(dict["default"] == .int(10))
    }

    @Test("Build array schema")
    func arraySchema() {
        let itemSchema = SchemaBuilder.string()
        let schema = SchemaBuilder.array(
            items: itemSchema,
            description: "List of tags",
            minItems: 1,
            maxItems: 10,
            uniqueItems: true,
        )

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["type"] == .string("array"))
        #expect(dict["description"] == .string("List of tags"))
        #expect(dict["items"] == itemSchema)
        #expect(dict["minItems"] == .int(1))
        #expect(dict["maxItems"] == .int(10))
        #expect(dict["uniqueItems"] == .bool(true))
    }

    @Test("Build object schema")
    func objectSchema() {
        let schema = SchemaBuilder.object(
            properties: [
                "name": SchemaBuilder.string(description: "User name"),
                "age": SchemaBuilder.integer(minimum: 0),
            ],
            required: ["name"],
            description: "User object",
            additionalProperties: false,
        )

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["type"] == .string("object"))
        #expect(dict["description"] == .string("User object"))
        #expect(dict["additionalProperties"] == .bool(false))

        if case let .array(required) = dict["required"] {
            #expect(required == [.string("name")])
        } else {
            Issue.record("Expected required array")
        }

        if case let .object(props) = dict["properties"] {
            #expect(props.count == 2)
            #expect(props["name"] != nil)
            #expect(props["age"] != nil)
        } else {
            Issue.record("Expected properties object")
        }
    }

    @Test("Build nullable schema")
    func testNullableSchema() {
        let baseSchema = SchemaBuilder.string(description: "Optional value")
        let nullableSchema = SchemaBuilder.nullable(baseSchema)

        guard case let .object(dict) = nullableSchema else {
            Issue.record("Expected object schema")
            return
        }

        if case let .array(types) = dict["type"] {
            #expect(types == [.string("string"), .string("null")])
        } else {
            Issue.record("Expected type array")
        }
    }

    @Test("Build oneOf schema")
    func oneOfSchema() {
        let schemas = [
            SchemaBuilder.string(),
            SchemaBuilder.integer(),
        ]

        let schema = SchemaBuilder.oneOf(schemas, description: "String or integer")

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["description"] == .string("String or integer"))

        if case let .array(oneOf) = dict["oneOf"] {
            #expect(oneOf.count == 2)
        } else {
            Issue.record("Expected oneOf array")
        }
    }

    @Test("Build anyOf schema")
    func anyOfSchema() {
        let schemas = [
            SchemaBuilder.string(),
            SchemaBuilder.integer(),
        ]

        let schema = SchemaBuilder.anyOf(schemas, description: "String or integer")

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["description"] == .string("String or integer"))

        if case let .array(anyOf) = dict["anyOf"] {
            #expect(anyOf.count == 2)
        } else {
            Issue.record("Expected anyOf array")
        }
    }
}
