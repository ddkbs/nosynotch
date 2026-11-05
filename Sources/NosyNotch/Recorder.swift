import AppKit
import SwiftUI

/// Renders every notch animation into PNG frames so `scripts/record-gifs.sh` can turn them into GIFs
/// for the README and `docs/`.
///
/// `NosyNotch --record <out-dir> [scene …]` plays scripted hook events into a fresh store per scene,
/// shows the real `NotchView` on a fake menu bar in a regular window and snapshots it at 30 fps.
@MainActor
final class Recorder {
    struct Scene {
        let name: String
        let duration: TimeInterval
        var height: CGFloat = 180
        /// Seconds after which the pointer "hovers" the notch (nil = never).
        var hoverAt: TimeInterval?
        /// Seconds after which a celebration / alert flash is dismissed (used to set up the hover list).
        var dismissFlashAt: TimeInterval?
        /// Moment (seconds) that is also saved as a still PNG – the notch fully expanded.
        var stillAt: TimeInterval?
        /// Seconds after which the demo song starts "playing" in the fake media player.
        var musicAt: TimeInterval?
        /// Seconds after which "Allow" is clicked on the open permission request.
        var allowAt: TimeInterval?
        /// Pretend the session's app is in front: "Done" stays small.
        var focused = false
        /// Fill in made-up usage limits for the hover view.
        var usage = false
        let steps: [(TimeInterval, HookEvent)]
    }

    static let fps: Double = 30
    static let width: CGFloat = 560

    private let outputDirectory: URL
    private var queue: [Scene]
    private var window: NSWindow?
    private let writer = DispatchQueue(label: "nosynotch.recorder", qos: .userInitiated)

    init(outputDirectory: URL, only names: [String]) {
        self.outputDirectory = outputDirectory
        let all = Self.scenes
        queue = names.isEmpty ? all : all.filter { names.contains($0.name) }
    }

    func start() {
        if queue.isEmpty {
            FileHandle.standardError.write(Data("✗ Unknown scene. Available: \(Self.scenes.map(\.name).joined(separator: ", "))\n".utf8))
            exit(1)
        }
        next()
    }

    private func next() {
        guard !queue.isEmpty else {
            writer.async {
                DispatchQueue.main.async { NSApp.terminate(nil) }
            }
            return
        }
        record(queue.removeFirst()) { [weak self] in self?.next() }
    }

