import Foundation

/// Adds / removes the Nosy Notch hooks in `settings.json` of every Claude Code config directory:
/// `~/.claude`, `$CLAUDE_CONFIG_DIR` and any `~/.claude-*` folder that looks like one (people who run
/// several accounts side by side point `CLAUDE_CONFIG_DIR` at e.g. `~/.claude-work`).
///
/// Every hook is a one-line `curl` that forwards the hook's stdin JSON to the app. If the app isn't
/// running, curl fails instantly and `|| true` keeps Claude Code happy – hooks never block Claude.
enum HookInstaller {
    static let marker = "nosynotch"
    /// Marker used before the rename – such hooks are replaced on install and removed on uninstall.
    static let legacyMarkers = ["claude-notch"]

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

    /// `agent` is added to the URL for every agent but Claude (whose hook command stays unchanged since 0.1.0).
    static func command(port: UInt16, agent: Agent = .claude) -> String {
        let query = agent == .claude ? "src=\(marker)" : "src=\(marker)&agent=\(agent.rawValue)"
        return [
            "curl -s -m 2 -X POST",
            "-H 'Content-Type: application/json'",
            "-H 'Expect:'",
            "-H \"X-Term-Program: ${TERM_PROGRAM:-}\"",
            "-H \"X-Bundle-Id: ${__CFBundleIdentifier:-}\"",
            "--data-binary @-",
            "'http://127.0.0.1:\(port)/event?\(query)'",
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
        // Only the current command counts – hooks from an older version get replaced on install.
        let current = command(port: Preferences.port)
        return events.allSatisfy { event in
            ((hooks[event.name] as? [[String: Any]]) ?? []).contains { group in
                ((group["hooks"] as? [[String: Any]]) ?? []).contains { ($0["command"] as? String) == current }
            }
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

    fileprivate static func isOurs(_ group: [String: Any]) -> Bool {
        let hooks = (group["hooks"] as? [[String: Any]]) ?? []
        return hooks.contains { hook in
            let command = (hook["command"] as? String) ?? ""
            return ([marker] + legacyMarkers).contains { command.contains($0) }
        }
    }

    fileprivate static func load(_ url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        if data.isEmpty { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "NosyNotch", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "\(url.path) is not a JSON object – please check it manually.",
            ])
        }
        return object
    }

    fileprivate static func save(_ settings: [String: Any], to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Keep a backup of whatever was there before we touched it.
        if fm.fileExists(atPath: url.path) {
            let backup = url.appendingPathExtension("nosynotch.bak")
            try? fm.removeItem(at: backup)
            try fm.copyItem(at: url, to: backup)
        }

        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
    }
}

// MARK: - Codex

extension HookInstaller {
    /// Codex (CLI and the Codex mode of the ChatGPT desktop app) reads hooks from `~/.codex/hooks.json`
    /// (or `$CODEX_HOME/hooks.json`). The format matches Claude Code's `hooks` block. Codex skips new or
    /// changed hooks until the user trusts them once (`/hooks` in the CLI, Settings → Hooks in the app).
    enum Codex {
        static let events: [(name: String, matcher: String?, timeout: Int)] = [
            ("SessionStart", nil, 5),
            ("SessionEnd", nil, 3),       // Codex caps SessionEnd and Interrupt at 3 s
            ("UserPromptSubmit", nil, 5),
            ("PreToolUse", "*", 5),
            ("PostToolUse", "*", 5),
            ("PermissionRequest", "*", 5),
            ("Stop", nil, 5),
            ("Interrupt", nil, 3),
            ("SubagentStop", nil, 5),
            ("PreCompact", nil, 5),
        ]

        static var home: URL {
            if let env = ProcessInfo.processInfo.environment["CODEX_HOME"], !env.isEmpty {
                return URL(fileURLWithPath: (env as NSString).expandingTildeInPath, isDirectory: true)
            }
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        }

        static var hooksURL: URL { home.appendingPathComponent("hooks.json") }

        /// Codex has been used on this Mac (its home folder exists).
        static var isAvailable: Bool { FileManager.default.fileExists(atPath: home.path) }

        static var displayPath: String {
            hooksURL.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
        }

        static var isInstalled: Bool {
            guard let file = try? load(hooksURL), let hooks = file["hooks"] as? [String: Any] else { return false }
            let current = command(port: Preferences.port, agent: .codex)
            return events.allSatisfy { event in
                ((hooks[event.name] as? [[String: Any]]) ?? []).contains { group in
                    ((group["hooks"] as? [[String: Any]]) ?? []).contains { ($0["command"] as? String) == current }
                }
            }
        }

        static func install(port: UInt16 = EventServer.defaultPort) throws {
            var file = try load(hooksURL)
            var hooks = (file["hooks"] as? [String: Any]) ?? [:]
            for event in events {
                var groups = ((hooks[event.name] as? [[String: Any]]) ?? []).filter { !isOurs($0) }
                var group: [String: Any] = [
                    "hooks": [["type": "command", "command": command(port: port, agent: .codex), "timeout": event.timeout]],
                ]
                if let matcher = event.matcher { group["matcher"] = matcher }
                groups.append(group)
                hooks[event.name] = groups
            }
            file["hooks"] = hooks
            try save(file, to: hooksURL)
        }

        static func uninstall() throws {
            guard FileManager.default.fileExists(atPath: hooksURL.path) else { return }
            var file = try load(hooksURL)
            guard var hooks = file["hooks"] as? [String: Any] else { return }
            for (name, value) in hooks {
                guard let groups = value as? [[String: Any]] else { continue }
                let remaining = groups.filter { !isOurs($0) }
                hooks[name] = remaining.isEmpty ? nil : remaining
            }
            file["hooks"] = hooks.isEmpty ? nil : hooks
            try save(file, to: hooksURL)
        }
    }
}
