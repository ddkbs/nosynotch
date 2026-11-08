import SwiftUI

/// Which coding agent a session belongs to.
enum Agent: String, Equatable {
    case claude, codex, cursor

    init(query value: String?) {
        self = Agent(rawValue: value?.lowercased() ?? "") ?? .claude
    }

    var name: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        }
    }

    /// Colour while the agent is thinking / working.
    var color: Color {
        switch self {
        case .claude: return Theme.claude
        case .codex: return Theme.codex
        case .cursor: return Theme.cursor
        }
    }
}

/// What a Claude Code / Codex session is doing right now.
enum ActivityState: Equatable {
    case idle
    case thinking
    case tool(ToolActivity)
    case waiting(message: String)
    case compacting
    case done
    /// The turn ended because of an API error (rate limit, overload, auth …).
    case error(message: String)

    var isActive: Bool {
        switch self {
        case .thinking, .tool, .compacting: return true
        default: return false
        }
    }
}

struct ToolActivity: Equatable {
    let name: String
    let detail: String?

    var symbol: String {
        switch name {
        case "Bash", "BashOutput", "KillShell", "Shell", "run_terminal_cmd": return "terminal"
        case "edit_file", "search_replace", "StrReplace": return "pencil"
        case "read_file": return "doc.text"
        case "codebase_search", "grep_search", "file_search": return "magnifyingglass"
        case "Edit", "MultiEdit": return "pencil"
        case "Write": return "square.and.pencil"
        case "Read": return "doc.text"
        case "NotebookEdit": return "book"
        case "Grep": return "magnifyingglass"
        case "Glob", "LS": return "folder"
        case "WebFetch": return "globe"
        case "WebSearch": return "safari"
        case "Task", "Agent": return "person.2"
        case "TodoWrite", "update_plan": return "checklist"
        case "apply_patch": return "pencil"
        case "web_search": return "safari"
        case "view_image": return "photo"
        default:
            return name.hasPrefix("mcp__") ? "puzzlepiece.extension" : "wrench.and.screwdriver"
        }
    }

    var verb: String {
        switch name {
        case "Bash", "BashOutput", "Shell", "run_terminal_cmd": return "Running"
        case "edit_file", "search_replace", "StrReplace": return "Editing"
        case "read_file": return "Reading"
        case "codebase_search", "grep_search", "file_search": return "Searching"
        case "Edit", "MultiEdit", "NotebookEdit": return "Editing"
        case "Write": return "Writing"
        case "Read": return "Reading"
        case "Grep", "Glob", "LS": return "Searching"
        case "WebFetch": return "Fetching"
        case "WebSearch": return "Researching"
        case "Task", "Agent": return "Delegating"
        case "TodoWrite", "update_plan": return "Planning"
        case "apply_patch": return "Editing"
        case "web_search": return "Researching"
        case "view_image": return "Looking"
        default: return "Using \(displayName)"
        }
    }

    var displayName: String {
        guard name.hasPrefix("mcp__") else { return name }
        let parts = name.split(separator: "_", omittingEmptySubsequences: true)
        // mcp__server__tool -> "server · tool"
        if parts.count >= 3 { return "\(parts[1]) · \(parts[2...].joined(separator: "_"))" }
        return name
    }

    init(name: String, input: [String: Any]) {
        self.name = name
        self.detail = ToolActivity.describe(name: name, input: input)
    }

    init(name: String, detail: String?) {
        self.name = name
        self.detail = detail
    }

