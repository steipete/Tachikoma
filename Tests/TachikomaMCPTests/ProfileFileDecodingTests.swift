import Foundation
import Tachikoma
import TachikomaMCP
import XCTest

/// SwiftPM runs XCTest separately from Swift Testing, isolating the shared profile
/// path from the core test target's environment-mutating suites.
@MainActor
final class ProfileFileDecodingTests: XCTestCase {
    func testProfileReadersDetectEncoding() async throws {
        let encodings: [(String.Encoding, [UInt8])] = [
            (.utf8, []),
            (.utf8, [0xEF, 0xBB, 0xBF]),
            (.utf16LittleEndian, [0xFF, 0xFE]),
            (.utf16BigEndian, [0xFE, 0xFF]),
        ]
        for (encoding, bom) in encodings {
            try await self.withProfile { profile in
                let value = "café-東京-🦞"
                let credentials = """
                TOKEN=first
                  # ignored comment
                malformed line
                EMPTY=
                TOKEN=\(value)
                WITH_EQUALS=a=b==
                """
                try self.write(credentials, encoding: encoding, bom: bom, to: profile, name: "credentials")
                try self.write(
                    self.config(value: value),
                    encoding: encoding,
                    bom: bom,
                    to: profile,
                    name: "config.json",
                )

                XCTAssertEqual(TKCredentialStore().load(), ["TOKEN": value, "WITH_EQUALS": "a=b=="])
                CustomProviderRegistry.shared.loadFromProfile()
                let provider = try XCTUnwrap(CustomProviderRegistry.shared.get("fixture"))
                XCTAssertEqual(provider.kind, .anthropic)
                XCTAssertEqual(provider.baseURL, "https://example.invalid/v1")
                XCTAssertEqual(provider.apiKey, value)
                XCTAssertEqual(provider.headers["X-Fixture"], "literal // and /* comments */")
                XCTAssertEqual(provider.models["alias"], value)

                let manager = self.managerWithDefaults()
                await manager.initializeFromProfile(connect: false)
                XCTAssertEqual(manager.listServerNames(), ["fixture"])
                let server = try XCTUnwrap(manager.getServerConfig(name: "fixture"))
                XCTAssertEqual(server.command, "never-executed")
                XCTAssertEqual(server.args, [value])
                XCTAssertEqual(server.description, value)
                XCTAssertEqual(server.timeout, 12)
            }
        }
    }

    func testProfileReadFailuresPreserveOwnerFallbacks() async throws {
        let failures: [(String, Data?)] = [
            ("missing", nil),
            ("directory", nil),
            ("invalid UTF-8", Data([0xC3, 0x28])),
            ("odd UTF-16", Data([0xFF, 0xFE, 0x61])),
            ("invalid contents", Data("not a credential or JSON".utf8)),
            ("empty", Data()),
        ]
        for (name, bytes) in failures {
            try await self.withProfile { profile in
                try self.write(
                    self.config(value: "retained"),
                    encoding: .utf8,
                    bom: [],
                    to: profile,
                    name: "config.json",
                )
                CustomProviderRegistry.shared.loadFromProfile()
                XCTAssertEqual(CustomProviderRegistry.shared.get("fixture")?.apiKey, "retained")

                for filename in ["credentials", "config.json"] {
                    let url = profile.appendingPathComponent(filename)
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                    if name == "directory" {
                        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    } else if let bytes {
                        try bytes.write(to: url)
                    }
                }

                XCTAssertEqual(TKCredentialStore().load(), [:], name)
                CustomProviderRegistry.shared.loadFromProfile()
                XCTAssertEqual(CustomProviderRegistry.shared.get("fixture")?.apiKey, "retained", name)
                let manager = self.managerWithDefaults()
                await manager.initializeFromProfile(connect: false)
                XCTAssertEqual(manager.listServerNames(), ["disabled", "fixture"], name)
                XCTAssertEqual(manager.getServerConfig(name: "fixture")?.description, "default", name)
            }
        }
    }

