import Foundation
import Security

/// Shared secret between the permission hook and the app. The app prefixes every decision with it and the hook
/// only passes on answers that start with it, so nothing else listening on the port (e.g. another user's process
/// while Nosy Notch isn't running) can approve a command. Stored in `~/.nosynotch/approval-token` (0600) so the
/// `npx nosynotch` CLI writes the exact same hook command.
enum ApprovalToken {
    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nosynotch", isDirectory: true)
            .appendingPathComponent("approval-token")
    }

    static let value: String = {
        if let existing = try? String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           existing.count >= 16, existing.allSatisfy({ $0.isHexDigit }) {
            return existing
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        }
        let token = bytes.map { String(format: "%02x", $0) }.joined()
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        fm.createFile(atPath: url.path, contents: Data(token.utf8), attributes: [.posixPermissions: 0o600])
        return token
    }()
}

/// A permission request that waits for an answer in the notch.
struct PendingApproval: Identifiable, Equatable {
    let id = UUID()
    let sessionID: String
    let agent: Agent
    let tool: ToolActivity
    /// Claude Code's "always allow" suggestions we can safely pass back (rules / directories, never mode switches).
    let alwaysRules: [[String: Any]]
    let createdAt = Clock.now()

    var canAlwaysAllow: Bool { !alwaysRules.isEmpty }

    static func == (a: PendingApproval, b: PendingApproval) -> Bool { a.id == b.id }
}

enum ApprovalDecision {
    case allow, alwaysAllow, deny
}

/// Holds the open permission hooks until the user clicks Allow / Deny in the notch, answers in the terminal,
/// or the request times out (then the hook returns nothing and the agent falls back to its own prompt).
@MainActor
final class ApprovalCenter: ObservableObject {
    @Published private(set) var pending: [PendingApproval] = [] {
        didSet { onChange?() }
    }

    var onChange: (() -> Void)?

    private var replies: [UUID: (String?) -> Void] = [:]
    private var timeouts: [UUID: DispatchWorkItem] = [:]

    /// Claude Code shows its own dialog while the hook waits, so the notch can wait almost as long as the hook
    /// may run (600 s). Codex only shows its prompt once the hook returns – don't keep it hidden for long.
    static func waitTime(for agent: Agent) -> TimeInterval {
        agent == .claude ? 570 : 45   // Codex and Cursor only show their own prompt after the hook returns
    }

    func pending(for sessionID: String) -> PendingApproval? {
        pending.last { $0.sessionID == sessionID }
    }

    /// A `PermissionRequest` hook is waiting. `reply` sends the hook's stdout (nil = no decision).
    func add(_ event: HookEvent, reply: @escaping (String?) -> Void) {
        guard Preferences.approvalsInNotch, event.name == "PermissionRequest" else { return reply(nil) }
        if event.agent == .cursor && !Preferences.cursorApprovals { return reply(nil) }

        let rules = event.agent == .claude ? event.permissionSuggestions.filter(Self.isSafeAlwaysRule) : []
        let approval = PendingApproval(sessionID: event.sessionID, agent: event.agent,
                                       tool: ToolActivity(name: event.toolName ?? "Tool", input: event.toolInput),
                                       alwaysRules: rules)
        replies[approval.id] = reply
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.finish(approval.id, output: nil) }
        }
        timeouts[approval.id] = work
        Clock.after(Self.waitTime(for: event.agent), execute: work)
        pending.append(approval)
    }

    func decide(_ id: UUID, _ decision: ApprovalDecision) {
        guard let approval = pending.first(where: { $0.id == id }) else { return }
        if approval.agent == .cursor {
            // Cursor's permission hooks: {"permission": "allow" | "deny"}.
            let output: [String: Any] = decision == .deny
                ? ["permission": "deny", "user_message": "Denied in Nosy Notch.", "agent_message": "The user denied this command."]
                : ["permission": "allow"]
            let json = (try? JSONSerialization.data(withJSONObject: output)).flatMap { String(data: $0, encoding: .utf8) }
            return finish(id, output: json)
        }
        var body: [String: Any]
        switch decision {
        case .allow:
            body = ["behavior": "allow"]
        case .alwaysAllow:
            body = ["behavior": "allow"]
            if approval.agent == .claude, approval.canAlwaysAllow { body["updatedPermissions"] = approval.alwaysRules }
        case .deny:
            body = ["behavior": "deny", "message": "The user denied this in Nosy Notch."]
        }
        let output: [String: Any] = ["hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": body]]
        let json = (try? JSONSerialization.data(withJSONObject: output)).flatMap { String(data: $0, encoding: .utf8) }
        finish(id, output: json)
    }

    /// Give the request back to the agent's own prompt (✕ in the notch).
    func release(_ id: UUID) {
        finish(id, output: nil)
    }

    /// The request was answered elsewhere (terminal, Codex app): the tool ran, or the turn moved on.
    /// Other tools of the same session (Claude runs some in parallel) don't count.
    func observe(_ event: HookEvent) {
        let endsTurn = ["UserPromptSubmit", "Stop", "StopFailure", "Interrupt", "SessionEnd"].contains(event.name)
        let toolDone = ["PostToolUse", "PostToolUseFailure"].contains(event.name)
        guard endsTurn || toolDone else { return }
        let finished = event.toolName.map { ToolActivity(name: $0, input: event.toolInput) }
        for approval in pending where approval.sessionID == event.sessionID {
            if endsTurn || finished == approval.tool { finish(approval.id, output: nil) }
        }
    }

    private func finish(_ id: UUID, output: String?) {
        timeouts.removeValue(forKey: id)?.cancel()
        pending.removeAll { $0.id == id }
        replies.removeValue(forKey: id)?(output.map { "\(ApprovalToken.value) \($0)" })
    }

    /// Only rule and directory suggestions – a `setMode` suggestion would e.g. switch the whole session to
    /// "accept edits", which is more than "always allow this".
    private static func isSafeAlwaysRule(_ suggestion: [String: Any]) -> Bool {
        guard let type = suggestion["type"] as? String else { return false }
        if type == "addRules" { return (suggestion["behavior"] as? String) == "allow" }
        return type == "addDirectories"
    }
}