    private static func describe(name: String, input: [String: Any]) -> String? {
        func str(_ key: String) -> String? {
            guard let v = input[key] as? String, !v.isEmpty else { return nil }
            return v
        }
        func file(_ key: String) -> String? {
            str(key).map { ($0 as NSString).lastPathComponent }
        }
        let raw: String?
        switch name {
        case "Bash": raw = str("description") ?? str("command")
        case "Edit", "MultiEdit", "Write", "Read": raw = file("file_path")
        case "NotebookEdit": raw = file("notebook_path")
        case "Grep", "Glob": raw = str("pattern")
        case "LS": raw = file("path")
        case "WebFetch": raw = str("url").flatMap { URL(string: $0)?.host } ?? str("url")
        case "WebSearch": raw = str("query")
        case "Task", "Agent": raw = str("description") ?? str("subagent_type")
        case "apply_patch": raw = patchFiles(str("command") ?? str("input") ?? str("patch"))
        default: raw = str("description") ?? str("command") ?? str("query") ?? file("file_path") ?? file("target_file")
            ?? file("path")
        }
        guard let raw else { return nil }
        if name == "apply_patch" { return raw }
        let firstLine = raw.split(whereSeparator: \.isNewline).first.map(String.init) ?? raw
        return firstLine.count > 80 ? String(firstLine.prefix(79)) + "…" : firstLine
    }
}

extension ToolActivity {
    /// Codex `apply_patch`: "*** Update File: Sources/App.swift" → "App.swift" (+ "and 2 more").
    fileprivate static func patchFiles(_ patch: String?) -> String? {
        guard let patch else { return nil }
        let prefixes = ["*** Update File: ", "*** Add File: ", "*** Delete File: "]
        let files = patch.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            guard let prefix = prefixes.first(where: { line.hasPrefix($0) }) else { return nil }
            return (String(line.dropFirst(prefix.count)) as NSString).lastPathComponent
        }
        guard let first = files.first else { return nil }
        return files.count == 1 ? first : "\(first) and \(files.count - 1) more"
    }
}

/// How far the agent is through its own task list. Claude Code either sends the whole list (`TodoWrite`, the desktop
/// app's plan tool) or one change at a time (`TaskCreate` / `TaskUpdate`), Codex its `update_plan`.
struct TodoProgress: Equatable {
    /// Step id → status ("pending", "in_progress", "completed").
    private var steps: [String: String] = [:]
    /// `TaskCreate` numbers its tasks through the whole session, also after the list was cleared.
    private var created = 0

    var total: Int { steps.count }
    var done: Int { steps.values.filter { $0 == "completed" }.count }
    var isFinished: Bool { total > 0 && done == total }

    mutating func clear() { steps = [:] }

    /// Reads a tool call. Anything that isn't a task-list tool changes nothing.
    mutating func apply(tool: String, input: [String: Any]) {
        switch tool {
        case "TodoWrite": replace(input["todos"])
        case "update_plan": replace(input["plan"])
        case "TaskCreate":
            created += 1
            steps[String(created)] = "pending"
        case "TaskUpdate":
            guard let id = input["taskId"] as? String, let status = input["status"] as? String else { return }
            created = max(created, Int(id) ?? 0)
            steps[id] = status == "deleted" ? nil : status
        default:
            if tool.hasSuffix("__update_plan") { updatePlan(input) }
        }
    }

    private mutating func replace(_ list: Any?) {
        guard let list = list as? [[String: Any]] else { return }
        steps = [:]
        for (index, step) in list.enumerated() { steps[String(index + 1)] = step["status"] as? String ?? "pending" }
    }

    /// The desktop app's plan tool: a whole list, or moves ("advance", "done", "start") on the one it already has.
    private mutating func updatePlan(_ input: [String: Any]) {
        if input["items"] != nil { return replace(input["items"]) }
        if input["advance"] as? Bool == true {
            let order = steps.keys.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
            if let current = order.first(where: { steps[$0] == "in_progress" }) { steps[current] = "completed" }
            if let next = order.first(where: { steps[$0] == "pending" }) { steps[next] = "in_progress" }
        }
        for number in input["done"] as? [Int] ?? [] where steps[String(number)] != nil { steps[String(number)] = "completed" }
        if let number = input["start"] as? Int, steps[String(number)] != nil { steps[String(number)] = "in_progress" }
    }
}

