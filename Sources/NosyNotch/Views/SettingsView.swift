import AppKit
import SwiftUI

/// The settings window (menu bar ✦ → Settings…, or `npx nosynotch settings`). Dark and black like the notch:
/// a sidebar with a live mini notch on the left, cards on the right.
@MainActor
final class SettingsWindowController {
    struct Actions {
        var statusLine: () -> String
        var playDemo: () -> Void
        var settingsChanged: () -> Void
        var muteChanged: () -> Void
    }

    private var window: NSWindow?
    private let actions: Actions

    init(actions: Actions) {
        self.actions = actions
    }

    func show(page: SettingsPage = .agents) {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(actions: actions, page: page))
            let window = NSWindow(contentViewController: host)
            window.title = "Nosy Notch"
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = .black
            window.isReleasedWhenClosed = false
            window.setContentSize(SettingsView.size)
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

enum SettingsPage: String, CaseIterable, Identifiable {
    case agents, alerts, permissions, usage, music, general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .agents: return "Agents"
        case .alerts: return "Alerts"
        case .permissions: return "Permissions"
        case .usage: return "Usage"
        case .music: return "Music"
        case .general: return "General"
        }
    }

    var symbol: String {
        switch self {
        case .agents: return "sparkles"
        case .alerts: return "bell.badge"
        case .permissions: return "hand.raised"
        case .usage: return "gauge.with.dots.needle.50percent"
        case .music: return "music.note"
        case .general: return "gearshape"
        }
    }

    var tint: Color {
        switch self {
        case .agents: return Theme.claude
        case .alerts: return Theme.success
        case .permissions: return Theme.amber
        case .usage: return Theme.codex
        case .music: return Color(red: 0.95, green: 0.42, blue: 0.62)
        case .general: return .white.opacity(0.7)
        }
    }
}

// MARK: - Root

struct SettingsView: View {
    static let size = CGSize(width: 760, height: 560)
    static let repoURL = URL(string: "https://github.com/ddkbs/nosynotch")!

    let actions: SettingsWindowController.Actions
    @State var page: SettingsPage

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(page: $page, actions: actions)
                .frame(width: 210)
            Rectangle().fill(.white.opacity(0.06)).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(page: page)
                    content
                }
                .padding(.horizontal, 28)
                .padding(.top, 38)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(page)
                .transition(.opacity.combined(with: .offset(y: 6)))
            }
            .scrollIndicators(.never)
            .background(Color(white: 0.035))
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .animation(.easeOut(duration: 0.2), value: page)
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .agents: AgentsPage(actions: actions)
        case .alerts: AlertsPage(actions: actions)
        case .permissions: PermissionsPage()
        case .usage: UsagePage(actions: actions)
        case .music: MusicPage(actions: actions)
        case .general: GeneralPage(actions: actions)
        }
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @Binding var page: SettingsPage
    let actions: SettingsWindowController.Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MiniNotch()
                .padding(.top, 34)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Text("Nosy Notch")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(Self.version)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 22)

            VStack(spacing: 3) {
                ForEach(SettingsPage.allCases) { item in
                    SidebarItem(page: item, selected: page == item) { page = item }
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 12)

            StarCard()
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
        }
        .background(Color.black)
    }

    static var version: String {
        // `swift run` / the GIF recorder have no Info.plist – keep in sync with Resources/Info.plist.
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    }
}

