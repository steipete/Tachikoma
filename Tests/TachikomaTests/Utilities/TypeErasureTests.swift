import Foundation
import Testing
@testable import Tachikoma

@Suite("Type Erasure Utilities")
struct TypeErasureTests {
    @Test("AnyEncodable encodes heterogenous dictionaries")
    func anyEncodableEncodesHeterogenousDictionary() throws {
        let payload: [String: Any] = [
            "string": "hello",
            "int": 42,
            "double": 3.14,
            "bool": true,
            "array": ["nested", 7, ["deep": "value"]],
            "dict": ["flag": false, "count": 2],
            "null": NSNull(),
        ]

        let encoded = try JSONEncoder().encode(AnyEncodable(payload))
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        #expect(json?["string"] as? String == "hello")
        #expect(json?["int"] as? Int == 42)
        #expect(json?["double"] as? Double == 3.14)
        #expect(json?["bool"] as? Bool == true)
        #expect((json?["array"] as? [Any])?.count == 3)

        if let dict = json?["dict"] as? [String: Any] {
            #expect(dict["flag"] as? Bool == false)
            #expect(dict["count"] as? Int == 2)
        } else {
            Issue.record("Expected nested dictionary")
        }

        #expect(json?["null"] is NSNull)
    }

    @Test("AnyDecodable decodes heterogenous JSON")
    func anyDecodableDecodesHeterogenousJson() throws {
        let jsonData = """
        {
            "title": "example",
            "value": 1.5,
            "items": [1, "two", {"three": 3}],
            "options": {"enabled": true, "threshold": 0.25},
            "missing": null
        }
        """.utf8Data()

        let decoded = try JSONDecoder().decode(AnyDecodable.self, from: jsonData)
        guard let root = decoded.value as? [String: Any] else {
            Issue.record("Expected dictionary root")
            return
        }

        #expect(root["title"] as? String == "example")
        #expect(root["value"] as? Double == 1.5)
        #expect(root["missing"] is NSNull)

        if let items = root["items"] as? [Any] {
            #expect(items.count == 3)
            #expect(items.first as? Int == 1)
            #expect(items.dropLast().last as? String == "two")
            if let third = items.last as? [String: Any] {
                #expect(third["three"] as? Int == 3)
            } else {
                Issue.record("Expected nested dictionary in array")
            }
        } else {
            Issue.record("Expected array for items")
        }

        if let options = root["options"] as? [String: Any] {
            #expect(options["enabled"] as? Bool == true)
            #expect(options["threshold"] as? Double == 0.25)
        } else {
            Issue.record("Expected options dictionary")
        }
    }
}
