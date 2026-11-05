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
        /// The turn ended with an API error.
        case failed
        /// Nothing from Claude – music is playing: cover on the left, equalizer on the right.
        case media
    }

    struct Celebration: Equatable {
        let id = UUID()
        let session: Session
    }

    static let wingWidth: CGFloat = 46
    static let expandedWidth: CGFloat = 460
    static let rowHeight: CGFloat = 50
    static let maxRows = 4
    static let mediaCardHeight: CGFloat = 84

    let store: SessionStore
    let media: NowPlaying

    @Published var notchSize = CGSize(width: 185, height: 32)
    @Published var hasPhysicalNotch = true
    @Published private(set) var presentation: Presentation = .hidden
    @Published private(set) var celebration: Celebration?
    @Published private(set) var attention: Session?
    @Published private(set) var failure: Session?
    /// Incremented to trigger the shake animation.
    @Published private(set) var shakes: CGFloat = 0
    @Published var isHovering = false {
        didSet { if oldValue != isHovering { recompute() } }
    }

    private var flashWork: DispatchWorkItem?

    init(store: SessionStore, media: NowPlaying) {
        self.store = store
        self.media = media
        media.onChange = { [weak self] in self?.recompute() }
    }

    /// A track is loaded in Spotify / Music and the media player is enabled.
    var hasMedia: Bool { Preferences.mediaEnabled && media.track != nil }

    /// Whether the hover view lists Claude sessions (always, unless there are none but music is playing).
    var showsSessionList: Bool { !store.sessions.isEmpty || !hasMedia }

    // MARK: - Geometry

    var size: CGSize {
        let flare = Self.topRadius(for: presentation)
        let compactWidth = notchSize.width + 2 * Self.wingWidth
        let wide = max(compactWidth, Self.expandedWidth)
        switch presentation {
        case .hidden:
            return CGSize(width: notchSize.width + 2 * flare, height: hasPhysicalNotch ? notchSize.height : 0)
        case .compact, .media:
            return CGSize(width: compactWidth, height: notchSize.height)
        case .expanded:
            var height = notchSize.height + 12
            if hasMedia { height += 2 + Self.mediaCardHeight }
            if showsSessionList {
                height += 10 + CGFloat(min(max(store.sessions.count, 1), Self.maxRows)) * Self.rowHeight
            }
            return CGSize(width: wide, height: height)
        case .celebrating:
            return CGSize(width: wide, height: notchSize.height + 104)
        case .attention, .failed:
            return CGSize(width: wide, height: notchSize.height + 88)
        }
    }

    /// Size of the window that hosts the notch – big enough for the largest state plus glow.
    var canvasSize: CGSize {
        CGSize(width: Self.expandedWidth + 80,
               height: notchSize.height + 10 + Self.mediaCardHeight + 10 + CGFloat(Self.maxRows) * Self.rowHeight + 12 + 40)
    }

    var topRadius: CGFloat { Self.topRadius(for: presentation) }

    var bottomRadius: CGFloat {
        switch presentation {
        case .hidden, .compact, .media: return min(12, notchSize.height * 0.38)
        default: return 26
        }
    }

    private static func topRadius(for p: Presentation) -> CGFloat {
        switch p {
        case .hidden, .compact, .media: return 6
        default: return 14
        }
    }

    // MARK: - State

    func handle(_ transition: Transition) {
        switch transition {
        case .finished(let session):
            attention = nil
            failure = nil
            celebration = Celebration(session: session)
            flash(for: Preferences.notificationSeconds)
        case .needsAttention(let session):
            celebration = nil
            failure = nil
            attention = session
            shakes += 1
            flash(for: Preferences.notificationSeconds)
        case .failed(let session):
            celebration = nil
            attention = nil
            failure = session
            shakes += 1
            flash(for: Preferences.notificationSeconds + 2)
        case .started(let session):
            if celebration?.session.id == session.id { endFlash() }
            if attention?.id == session.id { endFlash() }
            if failure?.id == session.id { endFlash() }
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
        if let f = failure {
            var stillFailed = false
            if let live = store.sessions[f.id], case .error = live.state { stillFailed = true }
            if !stillFailed { failure = nil }
        }

        let next: Presentation
        if celebration != nil {
            next = .celebrating
        } else if attention != nil {
            next = .attention
        } else if failure != nil {
            next = .failed
        } else if isHovering && (!store.sessions.isEmpty || hasMedia) {
            next = .expanded
        } else if store.hasActivity || store.hasWaiting {
            next = .compact
        } else if hasMedia && (media.isPlaying || Preferences.mediaShowWhenPaused) {
            next = .media
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
        failure = nil
        recompute()
    }
}