/// A tiny live notch: the spark thinks, as if Claude were at work.
private struct MiniNotch: View {
    var body: some View {
        ZStack {
            NotchShape(topRadius: 6, bottomRadius: 14)
                .fill(Color.black)
                .overlay(NotchShape(topRadius: 6, bottomRadius: 14).stroke(.white.opacity(0.08), lineWidth: 1))
                .shadow(color: Theme.claude.opacity(0.35), radius: 12)
            HStack {
                ClaudeSpark(mode: .thinking, color: Theme.claude)
                    .frame(width: 16, height: 16)
                Spacer()
                WaveDots(color: Theme.claude)
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
        }
        .frame(width: 128, height: 34)
    }
}

private struct SidebarItem: View {
    let page: SettingsPage
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: page.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? page.tint : .white.opacity(0.55))
                    .frame(width: 18)
                Text(page.title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(.white.opacity(selected ? 1 : 0.7))
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.white.opacity(selected ? 0.09 : (hovering ? 0.04 : 0)))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// "Like it? Star it on GitHub" – the star spins and sparkles on hover. Small enough to ignore, nice enough to click.
private struct StarCard: View {
    @State private var hovering = false
    @State private var bursts = 0

    var body: some View {
        Button {
            bursts += 1
            NSWorkspace.shared.open(SettingsView.repoURL)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    StarSparkles(active: hovering)
                    Image(systemName: hovering ? "star.fill" : "star")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                        .rotationEffect(.degrees(hovering ? 72 : 0))
                        .scaleEffect(hovering ? 1.2 : 1)
                        .symbolEffect(.bounce, value: bursts)
                }
                .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Enjoying it?")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Star it on GitHub")
                        .font(.system(size: 11))
                        .foregroundStyle(hovering ? Theme.amber : .white.opacity(0.45))
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(hovering ? 0.7 : 0.25))
            }
            .padding(.horizontal, 12)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.amber.opacity(hovering ? 0.12 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.amber.opacity(hovering ? 0.45 : 0.14), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.4, dampingFraction: 0.55), value: hovering)
        .help("Opens github.com/ddkbs/nosynotch")
    }
}

/// Little sparks that fly out of the star while hovering.
private struct StarSparkles: View {
    let active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    let angle = Double(i) / 6 * 2 * .pi + t * 0.8
                    let phase = (t * 1.3 + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .fill(Theme.amber)
                        .frame(width: 2.5, height: 2.5)
                        .offset(x: cos(angle) * (8 + 9 * phase), y: sin(angle) * (8 + 9 * phase))
                        .opacity(active ? (1 - phase) : 0)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Building blocks

private struct PageHeader: View {
    let page: SettingsPage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: page.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(page.tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(page.tint.opacity(0.14)))
            Text(page.title)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.bottom, 2)
    }
}

/// A rounded black card, like a piece of the notch.
private struct Card<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) { content }
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.07), lineWidth: 1))
            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.38))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }
}

/// Title (+ subtitle) on the left, any control on the right.
private struct Row<Accessory: View>: View {
    let title: String
    var subtitle: String?
    var badge: String?
    var divider = true
    @ViewBuilder var accessory: Accessory

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Theme.amber))
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.42))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 10)
                accessory
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            if divider {
                Rectangle().fill(.white.opacity(0.06)).frame(height: 1).padding(.leading, 16)
            }
        }
    }
}

/// A pill switch in the notch's colours.
private struct NotchToggle: View {
    @Binding var isOn: Bool
    var tint: Color = Theme.claude

    var body: some View {
        Button { isOn.toggle() } label: {
            Capsule()
                .fill(isOn ? tint : Color.white.opacity(0.12))
                .frame(width: 38, height: 22)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(2)
                }
                .shadow(color: tint.opacity(isOn ? 0.45 : 0), radius: 6)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
    }
}

/// Segmented control: capsules, the selected one lit.
private struct Segments<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    var tint: Color = Theme.claude

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { value, label in
                Button { selection = value } label: {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selection == value ? Color.black : .white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Capsule().fill(selection == value ? tint : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(.white.opacity(0.07)))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selection)
    }
}

