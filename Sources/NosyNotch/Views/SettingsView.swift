import AppKit
import SwiftUI

/// The settings window (menu bar ✦ → Settings…, or `npx nosynotch settings`).
@MainActor
final class SettingsWindowController {
    struct Actions {
        var statusLine: () -> String
        var playDemo: () -> Void
        var settingsChanged: () -> Void
    }

    private var window: NSWindow?
    private let actions: Actions

    init(actions: Actions) {
        self.actions = actions
    }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(actions: actions))
            let window = NSWindow(contentViewController: host)
            window.title = "Nosy Notch"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.setContentSize(CGSize(width: 480, height: 640))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    let actions: SettingsWindowController.Actions

    @AppStorage(Preferences.Key.soundDone) private var soundDone = true
    @AppStorage(Preferences.Key.soundAttention) private var soundAttention = true
    @AppStorage(Preferences.Key.soundError) private var soundError = true
    @AppStorage(Preferences.Key.systemNotifications) private var systemNotifications = false
    @AppStorage(Preferences.Key.notificationSeconds) private var notificationSeconds = 6.0
    @AppStorage(Preferences.Key.mediaEnabled) private var mediaEnabled = true
    @AppStorage(Preferences.Key.mediaShowWhenPaused) private var mediaShowWhenPaused = false

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var hooks: [(path: String, installed: Bool)] = []
    @State private var problem: String?

    private var allConnected: Bool { !hooks.isEmpty && hooks.allSatisfy(\.installed) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Form {
                Section {
                    ForEach(hooks, id: \.path) { hook in
                        LabeledContent(hook.path) {
                            Label(hook.installed ? "Connected" : "Not connected",
                                  systemImage: hook.installed ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundStyle(hook.installed ? Color.green : Color.secondary)
                        }
                    }
                    HStack {
                        if allConnected {
                            Button("Disconnect") { toggleHooks() }
                        } else {
                            Button("Connect Claude Code") { toggleHooks() }
                                .controlSize(.large)
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.claude)
                        }
                        Spacer()
                        Button("Play demo", action: actions.playDemo)
                    }
                } header: {
                    Text("Claude Code")
                } footer: {
                    FooterText(allConnected
                         ? "Every new Claude Code session reports to the notch. Restart sessions that were already running."
                         : "Adds a tiny hook to each Claude Code settings.json (a backup is kept).")
                }

                Section("General") {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, on in
                            do { try LoginItem.setEnabled(on) } catch { problem = error.localizedDescription }
                        }
                }

                Section {
                    Toggle("Sound when Claude is done", isOn: $soundDone)
                    Toggle("Sound when Claude needs you", isOn: $soundAttention)
                    Toggle("Sound on errors", isOn: $soundError)
                    LabeledContent("Keep notifications open") {
                        HStack {
                            Slider(value: Binding(get: { notificationSeconds }, set: { notificationSeconds = $0.rounded() }), in: 3...15)
                                .frame(width: 150)
                            Text("\(Int(notificationSeconds)) s")
                                .monospacedDigit()
                                .frame(width: 34, alignment: .trailing)
                        }
                    }
                    Toggle("Also send macOS notifications", isOn: $systemNotifications)
                        .onChange(of: systemNotifications) { _, _ in Notifier.requestAuthorizationIfNeeded() }
                } header: {
                    Text("Notifications")
                } footer: {
                    FooterText("The notch itself is the notification – macOS banners are optional.")
                }

                Section {
                    Toggle("Show Spotify / Apple Music in the notch", isOn: $mediaEnabled)
                    Toggle("Keep showing while paused", isOn: $mediaShowWhenPaused)
                        .disabled(!mediaEnabled)
                } header: {
                    Text("Music")
                } footer: {
                    FooterText("Shown while Claude is idle. The first time you press play, macOS asks whether Nosy Notch may control your player.")
                }
            }
            .formStyle(.grouped)

            footer
        }
        .frame(width: 480, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: reloadHooks)
        .onChange(of: mediaEnabled) { _, _ in actions.settingsChanged() }
        .onChange(of: mediaShowWhenPaused) { _, _ in actions.settingsChanged() }
        .alert("Something went wrong", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(problem ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black)
                ClaudeSpark(mode: allConnected ? .thinking : .idle, color: Theme.claude)
                    .frame(width: 30, height: 30)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Nosy Notch").font(.title2.weight(.semibold))
                    Text(Self.version).font(.callout).foregroundStyle(.secondary)
                }
                Text(actions.statusLine())
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 34)
        .padding(.bottom, 4)
    }

    private var footer: some View {
        HStack {
            Link("GitHub", destination: URL(string: "https://github.com/ddkbs/nosynotch")!)
            Spacer()
            Button("Quit Nosy Notch") { NSApp.terminate(nil) }
        }
        .font(.callout)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 4)
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private func reloadHooks() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        hooks = HookInstaller.settingsURLs.map { url in
            (url.deletingLastPathComponent().path.replacingOccurrences(of: home, with: "~"), HookInstaller.isInstalled(at: url))
        }
    }

    private func toggleHooks() {
        do {
            if allConnected { try HookInstaller.uninstall() } else { try HookInstaller.install(port: Preferences.port) }
        } catch {
            problem = error.localizedDescription
        }
        reloadHooks()
    }
}

/// Section footer text, left-aligned (grouped forms otherwise right-align wrapped lines).
private struct FooterText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
