import AppKit

// Command line helpers: `ClaudeNotch --install-hooks` / `--uninstall-hooks`.
let arguments = CommandLine.arguments
if arguments.contains("--install-hooks") || arguments.contains("--uninstall-hooks") {
    Preferences.register()
    do {
        if arguments.contains("--install-hooks") {
            try HookInstaller.install(port: Preferences.port)
            print("✓ Hooks installiert in: \(HookInstaller.settingsSummary)")
        } else {
            try HookInstaller.uninstall()
            print("✓ Hooks entfernt aus: \(HookInstaller.settingsSummary)")
        }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("✗ \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)   // no Dock icon, no app menu
    withExtendedLifetime(delegate) {
        app.run()
    }
}