private struct PillButton: View {
    let title: String
    var tint: Color = Theme.claude
    var prominent = true
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(prominent ? Color.black : .white.opacity(0.85))
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(Capsule().fill(prominent ? tint.opacity(hovering ? 1 : 0.9) : .white.opacity(hovering ? 0.16 : 0.09)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct StatusChip: View {
    enum Kind { case connected, disconnected, missing }
    let kind: Kind

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
                .shadow(color: color.opacity(kind == .connected ? 0.8 : 0), radius: 3)
            Text(label).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    private var label: String {
        switch kind {
        case .connected: return "Connected"
        case .disconnected: return "Not connected"
        case .missing: return "Not installed"
        }
    }

    private var color: Color {
        switch kind {
        case .connected: return Theme.success
        case .disconnected: return .white.opacity(0.5)
        case .missing: return .white.opacity(0.3)
        }
    }
}

/// Shows an error from any page.
private struct ProblemAlert: ViewModifier {
    @Binding var problem: String?

    func body(content: Content) -> some View {
        content.alert("Something went wrong", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(problem ?? "")
        }
    }
}

// MARK: - Agents

private struct AgentsPage: View {
    let actions: SettingsWindowController.Actions

    @State private var claudeDirs: [(path: String, installed: Bool)] = []
    @State private var codex = HookInstaller.Codex.isInstalled
    @State private var cursor = HookInstaller.Cursor.isInstalled
    @State private var problem: String?

    private var claudeConnected: Bool { !claudeDirs.isEmpty && claudeDirs.allSatisfy(\.installed) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AgentCard(agent: .claude, title: "Claude Code",
                      detail: claudeDirs.map(\.path).joined(separator: "  ·  "),
                      status: claudeConnected ? .connected : .disconnected,
                      note: claudeConnected
                        ? "Terminal, VS Code, the desktop app – every new session reports to the notch."
                        : "Adds a tiny hook to each Claude Code settings.json (a backup is kept).") {
                toggle { claudeConnected ? try HookInstaller.uninstall() : try HookInstaller.install(port: Preferences.port) }
            }

            AgentCard(agent: .codex, title: "Codex",
                      detail: HookInstaller.Codex.displayPath,
                      status: !HookInstaller.Codex.isAvailable ? .missing : (codex ? .connected : .disconnected),
                      note: codex
                        ? "One more step: Codex only runs hooks you trust. ChatGPT app → Codex → Settings → Hooks (or /hooks in the CLI)."
                        : "The Codex CLI and the Codex mode of the ChatGPT app.") {
                toggle { codex ? try HookInstaller.Codex.uninstall() : try HookInstaller.Codex.install(port: Preferences.port) }
            }

            AgentCard(agent: .cursor, title: "Cursor",
                      detail: HookInstaller.Cursor.displayPath,
                      status: !HookInstaller.Cursor.isAvailable ? .missing : (cursor ? .connected : .disconnected),
                      note: "Cursor's agent. Claude Code inside Cursor's terminal works through the Claude hooks anyway.") {
                toggle { cursor ? try HookInstaller.Cursor.uninstall() : try HookInstaller.Cursor.install(port: Preferences.port) }
            }

            HStack {
                Text(actions.statusLine())
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                PillButton(title: "Play demo", prominent: false, action: actions.playDemo)
            }
            .padding(.horizontal, 4)
        }
        .onAppear(perform: reload)
        .modifier(ProblemAlert(problem: $problem))
    }

    private func toggle(_ change: () throws -> Void) {
        do { try change() } catch { problem = error.localizedDescription }
        reload()
    }

    private func reload() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        claudeDirs = HookInstaller.settingsURLs.map { url in
            (url.deletingLastPathComponent().path.replacingOccurrences(of: home, with: "~"), HookInstaller.isInstalled(at: url))
        }
        codex = HookInstaller.Codex.isInstalled
        cursor = HookInstaller.Cursor.isInstalled
    }
}

private struct AgentCard: View {
    let agent: Agent
    let title: String
    let detail: String
    let status: StatusChip.Kind
    let note: String
    let toggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(agent.color.opacity(0.12))
                ClaudeSpark(mode: status == .connected ? .thinking : .idle, color: agent.color)
                    .frame(width: 20, height: 20)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    StatusChip(kind: status)
                }
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if status != .missing {
                PillButton(title: status == .connected ? "Disconnect" : "Connect",
                           tint: agent.color, prominent: status != .connected, action: toggle)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(status == .connected ? agent.color.opacity(0.3) : .white.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: agent.color.opacity(status == .connected ? 0.12 : 0), radius: 14)
    }
}

