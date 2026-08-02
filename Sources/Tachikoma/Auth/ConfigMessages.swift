import Foundation

/// Shared user-facing config messages reused by hosts and CLIs.
public enum TKConfigMessages {
    /// Lines to show when no configuration exists yet.
    public static let initGuidance: [String] = [
        "[info] Configuration file path: {path}",
        "",
        "No file was written. Configure credentials when ready:",
        "  tachikoma config add openai sk-...    # API key",
        "  tachikoma config add anthropic sk-ant-...",
        "  tachikoma config add grok gsk-...      # aliases: xai",
        "  tachikoma config add gemini ya29-...",
        "  tachikoma config login openai          # OAuth",
        "  tachikoma config login anthropic",
        "",
        "Use 'tachikoma config status' to inspect detected environment and stored credentials.",
    ]
}
