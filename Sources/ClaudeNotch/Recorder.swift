import AppKit
import SwiftUI

/// Renders every notch animation into PNG frames so `scripts/record-gifs.sh` can turn them into GIFs
/// for the README and `docs/`.
///
/// `ClaudeNotch --record <out-dir> [scene …]` plays scripted hook events into a fresh store per scene,
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
        let steps: [(TimeInterval, HookEvent)]
    }

    static let fps: Double = 30
    static let width: CGFloat = 560

    private let outputDirectory: URL
    private var queue: [Scene]
    private var window: NSWindow?
    private let writer = DispatchQueue(label: "claude-notch.recorder", qos: .userInitiated)

    init(outputDirectory: URL, only names: [String]) {
        self.outputDirectory = outputDirectory
        let all = Self.scenes
        queue = names.isEmpty ? all : all.filter { names.contains($0.name) }
    }

    func start() {
        if queue.isEmpty {
            FileHandle.standardError.write(Data("✗ Unbekannte Szene. Verfügbar: \(Self.scenes.map(\.name).joined(separator: ", "))\n".utf8))
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
        let model = NotchViewModel(store: store)
        model.notchSize = CGSize(width: 185, height: 32)
        model.hasPhysicalNotch = true
        store.onChange = { model.recompute() }
        store.onTransition = { model.handle($0) }

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
                MainActor.assumeIsolated { store.handle(event) }
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
                while frame < due {
                    let url = dir.appendingPathComponent(String(format: "frame_%04d.png", frame))
                    let image = rep
                    self.writer.async {
                        try? image.representation(using: .png, properties: [:])?.write(to: url)
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

    static var scenes: [Scene] {
        let cwd = "/Users/you/Projects/claude-notch"
        func ev(_ name: String, _ id: String = "rec", cwd: String = cwd, tool: String? = nil, input: [String: Any] = [:],
                message: String? = nil, last: String? = nil, error: String? = nil, details: String? = nil) -> HookEvent {
            HookEvent(name: name, sessionID: id, cwd: cwd, toolName: tool, toolInput: input, message: message,
                      lastAssistantMessage: last, error: error, errorDetails: details)
        }
        let prompt = ev("UserPromptSubmit")

        return [
            Scene(name: "thinking", duration: 4.5, steps: [
                (0.0, ev("SessionStart")),
                (0.6, prompt),
            ]),
            Scene(name: "tools", duration: 9, steps: [
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
            Scene(name: "attention", duration: 6.5, steps: [
                (0.0, ev("SessionStart")),
                (0.3, prompt),
                (1.5, ev("PermissionRequest", tool: "Bash", input: ["command": "npm publish", "description": "npm publish"])),
            ]),
            Scene(name: "done", duration: 7.5, steps: [
                (0.0, ev("SessionStart")),
                (0.3, prompt),
                (0.9, ev("PreToolUse", tool: "Edit", input: ["file_path": "\(cwd)/Sources/NotchView.swift"])),
                (1.7, ev("PostToolUse", tool: "Edit")),
                (2.2, ev("Stop", last: "Parser refactored – alle 42 Tests grün.")),
            ]),
            Scene(name: "compacting", duration: 4.5, steps: [
                (0.0, ev("SessionStart")),
                (0.3, prompt),
                (1.2, ev("PreCompact")),
            ]),
            Scene(name: "error", duration: 7, steps: [
                (0.0, ev("SessionStart")),
                (0.3, prompt),
                (1.6, ev("StopFailure", error: "rate_limit", details: "429 Too Many Requests")),
            ]),
            Scene(name: "hover", duration: 6, height: 240, hoverAt: 1.2, dismissFlashAt: 0.1, steps: [
                (0.0, ev("UserPromptSubmit", "a")),
                (0.0, ev("PreToolUse", "a", tool: "Edit", input: ["file_path": "\(cwd)/Sources/NotchView.swift"])),
                (0.0, ev("UserPromptSubmit", "b", cwd: "/Users/you/Projects/api-server")),
                (0.0, ev("UserPromptSubmit", "c", cwd: "/Users/you/Projects/website")),
                (0.0, ev("PreToolUse", "c", cwd: "/Users/you/Projects/website", tool: "Bash",
                         input: ["command": "npm run build", "description": "npm run build"])),
                (0.0, ev("PostToolUse", "c", cwd: "/Users/you/Projects/website", tool: "Bash")),
                (0.0, ev("Stop", "c", cwd: "/Users/you/Projects/website", last: "Build ist durch.")),
            ]),
            Scene(name: "demo", duration: 17, steps: [
                (0.0, ev("SessionStart")),
                (0.5, prompt),
                (2.6, ev("PreToolUse", tool: "Grep", input: ["pattern": "func parse"])),
                (3.8, ev("PostToolUse", tool: "Grep")),
                (4.3, ev("PreToolUse", tool: "Edit", input: ["file_path": "\(cwd)/Sources/Parser.swift"])),
                (5.8, ev("PostToolUse", tool: "Edit")),
                (6.2, ev("PermissionRequest", tool: "Bash", input: ["command": "swift test", "description": "swift test"])),
                (9.4, ev("PreToolUse", tool: "Bash", input: ["command": "swift test", "description": "Run tests"])),
                (11.2, ev("PostToolUse", tool: "Bash")),
                (11.8, ev("Stop", last: "Parser refactored – alle 42 Tests grün.")),
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
            LinearGradient(colors: [Color(red: 0.16, green: 0.13, blue: 0.24), Color(red: 0.07, green: 0.06, blue: 0.11)],
                           startPoint: .top, endPoint: .bottom)
            menuBar
            NotchView(model: model, store: store)
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
            Text("Do 5. Nov. 09:41").font(.system(size: 12))
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(Color.black.opacity(0.25))
    }
}
