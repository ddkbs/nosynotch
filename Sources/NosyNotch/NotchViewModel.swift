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
    let approvals: ApprovalCenter
    let usage: UsageStore
    /// Live band levels of the playing music (only with the live equalizer turned on).
    let spectrum = AudioSpectrum()
    private var tappedPlayer: String?
    private var wasPlaying = false
    /// Nod / shake with AirPods while a permission request is open (opt-in).
    let head = HeadGestures()

    static let usageRowHeight: CGFloat = 24

    /// Extra height for the Allow / Deny row.
    static let approvalRowHeight: CGFloat = 40

    @Published var notchSize = CGSize(width: 185, height: 32)
    @Published var hasPhysicalNotch = true
    @Published private(set) var presentation: Presentation = .hidden
    @Published private(set) var celebration: Celebration?
    @Published private(set) var attention: Session?
    @Published private(set) var failure: Session?
    /// A turn finished while its app was in front: only a small check in the compact notch.
    @Published private(set) var quietDone: Session?
    /// Incremented to trigger the shake animation.
    @Published private(set) var shakes: CGFloat = 0
    @Published var isHovering = false {
        didSet {
            guard oldValue != isHovering else { return }
            recompute()
            // Looking at the session list for a moment counts as "seen".
            if isHovering, !store.unseen.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    MainActor.assumeIsolated {
                        guard let self, self.isHovering, self.presentation == .expanded else { return }
                        self.store.markAllSeen()
                    }
                }
            }
        }
    }

    private var flashWork: DispatchWorkItem?
    /// When the current "needs you" card opened – a card with Allow / Deny closes after `approvalCardSeconds`.
    private var attentionSince: Date?
    static let approvalCardSeconds: TimeInterval = 30
    private var quietWork: DispatchWorkItem?

    init(store: SessionStore, media: NowPlaying, approvals: ApprovalCenter? = nil, usage: UsageStore? = nil) {
        self.store = store
        self.media = media
        let approvals = approvals ?? ApprovalCenter()
        self.approvals = approvals
        let usage = usage ?? UsageStore(load: false)
        self.usage = usage
        usage.onChange = { [weak self] in self?.objectWillChange.send() }
        head.onGesture = { [weak self] gesture in
            guard let self, let approval = self.attentionApproval else { return }
            self.decide(approval, gesture == .nod ? .allow : .deny)
        }
        media.onChange = { [weak self] in self?.recompute() }
        approvals.onChange = { [weak self] in
            guard let self else { return }
            self.objectWillChange.send()   // size depends on whether buttons are shown
            // A request for a session that was already "waiting" brings no new transition – show it anyway.
            if self.attention == nil, let approval = approvals.pending.last,
               let session = self.store.sessions[approval.sessionID] {
                self.handle(.needsAttention(session))
            } else {
                self.recompute()
            }
        }
    }

    /// The permission request shown with Allow / Deny buttons, if any.
    var attentionApproval: PendingApproval? {
        attention.flatMap { approvals.pending(for: $0.id) }
    }

    /// A track is loaded in Spotify / Music and the media player is enabled.
    var hasMedia: Bool { Preferences.mediaEnabled && media.track != nil }

    /// Usage bars shown at the bottom of the hover view.
    var usageRows: [(agent: Agent, usage: AgentUsage)] {
        Preferences.usageEnabled ? usage.rows.filter { Preferences.showsUsage(for: $0.agent) } : []
    }

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
            let usageCount = usageRows.count
            if usageCount > 0 { height += 8 + CGFloat(usageCount) * Self.usageRowHeight }
            return CGSize(width: wide, height: height)
        case .celebrating:
            return CGSize(width: wide, height: notchSize.height + 104)
        case .attention:
            return CGSize(width: wide, height: notchSize.height + 88 + (attentionApproval != nil ? Self.approvalRowHeight : 0))
        case .failed:
            return CGSize(width: wide, height: notchSize.height + 88)
        }
    }

    /// Size of the window that hosts the notch – big enough for the largest state plus glow.
    var canvasSize: CGSize {
        CGSize(width: Self.expandedWidth + 80,
               height: notchSize.height + 10 + Self.mediaCardHeight + 10 + CGFloat(Self.maxRows) * Self.rowHeight
                   + 8 + 2 * Self.usageRowHeight + 12 + 40)
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
            attentionSince = Date()
            shakes += 1
            flash(for: Preferences.notificationSeconds)
        case .failed(let session):
            celebration = nil
            attention = nil
            failure = session
            shakes += 1
            flash(for: Preferences.notificationSeconds + 2)
        case .started(let session):
            if quietDone?.id == session.id { quietDone = nil }
            if celebration?.session.id == session.id { endFlash() }
            if attention?.id == session.id { endFlash() }
            if failure?.id == session.id { endFlash() }
        }
        recompute()
    }

    /// "Done" / "needs you" without the big card – you're already looking at that app. A waiting session
    /// shows up in the compact notch anyway (amber bubble); "done" gets a check for 3 s.
    func showQuietly(_ transition: Transition) {
        if case .needsAttention(let session) = transition {
            if attention?.id == session.id { endFlash() } else { recompute() }
            return
        }
        guard case .finished(let session) = transition else { return handle(transition) }
        if celebration?.session.id == session.id { celebration = nil }
        if attention?.id == session.id { attention = nil }
        if failure?.id == session.id { failure = nil }
        quietDone = session
        quietWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.quietDone = nil
                self?.recompute()
            }
        }
        quietWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
        recompute()
    }

    /// The session the compact notch is about (the quiet "done" wins for its few seconds, then unseen ones).
    var compactSession: Session? {
        if let quiet = quietDone { return store.sessions[quiet.id] ?? quiet }
        if !store.hasActivity && !store.hasWaiting, let unseen = store.unseen.first { return unseen }
        return store.primary
    }

    /// Nothing running, but something finished that you haven't looked at yet: the green dot.
    var showsUnseenDot: Bool {
        quietDone == nil && !store.hasActivity && !store.hasWaiting && !store.unseen.isEmpty
    }

    func dismissFlash() {
        if let celebration { store.markSeen(celebration.session.id) }
        // ✕ on a permission request: hand it back to the terminal / Codex prompt right away.
        if let approval = attentionApproval { approvals.release(approval.id) }
        endFlash()
    }

    func decide(_ approval: PendingApproval, _ decision: ApprovalDecision) {
        approvals.decide(approval.id, decision)
        store.resume(approval.sessionID, allowed: decision != .deny, tool: approval.tool)
        endFlash()
    }

    /// Tap the player's audio only while it plays and the live equalizer is on (and we run as an .app –
    /// the audio permission needs a bundle).
    ///
    /// The tap starts with the first play and then stays open across pauses: every new tap is a fresh audio
    /// capture, and macOS may ask about it again. It closes when the player quits or the option is turned off.
    private func updateSpectrum() {
        let canTap = Bundle.main.bundleURL.pathExtension == "app"
        let wanted = canTap && Preferences.liveEqualizer && Preferences.mediaEnabled ? media.track?.source.bundleID : nil
        if wanted != tappedPlayer { tappedPlayer = media.isPlaying ? wanted : (wanted == nil ? nil : tappedPlayer) }
        spectrum.follow(bundleID: tappedPlayer)
        // Spotify sometimes plays through a new helper process after a long pause – reattach if it went quiet.
        if media.isPlaying && !wasPlaying { spectrum.reattachIfSilent() }
        wasPlaying = media.isPlaying
    }

    func recompute() {
        updateSpectrum()
        defer {
            let canTrack = Bundle.main.bundleURL.pathExtension == "app"
            head.setActive(canTrack && Preferences.headGestures && presentation == .attention && attentionApproval != nil)
        }
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
        } else if store.hasActivity || store.hasWaiting || quietDone != nil {
            next = .compact
        } else if hasMedia && (media.isPlaying || Preferences.mediaShowWhenPaused) {
            next = .media
        } else if !store.unseen.isEmpty {
            next = .compact
        } else {
            next = .hidden
        }
        if next != presentation { presentation = next }
    }

    private func flash(for seconds: TimeInterval) {
        flashWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Keep Allow / Deny on screen for a while, then fold away and leave the question to the
                // agent's own prompt (the compact notch keeps its amber bubble).
                if let approval = self.attentionApproval {
                    let open = Date().timeIntervalSince(self.attentionSince ?? .distantPast)
                    if open < Self.approvalCardSeconds { return self.flash(for: min(2, Self.approvalCardSeconds - open)) }
                    self.approvals.release(approval.id)
                }
                self.endFlash()
            }
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
