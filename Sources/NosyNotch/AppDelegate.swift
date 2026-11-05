import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private lazy var store = SessionStore()
    private lazy var nowPlaying = NowPlaying()
    private lazy var approvals = ApprovalCenter()
    private lazy var model = NotchViewModel(store: store, media: nowPlaying, approvals: approvals)
    private var windowController: NotchWindowController?
    private var server: EventServer?
    private var statusItem: NSStatusItem?
    private var serverError: String?
    private lazy var settings = SettingsWindowController(actions: .init(
        statusLine: { [weak self] in self?.statusLine ?? "" },
        playDemo: { [weak self] in self?.playDemo() },
        settingsChanged: { [weak self] in self?.model.recompute() }
    ))

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.register()

        store.onChange = { [weak self] in self?.model.recompute() }
        store.onTransition = { [weak self] transition in
            // Done while you're looking at that very app (Claude, terminal, Codex …): small check, no sound.
            if case .finished(let session) = transition, Preferences.quietWhenFocused,
               TerminalActivator.isFrontmost(session) {
                self?.model.showQuietly(transition)
                return
            }
            self?.model.handle(transition)
            Notifier.notify(transition)
        }

        windowController = NotchWindowController(model: model)
        startServer()
        setUpStatusItem()
        Notifier.requestAuthorizationIfNeeded()

        // First launch: open the settings so the one button that matters ("Connect Claude Code") is right there.
        if !UserDefaults.standard.bool(forKey: "didShowWelcome") {
            UserDefaults.standard.set(true, forKey: "didShowWelcome")
            if !HookInstaller.isInstalled { settings.show() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }

    // MARK: - Server

    private func startServer() {
        let server = EventServer(port: Preferences.port) { [weak self] event in
            Task { @MainActor in
                self?.store.handle(event)
                self?.approvals.observe(event)
            }
        }
        server.onPermission = { [weak self] event, reply in
            Task { @MainActor in
                guard let self else { return reply(nil) }
                self.approvals.add(event, reply: reply)
            }
        }
        server.onQuit = {
            Task { @MainActor in NSApp.terminate(nil) }
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
