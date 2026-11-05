import SwiftUI

/// Decides how big the notch is and what it shows. Pure UI state – session data lives in `SessionStore`.
@MainActor
final class NotchViewModel: ObservableObject {
    enum Presentation: Equatable {
        /// Invisible: exactly covers the physical notch.
        case hidden
        /// Notch plus two small "wings" with the live activity animation.
        case compact
        /// Hover: list of all sessions.
        case expanded
        /// A turn just finished – checkmark + confetti.
        case celebrating
        /// Claude needs permission / input.
        case attention
    }

    struct Celebration: Equatable {
        let id = UUID()
        let session: Session
    }

    static let wingWidth: CGFloat = 46
    static let expandedWidth: CGFloat = 460
    static let rowHeight: CGFloat = 50
    static let maxRows = 4

    let store: SessionStore

    @Published var notchSize = CGSize(width: 185, height: 32)
    @Published var hasPhysicalNotch = true
    @Published private(set) var presentation: Presentation = .hidden
    @Published private(set) var celebration: Celebration?
    @Published private(set) var attention: Session?
    /// Incremented to trigger the shake animation.
    @Published private(set) var shakes: CGFloat = 0
    @Published var isHovering = false {
        didSet { if oldValue != isHovering { recompute() } }
    }

    private var flashWork: DispatchWorkItem?

    init(store: SessionStore) {
        self.store = store
    }

    // MARK: - Geometry

    var size: CGSize {
        let flare = Self.topRadius(for: presentation)
        let compactWidth = notchSize.width + 2 * Self.wingWidth
        let wide = max(compactWidth, Self.expandedWidth)
        switch presentation {
        case .hidden:
            return CGSize(width: notchSize.width + 2 * flare, height: hasPhysicalNotch ? notchSize.height : 0)
        case .compact:
            return CGSize(width: compactWidth, height: notchSize.height)
        case .expanded:
            let rows = CGFloat(min(max(store.sessions.count, 1), Self.maxRows))
            return CGSize(width: wide, height: notchSize.height + 10 + rows * Self.rowHeight + 12)
        case .celebrating:
            return CGSize(width: wide, height: notchSize.height + 104)
        case .attention:
            return CGSize(width: wide, height: notchSize.height + 88)
        }
    }

    /// Size of the window that hosts the notch – big enough for the largest state plus glow.
    var canvasSize: CGSize {
        CGSize(width: Self.expandedWidth + 80,
               height: notchSize.height + 10 + CGFloat(Self.maxRows) * Self.rowHeight + 12 + 40)
    }

    var topRadius: CGFloat { Self.topRadius(for: presentation) }

    var bottomRadius: CGFloat {
        switch presentation {
        case .hidden, .compact: return min(12, notchSize.height * 0.38)
        default: return 26
        }
    }

    private static func topRadius(for p: Presentation) -> CGFloat {
        switch p {
        case .hidden, .compact: return 6
        default: return 14
        }
    }

    // MARK: - State

    func handle(_ transition: Transition) {
        switch transition {
        case .finished(let session):
            attention = nil
            celebration = Celebration(session: session)
            flash(for: 6)
        case .needsAttention(let session):
            celebration = nil
            attention = session
            shakes += 1
            flash(for: 6)
        case .started(let session):
            if celebration?.session.id == session.id { endFlash() }
            if attention?.id == session.id { endFlash() }
        }
        recompute()
    }

    func dismissFlash() {
        endFlash()
    }

    func recompute() {
        // Attention is over as soon as that session moves on (e.g. permission granted).
        if let a = attention {
            var stillWaiting = false
            if let live = store.sessions[a.id], case .waiting = live.state { stillWaiting = true }
            if !stillWaiting { attention = nil }
        }

        let next: Presentation
        if celebration != nil {
            next = .celebrating
        } else if attention != nil {
            next = .attention
        } else if isHovering && !store.sessions.isEmpty {
            next = .expanded
        } else if store.hasActivity || store.hasWaiting {
            next = .compact
        } else {
            next = .hidden
        }
        if next != presentation { presentation = next }
    }

    private func flash(for seconds: TimeInterval) {
        flashWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.endFlash() }
        }
        flashWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func endFlash() {
        flashWork?.cancel()
        flashWork = nil
        celebration = nil
        attention = nil
        recompute()
    }
}
