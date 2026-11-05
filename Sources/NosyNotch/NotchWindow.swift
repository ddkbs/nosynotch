import AppKit
import SwiftUI

/// Borderless, transparent panel that sits above the menu bar, centered on the notch.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Allow the window to overlap the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

enum NotchGeometry {
    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    static func notch(on screen: NSScreen) -> (size: CGSize, physical: Bool) {
        let top = screen.safeAreaInsets.top
        if top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return (CGSize(width: screen.frame.width - left.width - right.width, height: top), true)
        }
        // No notch: draw a "virtual" one that hangs from the middle of the menu bar.
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        return (CGSize(width: 120, height: max(24, menuBar)), false)
    }
}

/// Owns the panel, keeps it positioned on the notch and tracks hover without stealing clicks.
@MainActor
final class NotchWindowController {
    private let model: NotchViewModel
    private let panel: NotchPanel
    private var screen: NSScreen?
    private var globalMonitor: Any?
    private var hoverTimer: Timer?
    private var screenObserver: NSObjectProtocol?

    init(model: NotchViewModel) {
        self.model = model
        self.panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 600, height: 300))

        let host = NSHostingView(rootView: NotchView(model: model, store: model.store, media: model.media))
        host.sizingOptions = []
        host.wantsLayer = true
        host.layer?.backgroundColor = .clear
        panel.contentView = host

        layout()
        panel.orderFrontRegardless()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout() }
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateHover() }
        }
    }

    func layout() {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        self.screen = screen
        let notch = NotchGeometry.notch(on: screen)
        model.notchSize = notch.size
        model.hasPhysicalNotch = notch.physical

        let canvas = model.canvasSize
        let frame = NSRect(x: screen.frame.midX - canvas.width / 2,
                           y: screen.frame.maxY - canvas.height,
                           width: canvas.width,
                           height: canvas.height)
        panel.setFrame(frame, display: true)
    }

    /// The on-screen rect of the black notch shape in its current state.
    private var notchRect: NSRect {
        guard let screen else { return .zero }
        let size = model.size
        return NSRect(x: screen.frame.midX - size.width / 2,
                      y: screen.frame.maxY - size.height,
                      width: size.width,
                      height: size.height)
    }

    private func updateHover() {
        let mouse = NSEvent.mouseLocation
        var rect = notchRect
        if rect.height < 1 { rect.size.height = model.notchSize.height; rect.origin.y -= model.notchSize.height }
        let inside = rect.insetBy(dx: -6, dy: -6).contains(mouse)

        if inside != model.isHovering {
            model.isHovering = inside
        }
        // Only catch clicks while the pointer is over the notch; everywhere else clicks fall through.
        let interactive = inside && model.presentation != .hidden
        if panel.ignoresMouseEvents == interactive { panel.ignoresMouseEvents = !interactive }

        if inside, hoverTimer == nil {
            // While hovering, our window receives the mouse events, so poll to notice the exit.
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateHover() }
            }
        } else if !inside, let timer = hoverTimer {
            timer.invalidate()
            hoverTimer = nil
        }
    }
}
