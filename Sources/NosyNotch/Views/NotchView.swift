import SwiftUI

struct NotchView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var store: SessionStore
    @ObservedObject var media: NowPlaying

    private var spring: Animation { .spring(response: 0.42, dampingFraction: 0.74) }

    var body: some View {
        let size = model.size
        let shape = NotchShape(topRadius: model.topRadius, bottomRadius: model.bottomRadius)

        ZStack(alignment: .top) {
            shape
                .fill(Color.black)
                .shadow(color: glowColor.opacity(glowOpacity), radius: 14)
                .shadow(color: .black.opacity(model.presentation == .hidden ? 0 : 0.35), radius: 10, y: 4)

            content
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipShape(shape)
        }
        .frame(width: size.width, height: size.height)
        .opacity(model.presentation == .hidden && !model.hasPhysicalNotch ? 0 : 1)
        .modifier(ShakeEffect(animatableData: model.shakes))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(spring, value: model.presentation)
        .animation(spring, value: store.sessions.count)
        .animation(spring, value: media.track == nil)
        .animation(.linear(duration: 0.55), value: model.shakes)
    }

    // MARK: - Glow

    private var glowColor: Color {
        switch model.presentation {
        case .attention: return Theme.amber
        case .failed: return Theme.danger
        case .media: return media.accent
        case .celebrating: return Theme.success
        default: return store.primary?.accent ?? .clear
        }
    }

    private var glowOpacity: Double {
        switch model.presentation {
        case .attention, .celebrating, .failed: return 0.55
        case .compact: return store.hasWaiting ? 0.45 : 0.18
        case .media: return 0.22
        default: return 0
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            header
                .frame(height: model.notchSize.height)

            switch model.presentation {
            case .expanded:
                VStack(spacing: 0) {
                    if model.hasMedia {
                        MediaPlayerCard(media: media)
                            .padding(.top, 2)
                    }
                    if model.showsSessionList {
                        SessionList(store: store)
                    }
                }
                .transition(.blurFade.combined(with: .move(edge: .top)))
            case .celebrating:
                if let celebration = model.celebration {
                    CelebrationView(celebration: celebration,
                                    live: store.sessions[celebration.session.id],
                                    onTap: { model.dismissFlash() },
                                    onDismiss: { model.dismissFlash() })
                        .id(celebration.id)
                        .transition(.blurFade.combined(with: .scale(scale: 0.85, anchor: .top)))
                }
            case .attention:
                if let session = model.attention {
                    AttentionView(session: store.sessions[session.id] ?? session, onDismiss: { model.dismissFlash() })
                        .transition(.blurFade.combined(with: .scale(scale: 0.85, anchor: .top)))
                }
            case .failed:
                if let session = model.failure {
                    FailureView(session: store.sessions[session.id] ?? session, onDismiss: { model.dismissFlash() })
                        .transition(.blurFade.combined(with: .scale(scale: 0.85, anchor: .top)))
                }
            case .hidden, .compact, .media:
                EmptyView()
            }
        }
        .padding(.horizontal, model.topRadius)
    }

    /// The strip at notch height: activity on the left wing, status on the right wing.
    @ViewBuilder
    private var header: some View {
        if model.presentation == .media {
            mediaHeader
        } else {
            claudeHeader
        }
    }

    /// Cover on the left wing, equalizer on the right.
    private var mediaHeader: some View {
        HStack(spacing: 0) {
            MediaArtwork(image: media.artwork)
                .frame(width: 20, height: 20)
                .id(media.track?.id)
                .transition(.scale(scale: 0.2).combined(with: .opacity))
                .frame(width: Self.wingContent, alignment: .center)
                .onTapGesture { media.openPlayer() }
            Spacer(minLength: model.notchSize.width)
            EqualizerBars(color: media.accent, playing: media.isPlaying)
                .frame(width: Self.wingContent, alignment: .center)
                .transition(.scale(scale: 0.2).combined(with: .opacity))
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var claudeHeader: some View {
        let primary = store.primary
        let visible = model.presentation != .hidden
        HStack(spacing: 0) {
            ZStack {
                if visible, let primary {
                    ClaudeSpark(mode: model.presentation == .celebrating ? .done : SparkMode(primary.state),
                                color: model.presentation == .celebrating ? Theme.success : primary.accent)
                        .frame(width: 18, height: 18)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            }
            .frame(width: Self.wingContent, alignment: .center)

            Spacer(minLength: model.notchSize.width)

            ZStack {
                if visible, let primary {
                    if model.presentation == .expanded, store.sessions.count > 1 {
                        Text("\(store.sessions.count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.white.opacity(0.12)))
                    } else if primary.turnStartedAt != nil, model.presentation == .expanded {
                        ElapsedText(since: primary.turnStartedAt)
                    } else {
                        StatusIndicator(session: primary)
                            .transition(.scale(scale: 0.2).combined(with: .opacity))
                    }
                }
            }
            .frame(width: Self.wingContent, alignment: .center)
        }
        .padding(.horizontal, 4)
    }

    private static let wingContent: CGFloat = NotchViewModel.wingWidth - 14
}

/// "1:23" ticking up from a date.
struct ElapsedText: View {
    let since: Date?

    var body: some View {
        if let since {
            Text(since, style: .timer)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Expanded list

struct SessionList: View {
    @ObservedObject var store: SessionStore

    var body: some View {
        let sessions = Array(store.ordered.prefix(NotchViewModel.maxRows))
        VStack(spacing: 0) {
            if sessions.isEmpty {
                Text("No active Claude Code or Codex sessions")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(height: NotchViewModel.rowHeight)
            }
            ForEach(sessions) { session in
                SessionRow(session: session, onDismiss: { store.dismiss(session.id) })
                    .frame(height: NotchViewModel.rowHeight)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 14)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sessions.map(\.id))
    }
}

struct SessionRow: View {
    let session: Session
    var onDismiss: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            ClaudeSpark(mode: SparkMode(session.state), color: session.accent)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.projectName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    AgentBadge(agent: session.agent)
                    Text(session.statusTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(session.accent)
                        .shimmer(session.state.isActive)
                        .contentTransition(.interpolate)
                }
                .lineLimit(1)

                if let detail = session.statusDetail {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .contentTransition(.opacity)
                }
            }

            Spacer(minLength: 8)

            if hovering {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            } else if session.state.isActive {
                ElapsedText(since: session.turnStartedAt)
            }
        }
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(hovering ? 0.08 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { TerminalActivator.activate(session) }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: session.state)
    }
}

/// Tiny "Claude" / "Codex" label so mixed session lists stay readable.
struct AgentBadge: View {
    let agent: Agent

    var body: some View {
        Text(agent.name)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(agent.color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(agent.color.opacity(0.16)))
            .fixedSize()
    }
}

// MARK: - Done

struct CelebrationView: View {
    let celebration: NotchViewModel.Celebration
    /// Latest state of the session (the summary may arrive a moment after the Stop event).
    let live: Session?
    var onTap: () -> Void
    var onDismiss: () -> Void

    @State private var appeared = false
    @State private var burstStart = Date().addingTimeInterval(0.2)

    var body: some View {
        let session = live ?? celebration.session
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                ConfettiBurst(start: burstStart)
                    .frame(width: 120, height: 120)
                DrawnCheckmark()
                    .frame(width: 46, height: 46)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(session.projectName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.success)
                    if session.agent != .claude { AgentBadge(agent: session.agent) }
                    if let d = session.lastTurnDuration {
                        Text("· \(Format.duration(d))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .lineLimit(1)

                Text(session.lastSummary ?? summaryFallback(session))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeOut, value: session.lastSummary)
            }
            .offset(y: appeared ? 0 : 8)
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            TerminalActivator.activate(session)
            onTap()
        }
        .overlay(alignment: .topTrailing) {
            DismissButton(action: onDismiss).padding(.top, 8).padding(.trailing, 14)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.15)) { appeared = true }
        }
    }

    private func summaryFallback(_ s: Session) -> String {
        let waiting = "\(s.agent.name) is waiting for your next message."
        return s.toolCount > 0 ? "\(Format.toolCalls(s.toolCount)) – \(waiting)" : waiting
    }
}

