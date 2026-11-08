import Foundation
import Combine

/// Something noteworthy happened that deserves a big animation / sound.
enum Transition {
    case started(Session)
    case finished(Session)
    case needsAttention(Session)
    case failed(Session)

    /// Transitions that stay small while you're already in the session's app.
    var quietCandidate: Session? {
        switch self {
        case .finished(let s), .needsAttention(let s): return s
        default: return nil
        }
    }
}

/// Turns the raw hook event stream into per-session state.
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [String: Session] = [:] {
        didSet { onChange?() }
    }

    /// Called after `sessions` changed.
    var onChange: (() -> Void)?

    /// Called for transitions that should trigger a celebration / alert.
    var onTransition: ((Transition) -> Void)?

    /// Called when a session has been done (unseen) or waiting for 5 minutes.
    var onReminder: ((Transition) -> Void)?

    static let reminderDelay: TimeInterval = 5 * 60

    private var sweepTimer: Timer?

    init() {
        sweepTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sweep()
                self?.remind()
            }
        }
    }

    /// Sessions ordered by importance, then recency.
    var ordered: [Session] {
        sessions.values.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.lastUpdate > $1.lastUpdate
        }
    }

    var primary: Session? { ordered.first }
    var hasActivity: Bool { sessions.values.contains { $0.state.isActive } }
    var hasWaiting: Bool { sessions.values.contains { if case .waiting = $0.state { return true }; return false } }
    var unseen: [Session] { ordered.filter(\.isUnseen) }

    func handle(_ event: HookEvent) {
        var s = sessions[event.sessionID] ?? Session(id: event.sessionID, agent: event.agent)
        if let cwd = event.cwd { s.cwd = cwd }
        if let t = event.transcriptPath { s.transcriptPath = t }
        if let t = event.termProgram { s.termProgram = t }
        if let b = event.hostBundleID { s.hostBundleID = b }
        if let p = event.hostPID { s.hostPID = p }
        s.lastUpdate = Clock.now()
        let wasWaiting: Bool = { if case .waiting = s.state { return true }; return false }()

        var transition: Transition?

        switch event.name {
        case "SessionStart":
            if !s.state.isActive { s.state = .idle }

        case "UserPromptSubmit":
            s.unseenSince = nil
            s.state = .thinking
            s.turnStartedAt = Clock.now()
            s.toolCount = 0
            s.lastSummary = nil
            if s.todos.isFinished { s.todos.clear() }
            transition = .started(s)

        case "PreToolUse":
            if s.turnStartedAt == nil { s.turnStartedAt = Clock.now() }
            s.state = .tool(ToolActivity(name: event.toolName ?? "Tool", input: event.toolInput))
            s.toolCount += 1
            if let tool = event.toolName { s.todos.apply(tool: tool, input: event.toolInput) }

        case "PostToolUse", "PostToolUseFailure":
            s.state = .thinking

        case "PreCompact":
            s.state = .compacting

        case "PermissionRequest":
            // Fires the moment Claude Code shows a permission dialog (the Notification hook may lag behind).
            let tool = ToolActivity(name: event.toolName ?? "Tool", input: event.toolInput)
            let target = tool.detail.map { ": \($0)" } ?? ""
            let alreadyWaiting: Bool = { if case .waiting = s.state { return true }; return false }()
            s.state = .waiting(message: "May I use \(tool.displayName)\(target)?")
            if !alreadyWaiting { transition = .needsAttention(s) }

        case "Notification":
            let message = event.message ?? "\(s.agent.name) needs your attention"
            // The "waiting for your input" reminder fires ~60s after a turn ended; that's not news.
            let isIdleReminder = event.notificationType == "idle_prompt"
                || message.localizedCaseInsensitiveContains("waiting for your input")
            if isIdleReminder && !s.state.isActive { break }
            // PermissionRequest already put us into "waiting" with a more specific message.
            if case .waiting = s.state, event.notificationType == "permission_prompt" { break }
            s.state = .waiting(message: message)
            transition = .needsAttention(s)

        case "Stop":
            s.state = .done
            s.unseenSince = Clock.now()
            if let start = s.turnStartedAt { s.lastTurnDuration = Clock.now().timeIntervalSince(start) }
            s.turnStartedAt = nil
            s.lastSummary = event.lastAssistantMessage.map(Self.condense) ?? s.lastSummary
            transition = .finished(s)

        case "StopFailure":
            s.state = .error(message: APIErrorText.describe(code: event.error, details: event.errorDetails,
                                                            message: event.lastAssistantMessage))
            if let start = s.turnStartedAt { s.lastTurnDuration = Clock.now().timeIntervalSince(start) }
            s.turnStartedAt = nil
            transition = .failed(s)

        case "SubagentStop":
            break

        case "AgentResponse":
            // Cursor sends the answer text (and its token count) before its `stop` hook.
            if let text = event.lastAssistantMessage { s.lastSummary = Self.condense(text) }
            if let context = event.contextPercent { s.contextPercent = context }

        case "Interrupt":
            // Codex only: the user stopped the turn (Esc). Claude Code has no such hook.
            s.state = .idle
            s.turnStartedAt = nil

        case "SessionEnd":
            sessions[event.sessionID] = nil
            return

        default:
            break
        }

        // Reminder bookkeeping: a new "waiting" or "done" gets its own reminder.
        let isWaiting: Bool = { if case .waiting = s.state { return true }; return false }()
        if isWaiting && !wasWaiting { s.waitingSince = Clock.now(); s.reminded = false }
        if !isWaiting { s.waitingSince = nil }
        if event.name == "Stop" { s.reminded = false }

        sessions[s.id] = s
        if let transition { onTransition?(transition) }

        // Pull a short summary of the final answer out of the transcript.
        if event.name == "Stop", s.agent == .claude, s.lastSummary == nil, let path = s.transcriptPath {
            let id = s.id
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) { [weak self] in
                let summary = Transcript.lastAssistantText(at: path).map(Self.condense)
                Task { @MainActor [weak self] in
                    guard let self, let summary, var current = self.sessions[id], current.state == .done else { return }
                    current.lastSummary = summary
                    self.sessions[id] = current
                }
            }
        }
    }

    /// The user answered a permission request in the notch – don't keep showing "Waiting for you".
    func resume(_ id: String, allowed: Bool, tool: ToolActivity) {
        guard var s = sessions[id], case .waiting = s.state else { return }
        s.state = allowed ? .tool(tool) : .thinking
        s.lastUpdate = Clock.now()
        sessions[id] = s
    }

    /// You looked at the session (its app came to the front, you hovered the list, clicked, closed the card).
    func markSeen(_ id: String) {
        guard var s = sessions[id], s.isUnseen else { return }
        s.unseenSince = nil
        sessions[id] = s
    }

    func setContext(_ id: String, percent: Double) {
        guard var s = sessions[id], s.contextPercent != percent else { return }
        s.contextPercent = min(max(percent, 0), 100)
        sessions[id] = s
    }

    func markAllSeen() {
        for s in sessions.values where s.isUnseen { markSeen(s.id) }
    }

    /// Fire the 5-minute reminder for unseen "done" and unanswered "waiting" sessions.
    private func remind() {
        guard Preferences.remindAfterFiveMinutes else { return }
        let now = Clock.now()
        for (id, s) in sessions where !s.reminded {
            var due: Transition?
            if let since = s.unseenSince, s.state == .done, now.timeIntervalSince(since) >= Self.reminderDelay {
                due = .finished(s)
            } else if let since = s.waitingSince, now.timeIntervalSince(since) >= Self.reminderDelay {
                due = .needsAttention(s)
            }
            guard let due else { continue }
            var updated = s
            updated.reminded = true
            sessions[id] = updated
            onReminder?(due)
        }
    }

    func dismiss(_ id: String) {
        sessions[id] = nil
    }

    /// Drop stale sessions and un-stick sessions whose turn was interrupted (Esc / Ctrl-C send no Stop hook).
    private func sweep() {
        let now = Clock.now()
        for (id, s) in sessions {
            let age = now.timeIntervalSince(s.lastUpdate)
            switch s.state {
            case .thinking where age > 10 * 60, .tool where age > 30 * 60, .compacting where age > 10 * 60:
                var updated = s
                updated.state = .idle
                updated.turnStartedAt = nil
                sessions[id] = updated
            case .done where s.isUnseen && age > 12 * 60 * 60, .done where !s.isUnseen && age > 60 * 60,
                 .idle where age > 60 * 60, .error where age > 60 * 60:
                sessions[id] = nil
            default:
                break
            }
        }
    }

    nonisolated static func condense(_ text: String) -> String {
        // Strip markdown noise and collapse whitespace so it reads well in two lines.
        var t = text
        for token in ["**", "__", "`", "### ", "## ", "# "] { t = t.replacingOccurrences(of: token, with: "") }
        let collapsed = t.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsed.count > 240 ? String(collapsed.prefix(239)) + "…" : collapsed
    }
}