// MARK: - Alerts

private struct AlertsPage: View {
    let actions: SettingsWindowController.Actions

    @AppStorage(Preferences.Key.soundDone) private var soundDone = true
    @AppStorage(Preferences.Key.soundAttention) private var soundAttention = true
    @AppStorage(Preferences.Key.soundError) private var soundError = true
    @AppStorage(Preferences.Key.systemNotifications) private var systemNotifications = false
    @AppStorage(Preferences.Key.notificationSeconds) private var notificationSeconds = 6.0
    @AppStorage(Preferences.Key.quietWhenFocused) private var quietWhenFocused = true
    @AppStorage(Preferences.Key.remindAfterFiveMinutes) private var remind = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            MuteCard(actions: actions)

            Card(title: "Sounds") {
                Row(title: "When it's done", subtitle: "Glass") { NotchToggle(isOn: $soundDone, tint: Theme.success) }
                Row(title: "When it needs you", subtitle: "Funk") { NotchToggle(isOn: $soundAttention, tint: Theme.amber) }
                Row(title: "On errors", subtitle: "Basso", divider: false) { NotchToggle(isOn: $soundError, tint: Theme.danger) }
            }

            Card(title: "Behaviour", footer: "The notch itself is the notification. When the app a session runs in is already in front, \"done\" and \"needs you\" stay small and silent.") {
                Row(title: "Keep notifications open") {
                    HStack(spacing: 10) {
                        Slider(value: Binding(get: { notificationSeconds }, set: { notificationSeconds = $0.rounded() }), in: 3...15)
                            .frame(width: 130)
                            .tint(Theme.claude)
                        Text("\(Int(notificationSeconds)) s")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 34, alignment: .trailing)
                    }
                }
                Row(title: "Stay small when I'm already in that app") { NotchToggle(isOn: $quietWhenFocused) }
                Row(title: "Remind me after 5 minutes",
                    subtitle: "If a result stays unseen or a question unanswered") { NotchToggle(isOn: $remind) }
                Row(title: "Also send macOS notifications", divider: false) {
                    NotchToggle(isOn: Binding(get: { systemNotifications }, set: {
                        systemNotifications = $0
                        Notifier.requestAuthorizationIfNeeded()
                    }))
                }
            }
        }
    }
}

private struct MuteCard: View {
    let actions: SettingsWindowController.Actions
    @State private var choice: Double = Self.currentChoice
    @State private var until = Preferences.mutedUntil

    /// 0 = off, -1 = until unmuted, otherwise hours.
    private static var currentChoice: Double {
        guard let until = Preferences.mutedUntil else { return 0 }
        return until.timeIntervalSinceNow > 365 * 86_400 ? -1 : 1   // "1" marks "muted for a while"
    }

    var body: some View {
        Card(title: "Mute") {
            Row(title: until == nil ? "Sounds and banners are on" : "Muted \(AppDelegate.muteDescription(until!))",
                subtitle: "Animations keep running – only the noise stops.", divider: false) {
                Segments(options: [(0.0, "Off"), (1.0, "1 h"), (8.0, "8 h"), (-1.0, "∞")],
                         selection: Binding(get: { choice }, set: set), tint: Theme.amber)
            }
        }
    }

    private func set(_ value: Double) {
        choice = value
        switch value {
        case 0: Preferences.mutedUntil = nil
        case -1: Preferences.mutedUntil = .distantFuture
        default: Preferences.mutedUntil = Date().addingTimeInterval(value * 3600)
        }
        until = Preferences.mutedUntil
        actions.muteChanged()
    }
}

