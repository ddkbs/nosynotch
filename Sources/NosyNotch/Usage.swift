import Foundation

/// One rate-limit window (5 hours or a week): how much is used and when it resets.
struct UsageWindow: Codable, Equatable {
    var usedPercent: Double
    var resetsAt: Date?

    /// A window whose reset time has passed starts from zero again.
    var current: UsageWindow {
        if let resetsAt, resetsAt < Date() { return UsageWindow(usedPercent: 0, resetsAt: nil) }
        return self
    }
}

struct AgentUsage: Codable, Equatable {
    var fiveHour: UsageWindow?
    var week: UsageWindow?
    var updatedAt = Date()

    var isEmpty: Bool { fiveHour == nil && week == nil }
}

/// Usage limits of Claude (Pro/Max, from Claude Code's status line JSON) and Codex (from its session files).
/// Kept in UserDefaults so the bars survive a restart.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var claude: AgentUsage?
    @Published private(set) var codex: AgentUsage?

    var onChange: (() -> Void)?

    private static let defaultsKey = "usage"
    private let reader = DispatchQueue(label: "dev.davidkubus.nosynotch.usage", qos: .utility)

    init(load: Bool = true) {
        guard load, let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let saved = try? JSONDecoder().decode([String: AgentUsage].self, from: data) else { return }
        claude = saved["claude"]
        codex = saved["codex"]
    }

    /// Agents with data, Claude first.
    var rows: [(agent: Agent, usage: AgentUsage)] {
        var rows: [(Agent, AgentUsage)] = []
        if let claude, !claude.isEmpty { rows.append((.claude, claude)) }
        if let codex, !codex.isEmpty { rows.append((.codex, codex)) }
        return rows
    }

    func set(_ usage: AgentUsage?, for agent: Agent) {
        switch agent {
        case .claude: if claude != usage { claude = usage } else { return }
        case .codex: if codex != usage { codex = usage } else { return }
        }
        save()
        onChange?()
    }

    // MARK: - Claude Code (status line JSON)

    /// Body of `POST /usage`: the JSON Claude Code passes to its status line command.
    func ingestClaudeStatusLine(_ data: Data) {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let limits = json["rate_limits"] as? [String: Any] else { return }
        func window(_ key: String) -> UsageWindow? {
            guard let w = limits[key] as? [String: Any], let used = Self.number(w["used_percentage"]) else { return nil }
            return UsageWindow(usedPercent: used, resetsAt: Self.date(w["resets_at"]))
        }
        let usage = AgentUsage(fiveHour: window("five_hour"), week: window("seven_day"))
        if !usage.isEmpty { set(usage, for: .claude) }
    }

    // MARK: - Codex (session files)

    /// Reads the newest `rate_limits` entry from a Codex session file (or the newest one on disk).
    func refreshCodex(transcriptPath: String? = nil) {
        reader.async { [weak self] in
            let url = transcriptPath.map { URL(fileURLWithPath: $0) } ?? Self.newestCodexSession()
            guard let url, let usage = Self.codexUsage(in: url) else { return }
            Task { @MainActor [weak self] in self?.set(usage, for: .codex) }
        }
    }

    nonisolated static func newestCodexSession() -> URL? {
        let root = HookInstaller.Codex.home.appendingPathComponent("sessions", isDirectory: true)
        let fm = FileManager.default
        // sessions/YYYY/MM/DD/rollout-….jsonl – walk down the newest folders.
        var dir = root
        for _ in 0..<3 {
            let names = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).filter { !$0.hasPrefix(".") }
            guard let newest = names.sorted().last else { return nil }
            dir.appendPathComponent(newest, isDirectory: true)
        }
        let files = ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .filter { $0.pathExtension == "jsonl" }
        return files.max { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da < db
        }
    }

    /// `"rate_limits": {"primary": {"used_percent", "window_minutes", "resets_at"}, "secondary": {…}}`
    nonisolated static func codexUsage(in url: URL) -> AgentUsage? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > 512_000 ? size - 512_000 : 0)
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { return nil }

        for line in text.split(separator: "\n").reversed() where line.contains("\"rate_limits\"") {
            guard let json = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any],
                  let limits = findRateLimits(in: json) else { continue }
            var usage = AgentUsage()
            for key in ["primary", "secondary"] {
                guard let w = limits[key] as? [String: Any], let used = number(w["used_percent"]) else { continue }
                let window = UsageWindow(usedPercent: used, resetsAt: date(w["resets_at"]))
                let minutes = number(w["window_minutes"]) ?? (key == "primary" ? 300 : 10080)
                if minutes <= 24 * 60 { usage.fiveHour = window } else { usage.week = window }
            }
            if !usage.isEmpty { return usage }
        }
        return nil
    }

    private nonisolated static func findRateLimits(in object: Any) -> [String: Any]? {
        if let dict = object as? [String: Any] {
            if let limits = dict["rate_limits"] as? [String: Any] { return limits }
            for value in dict.values { if let found = findRateLimits(in: value) { return found } }
        }
        return nil
    }

    // MARK: - Helpers

    private nonisolated static func number(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    /// Epoch seconds (or milliseconds) or an ISO 8601 string.
    private nonisolated static func date(_ value: Any?) -> Date? {
        if let n = number(value) { return Date(timeIntervalSince1970: n > 1e12 ? n / 1000 : n) }
        if let s = value as? String { return ISO8601DateFormatter().date(from: s) }
        return nil
    }

    private func save() {
        var all: [String: AgentUsage] = [:]
        all["claude"] = claude
        all["codex"] = codex
        if let data = try? JSONEncoder().encode(all) { UserDefaults.standard.set(data, forKey: Self.defaultsKey) }
    }
}
