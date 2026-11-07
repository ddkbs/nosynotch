import Combine
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
        /// A usage limit that was nearly used up has reset.
        case limitReset
        /// Nothing from Claude – music is playing: cover on the left, equalizer on the right.
        case media
        /// Nothing going on, but the pointer came close: Nosy peeks out of the notch.
        case peek
        /// Files are being dragged near the notch: Shelf and AirDrop targets.
        case dropZone
        /// A small system moment: power, headphones, focus timer, meeting.
        case notice
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
    /// Where Nosy looks (the pointer).
    let gaze = NosyGaze()
    /// Energy, level and streak.
    let pet: NosyPet
    /// Files parked in the notch.
    let shelf: Shelf
    /// Files are being dragged and the pointer is near the notch.
    @Published var fileDragNear = false {
        didSet { if oldValue != fileDragNear { recompute() } }
    }

    /// A short mood that wins over everything else for a moment (petting, waking up).
    struct NosyBurst: Equatable {
        let mood: NosyMood
        let until: Date
    }
    @Published private(set) var nosyBurst: NosyBurst?
    /// Nothing happened for a while – Nosy dozes off.
    @Published private(set) var isAsleep = false
    /// The pointer is close to the notch (Nosy peeks out).
    @Published private(set) var pointerIsNear = false
    private var lastActivity = Clock.now()
    private var shelfObserver: AnyCancellable?
    private var sleepTimer: Timer?
    static let sleepAfter: TimeInterval = 10 * 60
    static let sleepAfterAtNight: TimeInterval = 2 * 60

    static let usageRowHeight: CGFloat = 24
    static let nosyCardHeight: CGFloat = 40
    static let shelfRowHeight: CGFloat = 46

    /// Extra height for the Allow / Deny row.
    static let approvalRowHeight: CGFloat = 40

    @Published var notchSize = CGSize(width: 185, height: 32)
    @Published var hasPhysicalNotch = true
    @Published private(set) var presentation: Presentation = .hidden
    @Published private(set) var celebration: Celebration?
    @Published private(set) var attention: Session?
    @Published private(set) var failure: Session?
    /// "Claude is ready again – 5-hour limit reset".
    @Published private(set) var limitReset: LimitReset?

    struct NoticeItem: Equatable {
        let id = UUID()
        let notice: Notice
    }
    @Published private(set) var notice: NoticeItem?
    private var noticeWork: DispatchWorkItem?

    /// Show a system moment for its few seconds – unless an agent has something more important to say.
    func showNotice(_ notice: Notice) {
        guard celebration == nil, attention == nil, failure == nil else { return }
        let item = NoticeItem(notice: notice)
        self.notice = item
        noticeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.notice?.id == item.id else { return }
                self.notice = nil
                self.recompute()
            }
        }
        noticeWork = work
        Clock.after(notice.seconds, execute: work)
        recompute()
    }

    /// The glow around a notice card.
    var noticeGlow: Color {
        switch notice?.notice {
        case .charging: return Theme.success
        case .lowBattery: return Theme.amber
        case .meeting(let m): return m.color
        case .timerDone: return NosyPalette.top
        default: return .white
        }
    }

    /// The button on a notice card (Join a meeting, start the break …).
    var onNoticeAction: ((Notice) -> Void)?

    func noticeAction(for notice: Notice) -> (() -> Void)? {
        guard let onNoticeAction else { return nil }
        return { [weak self] in
            onNoticeAction(notice)
            self?.dismissNotice()
        }
    }

    func dismissNotice() {
        noticeWork?.cancel()
        notice = nil
        recompute()
    }

    struct LimitReset: Equatable {
        let id = UUID()
        let agent: Agent
        let window: String
    }
    /// A turn finished while its app was in front: only a small check in the compact notch.
    @Published private(set) var quietDone: Session?
    /// Incremented to trigger the shake animation.
    @Published private(set) var shakes: CGFloat = 0
    @Published var isHovering = false {
        didSet {
            guard oldValue != isHovering else { return }
            if isHovering { wakeUp(); noteActivity() }
            recompute()
            // Looking at the session list for a moment counts as "seen".
            if isHovering, !store.unseen.isEmpty {
                Clock.after(0.8) { [weak self] in
                    guard let self, self.isHovering, self.presentation == .expanded else { return }
                    self.store.markAllSeen()
                }
            }
        }
    }

    private var flashWork: DispatchWorkItem?
    /// When the current "needs you" card opened – a card with Allow / Deny closes after `approvalCardSeconds`.
    private var attentionSince: Date?
    static let approvalCardSeconds: TimeInterval = 30
    private var quietWork: DispatchWorkItem?

    init(store: SessionStore, media: NowPlaying, approvals: ApprovalCenter? = nil, usage: UsageStore? = nil,
         pet: NosyPet? = nil, shelf: Shelf? = nil) {
        self.store = store
        self.media = media
        let pet = pet ?? NosyPet(persist: false)
        self.pet = pet
        let shelf = shelf ?? Shelf(persist: false)
        self.shelf = shelf
        let approvals = approvals ?? ApprovalCenter()
        self.approvals = approvals
        let usage = usage ?? UsageStore(load: false)
        self.usage = usage
        usage.onChange = { [weak self] in self?.objectWillChange.send() }
        shelfObserver = shelf.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.objectWillChange.send() } }
        }
        head.onGesture = { [weak self] gesture in
            guard let self, let approval = self.attentionApproval else { return }
            self.decide(approval, gesture == .nod ? .allow : .deny)
        }
        media.onChange = { [weak self] in self?.recompute() }
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateSleep() }
        }
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

    /// Whether the hover view lists Claude sessions (always, unless there are none but something else fills it).
    var showsSessionList: Bool { !store.sessions.isEmpty || (!hasMedia && !showsNosyCard) }

    /// Parked files in the hover view.
    var showsShelf: Bool { Preferences.shelfEnabled && !shelf.isEmpty }

    /// Nosy's energy / level / streak card at the top of the hover view.
    var showsNosyCard: Bool { Preferences.nosyEnabled && Preferences.nosyPet }

    // MARK: - Nosy

    /// How Nosy feels right now.
    var nosyMood: NosyMood {
        if let burst = nosyBurst, burst.until > Clock.now() { return burst.mood }
        switch presentation {
        case .celebrating, .limitReset: return .happy
        case .attention: return .needsYou
        case .failed: return .shocked
        case .dropZone: return .needsYou
        case .notice:
            switch notice?.notice {
            case .charging: return .charging
            case .lowBattery: return .sleepy
            case .device: return .grooving
            case .timerDone: return .happy
            case .meeting: return .needsYou
            case nil: break
            }
        default: break
        }
        if let session = compactSession {
            let long = (session.turnStartedAt.map { Clock.now().timeIntervalSince($0) } ?? 0) > 180
            switch session.state {
            case .waiting: return .needsYou
            case .compacting: return .dizzy
            case .thinking: return long ? .sweating : .working
            case .tool: return long ? .sweating : .typing
            case .error: return .shocked
            case .done where quietDone?.id == session.id: return .happy
            default: break
            }
        }
        if limitIsUsedUp { return .exhausted }
        if hasMedia && media.isPlaying { return .grooving }
        if isAsleep { return .sleeping }
        if Preferences.nosyPet && pet.isLowOnEnergy { return .sleepy }
        return .idle
    }

    /// Nosy hangs below the open notch (and dives back in when it closes).
    var nosyOutside: Bool {
        guard Preferences.nosyEnabled else { return false }
        switch presentation {
        case .hidden, .compact, .media, .peek: return false
        default: return true
        }
    }

    /// Extra room below the notch shape that belongs to the notch (Nosy hanging there).
    var hangingHeight: CGFloat { nosyOutside ? NosyHanger.size.height - 12 : 0 }

    /// Where Nosy hangs, measured from the notch's centre line.
    var hangerX: CGFloat { -size.width / 2 + topRadius + 52 }

    /// A shown usage limit sits at 100 %.
    var limitIsUsedUp: Bool {
        usageRows.contains { row in
            [row.usage.fiveHour?.current, row.usage.week?.current].contains { ($0?.usedPercent ?? 0) >= 100 }
        }
    }

    /// The antenna / eye glow: the active agent's colour, or the sparkle's gold.
    var nosyTint: Color {
        if let session = compactSession, session.state.isActive || session.state != .idle { return session.accent }
        return NosyPalette.spark
    }

    /// Show a mood for a moment (petting, waking up …).
    func nosyReact(_ mood: NosyMood, for seconds: TimeInterval = 1.6) {
        nosyBurst = NosyBurst(mood: mood, until: Clock.now().addingTimeInterval(seconds))
        Clock.after(seconds + 0.05) { [weak self] in
            guard let self, let burst = self.nosyBurst, burst.until <= Clock.now() else { return }
            self.nosyBurst = nil
        }
    }

    /// Nosy just reached a new level – shown on the "done" card for its duration.
    @Published private(set) var levelUp: Int?

    func celebrateLevel(_ level: Int) {
        levelUp = level
        nosyReact(.happy, for: 3)
        Clock.after(max(Preferences.notificationSeconds, 4) + 1) { [weak self] in
            if self?.levelUp == level { self?.levelUp = nil }
        }
    }

    /// You poked Nosy.
    func petNosy() {
        noteActivity()
        nosyReact(.giggle)
    }

    /// Called with every pointer move: where Nosy looks, and whether it peeks out.
    func updateGaze(mouse: CGPoint, notchCenter: CGPoint) {
        guard Preferences.nosyEnabled else { return }
        gaze.update(mouse: mouse, notchCenter: notchCenter)
        let near = gaze.nearness > (pointerIsNear ? 0.2 : 0.4)
        if near != pointerIsNear {
            pointerIsNear = near
            if near { wakeUp() }
            recompute()
        }
    }

    private func noteActivity() {
        lastActivity = Clock.now()
        if isAsleep { isAsleep = false }
    }

    private func wakeUp() {
        guard isAsleep else { return }
        noteActivity()
        nosyReact(.waking, for: 1.4)
    }

    private func updateSleep() {
        if store.hasActivity || store.hasWaiting || isHovering || media.isPlaying { lastActivity = Clock.now() }
        let hour = Calendar.current.component(.hour, from: Clock.now())
        let limit = hour >= 23 || hour < 6 ? Self.sleepAfterAtNight : Self.sleepAfter
        let asleep = Clock.now().timeIntervalSince(lastActivity) > limit
        if asleep != isAsleep { isAsleep = asleep }
    }

    // MARK: - Geometry

    var size: CGSize {
        let flare = Self.topRadius(for: presentation)
        let compactWidth = notchSize.width + 2 * Self.wingWidth
        let wide = max(compactWidth, Self.expandedWidth)
        switch presentation {
        case .hidden:
            return CGSize(width: notchSize.width + 2 * flare, height: hasPhysicalNotch ? notchSize.height : 0)
        case .compact, .media, .peek:
            return CGSize(width: compactWidth, height: notchSize.height)
        case .expanded:
            var height = notchSize.height + 12
            if showsNosyCard { height += Self.nosyCardHeight }
            if showsShelf { height += Self.shelfRowHeight }
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
        case .failed, .limitReset:
            return CGSize(width: wide, height: notchSize.height + 88)
        case .dropZone:
            return CGSize(width: wide, height: notchSize.height + 86)
        case .notice:
            return CGSize(width: wide, height: notchSize.height + 76)
        }
    }

    /// Size of the window that hosts the notch – big enough for the largest state plus glow.
    var canvasSize: CGSize {
        // Room for the tallest hover view (sessions, music, usage, Nosy, shelf, calendar …), Nosy hanging below it
        // and the glow. The window is transparent and ignores clicks outside the notch, so a bit too big is fine.
        CGSize(width: Self.expandedWidth + 80, height: notchSize.height + 700)
    }

    var topRadius: CGFloat { Self.topRadius(for: presentation) }

    var bottomRadius: CGFloat {
        switch presentation {
        case .hidden, .compact, .media, .peek: return min(12, notchSize.height * 0.38)
        default: return 26
        }
    }

    private static func topRadius(for p: Presentation) -> CGFloat {
        switch p {
        case .hidden, .compact, .media, .peek: return 6
        default: return 14
        }
    }

    // MARK: - State

    func handle(_ transition: Transition) {
        noteActivity()
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
            attentionSince = Clock.now()
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
        Clock.after(3, execute: work)
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

    func showLimitReset(agent: Agent, window: String) {
        // Agents' own news wins; the reset can wait for the next quiet moment.
        guard celebration == nil, attention == nil, failure == nil else { return }
        limitReset = LimitReset(agent: agent, window: window)
        flash(for: Preferences.notificationSeconds)
        recompute()
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
        if fileDragNear && Preferences.shelfEnabled {
            next = .dropZone
        } else if celebration != nil {
            next = .celebrating
        } else if attention != nil {
            next = .attention
        } else if failure != nil {
            next = .failed
        } else if limitReset != nil {
            next = .limitReset
        } else if notice != nil {
            next = .notice
        } else if isHovering && (!store.sessions.isEmpty || hasMedia || Preferences.nosyEnabled || showsShelf) {
            next = .expanded
        } else if store.hasActivity || store.hasWaiting || quietDone != nil {
            next = .compact
        } else if hasMedia && (media.isPlaying || Preferences.mediaShowWhenPaused) {
            next = .media
        } else if !store.unseen.isEmpty {
            next = .compact
        } else if Preferences.nosyEnabled && pointerIsNear {
            next = .peek
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
                    let open = Clock.now().timeIntervalSince(self.attentionSince ?? .distantPast)
                    if open < Self.approvalCardSeconds { return self.flash(for: min(2, Self.approvalCardSeconds - open)) }
                    self.approvals.release(approval.id)
                }
                self.endFlash()
            }
        }
        flashWork = work
        Clock.after(seconds, execute: work)
    }

    private func endFlash() {
        flashWork?.cancel()
        flashWork = nil
        celebration = nil
        attention = nil
        failure = nil
        limitReset = nil
        recompute()
    }
}
