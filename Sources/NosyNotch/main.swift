import AppKit

// Command line helpers: `NosyNotch --install-hooks` / `--uninstall-hooks`.
let arguments = CommandLine.arguments
if arguments.contains("--install-hooks") || arguments.contains("--uninstall-hooks") {
    Preferences.register()
    do {
        if arguments.contains("--install-hooks") {
            try HookInstaller.install(port: Preferences.port)
            print("✓ Claude Code hooks installed in: \(HookInstaller.settingsSummary)")
            if HookInstaller.Codex.isAvailable {
                try HookInstaller.Codex.install(port: Preferences.port)
                print("✓ Codex hooks installed in: \(HookInstaller.Codex.displayPath) – trust them once in Codex (/hooks)")
            }
        } else {
            try HookInstaller.uninstall()
            try HookInstaller.Codex.uninstall()
            print("✓ Hooks removed from: \(HookInstaller.settingsSummary), \(HookInstaller.Codex.displayPath)")
        }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("✗ \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

// `NosyNotch --record <out-dir> [scene …]`: render every animation to PNG frames (see scripts/record-gifs.sh).
if let index = arguments.firstIndex(of: "--record") {
    let rest = Array(arguments.dropFirst(index + 1))
    let output = URL(fileURLWithPath: rest.first ?? "docs/frames", isDirectory: true)
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let recorder = Recorder(outputDirectory: output, only: Array(rest.dropFirst()))
        DispatchQueue.main.async { MainActor.assumeIsolated { recorder.start() } }
        withExtendedLifetime(recorder) { app.run() }
    }
    exit(0)
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
