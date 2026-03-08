import Foundation
import Testing
@testable import Tachikoma

@Suite("Structured Output Generation")
struct StructuredOutputGenerationTests {
    @Test("generateObject requests json_schema when schema is provided")
    func generateObjectUsesStructuredOutputSchema() async throws {
        let capture = StructuredOutputCapture()
        let config = TachikomaConfiguration(loadFromEnvironment: false)
        config.setProviderFactoryOverride { _, _ in
            StructuredOutputCaptureProvider(capture: capture)
        }

        let result = try await generateObject(
            model: .openai(.gpt52),
            messages: [.user("Return the fixture")],
            schema: StructuredOutputFixture.self,
            configuration: config,
        )

        #expect(result.object == StructuredOutputFixture(value: "ok"))

        let request = try #require(await capture.request)
        let outputFormat = try #require(request.outputFormat)

        switch outputFormat {
        case let .jsonSchema(schema):
            #expect(schema == StructuredOutputFixture.structuredOutputSchema)
        case .text, .json:
            Issue.record("Expected json_schema output format, got \(outputFormat)")
        }
    }
}

private struct StructuredOutputFixture: Codable, Sendable, Equatable, StructuredOutputSchemaProviding {
    let value: String

    static let structuredOutputSchema = StructuredOutputSchema(
        name: "structured_output_fixture",
        schema: .object([
            "type": .string("object"),
            "properties": .object([
                "value": .object([
                    "type": .string("string"),
                ]),
            ]),
            "required": .array([.string("value")]),
            "additionalProperties": .bool(false),
        ]),
    )
}

private actor StructuredOutputCapture {
    var request: ProviderRequest?

    func record(_ request: ProviderRequest) {
        self.request = request
    }
}

private struct StructuredOutputCaptureProvider: ModelProvider {
    let modelId = "mock-structured-output"
    let baseURL: String? = nil
    let apiKey: String? = nil
    let capabilities = ModelCapabilities()

    let capture: StructuredOutputCapture

    func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        await capture.record(request)
        return ProviderResponse(text: #"{"value":"ok"}"#)
    }

    func streamText(request _: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
