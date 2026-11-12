import AppKit
import SwiftUI

/// Open ports in the hover view: one chip per port with what it is and who started it. Click opens it in the
/// browser, ✕ quits the process behind it (apps and agents ask first).
struct PortsRow: View {
    @ObservedObject var monitor: PortMonitor

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.codex)
                .help("Open ports")
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(monitor.visible) { port in
                        PortChip(port: port, closing: monitor.closing.contains(port.id), onQuit: { monitor.quit(port) })
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: monitor.visible.map(\.id))
            }
            .scrollIndicators(.never)
        }
        .padding(.horizontal, 24)
        .frame(height: NotchViewModel.portsRowHeight)
    }
}

private struct PortChip: View {
    let port: ListeningPort
    let closing: Bool
    var onQuit: () -> Void

    @State private var hovering = false
    @State private var confirming = false

    var body: some View {
        HStack(spacing: 7) {
            OriginIcon(port: port)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(verbatim: ":\(port.port)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(port.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    if port.exposed {
                        Image(systemName: "globe")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.amber)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(confirming ? Theme.danger : .white.opacity(0.45))
            }
            .lineLimit(1)
            .frame(maxWidth: 140, alignment: .leading)

            if confirming {
                Button {
                    confirming = false
                    onQuit()
                } label: {
                    Text("Quit")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(Capsule().fill(Theme.danger))
                }
                .buttonStyle(.plain)
            } else if hovering && !closing {
                Button {
                    if port.needsConfirm { confirming = true } else { onQuit() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help(port.needsConfirm ? "Quit \(port.process)…" : "Stop it (quits \(port.process), PID \(port.pid))")
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .frame(height: 34)
        .background(Capsule().fill(confirming ? Theme.danger.opacity(0.18) : .white.opacity(hovering ? 0.12 : 0.07)))
        .opacity(closing ? 0.35 : 1)
        .contentShape(Capsule())
        .onHover { inside in
            hovering = inside
            if !inside { confirming = false }
        }
        .onTapGesture {
            guard !confirming, let url = URL(string: "http://localhost:\(port.port)") else { return }
            NSWorkspace.shared.open(url)
        }
        .help(details)
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.easeOut(duration: 0.15), value: confirming)
    }

    /// "website · Claude" – or the question while confirming.
    private var subtitle: String {
        if confirming { return "Quit \(port.process)?" }
        if closing { return "Stopping…" }
        let parts = [port.folderName, port.shortOrigin].compactMap { $0 }
        return parts.isEmpty ? "runs on its own" : parts.joined(separator: " · ")
    }

    private var details: String {
        var lines = ["\(port.label) – \(port.process), PID \(port.pid)"]
        if let cwd = port.cwd { lines.append((cwd as NSString).abbreviatingWithTildeInPath) }
        var started = "Started by \(port.origin)"
        if let date = port.startedAt { started += ", " + date.formatted(.relative(presentation: .named)) }
        lines.append(started)
        lines.append(port.exposed ? "Reachable from your network" : "Only this Mac (localhost)")
        if !port.command.isEmpty { lines.append(String(port.command.prefix(160))) }
        lines.append("Click to open in the browser")
        return lines.joined(separator: "\n")
    }
}

/// The app that started it (terminal, editor, Claude …), or a terminal symbol when nothing did.
private struct OriginIcon: View {
    let port: ListeningPort

    var body: some View {
        Group {
            if let id = port.hostBundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
            } else {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(width: 22, height: 22)
        .overlay(alignment: .bottomTrailing) {
            if let agent = port.agent, port.hostBundleID != nil {
                Circle()
                    .fill(agent.color)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(.black, lineWidth: 1.5))
                    .offset(x: 1, y: 1)
            }
        }
    }
}

/// ":5173" next to a session that started a server.
struct SessionPorts: View {
    let ports: [ListeningPort]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(ports.prefix(2)) { port in
                Text(verbatim: ":\(port.port)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.codex)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Theme.codex.opacity(0.16)))
                    .onTapGesture {
                        if let url = URL(string: "http://localhost:\(port.port)") { NSWorkspace.shared.open(url) }
                    }
            }
            if ports.count > 2 {
                Text("+\(ports.count - 2)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .fixedSize()
        .help(ports.map { ":\($0.port) \($0.label)" }.joined(separator: "\n"))
    }
}
