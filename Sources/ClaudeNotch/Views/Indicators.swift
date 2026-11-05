import SwiftUI

/// The right-hand wing in the compact notch.
struct StatusIndicator: View {
    let session: Session

    var body: some View {
        Group {
            switch session.state {
            case .thinking:
                WaveDots(color: session.accent)
            case .tool(let tool):
                Image(systemName: tool.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(session.accent)
                    .symbolEffect(.pulse)
                    .id(tool.name)
                    .transition(.scale.combined(with: .opacity))
            case .waiting:
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(session.accent)
                    .symbolEffect(.pulse)
            case .compacting:
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(session.accent)
                    .symbolEffect(.pulse)
            case .done:
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(session.accent)
            case .idle:
                Circle().fill(session.accent).frame(width: 5, height: 5)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: session.state)
    }
}

/// Three dots bouncing in a wave – "thinking".
struct WaveDots: View {
    var color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    let wave = sin(t * 6 - Double(i) * 0.9)
                    Circle()
                        .fill(color)
                        .frame(width: 4.5, height: 4.5)
                        .offset(y: CGFloat(-wave * 2.5))
                        .opacity(0.55 + 0.45 * (wave + 1) / 2)
                }
            }
        }
    }
}

/// A moving highlight across text while Claude is busy.
struct Shimmer: ViewModifier {
    var active: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if active {
            content.overlay {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let progress = CGFloat((t.truncatingRemainder(dividingBy: 1.8)) / 1.8)
                    GeometryReader { geo in
                        LinearGradient(colors: [.clear, .white.opacity(0.85), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.5)
                            .offset(x: -geo.size.width * 0.5 + progress * geo.size.width * 1.5)
                    }
                }
                .mask { content }
                .allowsHitTesting(false)
            }
        } else {
            content
        }
    }
}

extension View {
    func shimmer(_ active: Bool) -> some View { modifier(Shimmer(active: active)) }
}

/// Circle + checkmark that draw themselves in.
struct DrawnCheckmark: View {
    var color: Color = Theme.success
    @State private var circle: CGFloat = 0
    @State private var check: CGFloat = 0
    @State private var pop: CGFloat = 0.6

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .scaleEffect(pop)
            Circle()
                .trim(from: 0, to: circle)
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            CheckShape()
                .trim(from: 0, to: check)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .padding(10)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { circle = 1 }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1)) { pop = 1 }
            withAnimation(.easeOut(duration: 0.3).delay(0.35)) { check = 1 }
        }
    }
}

struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.midY + rect.height * 0.02))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY - rect.height * 0.15))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY + rect.height * 0.2))
        return p
    }
}

/// Particles bursting out from the center, once.
struct ConfettiBurst: View {
    let start: Date
    private static let colors: [Color] = [Theme.claude, Theme.success, Theme.amber, .white, Theme.violet]
    private static let count = 22
    private static let lifetime: TimeInterval = 1.4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                guard elapsed >= 0, elapsed < Self.lifetime else { return }
                let progress = elapsed / Self.lifetime
                let eased = 1 - pow(1 - progress, 3)
                let cx = Double(size.width) / 2
                let cy = Double(size.height) / 2
                let maxDistance = Double(min(size.width, size.height)) * 0.9

                for i in 0..<Self.count {
                    // Deterministic pseudo-random values per particle.
                    let seed = Double(i) * 12.9898
                    let rand1 = abs(sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
                    let rand2 = abs(sin(seed * 1.7) * 24634.6345).truncatingRemainder(dividingBy: 1)
                    let angle = Double(i) / Double(Self.count) * 2 * .pi + rand1 * 0.5
                    let distance = maxDistance * (0.55 + 0.45 * rand2) * eased
                    let gravity = 18 * progress * progress
                    let px: Double = cx + cos(angle) * distance
                    let py: Double = cy + sin(angle) * distance + gravity
                    let particleSize: Double = 2.0 + 2.5 * rand2
                    var particle = context
                    particle.opacity = 1 - progress
                    particle.translateBy(x: px, y: py)
                    particle.rotate(by: .radians(angle + progress * 6))
                    let rect = CGRect(x: -particleSize / 2, y: -particleSize / 4, width: particleSize, height: particleSize / 2 + 1)
                    particle.fill(Path(roundedRect: rect, cornerRadius: 1),
                                  with: .color(Self.colors[i % Self.colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct BlurModifier: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View { content.blur(radius: radius) }
}

extension AnyTransition {
    /// Fade + blur, used when the notch content morphs between states.
    static var blurFade: AnyTransition {
        .modifier(active: BlurModifier(radius: 10), identity: BlurModifier(radius: 0)).combined(with: .opacity)
    }
}
