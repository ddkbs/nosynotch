import Foundation

/// Adds / removes the claude-notch hooks in `settings.json` of every Claude Code config directory:
/// `~/.claude`, `$CLAUDE_CONFIG_DIR` and any `~/.claude-*` folder that looks like one (people who run
/// several accounts side by side point `CLAUDE_CONFIG_DIR` at e.g. `~/.claude-work`).
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
        ("PostToolUseFailure", "*"),
        ("PermissionRequest", "*"),
        ("Notification", nil),
        ("Stop", nil),
        ("StopFailure", nil),
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

    /// All Claude Code config directories on this Mac, `~/.claude` first.
    static var configDirectories: [URL] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var dirs = [home.appendingPathComponent(".claude", isDirectory: true)]

        if let env = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], !env.isEmpty {
            dirs.append(URL(fileURLWithPath: (env as NSString).expandingTildeInPath, isDirectory: true))
        }
        let names = (try? fm.contentsOfDirectory(atPath: home.path)) ?? []
        for name in names.sorted() where name.hasPrefix(".claude-") || name.hasPrefix(".claude_") {
            guard name != ".claude-notch" else { continue }
            let dir = home.appendingPathComponent(name, isDirectory: true)
            let looksLikeConfig = ["settings.json", "projects", ".credentials.json"].contains {
                fm.fileExists(atPath: dir.appendingPathComponent($0).path)
            }
            if looksLikeConfig { dirs.append(dir) }
        }

        var seen = Set<String>()
        return dirs.filter { seen.insert($0.standardizedFileURL.resolvingSymlinksInPath().path).inserted }
    }

    static var settingsURLs: [URL] {
        configDirectories.map { $0.appendingPathComponent("settings.json") }
    }

    /// The primary settings file (`~/.claude/settings.json`).
    static var settingsURL: URL { settingsURLs[0] }

    /// Human-readable list of the settings files we touch, e.g. "~/.claude, ~/.claude-work".
    static var settingsSummary: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return settingsURLs
            .map { $0.deletingLastPathComponent().path.replacingOccurrences(of: home, with: "~") }
            .joined(separator: ", ")
    }

    static var isInstalled: Bool {
        settingsURLs.allSatisfy { isInstalled(at: $0) }
    }

    static func isInstalled(at url: URL) -> Bool {
        guard let settings = try? load(url), let hooks = settings["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { event in
            ((hooks[event.name] as? [[String: Any]]) ?? []).contains(where: isOurs)
        }
    }

    static func install(port: UInt16 = EventServer.defaultPort) throws {
        for url in settingsURLs { try install(port: port, at: url) }
    }

    static func uninstall() throws {
        for url in settingsURLs where FileManager.default.fileExists(atPath: url.path) { try uninstall(at: url) }
    }

    private static func install(port: UInt16, at url: URL) throws {
        var settings = try load(url)
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
        try save(settings, to: url)
    }

    private static func uninstall(at url: URL) throws {
        var settings = try load(url)
        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for (name, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            let remaining = groups.filter { !isOurs($0) }
            hooks[name] = remaining.isEmpty ? nil : remaining
        }
        settings["hooks"] = hooks.isEmpty ? nil : hooks
        try save(settings, to: url)
    }

    // MARK: - Helpers

    private static func isOurs(_ group: [String: Any]) -> Bool {
        let hooks = (group["hooks"] as? [[String: Any]]) ?? []
        return hooks.contains { (($0["command"] as? String) ?? "").contains(marker) }
    }

    private static func load(_ url: URL) throws -> [String: Any] {
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

    private static func save(_ settings: [String: Any], to url: URL) throws {
        let fm = FileManager.default
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
