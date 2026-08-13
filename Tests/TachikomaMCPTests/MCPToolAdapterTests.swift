import Foundation
import MCP
import Tachikoma
import Testing
@testable import TachikomaMCP

struct MCPToolAdapterTests {
    @Test
    func `Static and dynamic MCP tools share one schema conversion`() throws {
        let inputSchema = Value.object([
            "type": .string("object"),
            "properties": .object([
                "mode": .object([
                    "type": .string("string"),
                    "description": .string("Execution mode"),
                    "enum": .array([.string("safe"), .string("fast")]),
                ]),
                "tags": .object([
                    "type": .string("array"),
                    "description": .string("Numeric tag identifiers"),
                    "items": .object([
                        "type": .string("integer"),
                        "description": .string("Tag identifier"),
                    ]),
                ]),
                "settings": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "retries": .object([
                            "type": .string("integer"),
                            "minimum": .int(0),
                            "maximum": .int(3),
                        ]),
                    ]),
                    "required": .array([.string("retries")]),
                ]),
                "matrix": .object([
                    "type": .string("array"),
                    "items": .object([
                        "type": .string("array"),
                        "items": .object([
                            "type": .string("number"),
                            "minimum": .double(0.25),
                            "maximum": .int(1),
                        ]),
                    ]),
                ]),
                "openMatrix": .object([
                    "type": .string("array"),
                    "items": .object([
                        "type": .string("array"),
                    ]),
                ]),
            ]),
            "required": .array([
                .string("mode"),
                .int(42),
                .string("tags"),
                .string("settings"),
                .string("matrix"),
            ]),
        ])
        let mcpTool = MCP.Tool(name: "run", description: "Run work", inputSchema: inputSchema)
        let client = MCPClient(name: "test", config: MCPServerConfig(command: "unused"))

        let staticTool = MCPToolAdapter.toAgentTool(from: mcpTool, client: client)
        let dynamicTool = try #require(MCPToolProvider.makeDynamicTools(from: [mcpTool]).first)
        let dynamicParameters = dynamicTool.schema.toAgentToolParameters()

        #expect(staticTool.parameters.required == ["mode", "tags", "settings", "matrix"])
        #expect(dynamicParameters.required == staticTool.parameters.required)
        #expect(dynamicParameters.properties["mode"]?.type == staticTool.parameters.properties["mode"]?.type)
        #expect(dynamicParameters.properties["mode"]?.description == "Execution mode")
        #expect(dynamicParameters.properties["mode"]?.enumValues == ["safe", "fast"])
        #expect(dynamicParameters.properties["tags"]?.type == .array)
        #expect(dynamicParameters.properties["tags"]?.description == "Numeric tag identifiers")
        #expect(dynamicParameters.properties["tags"]?.items?.type == "integer")
        #expect(dynamicParameters.properties["tags"]?.items?.description == "Tag identifier")
        #expect(dynamicParameters.properties["tags"]?.type == staticTool.parameters.properties["tags"]?.type)
        #expect(
            dynamicParameters.properties["tags"]?.items?.type == staticTool.parameters.properties["tags"]?.items?.type,
        )
        let settings = try #require(dynamicParameters.properties["settings"])
        #expect(settings.required == ["retries"])
        #expect(settings.properties?["retries"]?.minimum == 0)
        #expect(settings.properties?["retries"]?.maximum == 3)
        #expect(settings.properties?["retries"]?.minimum == staticTool.parameters.properties["settings"]?
            .properties?["retries"]?.minimum)
        let matrixItems = try #require(dynamicParameters.properties["matrix"]?.items)
        #expect(matrixItems.type == "array")
        #expect(matrixItems.items?.type == "number")
        #expect(matrixItems.items?.minimum == 0.25)
        #expect(matrixItems.items?.maximum == 1)
        #expect(matrixItems.items?.minimum == staticTool.parameters.properties["matrix"]?.items?.items?.minimum)
        let openMatrixItems = try #require(dynamicParameters.properties["openMatrix"]?.items)
        #expect(openMatrixItems.type == "array")
        #expect(openMatrixItems.items == nil)
        #expect(staticTool.parameters.properties["openMatrix"]?.items?.items == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func `Real stdio discovery preserves nested schema for static and dynamic tools`() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tachikoma-schema-\(UUID().uuidString)", isDirectory: true)
        let script = directory.appendingPathComponent("server.sh")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(Self.schemaServerScript.utf8).write(to: script)

        let client = MCPClient(
            name: "schema-stdio",
            config: MCPServerConfig(
                command: "/bin/sh",
                args: [script.path],
                timeout: 5,
                autoReconnect: false,
            ),
        )

        do {
            try await client.connect()
            let mcpTool = try #require(await client.tools.first)
            let staticTool = MCPToolAdapter.toAgentTool(from: mcpTool, client: client)
            let provider = MCPToolProvider(client: client)
            let dynamicTool = try #require(try await provider.discoverTools().first)
            let dynamicParameters = dynamicTool.schema.toAgentToolParameters()

            #expect(staticTool.parameters.required == ["settings", "steps"])
            #expect(dynamicParameters.required == staticTool.parameters.required)
            let settings = try #require(dynamicParameters.properties["settings"])
            #expect(settings.required == ["mode"])
            #expect(settings.properties?["mode"]?.enumValues == ["safe", "fast"])
            let stepItems = try #require(dynamicParameters.properties["steps"]?.items)
            #expect(stepItems.type == "object")
            #expect(stepItems.required == ["label"])
            #expect(stepItems.properties?["label"]?.minLength == 1)
            #expect(stepItems.properties?["label"]?.maxLength == 12)
            #expect(stepItems.required == staticTool.parameters.properties["steps"]?.items?.required)

            await client.disconnect()
            try FileManager.default.removeItem(at: directory)
        } catch {
            await client.disconnect()
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    @Test
    func `MCP schema conversion preserves established fallbacks`() {
        let emptySchemas: [Value?] = [nil, .string("not-an-object")]
        for schema in emptySchemas {
            let converted = MCPToolSchemaBridge.dynamicSchema(from: schema)
            #expect(converted.type == .object)
            #expect(converted.properties?.isEmpty == true)
            #expect(converted.required == nil)
            #expect(converted.toAgentToolParameters().required.isEmpty)
        }

        let converted = MCPToolSchemaBridge.dynamicSchema(from: .object([
            "properties": .object([
                "malformed": .string("not-a-property"),
                "unknown": .object(["type": .string("future-type")]),
                "untypedArray": .object(["type": .string("array")]),
            ]),
        ]))

        #expect(converted.properties?["malformed"]?.type == .string)
        #expect(converted.properties?["malformed"]?.description == "String parameter")
        #expect(converted.properties?["unknown"]?.type == .string)
        #expect(converted.properties?["unknown"]?.description == "Parameter")
        #expect(converted.properties?["untypedArray"]?.items?.type == .string)

        let invalidRoot = MCPToolSchemaBridge.dynamicSchema(from: .object([
            "type": .string("array"),
            "items": .object(["type": .string("string")]),
        ]))
        #expect(invalidRoot.type == .array)
        #expect(invalidRoot.toAgentToolParameters().type == "array")
        #expect(throws: TachikomaError.self) {
            _ = try toolParametersToJSON(invalidRoot.toAgentToolParameters())
        }
    }

    @Test
    func `ToolArguments getString`() {
        let args = ToolArguments(raw: [
            "name": "Alice",
            "count": 42,
            "ratio": 3.14,
            "active": true,
        ])

        #expect(args.getString("name") == "Alice")
        #expect(args.getString("count") == "42")
        #expect(args.getString("ratio") == "3.14")
        #expect(args.getString("active") == "true")
        #expect(args.getString("missing") == nil)
    }

    @Test
    func `ToolArguments getNumber`() {
        let args = ToolArguments(raw: [
            "int": 42,
            "double": 3.14,
            "string": "2.5",
            "invalid": "abc",
        ])

        #expect(args.getNumber("int") == 42.0)
        #expect(args.getNumber("double") == 3.14)
        #expect(args.getNumber("string") == 2.5)
        #expect(args.getNumber("invalid") == nil)
        #expect(args.getNumber("missing") == nil)
    }

    @Test
    func `ToolArguments getInt`() {
        let args = ToolArguments(raw: [
            "int": 42,
            "wholeDouble": 42.0,
            "double": 3.14,
            "string": "25",
            "invalid": "abc",
        ])

        #expect(args.getInt("int") == 42)
        #expect(args.getInt("wholeDouble") == 42)
        #expect(args.getInt("double") == nil)
        #expect(args.getInt("string") == 25)
        #expect(args.getInt("invalid") == nil)
        #expect(args.getInt("missing") == nil)
    }

    @Test
    func `ToolArguments reject unsafe numeric conversions`() {
        let args = ToolArguments(value: .object([
            "fractional": .double(1234.9),
            "overflow": .double(1e20),
            "infinity": .double(.infinity),
            "nan": .double(.nan),
            "stringOverflow": .string("100000000000000000000"),
        ]))

        #expect(args.getInt("fractional") == nil)
        #expect(args.getInt("overflow") == nil)
        #expect(args.getInt("infinity") == nil)
        #expect(args.getInt("nan") == nil)
        #expect(args.getInt("stringOverflow") == nil)
        #expect(args.getNumber("infinity") == nil)
        #expect(args.getNumber("nan") == nil)
    }

    @Test
    func `ToolArguments getBool`() {
        let args = ToolArguments(raw: [
            "bool": true,
            "stringTrue": "true",
            "stringYes": "yes",
            "string1": "1",
            "stringFalse": "false",
            "int0": 0,
            "int1": 1,
        ])

        #expect(args.getBool("bool") == true)
        #expect(args.getBool("stringTrue") == true)
        #expect(args.getBool("stringYes") == true)
        #expect(args.getBool("string1") == true)
        #expect(args.getBool("stringFalse") == false)
        #expect(args.getBool("int0") == false)
        #expect(args.getBool("int1") == true)
        #expect(args.getBool("missing") == nil)
    }

    @Test
    func `ToolArguments getStringArray`() {
        let args = ToolArguments(raw: [
            "array": ["a", "b", "c"],
            "mixed": ["string", 123, true],
            "notArray": "single",
        ])

        #expect(args.getStringArray("array") == ["a", "b", "c"])
        #expect(args.getStringArray("mixed") == ["string"]) // Only strings extracted
        #expect(args.getStringArray("notArray") == nil)
        #expect(args.getStringArray("missing") == nil)
    }

    @Test
    func `ToolArguments isEmpty`() {
        let emptyArgs = ToolArguments(raw: [:])
        #expect(emptyArgs.isEmpty == true)

        let nonEmptyArgs = ToolArguments(raw: ["key": "value"])
        #expect(nonEmptyArgs.isEmpty == false)
    }

    @Test
    func `ToolResponse text creation`() {
        let response = ToolResponse.text("Hello, world!")

        #expect(response.isError == false)
        #expect(response.content.count == 1)
        if case .text(text: let text, annotations: _, _meta: _) = response.content[0] {
            #expect(text == "Hello, world!")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test
    func `ToolResponse error creation`() {
        let response = ToolResponse.error("Something went wrong")

        #expect(response.isError == true)
        #expect(response.content.count == 1)
        if case .text(text: let text, annotations: _, _meta: _) = response.content[0] {
            #expect(text == "Something went wrong")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test
    func `ToolResponse image creation`() {
        let imageData = Data([0xFF, 0xD8, 0xFF]) // JPEG header
        let response = ToolResponse.image(data: imageData, mimeType: "image/jpeg")

        #expect(response.isError == false)
        #expect(response.content.count == 1)
        if case let .image(data: data, mimeType: mimeType, annotations: _, _meta: _) = response.content[0] {
            #expect(data == imageData.base64EncodedString())
            #expect(mimeType == "image/jpeg")
        } else {
            Issue.record("Expected image content")
        }
    }

    private static let schemaServerScript = #"""
    while IFS= read -r line; do
      id=$(printf '%s\n' "$line" | /usr/bin/sed -n 's/.*"id":\([0-9][0-9]*\).*/\1/p')
      case "$line" in
        *'"method":"initialize"'*)
          response='{"jsonrpc":"2.0","id":'
          response=$response"$id"
          response=$response',"result":{"protocolVersion":"2025-03-26","capabilities":{"tools":{}},'
          response=$response'"serverInfo":{"name":"schema-fixture","version":"1.0"}}}'
          printf '%s\n' "$response"
          ;;
        *tools*list*)
          response='{"jsonrpc":"2.0","id":'
          response=$response"$id"
          response=$response',"result":{"tools":[{"name":"run_plan","description":"Run a plan","inputSchema":{'
          response=$response'"type":"object","properties":{"settings":{"type":"object","properties":{'
          response=$response'"mode":{"type":"string","enum":["safe","fast"]}},"required":["mode"]},'
          response=$response'"steps":{"type":"array","items":{"type":"object","description":"One step",'
          response=$response'"properties":{"label":{"type":"string","minLength":1,"maxLength":12}},'
          response=$response'"required":["label"]}}},"required":["settings","steps"]}}]}}'
          printf '%s\n' "$response"
          ;;
      esac
    done
    """#
}
