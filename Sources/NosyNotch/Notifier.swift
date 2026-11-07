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

    /// A usage limit that was nearly used up has reset.
    static func limitReset(agent: Agent, window: String) {
        play("Hero", if: Preferences.soundDone, volume: 0.6)
        post(title: "\(agent.name) is ready again", body: "Your \(window) limit just reset.")
    }

    /// The 5-minute reminder: a softer sound, same banner.
    static func remind(_ transition: Transition) {
        switch transition {
        case .finished(let s):
            play("Glass", if: Preferences.soundDone, volume: 0.4)
            post(title: "\(s.projectName) – still unseen", body: s.lastSummary ?? "\(s.agent.name) finished 5 minutes ago.")
        case .needsAttention(let s):
            play("Funk", if: Preferences.soundAttention, volume: 0.5)
            post(title: "\(s.projectName) – \(s.agent.name) is still waiting",
                 body: { if case .waiting(let m) = s.state { return m }; return "Please check your terminal." }())
        default:
            break
        }
    }

    private static func play(_ name: String, if enabled: Bool, volume: Float = 1) {
        let focusing = FocusTimer.shared.isFocusing && Preferences.focusMutesAlerts
        guard enabled, !Preferences.isMuted, !focusing, let sound = NSSound(named: NSSound.Name(name))?.copy() as? NSSound else { return }
        sound.volume = volume
        sound.play()
    }

    private static func post(title: String, body: String) {
        guard canUseUserNotifications, Preferences.systemNotifications, !Preferences.isMuted else { return }
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

    private static func candidates(for session: Session) -> [String] {
        var candidates: [String] = []
        if let b = session.hostBundleID { candidates.append(b) }
        if let t = session.termProgram, let b = termProgramBundles[t] { candidates.append(b) }
        // No hint from the hook's environment: the agent's own app (Cursor, the ChatGPT app for Codex).
        if candidates.isEmpty {
            switch session.agent {
            case .cursor: candidates.append("com.todesktop.230313mzl4w4u92")
            case .codex: candidates.append("com.openai.codex")
            case .claude: candidates.append("com.anthropic.claudefordesktop")
            }
        }
        return candidates
    }

    /// The app instance the session runs in: walk up from the agent's process to the first regular app. Finds the
    /// right one even with two copies of the same app open (e.g. two Claude accounts).
    static func hostApp(for session: Session) -> NSRunningApplication? {
        var pid = session.hostPID
        for _ in 0..<24 {
            guard let current = pid, current > 1 else { return nil }
            if let app = NSRunningApplication(processIdentifier: current), app.activationPolicy == .regular { return app }
            pid = parentPID(of: current)
        }
        return nil
    }

    private static func parentPID(of pid: pid_t) -> pid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let parent = info.kp_eproc.e_ppid
        return parent > 1 ? parent : nil
    }

    /// The app the session runs in (Claude desktop app, terminal, VS Code, ChatGPT …) is the frontmost app.
    static func isFrontmost(_ session: Session) -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }
        if let host = hostApp(for: session) { return host.processIdentifier == front.processIdentifier }
        guard let bundleID = front.bundleIdentifier else { return false }
        return candidates(for: session).contains(bundleID)
    }

    static func runs(_ session: Session, in bundleID: String) -> Bool {
        candidates(for: session).contains(bundleID)
    }

    static func activate(_ session: Session) {
        if let host = hostApp(for: session) {
            host.activate()
            return
        }
        let candidates = candidates(for: session)

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