// MARK: - Permissions

private struct PermissionsPage: View {
    @AppStorage(Preferences.Key.approvalsInNotch) private var approvalsInNotch = true
    @AppStorage(Preferences.Key.headGestures) private var headGestures = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Card(footer: "Claude Code keeps its own dialog open meanwhile – answer wherever you like. Codex shows its prompt once you click ✕ or after 45 s. Your deny rules always win, and \"Always allow\" never switches the permission mode.") {
                Row(title: "Allow or deny right in the notch",
                    subtitle: "Deny · Always allow · Allow, for Claude Code and Codex", divider: false) {
                    NotchToggle(isOn: $approvalsInNotch, tint: Theme.amber)
                }
            }

            Card(title: "Hands-free", footer: "Uses the head tracking of AirPods Pro / Max / 3rd gen and newer. Motion is only read while a request is open in the notch – macOS asks once for Motion & Fitness access.") {
                Row(title: "Nod to allow, shake to deny", subtitle: "With your AirPods in", badge: "NEW", divider: false) {
                    NotchToggle(isOn: $headGestures, tint: Theme.amber)
                }
            }
            .opacity(approvalsInNotch ? 1 : 0.45)
            .disabled(!approvalsInNotch)

            NodIllustration(active: headGestures && approvalsInNotch)
        }
    }
}

/// A little head that nods – shows what the setting does.
private struct NodIllustration: View {
    let active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let cycle = t.truncatingRemainder(dividingBy: 2.4)
            let nod = cycle < 0.9 ? sin(cycle / 0.9 * .pi * 2) * 12 : 0
            HStack(spacing: 14) {
                Image(systemName: "airpodspro")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.white.opacity(active ? 0.85 : 0.3))
                    .rotationEffect(.degrees(active ? nod : 0), anchor: .center)
                    .offset(y: active ? nod / 3 : 0)
                VStack(alignment: .leading, spacing: 2) {
                    Text(active ? "Ready – nod when the notch asks" : "Off")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(active ? 0.8 : 0.35))
                    Text("Nod ↕ allow  ·  shake ↔ deny")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 6)
        }
    }
}

// MARK: - Usage

private struct UsagePage: View {
    let actions: SettingsWindowController.Actions

    @AppStorage(Preferences.Key.usageEnabled) private var usageEnabled = true
    @AppStorage(Preferences.Key.usageAgents) private var usageAgents = "all"
    @AppStorage(Preferences.Key.contextEnabled) private var contextEnabled = true
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Card(title: "Limits", footer: "5-hour and weekly limits as bars when you hover the notch. Claude (Pro / Max) only shares them with its status line, so Nosy Notch adds a silent one – unless you already have your own. Codex: read from its session files.") {
                Row(title: "Show usage limits") {
                    NotchToggle(isOn: Binding(get: { usageEnabled }, set: setUsage), tint: Theme.codex)
                }
                Row(title: "Show", divider: false) {
                    Segments(options: [("all", "Both"), ("claude", "Claude"), ("codex", "Codex")],
                             selection: Binding(get: { usageAgents }, set: { usageAgents = $0; actions.settingsChanged() }),
                             tint: Theme.codex)
                }
                .opacity(usageEnabled ? 1 : 0.4)
                .disabled(!usageEnabled)
            }

            Card(title: "Context", footer: "A small ring per session in the hover list: how full the context window is. Amber from 60 %, red from 85 % – time to /compact soon.") {
                Row(title: "Show context fill per session", divider: false) {
                    NotchToggle(isOn: Binding(get: { contextEnabled }, set: { contextEnabled = $0; actions.settingsChanged() }),
                                tint: Theme.codex)
                }
            }

