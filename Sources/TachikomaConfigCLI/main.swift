import Commander
import Foundation
import Tachikoma

@main
struct TKConfigCLI {
    static func main() async {
        let group = command(
            "add",
            Arg<String>("provider", description: "openai|anthropic|grok|xai|gemini"),
            Arg<String>("secret", description: "API key / bearer"),
            Option<Double>("timeout", default: 30, description: "Validation timeout in seconds")
        ) { provider, secret, timeout in
            guard let pid = TKProviderId.normalize(provider) else {
                print("Unsupported provider. Use openai|anthropic|grok|xai|gemini")
                exit(1)
            }
            let result = await TKAuthManager.shared.validate(provider: pid, secret: secret, timeout: timeout)
            do {
                try TKAuthManager.shared.setCredential(key: pid.credentialKeys.first!, value: secret)
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

        let login = command(
            "login",
            Arg<String>("provider", description: "openai|anthropic"),
            Option<Double>("timeout", default: 30, description: "Token exchange timeout in seconds"),
            Flag("no-browser", description: "Do not auto-open browser")
        ) { provider, timeout, noBrowser in
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

        let show = command(
            "status",
            Option<Double>("timeout", default: 30, description: "Validation timeout in seconds")
        ) { timeout in
            let reporter = ProviderStatusReporter(timeoutSeconds: timeout)
            await reporter.printSummary()
        }

        let main = Group {
            $0.addCommand("add", group)
            $0.addCommand("login", login)
            $0.addCommand("status", show)
        }

        await main.parseAsync()
    }
}
