import AppKit
import SwiftUI

/// Renders every notch animation into PNG frames so `scripts/record-gifs.sh` can turn them into GIFs
/// for the README and MP4s for the website.
///
/// `NosyNotch --record <out-dir> [scene …]` plays scripted hook events into a fresh store per scene and shows the
/// real `NotchView` on a fake menu bar in a regular window. Frames are rendered deterministically: frame N shows
/// the moment N / fps on a virtual clock (`Clock`), SwiftUI's own animations are stepped with
/// `NSHostingView._renderForTest(interval:)`. Slow frames make the recording take longer, they never drop.
///
/// Environment: `FPS` (default 60) and `SCALE` (pixels per point, default 2; 3 = 1680 px wide).
@MainActor
final class Recorder {
    struct Scene {
        let name: String
        let duration: TimeInterval
        var height: CGFloat = 214
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
        /// Seconds after which a nearly used-up 5-hour limit "resets".
        var limitResetAt: TimeInterval?
        let steps: [(TimeInterval, HookEvent)]
        /// Anything else to do with the model at a given moment (drag files, plug in power, …).
        var actions: [(TimeInterval, @MainActor (NotchViewModel) -> Void)] = []
    }

    static let fps: Double = environment("FPS", default: 60, in: 1...240)
    static let scale: CGFloat = CGFloat(environment("SCALE", default: 2, in: 1...4))
    static let width: CGFloat = 560

    private static func environment(_ key: String, default value: Double, in range: ClosedRange<Double>) -> Double {
        guard let raw = ProcessInfo.processInfo.environment[key], !raw.isEmpty else { return value }
        guard let number = Double(raw), range.contains(number) else {
            FileHandle.standardError.write(Data("✗ \(key)=\(raw) is not a number in \(range)\n".utf8))
            exit(1)
        }
        return number
    }