// MARK: - API error

struct FailureView: View {
    let session: Session
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.danger.opacity(0.18))
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    // A short "glitch" jitter every couple of seconds.
                    let cycle = t.truncatingRemainder(dividingBy: 2.2)
                    let jitter = cycle < 0.35 ? sin(cycle * 90) * 2.5 : 0
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .offset(x: jitter)
                        .opacity(cycle < 0.35 ? 0.65 + 0.35 * abs(sin(cycle * 40)) : 1)
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(session.agent.name) hit a snag")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(session.projectName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.danger)
                }
                .lineLimit(1)
                if case .error(let message) = session.state {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .contentShape(Rectangle())
        .onTapGesture { TerminalActivator.activate(session) }
        .overlay(alignment: .topTrailing) {
            DismissButton(action: onDismiss).padding(.top, 8).padding(.trailing, 14)
        }
    }
}

// MARK: - Needs attention

struct AttentionView: View {
    let session: Session
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.amber.opacity(0.18))
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    // Wave: a quick wiggle, then a short pause.
                    let cycle = t.truncatingRemainder(dividingBy: 1.4)
                    let angle = cycle < 0.6 ? sin(cycle / 0.6 * .pi * 4) * 14 * (1 - cycle / 0.6) : 0
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                        .rotationEffect(.degrees(angle), anchor: .bottom)
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(session.agent.name) needs you")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(session.projectName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.amber)
                }
                .lineLimit(1)
                if case .waiting(let message) = session.state {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .contentShape(Rectangle())
        .onTapGesture { TerminalActivator.activate(session) }
        .overlay(alignment: .topTrailing) {
            DismissButton(action: onDismiss).padding(.top, 8).padding(.trailing, 14)
        }
    }
}