    func testUnpairedUTF16PreservesPlatformBehavior() async throws {
        try await self.withProfile { profile in
            // An unpaired surrogate is accepted by Apple's legacy NSString reader,
            // but rejected by swift-foundation's String reader on Linux.
            for (filename, text) in [
                ("credentials", "TOKEN=\u{FFFD}"),
                ("config.json", self.config(value: "\u{FFFD}")),
            ] {
                let bytes = text.utf16.flatMap { codeUnit -> [UInt8] in
                    let unit: UInt16 = codeUnit == 0xFFFD ? 0xD800 : codeUnit
                    return [UInt8(truncatingIfNeeded: unit), UInt8(truncatingIfNeeded: unit >> 8)]
                }
                try (Data([0xFF, 0xFE]) + Data(bytes)).write(to: profile.appendingPathComponent(filename))
            }

            CustomProviderRegistry.shared.loadFromProfile()
            let manager = self.managerWithDefaults()
            await manager.initializeFromProfile(connect: false)
            #if canImport(Darwin)
            XCTAssertEqual(TKCredentialStore().load(), ["TOKEN": "\u{FFFD}"])
            XCTAssertEqual(CustomProviderRegistry.shared.get("fixture")?.apiKey, "\u{FFFD}")
            XCTAssertEqual(manager.getServerConfig(name: "fixture")?.description, "\u{FFFD}")
            #else
            XCTAssertEqual(TKCredentialStore().load(), [:])
            XCTAssertTrue(CustomProviderRegistry.shared.list().isEmpty)
            XCTAssertEqual(manager.getServerConfig(name: "fixture")?.description, "default")
            #endif
        }
    }

    private func withProfile(_ body: (URL) async throws -> Void) async throws {
        let profile = FileManager.default.temporaryDirectory
            .appendingPathComponent("tachikoma-file-decoding-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
        let originalProfile = TachikomaConfiguration.profileDirectoryName
        TachikomaConfiguration.profileDirectoryName = profile.path
        defer {
            // Reset the registry using only this fixture, never the restored profile.
            let configURL = profile.appendingPathComponent("config.json")
            try? FileManager.default.removeItem(at: configURL)
            try? Data(#"{"customProviders":{}}"#.utf8).write(to: configURL)
            CustomProviderRegistry.shared.loadFromProfile()
            TachikomaConfiguration.profileDirectoryName = originalProfile
            try? FileManager.default.removeItem(at: profile)
        }
        try await body(profile)
    }

    private func write(
        _ text: String,
        encoding: String.Encoding,
        bom: [UInt8],
        to profile: URL,
        name: String,
    ) throws {
        let data = try XCTUnwrap(text.data(using: encoding))
        try (Data(bom) + data).write(to: profile.appendingPathComponent(name))
    }

    private func managerWithDefaults() -> TachikomaMCPClientManager {
        let manager = TachikomaMCPClientManager()
        manager.registerDefaultServers([
            "fixture": MCPServerConfig(command: "never-executed", timeout: 12, description: "default"),
            "disabled": MCPServerConfig(command: "never-executed"),
        ])
        return manager
    }

    private func config(value: String) -> String {
        """
        {
          // A shared JSONC profile exercises both configuration readers.
          "customProviders": {
            "fixture": {
              "type": "anthropic",
              "options": {
                "baseURL": "https://example.invalid/v1",
                "apiKey": "\(value)",
                "headers": { "X-Fixture": "literal // and /* comments */" }
              },
              "models": { "alias": { "name": "\(value)" } }
            }
          },
          /* File overrides retain missing fields from the host defaults. */
          "mcpClients": {
            "fixture": { "args": ["\(value)"], "description": "\(value)", "timeout": 0 },
            "disabled": { "enabled": false }
          }
        }
        """
    }
}
