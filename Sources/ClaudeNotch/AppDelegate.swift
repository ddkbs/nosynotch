import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private lazy var store = SessionStore()
    private lazy var nowPlaying = NowPlaying()
    private lazy var model = NotchViewModel(store: store, media: nowPlaying)
    private var windowController: NotchWindowController?
    private var server: EventServer?
    private var statusItem: NSStatusItem?
    private var serverError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.register()

        store.onChange = { [weak self] in self?.model.recompute() }
        store.onTransition = { [weak self] transition in
            self?.model.handle(transition)
            Notifier.notify(transition)
        }

        windowController = NotchWindowController(model: model)
        startServer()
        setUpStatusItem()
        Notifier.requestAuthorizationIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }

    // MARK: - Server

    private func startServer() {
        let server = EventServer(port: Preferences.port) { [weak self] event in
            Task { @MainActor in self?.store.handle(event) }
        }
        server.onQuit = {
            Task { @MainActor in NSApp.terminate(nil) }
        }
        do {
            try server.start()
            self.server = server
        } catch {
            serverError = error.localizedDescription
            NSLog("ClaudeNotch: could not start server: \(error)")
        }
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Claude Notch")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    /// Rebuild the menu every time it opens so checkmarks are current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "Claude Notch", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let status: String
        if let serverError {
            status = "⚠︎ Server: \(serverError)"
        } else if let error = server?.lastError {
            status = "⚠︎ Server: \(error)"
        } else {
            status = "Listening on 127.0.0.1:\(Preferences.port) · \(store.sessions.count) Session(s)"
        }
        let statusLine = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())

        let installed = HookInstaller.isInstalled
        menu.addItem(item(installed ? "Claude-Code-Hooks entfernen" : "Claude-Code-Hooks installieren…",
                          #selector(toggleHooks)))

        let sound = item("Sounds for done / needs you / error", #selector(toggleSound))
        sound.state = Preferences.soundEnabled ? .on : .off
        menu.addItem(sound)

        let media = item("Media player in the notch (Spotify / Music)", #selector(toggleMedia))
        media.state = Preferences.mediaEnabled ? .on : .off
        menu.addItem(media)

        let notifications = item("macOS-Mitteilungen", #selector(toggleNotifications))
        notifications.state = Preferences.systemNotifications ? .on : .off
        menu.addItem(notifications)

        menu.addItem(.separator())
        menu.addItem(item("Play demo", #selector(playDemo), key: "d"))
        menu.addItem(item("Show settings file", #selector(revealSettings)))
        menu.addItem(.separator())
        menu.addItem(item("Quit", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleHooks() {
        do {
            if HookInstaller.isInstalled {
                try HookInstaller.uninstall()
                alert("Hooks removed", "The hooks were removed from: \(HookInstaller.settingsSummary)")
            } else {
                try HookInstaller.install(port: Preferences.port)
                alert("Hooks installed 🎉",
                      "The hooks are now in: \(HookInstaller.settingsSummary) (settings.json each, backup: settings.json.claude-notch.bak).\n\nClaude Code sessions that are already running pick up the hooks after a restart.")
            }
        } catch {
            alert("Error", error.localizedDescription)
        }
    }

    @objc private func toggleSound() {
        Preferences.soundEnabled.toggle()
    }

    @objc private func toggleMedia() {
        Preferences.mediaEnabled.toggle()
        model.recompute()
    }

    @objc private func toggleNotifications() {
        Preferences.systemNotifications.toggle()
        Notifier.requestAuthorizationIfNeeded()
    }

    @objc private func revealSettings() {
        NSWorkspace.shared.activateFileViewerSelecting([HookInstaller.settingsURL])
    }

    @objc private func playDemo() {
        Demo.run(into: store)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}