    private func record(_ scene: Scene, completion: @escaping () -> Void) {
        let store = SessionStore()
        let model = NotchViewModel(store: store, media: NowPlaying(observeSystem: false))
        model.notchSize = CGSize(width: 185, height: 32)
        model.hasPhysicalNotch = true
        store.onChange = { model.recompute() }
        store.onTransition = { scene.focused ? model.showQuietly($0) : model.handle($0) }
        if scene.usage {
            let now = Date()
            model.usage.set(AgentUsage(fiveHour: UsageWindow(usedPercent: 38, resetsAt: now + 2 * 3600 + 840),
                                       week: UsageWindow(usedPercent: 71, resetsAt: now + 3 * 86_400)), for: .claude)
            model.usage.set(AgentUsage(fiveHour: UsageWindow(usedPercent: 12, resetsAt: now + 4 * 3600),
                                       week: UsageWindow(usedPercent: 90, resetsAt: now + 86_400)), for: .codex)
        }

        let size = CGSize(width: Self.width, height: scene.height)
        let host = NSHostingView(rootView: RecordingStage(model: model, store: store))
        host.frame = CGRect(origin: .zero, size: size)

        let window = self.window ?? NSWindow(contentRect: CGRect(origin: .zero, size: size),
                                             styleMask: [.borderless], backing: .buffered, defer: false)
        window.setContentSize(size)
        window.contentView = host
        window.isOpaque = true
        window.backgroundColor = .black
        window.level = .floating
        if let screen = NSScreen.main {
            window.setFrameOrigin(CGPoint(x: screen.visibleFrame.minX + 20, y: screen.visibleFrame.minY + 20))
        }
        window.orderFrontRegardless()
        self.window = window

        let dir = outputDirectory.appendingPathComponent(scene.name, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        print("● \(scene.name) (\(Int(scene.duration))s) …")

        let start = Date()
        for (delay, event) in scene.steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                MainActor.assumeIsolated {
                    store.handle(event)
                    // Permission requests wait for Allow / Deny, like the real hook.
                    if event.name == "PermissionRequest" { model.approvals.add(event) { _ in } }
                }
            }
        }
        if let t = scene.allowAt {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                MainActor.assumeIsolated {
                    if let approval = model.attentionApproval { model.decide(approval, .allow) }
                }
            }
        }
        if let t = scene.musicAt {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                MainActor.assumeIsolated {
                    model.media.preview(Self.demoTrack, artwork: Self.demoArtwork(), playing: true, position: 74)
                }
            }
        }
        if let t = scene.dismissFlashAt {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                MainActor.assumeIsolated { model.dismissFlash() }
            }
        }
        if let t = scene.hoverAt {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                MainActor.assumeIsolated { model.isHovering = true }
            }
        }

        var frame = 0
        let total = Int(scene.duration * Self.fps)
        let timer = Timer(timeInterval: 1 / Self.fps, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { return timer.invalidate() }
                // Catch up on dropped ticks so the GIF plays at real speed.
                let due = min(total, Int(Date().timeIntervalSince(start) * Self.fps) + 1)
                guard frame < due, let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
                host.cacheDisplay(in: host.bounds, to: rep)
                let image = rep
                while frame < due {
                    var urls = [dir.appendingPathComponent(String(format: "frame_%04d.png", frame))]
                    if let still = scene.stillAt, frame == Int(still * Self.fps) {
                        urls.append(self.outputDirectory.appendingPathComponent("stills/\(scene.name).png"))
                    }
                    let targets = urls
                    self.writer.async {
                        guard let png = image.representation(using: .png, properties: [:]) else { return }
                        for url in targets {
                            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                                     withIntermediateDirectories: true)
                            try? png.write(to: url)
                        }
                    }
                    frame += 1
                }
                if frame >= total {
                    timer.invalidate()
                    store.onChange = nil
                    store.onTransition = nil
                    completion()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - Scenes

    static let demoTrack = NowPlaying.Track(id: "spotify:track:demo", title: "Neon Horizon", artist: "Lumen Drive",
                                            album: "Night Shift", duration: 213, source: .spotify)

    /// A made-up album cover: sunset gradient, sun and horizon lines.
    static func demoArtwork() -> NSImage {
        NSImage(size: CGSize(width: 300, height: 300), flipped: false) { rect in
            NSGradient(colors: [NSColor(red: 0.98, green: 0.45, blue: 0.30, alpha: 1),
                                NSColor(red: 0.85, green: 0.20, blue: 0.55, alpha: 1),
                                NSColor(red: 0.28, green: 0.12, blue: 0.50, alpha: 1)])?
                .draw(in: rect, angle: -90)
            NSColor(red: 1, green: 0.85, blue: 0.45, alpha: 1).setFill()
            NSBezierPath(ovalIn: CGRect(x: 80, y: 110, width: 140, height: 140)).fill()
            NSColor(red: 0.28, green: 0.12, blue: 0.50, alpha: 1).setFill()
            for i in 0..<6 {
                let y = 110 + CGFloat(i) * 14
                NSBezierPath(rect: CGRect(x: 0, y: y, width: 300, height: 4 + CGFloat(5 - i))).fill()
            }
            NSBezierPath(rect: CGRect(x: 0, y: 0, width: 300, height: 112)).fill()
            return true
        }
    }

    static var scenes: [Scene] {
        let cwd = "/Users/you/Projects/nosynotch"
        func ev(_ name: String, _ id: String = "rec", agent: Agent = .claude, cwd: String = cwd, tool: String? = nil,
                input: [String: Any] = [:], message: String? = nil, last: String? = nil, error: String? = nil,
                details: String? = nil) -> HookEvent {
            HookEvent(name: name, sessionID: id, agent: agent, cwd: cwd, toolName: tool, toolInput: input, message: message,
                      lastAssistantMessage: last, error: error, errorDetails: details)
        }
        let prompt = ev("UserPromptSubmit")

        return [
            Scene(name: "thinking", duration: 4.5, stillAt: 3.0, steps: [
                (0.0, ev("SessionStart")),
                (0.6, prompt),
            ]),
            Scene(name: "tools", duration: 9, stillAt: 6.3, steps: [
                (0.0, ev("SessionStart")),
                (0.3, prompt),
                (1.2, ev("PreToolUse", tool: "Grep", input: ["pattern": "func parse"])),
                (2.4, ev("PostToolUse", tool: "Grep")),
                (2.7, ev("PreToolUse", tool: "Read", input: ["file_path": "\(cwd)/Sources/Parser.swift"])),
                (3.9, ev("PostToolUse", tool: "Read")),
                (4.2, ev("PreToolUse", tool: "Edit", input: ["file_path": "\(cwd)/Sources/Parser.swift"])),
                (5.4, ev("PostToolUse", tool: "Edit")),
                (5.7, ev("PreToolUse", tool: "Bash", input: ["command": "swift test", "description": "Run tests"])),
                (6.9, ev("PostToolUse", tool: "Bash")),
                (7.2, ev("PreToolUse", tool: "WebSearch", input: ["query": "SwiftUI Canvas"])),
            ]),
            Scene(name: "attention", duration: 7.5, stillAt: 3.2, allowAt: 5.4, steps: [
                (0.0, ev("SessionStart")),
                (0.3, prompt),
                (1.5, ev("PermissionRequest", tool: "Bash", input: ["command": "npm publish", "description": "npm publish"])),
                (6.4, ev("PostToolUse", tool: "Bash", input: ["command": "npm publish", "description": "npm publish"])),
            ]),
            Scene(name: "done", duration: 7.5, stillAt: 3.9, steps: [
                (0.0, ev("SessionStart")),
                (0.3, prompt),
                (0.9, ev("PreToolUse", tool: "Edit", input: ["file_path": "\(cwd)/Sources/NotchView.swift"])),
                (1.7, ev("PostToolUse", tool: "Edit")),
                (2.2, ev("Stop", last: "Parser refactored – all 42 tests pass.")),
            ]),
            Scene(name: "quiet-done", duration: 6, focused: true, steps: [
                (0.0, ev("SessionStart")),
                (0.3, prompt),
                (0.9, ev("PreToolUse", tool: "Edit", input: ["file_path": "\(cwd)/Sources/NotchView.swift"])),
                (1.7, ev("PostToolUse", tool: "Edit")),
                (2.2, ev("Stop", last: "Parser refactored – all 42 tests pass.")),
            ]),
            Scene(name: "compacting", duration: 4.5, stillAt: 3.0, steps: [
                (0.0, ev("SessionStart")),
                (0.3, prompt),
                (1.2, ev("PreCompact")),
            ]),
            Scene(name: "error", duration: 7, stillAt: 3.2, steps: [
                (0.0, ev("SessionStart")),
                (0.3, prompt),
                (1.6, ev("StopFailure", error: "rate_limit", details: "429 Too Many Requests")),
            ]),
            Scene(name: "hover", duration: 6, height: 240, hoverAt: 1.2, dismissFlashAt: 0.1, stillAt: 4.5, steps: [
                (0.0, ev("UserPromptSubmit", "a")),
                (0.0, ev("PreToolUse", "a", tool: "Edit", input: ["file_path": "\(cwd)/Sources/NotchView.swift"])),
                (0.0, ev("UserPromptSubmit", "b", cwd: "/Users/you/Projects/api-server")),
                (0.0, ev("UserPromptSubmit", "c", cwd: "/Users/you/Projects/website")),
                (0.0, ev("PreToolUse", "c", cwd: "/Users/you/Projects/website", tool: "Bash",
                         input: ["command": "npm run build", "description": "npm run build"])),
                (0.0, ev("PostToolUse", "c", cwd: "/Users/you/Projects/website", tool: "Bash")),
                (0.0, ev("Stop", "c", cwd: "/Users/you/Projects/website", last: "Build succeeded.")),
            ]),
            Scene(name: "codex", duration: 10, height: 200, hoverAt: 6.6, dismissFlashAt: 6.5, stillAt: 8.8, steps: [
                (0.0, ev("UserPromptSubmit", "claude", cwd: "/Users/you/Projects/website")),
                (0.0, ev("PreToolUse", "claude", cwd: "/Users/you/Projects/website", tool: "Bash",
                         input: ["command": "npm run build", "description": "npm run build"])),
                (0.3, ev("UserPromptSubmit", "cx", agent: .codex, cwd: "/Users/you/Projects/api-server")),
                (1.6, ev("PreToolUse", "cx", agent: .codex, cwd: "/Users/you/Projects/api-server", tool: "Bash",
                         input: ["command": "rg -n handleLogin src"])),
                (2.6, ev("PostToolUse", "cx", agent: .codex, cwd: "/Users/you/Projects/api-server", tool: "Bash")),
                (2.9, ev("PreToolUse", "cx", agent: .codex, cwd: "/Users/you/Projects/api-server", tool: "apply_patch",
                         input: ["command": "*** Begin Patch\n*** Update File: src/auth/login.ts\n*** End Patch"])),
                (4.0, ev("PostToolUse", "cx", agent: .codex, cwd: "/Users/you/Projects/api-server", tool: "apply_patch")),
                (4.3, ev("Stop", "cx", agent: .codex, cwd: "/Users/you/Projects/api-server",
                         last: "Fixed the login redirect and added a regression test.")),
            ]),
            Scene(name: "usage", duration: 5, height: 250, hoverAt: 0.8, stillAt: 3.5, usage: true, steps: [
                (0.0, ev("UserPromptSubmit", "a")),
                (0.0, ev("PreToolUse", "a", tool: "Edit", input: ["file_path": "\(cwd)/Sources/NotchView.swift"])),
                (0.0, ev("UserPromptSubmit", "cx", agent: .codex, cwd: "/Users/you/Projects/api-server")),
            ]),
            Scene(name: "media", duration: 7, height: 170, hoverAt: 2.6, stillAt: 5.0, musicAt: 0.5, steps: []),
            Scene(name: "handoff", duration: 9, dismissFlashAt: 6.6, musicAt: 0.0, steps: [
                (1.4, prompt),
                (2.6, ev("PreToolUse", tool: "Edit", input: ["file_path": "\(cwd)/Sources/NotchView.swift"])),
                (3.4, ev("PostToolUse", tool: "Edit")),
                (3.8, ev("Stop", last: "Media player added – the notch now shows Spotify while Claude takes a break.")),
            ]),
            Scene(name: "demo", duration: 17, allowAt: 8.9, steps: [
                (0.0, ev("SessionStart")),
                (0.5, prompt),
                (2.6, ev("PreToolUse", tool: "Grep", input: ["pattern": "func parse"])),
                (3.8, ev("PostToolUse", tool: "Grep")),
                (4.3, ev("PreToolUse", tool: "Edit", input: ["file_path": "\(cwd)/Sources/Parser.swift"])),
                (5.8, ev("PostToolUse", tool: "Edit")),
                (6.2, ev("PermissionRequest", tool: "Bash", input: ["command": "swift test", "description": "swift test"])),
                (9.4, ev("PreToolUse", tool: "Bash", input: ["command": "swift test", "description": "Run tests"])),
                (11.2, ev("PostToolUse", tool: "Bash")),
                (11.8, ev("Stop", last: "Parser refactored – all 42 tests pass.")),
            ]),
        ]
    }
}