    private let outputDirectory: URL
    private var queue: [Scene]
    private var window: NSWindow?

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
            FrameWriter.shared.finish { NSApp.terminate(nil) }
            return
        }
        record(queue.removeFirst()) { [weak self] in self?.next() }
    }

    private func record(_ scene: Scene, completion: @escaping () -> Void) {
        // Everything below – store dates, flash timeouts, the scripted events – runs on the virtual clock.
        let start = Date()
        Clock.startVirtual(at: start)
        let clock = RecordingClock(date: start)

        let store = SessionStore()
        let model = NotchViewModel(store: store, media: NowPlaying(observeSystem: false), pet: SettingsRecorder.demoPet,
                                   shelf: Shelf(persist: false))
        model.notchSize = CGSize(width: 185, height: 32)
        model.onNoticeAction = { _ in }
        model.hasPhysicalNotch = true
        store.onChange = { model.recompute() }
        store.onTransition = { scene.focused ? model.showQuietly($0) : model.handle($0) }
        if let t = scene.limitResetAt {
            model.usage.onReset = { agent, window in model.showLimitReset(agent: agent, window: window) }
            model.usage.set(AgentUsage(fiveHour: UsageWindow(usedPercent: 94, resetsAt: start + t)), for: .claude)
            Clock.after(t + 0.05) { model.usage.checkResets(now: Clock.now().addingTimeInterval(1)) }
        }
        if scene.usage {
            model.usage.set(AgentUsage(fiveHour: UsageWindow(usedPercent: 38, resetsAt: start + 2 * 3600 + 840),
                                       week: UsageWindow(usedPercent: 71, resetsAt: start + 3 * 86_400)), for: .claude)
            model.usage.set(AgentUsage(fiveHour: UsageWindow(usedPercent: 12, resetsAt: start + 4 * 3600),
                                       week: UsageWindow(usedPercent: 90, resetsAt: start + 86_400)), for: .codex)
            Clock.after(0.2) {
                store.setContext("a", percent: 64)
                store.setContext("cx", percent: 88)
            }
        }

        for (delay, event) in scene.steps {
            Clock.after(delay) {
                store.handle(event)
                // Permission requests wait for Allow / Deny, like the real hook.
                if event.name == "PermissionRequest" { model.approvals.add(event) { _ in } }
            }
        }
        if let t = scene.allowAt {
            Clock.after(t) { if let approval = model.attentionApproval { model.decide(approval, .allow) } }
        }
        if let t = scene.musicAt {
            Clock.after(t) { model.media.preview(Self.demoTrack, artwork: Self.demoArtwork(), playing: true, position: 74) }
        }
        if let t = scene.dismissFlashAt {
            Clock.after(t) { model.dismissFlash() }
        }
        if let t = scene.hoverAt {
            Clock.after(t) { model.isHovering = true }
        }
        for (t, action) in scene.actions {
            Clock.after(t) { action(model) }
        }

        let size = CGSize(width: Self.width, height: scene.height)
        let host = NSHostingView(rootView: RecordingStage(model: model, store: store, clock: clock))
        host.frame = CGRect(origin: .zero, size: size)
        show(host, size: size)

        let dir = outputDirectory.appendingPathComponent(scene.name, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let total = Int((scene.duration * Self.fps).rounded())
        let stillFrame = scene.stillAt.map { Int(($0 * Self.fps).rounded()) }
        print("● \(scene.name) (\(total) frames, \(Int(Self.fps)) fps, \(Int(Self.width * Self.scale)) px) …")

        var frame = 0
        func step() {
            let now = start + Double(frame) / Self.fps
            Clock.advance(to: now)
            clock.date = now
            host._renderForTest(interval: frame == 0 ? 0 : 1 / Self.fps)

            var urls = [dir.appendingPathComponent(String(format: "frame_%04d.png", frame))]
            if frame == stillFrame { urls.append(outputDirectory.appendingPathComponent("stills/\(scene.name).png")) }
            FrameWriter.shared.write(Self.snapshot(host), to: urls)

            frame += 1
            if frame < total {
                // Back to the run loop between frames so queued main-thread work (Combine, Tasks) gets to run.
                DispatchQueue.main.async { MainActor.assumeIsolated { step() } }
            } else {
                store.onChange = nil
                store.onTransition = nil
                Clock.stopVirtual()
                completion()
            }
        }
        step()
    }

    private func show(_ host: NSView, size: CGSize) {
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
    }

    /// The view's current state at `scale` pixels per point, independent of the screen's backing scale.
    /// Plain sRGB: the screen's own profile would be baked into the pixels, and ffmpeg ignores ICC profiles.
    static func snapshot(_ view: NSView) -> NSBitmapImageRep? {
        let bounds = view.bounds
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int((bounds.width * scale).rounded()),
                                         pixelsHigh: Int((bounds.height * scale).rounded()),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)?
            .retagging(with: .sRGB)
        else { return nil }
        rep.size = bounds.size
        view.cacheDisplay(in: bounds, to: rep)
        return rep
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

    static var demoMeeting: Meeting {
        Meeting(id: "demo", title: "Daily standup", start: Clock.now().addingTimeInterval(10 * 60 + 20),
                end: Clock.now().addingTimeInterval(25 * 60), color: Color(red: 0.36, green: 0.62, blue: 1),
                location: "Zoom", joinURL: URL(string: "https://zoom.us/j/123"))
    }

    static let demoChat: [ChatMessage] = [
        ChatMessage(id: "1", role: .user, text: "the login redirect loops after a token refresh – can you fix it?"),
        ChatMessage(id: "2", role: .assistant, text: "Found it: `AuthGuard` checked the old token before the refresh finished. I moved the refresh in front of the guard and added a regression test."),
        ChatMessage(id: "3", role: .user, text: "nice. run the whole test suite once more"),
        ChatMessage(id: "4", role: .assistant, text: "All **214 tests** pass. Ready to commit when you are."),
    ]

    /// Files that exist on every Mac, for the shelf scenes.
    static let demoFiles: [URL] = ["/System/Library/CoreServices/Finder.app", "/etc/hosts",
                                   "/System/Library/Desktop Pictures"]
        .map { URL(fileURLWithPath: $0) }

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
            Scene(name: "nosy", duration: 8, height: 290, stillAt: 3.6, steps: [], actions: [
                (0.3, { $0.updateGaze(mouse: CGPoint(x: -150, y: -50), notchCenter: .zero) }),
                (1.0, { $0.updateGaze(mouse: CGPoint(x: 160, y: -40), notchCenter: .zero) }),
                (1.7, { $0.updateGaze(mouse: CGPoint(x: 20, y: -30), notchCenter: .zero) }),
                (2.2, { $0.isHovering = true }),
                (4.0, { $0.petNosy() }),
                (5.8, { $0.isHovering = false }),
                (6.6, { $0.updateGaze(mouse: CGPoint(x: -120, y: -90), notchCenter: .zero) }),
            ]),
            Scene(name: "level-up", duration: 6, stillAt: 3.2, steps: [
                (0.0, ev("SessionStart")),
                (0.3, prompt),
                (1.0, ev("PreToolUse", tool: "Edit", input: ["file_path": "\(cwd)/Sources/NotchView.swift"])),
                (1.8, ev("PostToolUse", tool: "Edit")),
                (2.2, ev("Stop", last: "Nosy's new look is in – eight colours to pick from.")),
            ], actions: [
                (2.21, { $0.celebrateLevel(7) }),
            ]),
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
            Scene(name: "unseen", duration: 10, stillAt: 8.8, steps: [
                (0.0, ev("SessionStart")),
                (0.3, prompt),
                (1.0, ev("Stop", last: "Parser refactored – all 42 tests pass.")),
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
            Scene(name: "hover", duration: 6, height: 290, hoverAt: 1.2, dismissFlashAt: 0.1, stillAt: 4.5, steps: [
                (0.0, ev("UserPromptSubmit", "a")),
                (0.0, ev("PreToolUse", "a", tool: "Edit", input: ["file_path": "\(cwd)/Sources/NotchView.swift"])),
                (0.0, ev("UserPromptSubmit", "b", cwd: "/Users/you/Projects/api-server")),
                (0.0, ev("UserPromptSubmit", "c", agent: .cursor, cwd: "/Users/you/Projects/website")),
                (0.0, ev("PreToolUse", "c", agent: .cursor, cwd: "/Users/you/Projects/website", tool: "Shell",
                         input: ["command": "npm run build"])),
                (0.0, ev("PostToolUse", "c", agent: .cursor, cwd: "/Users/you/Projects/website", tool: "Shell")),
                (0.0, ev("Stop", "c", agent: .cursor, cwd: "/Users/you/Projects/website", last: "Build succeeded.")),
            ]),
            Scene(name: "codex", duration: 10, height: 250, hoverAt: 6.6, dismissFlashAt: 6.5, stillAt: 8.8, steps: [
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
            Scene(name: "usage", duration: 5, height: 300, hoverAt: 0.8, stillAt: 3.5, usage: true, steps: [
                (0.0, ev("UserPromptSubmit", "a")),
                (0.0, ev("PreToolUse", "a", tool: "Edit", input: ["file_path": "\(cwd)/Sources/NotchView.swift"])),
                (0.0, ev("UserPromptSubmit", "cx", agent: .codex, cwd: "/Users/you/Projects/api-server")),
            ]),
            Scene(name: "limit-reset", duration: 5.5, stillAt: 3.0, limitResetAt: 0.6, steps: []),
            Scene(name: "charging", duration: 4.5, stillAt: 2.0, steps: [], actions: [
                (0.5, { $0.showNotice(.charging(percent: 64)) }),
            ]),
            Scene(name: "airpods", duration: 4.5, stillAt: 2.0, steps: [], actions: [
                (0.5, { $0.showNotice(.device(name: "David's AirPods Pro", symbol: "airpodspro",
                                              batteries: [.init(label: "L", percent: 82), .init(label: "R", percent: 79),
                                                          .init(label: "Case", percent: 46)])) }),
            ]),
            Scene(name: "focus", duration: 6, stillAt: 4.5, steps: [], actions: [
                (0.4, { $0.focus.start(.focus, minutes: 25) }),
                (3.0, { model in
                    model.focus.stop()
                    model.showNotice(.timerDone(wasFocus: true, minutes: 25))
                }),
            ]),
            Scene(name: "meeting", duration: 5, stillAt: 2.2, steps: [], actions: [
                (0.5, { $0.showNotice(.meeting(Self.demoMeeting)) }),
            ]),
            Scene(name: "chat", duration: 6, height: 370, stillAt: 4.0, steps: [
                (0.0, ev("SessionStart", "chat", cwd: "/Users/you/Projects/api-server")),
                (0.2, ev("UserPromptSubmit", "chat", cwd: "/Users/you/Projects/api-server")),
                (0.6, ev("Stop", "chat", cwd: "/Users/you/Projects/api-server",
                         last: "Fixed the login redirect – the token refresh now runs before the guard.")),
            ], actions: [
                (2.0, { model in
                    guard let session = model.store.sessions["chat"] else { return }
                    model.previewChat(session, messages: Self.demoChat)
                }),
            ]),
            Scene(name: "drop-zone", duration: 5, stillAt: 2.0, steps: [], actions: [
                (0.6, { $0.fileDragNear = true }),
                (3.2, { model in
                    model.shelf.add(Self.demoFiles)
                    model.fileDragNear = false
                }),
            ]),
            Scene(name: "shelf", duration: 5, height: 250, hoverAt: 0.8, stillAt: 3.0, steps: [], actions: [
                (0.0, { $0.shelf.add(Self.demoFiles) }),
            ]),
            Scene(name: "media", duration: 7, height: 220, hoverAt: 2.6, stillAt: 5.0, musicAt: 0.5, steps: []),
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

/// The virtual time the recorder hands to every `ClockTimeline` in the stage.
@MainActor
final class RecordingClock: ObservableObject {
    @Published var date: Date
    init(date: Date) { self.date = date }
}

/// Encodes and writes frames off the main thread, with a cap on how many wait in memory.
final class FrameWriter: @unchecked Sendable {
    static let shared = FrameWriter()

    private let queue = DispatchQueue(label: "nosynotch.recorder.writer", qos: .userInitiated, attributes: .concurrent)
    private let group = DispatchGroup()
    private let slots = DispatchSemaphore(value: ProcessInfo.processInfo.activeProcessorCount * 2)

    func write(_ image: NSBitmapImageRep?, to urls: [URL]) {
        guard let image else { return }
        slots.wait()
        queue.async(group: group) { [slots] in
            defer { slots.signal() }
            guard let png = image.representation(using: .png, properties: [:]) else { return }
            for url in urls {
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                         withIntermediateDirectories: true)
                try? png.write(to: url)
            }
        }
    }

    /// Calls `done` on the main queue once every frame is on disk.
    func finish(_ done: @escaping @MainActor () -> Void) {
        group.notify(queue: .main) { MainActor.assumeIsolated(done) }
    }

    func wait() { group.wait() }
}

/// The notch on a stylised desktop: wallpaper + menu bar.
private struct RecordingStage: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var store: SessionStore
    @ObservedObject var clock: RecordingClock

    var body: some View {
        ZStack(alignment: .top) {
            Wallpaper()
            menuBar
            NotchView(model: model, store: store, media: model.media)
        }
        .frame(width: Recorder.width)
        .environment(\.colorScheme, .dark)
        .environment(\.virtualDate, clock.date)
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

// MARK: - Settings window

/// `NosyNotch --record-settings <dir>`: frames of the settings window flipping through its pages (for the README).
@MainActor
enum SettingsRecorder {
    static func run(output: URL) {
        let actions = SettingsWindowController.Actions(statusLine: { "Listening on 127.0.0.1:7823 · 3 sessions" },
                                                       playDemo: {}, settingsChanged: {}, muteChanged: {},
                                                       pet: Self.demoPet)
        let pages: [SettingsPage] = [.agents, .nosy, .alerts, .permissions, .usage, .extras, .music]
        let dir = output.appendingPathComponent("settings", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let window = NSWindow(contentRect: CGRect(origin: .zero, size: SettingsView.size), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        if let screen = NSScreen.main {
            window.setFrameOrigin(CGPoint(x: screen.visibleFrame.minX + 20, y: screen.visibleFrame.minY + 20))
        }
        window.orderFrontRegardless()
        print("● settings …")

        // About 1.8 s per page, on the virtual clock like the notch scenes.
        let start = Date()
        Clock.startVirtual(at: start)
        let clock = RecordingClock(date: start)
        let perPage = Int((1.8 * Recorder.fps).rounded())
        var frame = 0
        for page in pages {
            let host = NSHostingView(rootView: SettingsStage(clock: clock) { SettingsView(actions: actions, page: page) })
            host.frame = CGRect(origin: .zero, size: SettingsView.size)
            window.contentView = host
            for i in 0..<perPage {
                let now = start + Double(frame) / Recorder.fps
                Clock.advance(to: now)
                clock.date = now
                RunLoop.main.run(until: Date())   // let queued main-thread work run
                host._renderForTest(interval: i == 0 ? 0 : 1 / Recorder.fps)
                let url = dir.appendingPathComponent(String(format: "frame_%04d.png", frame))
                FrameWriter.shared.write(Recorder.snapshot(host), to: [url])
                frame += 1
            }
        }
        FrameWriter.shared.wait()
        Clock.stopVirtual()
        window.orderOut(nil)
    }

    /// A Nosy that has been around for a while (level 6, a 5-day streak).
    static var demoPet: NosyPet {
        let pet = NosyPet(persist: false)
        var state = NosyPet.State()
        state.xp = 2_200
        state.energy = 0.78
        state.streak = 5
        state.bestStreak = 12
        state.totalTasks = 318
        state.lastActiveDay = NosyPet.dayString(Date())
        state.today = NosyPet.dayString(Date())
        state.tasksToday = 14
        state.secondsToday = 9_240
        state.lastDecay = Date()
        pet.set(state)
        return pet
    }

    private struct SettingsStage<Content: View>: View {
        @ObservedObject var clock: RecordingClock
        @ViewBuilder var content: () -> Content

        var body: some View {
            content().environment(\.virtualDate, clock.date)
        }
    }
}