            UsagePreview()
        }
        .modifier(ProblemAlert(problem: $problem))
    }

    private func setUsage(_ on: Bool) {
        usageEnabled = on
        do {
            if on, HookInstaller.isInstalled { try HookInstaller.installStatusLine(port: Preferences.port) }
            if !on { try HookInstaller.uninstallStatusLine() }
        } catch { problem = error.localizedDescription }
        actions.settingsChanged()
    }
}

/// What the bars look like in the notch.
private struct UsagePreview: View {
    var body: some View {
        VStack(spacing: 6) {
            UsageMeter(label: "5h", window: UsageWindow(usedPercent: 38, resetsAt: Date().addingTimeInterval(8_000)))
            UsageMeter(label: "Week", window: UsageWindow(usedPercent: 71, resetsAt: Date().addingTimeInterval(200_000)))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black))
        .overlay(alignment: .topLeading) {
            Text("PREVIEW")
                .font(.system(size: 8, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.25))
                .padding(.leading, 14)
                .offset(y: -12)
        }
        .padding(.top, 8)
    }
}

// MARK: - Music

private struct MusicPage: View {
    let actions: SettingsWindowController.Actions

    @AppStorage(Preferences.Key.mediaEnabled) private var mediaEnabled = true
    @AppStorage(Preferences.Key.mediaShowWhenPaused) private var mediaShowWhenPaused = false
    @AppStorage(Preferences.Key.liveEqualizer) private var liveEqualizer = false

    private let pink = SettingsPage.music.tint

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Card(footer: "Shown while no agent is busy. The first time you press play, macOS asks whether Nosy Notch may control your player.") {
                Row(title: "Show Spotify / Apple Music in the notch") {
                    NotchToggle(isOn: bind($mediaEnabled), tint: pink)
                }
                Row(title: "Keep showing while paused", divider: false) {
                    NotchToggle(isOn: bind($mediaShowWhenPaused), tint: pink)
                }
                .opacity(mediaEnabled ? 1 : 0.4)
                .disabled(!mediaEnabled)
            }

            Card(title: "Equalizer", footer: "Listens to Spotify / Music only (macOS asks once for \"System Audio Recording\"). Nothing is recorded or stored.") {
                Row(title: "Live equalizer", subtitle: "Bigger bars that move with the actual music", divider: false) {
                    NotchToggle(isOn: bind($liveEqualizer), tint: pink)
                }
                .opacity(mediaEnabled ? 1 : 0.4)
                .disabled(!mediaEnabled)
            }

            HStack(spacing: 24) {
                VStack(spacing: 6) {
                    EqualizerBars(color: pink, playing: true)
                        .frame(height: 20)
                    Text("Classic").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                }
                VStack(spacing: 6) {
                    EqualizerBars(color: pink, playing: true, live: true)
                    Text("Live").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black))
        }
    }

    private func bind(_ value: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0; actions.settingsChanged() })
    }
}

// MARK: - General

private struct GeneralPage: View {
    let actions: SettingsWindowController.Actions
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Card {
                Row(title: "Launch at login", subtitle: "Starts quietly in the menu bar") {
                    NotchToggle(isOn: Binding(get: { launchAtLogin }, set: { on in
                        do { try LoginItem.setEnabled(on); launchAtLogin = on } catch { problem = error.localizedDescription }
                    }))
                }
                Row(title: "Status", subtitle: actions.statusLine(), divider: false) { EmptyView() }
            }

            Card(title: "About") {
                Row(title: "Nosy Notch \(Sidebar.version)", subtitle: "Made with Claude Code. Not affiliated with Anthropic, OpenAI or Anysphere.") {
                    PillButton(title: "GitHub", prominent: false) { NSWorkspace.shared.open(SettingsView.repoURL) }
                }
                Row(title: "Quit Nosy Notch", subtitle: "The notch goes back to being just a notch.", divider: false) {
                    PillButton(title: "Quit", tint: Theme.danger, prominent: false) { NSApp.terminate(nil) }
                }
            }
        }
        .modifier(ProblemAlert(problem: $problem))
    }
}
