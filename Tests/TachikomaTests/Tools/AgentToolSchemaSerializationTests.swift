import Foundation
import Testing
@testable import Tachikoma

struct AgentToolSchemaSerializationTests {
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
        )

        let dynamicData = try JSONEncoder().encode(dynamic)
        let decodedDynamic = try JSONDecoder().decode(DynamicSchema.self, from: dynamicData)
        let parameters = decodedDynamic.toAgentToolParameters()
        let parametersData = try JSONEncoder().encode(parameters)
        let decodedParameters = try JSONDecoder().decode(AgentToolParameters.self, from: parametersData)

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

        let schema = try toolParametersToJSON(decodedParameters)
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
