import Foundation
import TachikomaAudio
import Testing
@testable import Tachikoma

struct AgentToolSchemaSerializationTests {
    @Test
    func `Realtime tools encode preserved source schema without internal storage fields`() throws {
        let sourceSchema = AnyAgentToolValue(object: [
            "type": AnyAgentToolValue(string: "object"),
            "properties": AnyAgentToolValue(object: [
                "task": AnyAgentToolValue(object: [
                    "type": AnyAgentToolValue(string: "string"),
                    "description": AnyAgentToolValue(string: "Task"),
                ]),
                "choice": AnyAgentToolValue(object: [
                    "oneOf": AnyAgentToolValue(array: [
                        AnyAgentToolValue(object: ["type": AnyAgentToolValue(string: "string")]),
                        AnyAgentToolValue(object: ["type": AnyAgentToolValue(string: "integer")]),
                    ]),
                ]),
            ]),
            "required": AnyAgentToolValue(array: [AnyAgentToolValue(string: "task")]),
            "oneOf": AnyAgentToolValue(array: [
                AnyAgentToolValue(object: [
                    "required": AnyAgentToolValue(array: [AnyAgentToolValue(string: "task")]),
                ]),
            ]),
        ])
        let parameters = AgentToolParameters(
            properties: [:],
            required: ["task"],
            sourceSchema: sourceSchema,
        )
        let tool = RealtimeTool(name: "run", description: "Run", parameters: parameters)
        let encoded = try JSONEncoder().encode(tool)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let schema = try #require(object["parameters"] as? [String: Any])

        #expect(schema["type"] as? String == "object")
        #expect((schema["oneOf"] as? [[String: Any]])?.count == 1)
        #expect(schema["sourceSchema"] == nil)

        let decoded = try JSONDecoder().decode(RealtimeTool.self, from: encoded)
        #expect(decoded.parameters.required == ["task"])
        #expect(decoded.parameters.properties["task"]?.type == .string)
        #expect(decoded.parameters.properties["task"]?.description == "Task")
        #expect(decoded.parameters.properties["choice"] == nil)
        #expect(decoded.parameters.sourceSchema?.objectValue?["properties"]?.objectValue?["choice"] != nil)
        let reencoded = try JSONEncoder().encode(decoded)
        let reencodedObject = try #require(JSONSerialization.jsonObject(with: reencoded) as? [String: Any])
        let reencodedSchema = try #require(reencodedObject["parameters"] as? [String: Any])
        #expect((reencodedSchema["oneOf"] as? [[String: Any]])?.count == 1)
        #expect(reencodedSchema["sourceSchema"] == nil)
    }

    @Test
    func `Original public initializer function references remain source compatible`() {
        let propertyInitializer: (
            String,
            AgentToolParameterProperty.ParameterType,
            String,
            [String]?,
            AgentToolParameterItems?,
        )
            -> AgentToolParameterProperty = AgentToolParameterProperty.init(
                name:type:description:enumValues:items:
            )
        let itemInitializer: (String, String?) -> AgentToolParameterItems = AgentToolParameterItems.init(
            type:description:
        )
        let dynamicItemInitializer: (
            DynamicSchema.SchemaType,
            String?,
        )
            -> DynamicSchema.SchemaItems = DynamicSchema.SchemaItems.init(type:description:)

        #expect(propertyInitializer("name", .string, "Name", nil, nil).name == "name")
        #expect(itemInitializer("string", "Item").description == "Item")
        #expect(dynamicItemInitializer(.integer, "Item").type == .integer)
    }

