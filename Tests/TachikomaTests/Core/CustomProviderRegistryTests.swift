import Foundation
import Tachikoma
import Testing
#if os(Windows)
import CRT
#elseif canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@Suite("Custom Provider Registry")
struct CustomProviderRegistryTests {
    @Test("Loads providers from profile config with comments and env vars")
    func loadProvidersFromProfile() throws {
        let fm = FileManager.default
        let tempHome = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempHome, withIntermediateDirectories: true)

        let profileDirName = ".tachikoma-test-\(UUID().uuidString)"
        let profileDir = tempHome.appendingPathComponent(profileDirName)
        try fm.createDirectory(at: profileDir, withIntermediateDirectories: true)
        let configURL = profileDir.appendingPathComponent("config.json")

        let configContents = """
        {
          // Custom providers with comments and env vars
          "customProviders": {
            "weather-ai": {
              "type": "openai",
              "options": {
                "baseURL": "https://api.example.com",
                /* secret token */
                "headers": {
                  "Authorization": "Bearer ${WEATHER_TOKEN}"
                }
              },
              "models": {
                "fast": { "name": "weather-fast" }
              }
            },
            "claude-proxy": {
              "type": "anthropic",
              "options": { "baseURL": "https://anthropic.local" }
            }
          }
        }
        """

        try configContents.write(to: configURL, atomically: true, encoding: .utf8)

        let originalHome = ProcessInfo.processInfo.environment["HOME"]
        #if os(Windows)
        let originalUserProfile = ProcessInfo.processInfo.environment["USERPROFILE"]
        #endif
        let originalProfileDir = TachikomaConfiguration.profileDirectoryName

        defer {
            #if os(Windows)
            let userProfileValue = originalUserProfile
            #else
            let userProfileValue: String? = nil
            #endif
            TachikomaConfiguration.profileDirectoryName = originalProfileDir
            unsetenv("WEATHER_TOKEN")
            self.resetRegistry(
                forProfile: originalProfileDir,
                originalHome: originalHome,
                originalUserProfile: userProfileValue,
            )
        }

        TachikomaConfiguration.profileDirectoryName = profileDirName
        self.setHomeEnvironment(to: tempHome.path)
        setenv("WEATHER_TOKEN", "sk-test-weather", 1)

        CustomProviderRegistry.shared.loadFromProfile()
        let providers = CustomProviderRegistry.shared.list()

        #expect(providers.count == 2)

        let weather = try #require(providers["weather-ai"])
        #expect(weather.kind == .openai)
        #expect(weather.baseURL == "https://api.example.com")
        #expect(weather.headers["Authorization"] == "Bearer sk-test-weather")
        #expect(weather.models["fast"] == "weather-fast")

        let claude = try #require(CustomProviderRegistry.shared.get("claude-proxy"))
        #expect(claude.kind == .anthropic)
        #expect(claude.headers.isEmpty)
        #expect(claude.models.isEmpty)

        #expect(CustomProviderRegistry.shared.get("missing") == nil)
    }

    private func setHomeEnvironment(to path: String) {
        setenv("HOME", path, 1)
        #if os(Windows)
        setenv("USERPROFILE", path, 1)
        #endif
    }

    private func restoreEnvironment(home: String?) {
        if let home {
            setenv("HOME", home, 1)
        } else {
            unsetenv("HOME")
        }
    }

    #if os(Windows)
    private func restoreUserProfile(_ path: String?) {
        if let path {
            setenv("USERPROFILE", path, 1)
        } else {
            unsetenv("USERPROFILE")
        }
    }
    #endif

    private func resetRegistry(
        forProfile profileDir: String,
        originalHome: String?,
        originalUserProfile: String?,
    ) {
        let fm = FileManager.default
        let resetHome = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fm.createDirectory(at: resetHome, withIntermediateDirectories: true)
        let resetProfileDir = resetHome.appendingPathComponent(profileDir)
        try? fm.createDirectory(at: resetProfileDir, withIntermediateDirectories: true)
        let resetConfigURL = resetProfileDir.appendingPathComponent("config.json")
        try? "{ \"customProviders\": {} }".write(to: resetConfigURL, atomically: true, encoding: .utf8)

        TachikomaConfiguration.profileDirectoryName = profileDir
        self.setHomeEnvironment(to: resetHome.path)
        CustomProviderRegistry.shared.loadFromProfile()
        self.restoreEnvironment(home: originalHome)
        #if os(Windows)
        self.restoreUserProfile(originalUserProfile)
        #endif
    }
}
