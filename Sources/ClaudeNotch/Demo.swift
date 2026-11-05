import Foundation

/// Plays a scripted Claude Code session so you can see every animation without running Claude.
@MainActor
enum Demo {
    static func run(into store: SessionStore) {
        let id = "demo-\(Int(Date().timeIntervalSince1970))"
        let cwd = "/Users/you/Projects/claude-notch"

        let steps: [(TimeInterval, HookEvent)] = [
            (0.0, HookEvent(name: "SessionStart", sessionID: id, cwd: cwd)),
            (0.4, HookEvent(name: "UserPromptSubmit", sessionID: id, cwd: cwd, prompt: "Bau mir eine Notch-App")),
            (3.0, HookEvent(name: "PreToolUse", sessionID: id, cwd: cwd, toolName: "Glob", toolInput: ["pattern": "**/*.swift"])),
            (4.2, HookEvent(name: "PostToolUse", sessionID: id, cwd: cwd, toolName: "Glob")),
            (5.0, HookEvent(name: "PreToolUse", sessionID: id, cwd: cwd, toolName: "Read", toolInput: ["file_path": "\(cwd)/Sources/NotchView.swift"])),
            (6.2, HookEvent(name: "PostToolUse", sessionID: id, cwd: cwd, toolName: "Read")),
            (7.5, HookEvent(name: "PreToolUse", sessionID: id, cwd: cwd, toolName: "Edit", toolInput: ["file_path": "\(cwd)/Sources/NotchView.swift"])),
            (9.0, HookEvent(name: "PostToolUse", sessionID: id, cwd: cwd, toolName: "Edit")),
            (9.6, HookEvent(name: "Notification", sessionID: id, cwd: cwd, message: "Claude needs your permission to use Bash")),
            (13.0, HookEvent(name: "PreToolUse", sessionID: id, cwd: cwd, toolName: "Bash", toolInput: ["command": "swift build -c release", "description": "Build release"])),
            (16.0, HookEvent(name: "PostToolUse", sessionID: id, cwd: cwd, toolName: "Bash")),
            (18.0, HookEvent(name: "Stop", sessionID: id, cwd: cwd,
                             lastAssistantMessage: "Die Notch-App ist fertig: Hooks installiert, Animationen für Denken, Tools, Rückfragen und Fertig-Status eingebaut.")),
            (40.0, HookEvent(name: "SessionEnd", sessionID: id, cwd: cwd)),
        ]

        for (delay, event) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                MainActor.assumeIsolated { store.handle(event) }
            }
        }
    }
}