/// The notch on a stylised desktop: wallpaper + menu bar.
private struct RecordingStage: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var store: SessionStore

    var body: some View {
        ZStack(alignment: .top) {
            Wallpaper()
            menuBar
            NotchView(model: model, store: store, media: model.media)
        }
        .frame(width: Recorder.width)
        .environment(\.colorScheme, .dark)
    }

    private var menuBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "apple.logo").font(.system(size: 12, weight: .semibold))
            Text("Terminal").font(.system(size: 12, weight: .bold))
            Text("Shell").font(.system(size: 12))
            Spacer()
            Image(systemName: "sparkle").font(.system(size: 11, weight: .semibold))
            Image(systemName: "wifi").font(.system(size: 11, weight: .semibold))
            Text("Thu Nov 5  9:41 AM").font(.system(size: 12))
        }
        .foregroundStyle(.white.opacity(0.92))
        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(Color.white.opacity(0.08))
    }
}

/// An abstract, macOS-style wallpaper: soft colour blobs over deep blue. Static, so GIFs stay small.
private struct Wallpaper: View {
    private struct Blob {
        let color: Color
        let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, angle: Double
    }

    private static let blobs: [Blob] = [
        Blob(color: Color(red: 0.16, green: 0.36, blue: 1.00), x: 0.10, y: 0.25, w: 0.75, h: 0.90, angle: -18),
        Blob(color: Color(red: 0.55, green: 0.24, blue: 0.98), x: 0.45, y: 0.10, w: 0.70, h: 0.80, angle: 12),
        Blob(color: Color(red: 1.00, green: 0.30, blue: 0.55), x: 0.80, y: 0.55, w: 0.60, h: 0.90, angle: -25),
        Blob(color: Color(red: 1.00, green: 0.58, blue: 0.24), x: 1.02, y: 1.05, w: 0.55, h: 0.70, angle: 20),
        Blob(color: Color(red: 0.05, green: 0.80, blue: 0.95), x: -0.05, y: 1.10, w: 0.55, h: 0.60, angle: 0),
    ]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Color(red: 0.10, green: 0.12, blue: 0.36)
                ForEach(Array(Self.blobs.enumerated()), id: \.offset) { _, blob in
                    // Radial gradients instead of .blur(): snapshots don't render blur filters.
                    let w = size.width * blob.w * 1.5
                    Circle()
                        .fill(RadialGradient(colors: [blob.color, blob.color.opacity(0.75), blob.color.opacity(0)],
                                             center: .center, startRadius: 0, endRadius: w / 2))
                        .frame(width: w, height: w)
                        .scaleEffect(x: 1, y: blob.h / blob.w * 0.6)
                        .rotationEffect(.degrees(blob.angle))
                        .position(x: size.width * blob.x, y: size.height * blob.y)
                }
            }
            .overlay(
                // Gentle vignette at the top so the menu bar reads well.
                LinearGradient(colors: [.black.opacity(0.25), .clear], startPoint: .top, endPoint: .center)
            )
        }
        .clipped()
    }
}
