import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private lazy var store = SessionStore()
    private lazy var nowPlaying = NowPlaying()
    private lazy var approvals = ApprovalCenter()
    private lazy var usage = UsageStore()
    private lazy var model = NotchViewModel(store: store, media: nowPlaying, approvals: approvals, usage: usage)
    private var windowController: NotchWindowController?
    private var server: EventServer?
    private var statusItem: NSStatusItem?
    private var serverError: String?
    private lazy var settings = SettingsWindowController(actions: .init(
        statusLine: { [weak self] in self?.statusLine ?? "" },
        playDemo: { [weak self] in self?.playDemo() },
        settingsChanged: { [weak self] in
            self?.model.objectWillChange.send()
            self?.model.recompute()
        },
        muteChanged: { [weak self] in self?.updateStatusIcon() }
    ))

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.register()

        store.onChange = { [weak self] in self?.model.recompute() }
        store.onTransition = { [weak self] transition in
            // Done / needs you while you're looking at that very app (Claude, terminal, Codex …):
            // stay in the small notch, no sound.
            if let session = transition.quietCandidate, Self.isLookingAt(session) {
                self?.store.markSeen(session.id)
                self?.model.showQuietly(transition)
                return
            }
            self?.model.handle(transition)
            Notifier.notify(transition)
        }

        store.onReminder = { [weak self] transition in
            guard let self, let session = transition.quietCandidate else { return }
            if Self.isLookingAt(session) { return self.store.markSeen(session.id) }
            self.model.handle(transition)
            Notifier.remind(transition)
        }
        // Switching to the app a session runs in counts as "seen".
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                guard let self, let bundleID else { return }
                for session in self.store.unseen where TerminalActivator.runs(session, in: bundleID) {
                    self.store.markSeen(session.id)
                }
            }
        }

        windowController = NotchWindowController(model: model)
        startServer()
        setUpStatusItem()
        Notifier.requestAuthorizationIfNeeded()
        usage.onContext = { [weak self] id, percent in self?.store.setContext(id, percent: percent) }
        if HookInstaller.Codex.isAvailable { usage.refreshCodex() }

        // First launch: open the settings so the one button that matters ("Connect Claude Code") is right there.
        if !UserDefaults.standard.bool(forKey: "didShowWelcome") {
            UserDefaults.standard.set(true, forKey: "didShowWelcome")
            if !HookInstaller.isInstalled { settings.show() }
        }
    }

    private static func isLookingAt(_ session: Session) -> Bool {
        Preferences.quietWhenFocused && TerminalActivator.isFrontmost(session)
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }

    // MARK: - Server

    private func startServer() {
        let server = EventServer(port: Preferences.port) { [weak self] event in
            // Cursor runs our Claude hooks too – with our own Cursor hooks installed that's a duplicate.
            if event.isCursorViaClaudeHook && HookInstaller.Cursor.isInstalledCached { return }
            Task { @MainActor in
                self?.store.handle(event)
                self?.approvals.observe(event)
                if event.agent == .codex, ["SessionStart", "UserPromptSubmit", "Stop"].contains(event.name) {
                    self?.usage.refreshCodex(transcriptPath: event.transcriptPath, sessionID: event.sessionID)
                }
            }
        }
        server.onPermission = { [weak self] event, reply in
            Task { @MainActor in
                guard let self else { return reply(nil) }
                // You're in that app: its own prompt is right in front of you (Codex only shows it once we answer).
                if let session = self.store.sessions[event.sessionID], Self.isLookingAt(session) { return reply(nil) }
                self.approvals.add(event, reply: reply)
            }
        }
        server.onQuit = {
            Task { @MainActor in NSApp.terminate(nil) }
        }
        server.onUsage = { [weak self] data in
            Task { @MainActor in self?.usage.ingestClaudeStatusLine(data) }
        }
        server.onSettings = { [weak self] in
            Task { @MainActor in self?.settings.show() }
        }
        do {
            try server.start()
            self.server = server
        } catch {
            serverError = error.localizedDescription
            NSLog("NosyNotch: could not start server: \(error)")
        }
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Nosy Notch")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        updateStatusIcon()
        // Mute runs out on its own – keep the icon honest.
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateStatusIcon() }
        }
    }

    private var statusLine: String {
        if let serverError { return "⚠︎ Server: \(serverError)" }
        if let error = server?.lastError { return "⚠︎ Server: \(error)" }
        let count = store.sessions.count
        return "Listening on 127.0.0.1:\(Preferences.port) · \(count) session\(count == 1 ? "" : "s")"
    }

    /// Rebuild the menu every time it opens so the status line is current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "Nosy Notch", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        let status = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        if let until = Preferences.mutedUntil {
            menu.addItem(item("Unmute  (\(Self.muteDescription(until)))", #selector(unmute)))
        } else {
            let mute = NSMenuItem(title: "Mute", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for (title, hours) in [("For 1 hour", 1.0), ("For 8 hours", 8.0), ("Until I unmute", 0.0)] {
                let entry = item(title, #selector(muteFromMenu(_:)))
                entry.representedObject = hours
                sub.addItem(entry)
            }
            mute.submenu = sub
            menu.addItem(mute)
        }
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(item("Play demo", #selector(playDemo), key: "d"))
        menu.addItem(.separator())
        menu.addItem(item("Quit", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    /// "until 18:30" / "until you unmute".
    static func muteDescription(_ until: Date) -> String {
        until == .distantFuture || until.timeIntervalSinceNow > 365 * 86_400
            ? "until you unmute" : "until \(until.formatted(date: .omitted, time: .shortened))"
    }

    @objc private func muteFromMenu(_ sender: NSMenuItem) {
        let hours = sender.representedObject as? Double ?? 0
        Preferences.mutedUntil = hours > 0 ? Date().addingTimeInterval(hours * 3600) : .distantFuture
        updateStatusIcon()
    }

    @objc private func unmute() {
        Preferences.mutedUntil = nil
        updateStatusIcon()
    }

    /// The menu bar ✦ gets a slash while muted.
    func updateStatusIcon() {
        let symbol = Preferences.isMuted ? "speaker.slash" : "sparkle"
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Nosy Notch")
    }

    @objc private func openSettings() {
        settings.show()
    }

    @objc private func playDemo() {
        Demo.run(into: store)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
