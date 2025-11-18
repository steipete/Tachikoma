import Foundation

/// Shared user-facing config messages reused by hosts and CLIs.
public enum TKConfigMessages {
    /// Lines to show when no configuration exists yet.
    public static let initGuidance: [String] = [
        "[ok] Configuration file created at: {path}",
        "",
        "Next steps (no secrets written yet):",
        "  peekaboo config add openai sk-...    # API key",
        "  peekaboo config add anthropic sk-ant-...",
        "  peekaboo config add grok gsk-...      # aliases: xai",
        "  peekaboo config add gemini ya29-...",
        "  peekaboo config login openai          # OAuth, no key stored",
        "  peekaboo config login anthropic",
        "",
        "Use 'peekaboo config show --effective' to see detected env/creds,",
        "and 'peekaboo config edit' to tweak the JSONC file if needed.",
    ]
}