struct Session: Identifiable, Equatable {
    let id: String
    var agent: Agent = .claude
    var cwd: String?
    var state: ActivityState = .idle
    var turnStartedAt: Date?
    var lastTurnDuration: TimeInterval?
    var lastUpdate = Clock.now()
    var toolCount = 0
    var lastSummary: String?
    var transcriptPath: String?
    var termProgram: String?
    var hostBundleID: String?
    /// The agent's process id (from the hook) – leads to the exact app instance.
    var hostPID: Int32?
    /// Finished while you weren't looking – shown as a green dot until you look at it.
    var unseenSince: Date?
    /// When the session started waiting for you (for the 5-minute reminder).
    var waitingSince: Date?
    /// The 5-minute reminder for the current "done" / "waiting" already went off.
    var reminded = false
    /// How full the context window is (0–100), when the agent tells us.
    var contextPercent: Double?
    /// The agent's own task list, when it keeps one.
    var todos = TodoProgress()

    var isUnseen: Bool { unseenSince != nil }

    /// Working, or waiting for an answer: a new prompt has to wait its turn.
    var isBusy: Bool {
        if case .waiting = state { return true }
        return state.isActive
    }

    var projectName: String {
        guard let cwd, !cwd.isEmpty else { return agent.name }
        return (cwd as NSString).lastPathComponent
    }

    var statusTitle: String {
        switch state {
        case .idle: return "Ready"
        case .thinking: return "Thinking"
        case .tool(let t): return t.verb
        case .waiting: return "Waiting for you"
        case .compacting: return "Compacting context"
        case .done: return "Done"
        case .error: return "Error"
        }
    }

    var statusDetail: String? {
        switch state {
        case .tool(let t): return t.detail ?? t.displayName
        case .waiting(let message), .error(let message): return message
        case .done:
            var parts: [String] = []
            if toolCount > 0 { parts.append(Format.toolCalls(toolCount)) }
            if let d = lastTurnDuration, d >= 1 { parts.append(Format.duration(d)) }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        default: return nil
        }
    }

    var accent: Color { Theme.color(for: state, agent: agent) }

    /// Higher = more important to show in the compact notch.
    var priority: Int {
        switch state {
        case .waiting, .error: return 4
        case .tool, .thinking, .compacting: return 3
        case .done: return 2
        case .idle: return 1
        }
    }
}

enum Theme {
    static let claude = Color(red: 0.851, green: 0.467, blue: 0.341)     // #D97757
    static let amber = Color(red: 0.961, green: 0.647, blue: 0.141)      // #F5A524
    static let success = Color(red: 0.290, green: 0.871, blue: 0.502)    // #4ADE80
    static let violet = Color(red: 0.655, green: 0.545, blue: 0.980)     // #A78BFA
    static let danger = Color(red: 0.973, green: 0.443, blue: 0.443)     // #F87171
    static let codex = Color(red: 0.502, green: 0.667, blue: 1.0)        // #80AAFF
    static let cursor = Color(red: 0.82, green: 0.84, blue: 0.88)        // #D1D6E0

    static func color(for state: ActivityState, agent: Agent = .claude) -> Color {
        switch state {
        case .idle: return .white.opacity(0.55)
        case .thinking, .tool: return agent.color
        case .waiting: return amber
        case .compacting: return violet
        case .done: return success
        case .error: return danger
        }
    }
}

enum APIErrorText {
    /// Human-readable text for the `error` field of a `StopFailure` hook.
    static func describe(code: String?, details: String?, message: String?) -> String {
        let known: [String: String] = [
            "rate_limit": "Rate limit reached",
            "overloaded": "API is overloaded",
            "authentication_failed": "Authentication failed",
            "oauth_org_not_allowed": "Organization not allowed",
            "account_on_hold": "Account on hold",
            "billing_error": "Billing problem",
            "invalid_request": "Invalid request",
            "model_not_found": "Model not found",
            "server_error": "API server error",
            "max_output_tokens": "Response hit the token limit",
            "cloud_credential_error": "Cloud credentials invalid",
        ]
        let title = code.flatMap { known[$0] } ?? "API error"
        let extra = [details, message].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let extra else { return title }
        let line = extra.split(whereSeparator: \.isNewline).first.map(String.init) ?? extra
        return "\(title) · \(line.count > 90 ? String(line.prefix(89)) + "…" : line)"
    }
}

enum Format {
    static func toolCalls(_ n: Int) -> String {
        n == 1 ? "1 tool call" : "\(n) tool calls"
    }

    static func duration(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded()))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }
}
