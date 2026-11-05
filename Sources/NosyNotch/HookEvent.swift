import Foundation

/// A single event forwarded by a Claude Code or Codex hook (the hook's stdin JSON, posted to our local server).
///
/// See https://docs.claude.com/en/docs/claude-code/hooks for the payload shape. We decode leniently
/// with `JSONSerialization` because fields differ per event and new ones get added over time.
struct HookEvent {
    let name: String
    /// Which agent sent it (`?agent=codex` in the hook URL; Claude Code hooks don't set it).
    let agent: Agent
    let sessionID: String
    let cwd: String?
    let transcriptPath: String?
    let toolName: String?
    let toolInput: [String: Any]
    let message: String?
    let notificationType: String?
    let prompt: String?
    let lastAssistantMessage: String?
    /// `StopFailure`: error code (rate_limit, overloaded, …) and optional details.
    let error: String?
    let errorDetails: String?
    /// `PermissionRequest` (Claude Code): the "always allow" options the terminal dialog offers.
    let permissionSuggestions: [[String: Any]]

    /// Value of `$TERM_PROGRAM` in the shell that ran the hook (e.g. "iTerm.app", "Apple_Terminal", "vscode").
    let termProgram: String?
    /// Value of `$__CFBundleIdentifier` — the bundle id of the app Claude Code runs in, if macOS set it.
    let hostBundleID: String?

    init?(data: Data, headers: [String: String] = [:], query: [String: String] = [:]) {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let json = object as? [String: Any],
              let name = json["hook_event_name"] as? String
        else { return nil }

        let agent = Agent(query: query["agent"])
        self.agent = agent
        if agent == .cursor {
            // Cursor names its hooks differently (camelCase) and keys sessions by conversation.
            self.name = Self.cursorEventName(name, status: json["status"] as? String)
            self.sessionID = (json["conversation_id"] as? String) ?? (json["session_id"] as? String) ?? "cursor"
            self.cwd = (json["cwd"] as? String) ?? (json["workspace_roots"] as? [String])?.first
        } else {
            self.name = name
            self.sessionID = (json["session_id"] as? String) ?? "default"
            self.cwd = json["cwd"] as? String
        }
        self.transcriptPath = json["transcript_path"] as? String
        self.toolName = json["tool_name"] as? String
        self.toolInput = (json["tool_input"] as? [String: Any]) ?? [:]
        self.message = json["message"] as? String
        self.notificationType = json["notification_type"] as? String
        self.prompt = json["prompt"] as? String
        self.lastAssistantMessage = (json["last_assistant_message"] as? String)
            ?? (agent == .cursor ? json["text"] as? String : nil)
        self.error = (json["error"] as? String) ?? (agent == .cursor && json["status"] as? String == "error" ? "error" : nil)
        self.errorDetails = json["error_details"] as? String
        self.permissionSuggestions = (json["permission_suggestions"] as? [[String: Any]]) ?? []
        self.termProgram = headers["x-term-program"].flatMap { $0.isEmpty ? nil : $0 }
        self.hostBundleID = headers["x-bundle-id"].flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Cursor hook → the Claude Code name the store understands.
    static func cursorEventName(_ name: String, status: String?) -> String {
        switch name {
        case "sessionStart": return "SessionStart"
        case "sessionEnd": return "SessionEnd"
        case "beforeSubmitPrompt": return "UserPromptSubmit"
        case "preToolUse": return "PreToolUse"
        case "postToolUse": return "PostToolUse"
        case "postToolUseFailure": return "PostToolUseFailure"
        case "preCompact": return "PreCompact"
        case "subagentStop": return "SubagentStop"
        case "afterAgentResponse": return "AgentResponse"
        case "stop":
            switch status {
            case "aborted": return "Interrupt"
            case "error": return "StopFailure"
            default: return "Stop"
            }
        default: return name
        }
    }

    /// Memberwise initializer used by the built-in demo.
    init(name: String, sessionID: String, agent: Agent = .claude, cwd: String? = nil, toolName: String? = nil,
         toolInput: [String: Any] = [:], message: String? = nil, prompt: String? = nil,
         lastAssistantMessage: String? = nil, error: String? = nil, errorDetails: String? = nil) {
        self.name = name
        self.agent = agent
        self.sessionID = sessionID
        self.cwd = cwd
        self.transcriptPath = nil
        self.toolName = toolName
        self.toolInput = toolInput
        self.message = message
        self.notificationType = nil
        self.prompt = prompt
        self.lastAssistantMessage = lastAssistantMessage
        self.error = error
        self.errorDetails = errorDetails
        self.permissionSuggestions = []
        self.termProgram = nil
        self.hostBundleID = nil
    }
}
