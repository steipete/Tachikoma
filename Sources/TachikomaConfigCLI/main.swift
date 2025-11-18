import Foundation
import Tachikoma

@main
struct TKConfigCLI {
    static func main() async {
        var args = Array(CommandLine.arguments.dropFirst())

        // Top-level command namespace so we can add more in the future.
        if let first = args.first, first == "config" {
            args.removeFirst()
        }

        guard let cmd = args.first else {
            self.printUsage()
            exit(0)
        }

        switch cmd {
        case "add":
            await self.handleAdd(Array(args.dropFirst()))
        case "login":
            await self.handleLogin(Array(args.dropFirst()))
        case "status", "show":
            await self.handleStatus(Array(args.dropFirst()))
        case "init":
            self.handleInit()
        default:
            print("Unknown command \(cmd)")
            self.printUsage()
            exit(1)
        }
    }

    private static func printUsage() {
        print("""
        tachikoma config commands:
          config add <provider> <secret> [--timeout <sec>]
          config login <provider> [--timeout <sec>] [--no-browser]
          config status [--timeout <sec>]   # alias: show
          config init                       # prints guidance, does not write by default

        Providers: openai | anthropic | grok | xai | gemini
        """)
    }

    private static func parseTimeout(_ args: inout [String], default value: Double = 30) -> Double {
        if let idx = args.firstIndex(of: "--timeout"), idx + 1 < args.count, let t = Double(args[idx + 1]) {
            args.removeSubrange(idx...(idx + 1))
            return t
        }
        return value
    }

    private static func handleAdd(_ raw: [String]) async {
        var mutable = raw
        guard mutable.count >= 2 else {
            print("Usage: tk-config add <provider> <secret> [--timeout <sec>]")
            exit(1)
        }
        let provider = mutable.removeFirst()
        let secret = mutable.removeFirst()
        let timeout = self.parseTimeout(&mutable)

        guard let pid = TKProviderId.normalize(provider) else {
            print("Unsupported provider. Use openai|anthropic|grok|xai|gemini")
            exit(1)
        }
        let result = await TKAuthManager.shared.validate(provider: pid, secret: secret, timeout: timeout)
        do {
            if let key = pid.credentialKeys.first {
                try TKAuthManager.shared.setCredential(key: key, value: secret)
            }
        } catch {
            print("Failed to store credential: \(error)")
            exit(1)
        }
        switch result {
        case .success: print("[ok] Stored and validated \(pid.displayName)")
        case let .failure(reason): print("[warn] Stored but validation failed: \(reason)")
        case let .timeout(sec): print("[warn] Stored but validation timed out after \(Int(sec))s")
        }
    }

    private static func handleLogin(_ raw: [String]) async {
        var mutable = raw
        guard let provider = mutable.first else {
            print("Usage: tk-config login <provider> [--timeout <sec>] [--no-browser]")
            exit(1)
        }
        mutable.removeFirst()
        let timeout = self.parseTimeout(&mutable)
        let noBrowser = mutable.contains("--no-browser")
        guard let pid = TKProviderId.normalize(provider), pid.supportsOAuth else {
            print("OAuth supported providers: openai, anthropic")
            exit(1)
        }
        let result = await TKAuthManager.shared.oauthLogin(provider: pid, timeout: timeout, noBrowser: noBrowser)
        switch result {
        case .success: print("[ok] OAuth tokens stored for \(pid.displayName)")
        case let .failure(reason):
            print("[error] \(reason)")
            exit(1)
        }
    }

    private static func handleInit() {
        let lines = TKConfigMessages.initGuidance.map { $0.replacingOccurrences(
            of: "{path}",
            with: "~/.tachikoma/config.json",
        ) }
        print(lines.joined(separator: "\n"))
    }

    private static func handleStatus(_ raw: [String]) async {
        var mutable = raw
        let timeout = self.parseTimeout(&mutable)
        print("Providers:")
        for pid in [TKProviderId.openai, .anthropic, .grok, .gemini] {
            let status = await TKConfigCLI.status(for: pid, timeout: timeout)
            print("  \(pid.displayName): \(status)")
        }
    }

    private static func status(for pid: TKProviderId, timeout: Double) async -> String {
        let env = ProcessInfo.processInfo.environment
        if let source = envSource(pid: pid, env: env) {
            let validation = await TKAuthManager.shared.validate(provider: pid, secret: source.value, timeout: timeout)
            return self.describe(source: "env \(source.key)", validation: validation)
        }
        let credsSource = self.credentialSource(pid: pid)
        switch credsSource {
        case let .some(source):
            let validation = await TKAuthManager.shared.validate(provider: pid, secret: source.value, timeout: timeout)
            return self.describe(source: "credentials \(source.key)", validation: validation)
        case .none:
            return "missing"
        }
    }

    private static func envSource(pid: TKProviderId, env: [String: String]) -> (key: String, value: String)? {
        switch pid {
        case .openai:
            if let v = env["OPENAI_API_KEY"], !v.isEmpty { return ("OPENAI_API_KEY", v) }
        case .anthropic:
            if let v = env["ANTHROPIC_API_KEY"], !v.isEmpty { return ("ANTHROPIC_API_KEY", v) }
        case .grok:
            for k in ["GROK_API_KEY", "X_AI_API_KEY", "XAI_API_KEY"] {
                if let v = env[k], !v.isEmpty { return (k, v) }
            }
        case .gemini:
            if let v = env["GEMINI_API_KEY"], !v.isEmpty { return ("GEMINI_API_KEY", v) }
        }
        return nil
    }

    private static func credentialSource(pid: TKProviderId) -> (key: String, value: String)? {
        let manager = TKAuthManager.shared
        switch pid {
        case .openai:
            if let v = manager.credentialValue(for: "OPENAI_ACCESS_TOKEN") { return ("OPENAI_ACCESS_TOKEN", v) }
            if let v = manager.credentialValue(for: "OPENAI_API_KEY") { return ("OPENAI_API_KEY", v) }
        case .anthropic:
            if let v = manager.credentialValue(for: "ANTHROPIC_ACCESS_TOKEN") { return ("ANTHROPIC_ACCESS_TOKEN", v) }
            if let v = manager.credentialValue(for: "ANTHROPIC_API_KEY") { return ("ANTHROPIC_API_KEY", v) }
        case .grok:
            for k in ["GROK_API_KEY", "X_AI_API_KEY", "XAI_API_KEY"] {
                if let v = manager.credentialValue(for: k) { return (k, v) }
            }
        case .gemini:
            if let v = manager.credentialValue(for: "GEMINI_API_KEY") { return ("GEMINI_API_KEY", v) }
        }
        return nil
    }

    private static func describe(source: String, validation: TKValidationResult) -> String {
        switch validation {
        case .success:
            "ready (\(source), validated)"
        case let .failure(reason):
            "stored (\(source), validation failed: \(reason))"
        case let .timeout(sec):
            "stored (\(source), validation timed out after \(Int(sec))s)"
        }
    }
}
