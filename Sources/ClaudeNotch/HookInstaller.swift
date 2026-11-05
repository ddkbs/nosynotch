import Foundation

/// Adds / removes the claude-notch hooks in `~/.claude/settings.json`.
///
/// Every hook is a one-line `curl` that forwards the hook's stdin JSON to the app. If the app isn't
/// running, curl fails instantly and `|| true` keeps Claude Code happy – hooks never block Claude.
enum HookInstaller {
    static let marker = "claude-notch"

    /// Events we listen to. Tool events get the `*` matcher.
    static let events: [(name: String, matcher: String?)] = [
        ("SessionStart", nil),
        ("SessionEnd", nil),
        ("UserPromptSubmit", nil),
        ("PreToolUse", "*"),
        ("PostToolUse", "*"),
        ("Notification", nil),
        ("Stop", nil),
        ("SubagentStop", nil),
        ("PreCompact", nil),
    ]

    static func command(port: UInt16) -> String {
        [
            "curl -s -m 2 -X POST",
            "-H 'Content-Type: application/json'",
            "-H 'Expect:'",
            "-H \"X-Term-Program: ${TERM_PROGRAM:-}\"",
            "-H \"X-Bundle-Id: ${__CFBundleIdentifier:-}\"",
            "--data-binary @-",
            "'http://127.0.0.1:\(port)/event?src=\(marker)'",
            ">/dev/null 2>&1 || true",
        ].joined(separator: " ")
    }

    static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    static var isInstalled: Bool {
        guard let settings = try? load(), let hooks = settings["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { event in
            ((hooks[event.name] as? [[String: Any]]) ?? []).contains(where: isOurs)
        }
    }

    static func install(port: UInt16 = EventServer.defaultPort) throws {
        var settings = try load()
        var hooks = (settings["hooks"] as? [String: Any]) ?? [:]

        for event in events {
            var groups = ((hooks[event.name] as? [[String: Any]]) ?? []).filter { !isOurs($0) }
            var group: [String: Any] = [
                "hooks": [["type": "command", "command": command(port: port), "timeout": 5]],
            ]
            if let matcher = event.matcher { group["matcher"] = matcher }
            groups.append(group)
            hooks[event.name] = groups
        }

        settings["hooks"] = hooks
        try save(settings)
    }

    static func uninstall() throws {
        var settings = try load()
        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for (name, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            let remaining = groups.filter { !isOurs($0) }
            hooks[name] = remaining.isEmpty ? nil : remaining
        }
        settings["hooks"] = hooks.isEmpty ? nil : hooks
        try save(settings)
    }

    // MARK: - Helpers

    private static func isOurs(_ group: [String: Any]) -> Bool {
        let hooks = (group["hooks"] as? [[String: Any]]) ?? []
        return hooks.contains { (($0["command"] as? String) ?? "").contains(marker) }
    }

    private static func load() throws -> [String: Any] {
        let url = settingsURL
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        if data.isEmpty { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "ClaudeNotch", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "\(url.path) ist kein JSON-Objekt – bitte manuell prüfen.",
            ])
        }
        return object
    }

    private static func save(_ settings: [String: Any]) throws {
        let fm = FileManager.default
        let url = settingsURL
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Keep a backup of whatever was there before we touched it.
        if fm.fileExists(atPath: url.path) {
            let backup = url.appendingPathExtension("claude-notch.bak")
            try? fm.removeItem(at: backup)
            try fm.copyItem(at: url, to: backup)
        }

        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
    }
}
