import SwiftUI

/// What a Claude Code session is doing right now.
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
        case "Bash", "BashOutput", "KillShell": return "terminal"
        case "Edit", "MultiEdit": return "pencil"
        case "Write": return "square.and.pencil"
        case "Read": return "doc.text"
        case "NotebookEdit": return "book"
        case "Grep": return "magnifyingglass"
        case "Glob", "LS": return "folder"
        case "WebFetch": return "globe"
        case "WebSearch": return "safari"
        case "Task", "Agent": return "person.2"
        case "TodoWrite": return "checklist"
        default:
            return name.hasPrefix("mcp__") ? "puzzlepiece.extension" : "wrench.and.screwdriver"
        }
    }

    var verb: String {
        switch name {
        case "Bash", "BashOutput": return "Führt aus"
        case "Edit", "MultiEdit", "NotebookEdit": return "Bearbeitet"
        case "Write": return "Schreibt"
        case "Read": return "Liest"
        case "Grep", "Glob", "LS": return "Sucht"
        case "WebFetch": return "Lädt"
        case "WebSearch": return "Recherchiert"
        case "Task", "Agent": return "Delegiert"
        case "TodoWrite": return "Plant"
        default: return "Nutzt \(displayName)"
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
        default: raw = str("description") ?? str("command") ?? str("query") ?? file("file_path")
        }
        guard let raw else { return nil }
        let firstLine = raw.split(whereSeparator: \.isNewline).first.map(String.init) ?? raw
        return firstLine.count > 80 ? String(firstLine.prefix(79)) + "…" : firstLine
    }
}

struct Session: Identifiable, Equatable {
    let id: String
    var cwd: String?
    var state: ActivityState = .idle
    var turnStartedAt: Date?
    var lastTurnDuration: TimeInterval?
    var lastUpdate = Date()
    var toolCount = 0
    var lastSummary: String?
    var transcriptPath: String?
    var termProgram: String?
    var hostBundleID: String?

    var projectName: String {
        guard let cwd, !cwd.isEmpty else { return "Claude" }
        return (cwd as NSString).lastPathComponent
    }

    var statusTitle: String {
        switch state {
        case .idle: return "Bereit"
        case .thinking: return "Denkt nach"
        case .tool(let t): return t.verb
        case .waiting: return "Wartet auf dich"
        case .compacting: return "Komprimiert Kontext"
        case .done: return "Fertig"
        case .error: return "Fehler"
        }
    }

    var statusDetail: String? {
        switch state {
        case .tool(let t): return t.detail ?? t.displayName
        case .waiting(let message), .error(let message): return message
        case .done:
            var parts: [String] = []
            if toolCount > 0 { parts.append(Format.toolCalls(toolCount)) }
            if let d = lastTurnDuration { parts.append(Format.duration(d)) }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        default: return nil
        }
    }

    var accent: Color { Theme.color(for: state) }

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

    static func color(for state: ActivityState) -> Color {
        switch state {
        case .idle: return .white.opacity(0.55)
        case .thinking, .tool: return claude
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
            "rate_limit": "Rate-Limit erreicht",
            "overloaded": "API ist überlastet",
            "authentication_failed": "Anmeldung fehlgeschlagen",
            "oauth_org_not_allowed": "Organisation nicht freigegeben",
            "account_on_hold": "Account gesperrt",
            "billing_error": "Problem mit der Abrechnung",
            "invalid_request": "Ungültige Anfrage",
            "model_not_found": "Modell nicht gefunden",
            "server_error": "Serverfehler bei der API",
            "max_output_tokens": "Antwort hat das Token-Limit erreicht",
            "cloud_credential_error": "Cloud-Zugangsdaten ungültig",
        ]
        let title = code.flatMap { known[$0] } ?? "API-Fehler"
        let extra = [details, message].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let extra else { return title }
        let line = extra.split(whereSeparator: \.isNewline).first.map(String.init) ?? extra
        return "\(title) · \(line.count > 90 ? String(line.prefix(89)) + "…" : line)"
    }
}

enum Format {
    static func toolCalls(_ n: Int) -> String {
        n == 1 ? "1 Tool-Aufruf" : "\(n) Tool-Aufrufe"
    }

    static func duration(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded()))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }
}
