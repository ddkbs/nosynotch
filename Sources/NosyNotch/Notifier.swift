import AppKit
import UserNotifications

/// Sounds + (optional) macOS notifications. The notch animation itself lives in the views.
@MainActor
enum Notifier {
    /// UNUserNotificationCenter crashes when the binary isn't inside an .app bundle (e.g. `swift run`).
    private static var canUseUserNotifications: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    static func requestAuthorizationIfNeeded() {
        guard canUseUserNotifications, Preferences.systemNotifications else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notify(_ transition: Transition) {
        switch transition {
        case .finished(let s):
            play("Glass", if: Preferences.soundDone)
            post(title: "\(s.projectName) – done",
                 body: s.lastSummary ?? s.statusDetail ?? "\(s.agent.name) is done.")
        case .needsAttention(let s):
            play("Funk", if: Preferences.soundAttention)
            post(title: "\(s.projectName) – \(s.agent.name) needs you",
                 body: { if case .waiting(let m) = s.state { return m }; return "Please check your terminal." }())
        case .failed(let s):
            play("Basso", if: Preferences.soundError)
            post(title: "\(s.projectName) – error",
                 body: { if case .error(let m) = s.state { return m }; return "The turn was aborted." }())
        case .started:
            break
        }
    }

    private static func play(_ name: String, if enabled: Bool) {
        guard enabled else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    private static func post(title: String, body: String) {
        guard canUseUserNotifications, Preferences.systemNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

/// Brings the terminal / editor that runs a session to the front.
@MainActor
enum TerminalActivator {
    private static let termProgramBundles: [String: String] = [
        "iTerm.app": "com.googlecode.iterm2",
        "Apple_Terminal": "com.apple.Terminal",
        "vscode": "com.microsoft.VSCode",
        "WarpTerminal": "dev.warp.Warp-Stable",
        "ghostty": "com.mitchellh.ghostty",
        "WezTerm": "com.github.wez.wezterm",
        "Hyper": "co.zeit.hyper",
        "tmux": "com.apple.Terminal",
    ]

    static func activate(_ session: Session) {
        var candidates: [String] = []
        if let b = session.hostBundleID { candidates.append(b) }
        if let t = session.termProgram, let b = termProgramBundles[t] { candidates.append(b) }

        for bundleID in candidates {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                app.activate()
                return
            }
        }
        if let bundleID = candidates.first,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        }
    }
}