    @Test
    func `Dynamic schema conversion and Codable preserve every supported field`() throws {
        let sourceSchema = AnyAgentToolValue(object: [
            "type": AnyAgentToolValue(string: "object"),
            "properties": AnyAgentToolValue(object: [
                "config": AnyAgentToolValue(object: [
                    "type": AnyAgentToolValue(string: "object"),
                    "properties": AnyAgentToolValue(object: [:]),
                    "required": AnyAgentToolValue(array: []),
                ]),
                "settings": AnyAgentToolValue(object: [
                    "type": AnyAgentToolValue(string: "object"),
                ]),
            ]),
            "additionalProperties": AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(array: [
                    AnyAgentToolValue(string: "array"),
                    AnyAgentToolValue(string: "null"),
                ]),
            ]),
            "allOf": AnyAgentToolValue(array: [
                AnyAgentToolValue(object: [
                    "properties": AnyAgentToolValue(object: [
                        "a": AnyAgentToolValue(object: ["type": AnyAgentToolValue(string: "string")]),
                    ]),
                ]),
                AnyAgentToolValue(object: [
                    "properties": AnyAgentToolValue(object: [
                        "b": AnyAgentToolValue(object: ["type": AnyAgentToolValue(string: "string")]),
                    ]),
                    "required": AnyAgentToolValue(array: [
                        AnyAgentToolValue(string: "a"),
                        AnyAgentToolValue(string: "b"),
                    ]),
                ]),
            ]),
            "oneOf": AnyAgentToolValue(array: [
                AnyAgentToolValue(object: [
                    "properties": AnyAgentToolValue(object: [
                        "branchValue": AnyAgentToolValue(object: [
                            "type": AnyAgentToolValue(string: "array"),
                        ]),
                    ]),
                    "required": AnyAgentToolValue(array: [
                        AnyAgentToolValue(string: "settings"),
                        AnyAgentToolValue(string: "branchValue"),
                    ]),
                ]),
                AnyAgentToolValue(bool: true),
            ]),
        ])
        let dynamic = DynamicSchema(
            type: .object,
            properties: [
                "settings": DynamicSchema.SchemaProperty(
                    type: .object,
                    description: "Settings",
                    properties: [
                        "mode": DynamicSchema.SchemaProperty(
                            type: .string,
                            description: "Mode",
                            enumValues: ["safe", "fast"],
                            format: "mode-name",
                            minLength: 4,
                            maxLength: 4,
                        ),
                    ],
                    required: ["mode"],
                ),
                "steps": DynamicSchema.SchemaProperty(
                    type: .array,
                    description: "Steps",
                    items: DynamicSchema.SchemaItems(
                        type: .object,
                        description: "Step",
                        properties: [
                            "weight": DynamicSchema.SchemaProperty(
                                type: .number,
                                description: "Weight",
                                minimum: 0.25,
                                maximum: 1,
                            ),
                        ],
                        required: ["weight"],
                    ),
                ),
                "matrix": DynamicSchema.SchemaProperty(
                    type: .array,
                    description: "Rows",
                    items: DynamicSchema.SchemaItems(
                        type: .array,
                        description: "Row",
                        items: DynamicSchema.SchemaItems(
                            type: .integer,
                            description: "Cell",
                            minimum: 0,
                            maximum: 9,
                        ),
                    ),
                ),
            ],
            required: ["settings", "steps", "matrix"],
            items: nil,
            sourceSchema: sourceSchema,
        )

        let dynamicData = try JSONEncoder().encode(dynamic)
        let decodedDynamic = try JSONDecoder().decode(DynamicSchema.self, from: dynamicData)
        let parameters = decodedDynamic.toAgentToolParameters()
        let parametersData = try JSONEncoder().encode(parameters)
        let decodedParameters = try JSONDecoder().decode(AgentToolParameters.self, from: parametersData)

        #expect(decodedDynamic.sourceSchema == sourceSchema)
        #expect(decodedParameters.sourceSchema == sourceSchema)
        #expect(decodedParameters.required == ["settings", "steps", "matrix"])
        let settings = try #require(decodedParameters.properties["settings"])
        #expect(settings.required == ["mode"])
        let mode = try #require(settings.properties?["mode"])
        #expect(mode.enumValues == ["safe", "fast"])
        #expect(mode.format == "mode-name")
        #expect(mode.minLength == 4)
        #expect(mode.maxLength == 4)
        let stepItems = try #require(decodedParameters.properties["steps"]?.items)
        #expect(stepItems.type == "object")
        #expect(stepItems.description == "Step")
        #expect(stepItems.required == ["weight"])
        let weight = try #require(stepItems.properties?["weight"])
        #expect(weight.minimum == 0.25)
        #expect(weight.maximum == 1)
        let matrixItems = try #require(decodedParameters.properties["matrix"]?.items)
        #expect(matrixItems.type == "array")
        #expect(matrixItems.items?.type == "integer")
        #expect(matrixItems.items?.minimum == 0)
        #expect(matrixItems.items?.maximum == 9)

        let schema = try AgentToolParameters(
            properties: decodedParameters.properties,
            required: decodedParameters.required,
        ).jsonSchema()
        let properties = try #require(schema["properties"] as? [String: Any])
        let encodedSettings = try #require(properties["settings"] as? [String: Any])
        #expect(encodedSettings["required"] as? [String] == ["mode"])
        let encodedMode = try #require(
            (encodedSettings["properties"] as? [String: Any])?["mode"] as? [String: Any],
        )
        #expect(encodedMode["enum"] as? [String] == ["safe", "fast"])
        #expect(encodedMode["format"] as? String == "mode-name")
        let encodedSteps = try #require(properties["steps"] as? [String: Any])
        let encodedItems = try #require(encodedSteps["items"] as? [String: Any])
        #expect(encodedItems["required"] as? [String] == ["weight"])
        #expect((encodedItems["properties"] as? [String: Any])?["weight"] is [String: Any])
        let encodedMatrix = try #require(properties["matrix"] as? [String: Any])
        let encodedRow = try #require(encodedMatrix["items"] as? [String: Any])
        let encodedCell = try #require(encodedRow["items"] as? [String: Any])
        #expect(encodedCell["type"] as? String == "integer")
        #expect(encodedCell["minimum"] as? Double == 0)
        #expect(encodedCell["maximum"] as? Double == 9)

        let preservedSource = try toolParametersToJSON(decodedParameters)
        #expect(preservedSource["additionalProperties"] is [String: Any])
        #expect((preservedSource["oneOf"] as? [Any])?.count == 2)

        let providerCompatible = try decodedParameters.jsonSchema(options: [
            .defaultStringArrayItems,
            .omitEmptyRequired,
        ])
        let compatibleProperties = try #require(providerCompatible["properties"] as? [String: Any])
        let compatibleConfig = try #require(compatibleProperties["config"] as? [String: Any])
        #expect(compatibleConfig["required"] == nil)
        let compatibleAdditional = try #require(providerCompatible["additionalProperties"] as? [String: Any])
        #expect((compatibleAdditional["items"] as? [String: Any])?["type"] as? String == "string")
        let compatibleOneOf = try #require(providerCompatible["oneOf"] as? [Any])
        let compatibleBranch = try #require(compatibleOneOf.first as? [String: Any])
        let compatibleBranchProperties = try #require(compatibleBranch["properties"] as? [String: Any])
        let compatibleBranchValue = try #require(compatibleBranchProperties["branchValue"] as? [String: Any])
        #expect((compatibleBranchValue["items"] as? [String: Any])?["type"] as? String == "string")
        #expect(compatibleOneOf.last as? Bool == true)

        let filtered = try decodedParameters.jsonSchema(options: [
            .filterUndeclaredRequired,
            .omitEmptyRequired,
        ])
        let filteredOneOf = try #require(filtered["oneOf"] as? [Any])
        let filteredBranch = try #require(filteredOneOf.first as? [String: Any])
        #expect(filteredBranch["required"] as? [String] == ["settings", "branchValue"])
        let filteredAllOf = try #require(filtered["allOf"] as? [[String: Any]])
        #expect(filteredAllOf.last?["required"] as? [String] == ["a", "b"])
    }

    @Test
    func `Malformed schemas fail before provider serialization`() {
        let malformed: [AgentToolParameters] = [
            AgentToolParameters(
                properties: [
                    "value": .init(name: "value", type: .string, description: "Value"),
                ],
                required: ["value", "value"],
            ),
            AgentToolParameters(properties: [
                "values": .init(
                    name: "values",
                    type: .array,
                    description: "Values",
                    items: .init(type: "future-type"),
                ),
            ]),
            AgentToolParameters(properties: [
                "ratio": .init(
                    name: "ratio",
                    type: .number,
                    description: "Ratio",
                    minimum: .nan,
                ),
            ]),
            AgentToolParameters(properties: [
                "count": .init(
                    name: "count",
                    type: .integer,
                    description: "Count",
                    minimum: 5,
                    maximum: 2,
                ),
            ]),
            AgentToolParameters(properties: [
                "enabled": .init(
                    name: "enabled",
                    type: .boolean,
                    description: "Enabled",
                    minLength: 1,
                ),
            ]),
            AgentToolParameters(properties: [
                "value": .init(
                    name: "value",
                    type: .string,
                    description: "Value",
                    properties: [:],
                ),
            ]),
            AgentToolParameters(properties: [
                "mode": .init(
                    name: "mode",
                    type: .string,
                    description: "Mode",
                    enumValues: [],
                ),
            ]),
            AgentToolParameters(properties: [
                "mode": .init(
                    name: "mode",
                    type: .string,
                    description: "Mode",
                    enumValues: ["safe", "safe"],
                ),
            ]),
        ]

        for parameters in malformed {
            #expect(throws: TachikomaError.self) {
                _ = try parameters.jsonSchema()
            }
        }

        let nonObjectRoot = Data(#"{"type":"array","properties":{},"required":[]}"#.utf8)
        #expect(throws: TachikomaError.self) {
            let decoded = try JSONDecoder().decode(AgentToolParameters.self, from: nonObjectRoot)
            _ = try decoded.jsonSchema()
        }

        let dynamicRoot = DynamicSchema(type: .array).toAgentToolParameters()
        #expect(dynamicRoot.type == "array")
        #expect(throws: TachikomaError.self) {
            _ = try dynamicRoot.jsonSchema()
        }

        let mismatchedSource = AgentToolParameters(
            properties: [:],
            required: [],
            sourceSchema: AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "array"),
            ]),
        )
        #expect(throws: TachikomaError.self) {
            _ = try mismatchedSource.jsonSchema()
        }

        let mismatchedUnionSource = AgentToolParameters(
            properties: [:],
            required: [],
            sourceSchema: AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(array: [AnyAgentToolValue(string: "array")]),
            ]),
        )
        #expect(throws: TachikomaError.self) {
            _ = try mismatchedUnionSource.jsonSchema()
        }
    }

    @Test
    func `Default serialization preserves unconstrained required names while Google filtering remains explicit`(
    ) throws {
        let parameters = AgentToolParameters(
            properties: [
                "query": .init(name: "query", type: .string, description: "Query"),
            ],
            required: ["query", "unconstrained"],
        )

        let compatibilitySchema = try parameters.jsonSchema()
        #expect(compatibilitySchema["required"] as? [String] == ["query", "unconstrained"])

        let googleSchema = try parameters.jsonSchema(options: [.filterUndeclaredRequired])
        #expect(googleSchema["required"] as? [String] == ["query"])

        let composedSource = AnyAgentToolValue(object: [
            "type": AnyAgentToolValue(string: "object"),
            "properties": AnyAgentToolValue(object: [
                "query": AnyAgentToolValue(object: ["type": AnyAgentToolValue(string: "string")]),
            ]),
            "allOf": AnyAgentToolValue(array: [
                AnyAgentToolValue(object: [
                    "properties": AnyAgentToolValue(object: [
                        "limit": AnyAgentToolValue(object: ["type": AnyAgentToolValue(string: "integer")]),
                    ]),
                ]),
            ]),
        ])
        let composed = AgentToolParameters(
            properties: parameters.properties,
            required: ["query", "limit"],
            sourceSchema: composedSource,
        )
        let composedJSON = try composed.jsonSchema(options: [.filterUndeclaredRequired])
        #expect(composedJSON["required"] as? [String] == ["query", "limit"])
    }

    @Test
    func `Provider policies only adjust established required and array fallbacks`() throws {
        let parameters = AgentToolParameters(
            properties: [
                "values": .init(name: "values", type: .array, description: "Values"),
            ],
            required: ["missing"],
        )

        let googleSchema = try parameters.jsonSchema(options: [
            .filterUndeclaredRequired,
            .omitEmptyRequired,
        ])
        #expect(googleSchema["required"] == nil)
        let googleProperties = try #require(googleSchema["properties"] as? [String: Any])
        #expect((googleProperties["values"] as? [String: Any])?["items"] == nil)

        let openAISchema = try AgentToolParameters(
            properties: parameters.properties,
            required: [],
        ).jsonSchema(options: [.defaultStringArrayItems, .omitEmptyRequired])
        #expect(openAISchema["required"] == nil)
        let openAIProperties = try #require(openAISchema["properties"] as? [String: Any])
        let items = try #require((openAIProperties["values"] as? [String: Any])?["items"] as? [String: Any])
        #expect(items["type"] as? String == "string")
    }
}
