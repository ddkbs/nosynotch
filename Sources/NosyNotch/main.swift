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
            if HookInstaller.Cursor.isAvailable {
                try HookInstaller.Cursor.install(port: Preferences.port)
                print("✓ Cursor hooks installed in: \(HookInstaller.Cursor.displayPath)")
            }
        } else {
            try HookInstaller.uninstall()
            try HookInstaller.Codex.uninstall()
            try HookInstaller.Cursor.uninstall()
            print("✓ Hooks removed from: \(HookInstaller.settingsSummary), \(HookInstaller.Codex.displayPath), \(HookInstaller.Cursor.displayPath)")
        }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("✗ \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

// `NosyNotch --nosy-sheet <file.png>`: every Nosy mood on one image.
if let index = arguments.firstIndex(of: "--nosy-sheet") {
    let output = URL(fileURLWithPath: arguments.dropFirst(index + 1).first ?? "nosy.png")
    MainActor.assumeIsolated { NosySheet.render(to: output) }
    exit(0)
}

// `NosyNotch --ports`: the listening ports the notch would show, with who opened them.
if arguments.contains("--ports") {
    let ports = MainActor.assumeIsolated { PortScan.run() }
    for p in ports {
        let flags = [p.isDev ? "dev" : "app", p.exposed ? "network" : "local", p.needsConfirm ? "confirm" : nil].compactMap { $0 }
        print(":\(p.port)\t\(p.label) (\(p.process), pid \(p.pid))\t\(p.folderName ?? "–")\t\(p.origin)\t[\(flags.joined(separator: ", "))]")
    }
    exit(0)
}

// `NosyNotch --record-settings <out-dir>`: the settings window, page by page.
if let index = arguments.firstIndex(of: "--record-settings") {
    let output = URL(fileURLWithPath: arguments.dropFirst(index + 1).first ?? "docs/frames", isDirectory: true)
    MainActor.assumeIsolated {
        NSApplication.shared.setActivationPolicy(.accessory)
        Preferences.register()
        SettingsRecorder.run(output: output)
    }
    exit(0)
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
