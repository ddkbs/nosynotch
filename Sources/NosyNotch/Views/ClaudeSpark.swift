import SwiftUI

enum SparkMode: Equatable {
    case idle, thinking, working, waiting, compacting, done, error

    init(_ state: ActivityState) {
        switch state {
        case .idle: self = .idle
        case .thinking: self = .thinking
        case .tool: self = .working
        case .waiting: self = .waiting
        case .compacting: self = .compacting
        case .done: self = .done
        case .error: self = .error
        }
    }
}

/// A radial sparkle whose rays breathe, wave and spin depending on what Claude is doing.
struct ClaudeSpark: View {
    var mode: SparkMode
    var color: Color
    var animated = true

    private static let rays: [CGFloat] = [1.0, 0.82, 0.95, 0.78, 1.0, 0.86, 0.93, 0.8, 0.97, 0.84]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !animated)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                draw(in: &context, size: size, t: t)
            }
        }
        .shadow(color: color.opacity(glow), radius: 4)
    }

    private var glow: Double {
        switch mode {
        case .waiting, .working, .thinking: return 0.7
        case .done: return 0.5
        case .error: return 0.6
        default: return 0.2
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let radius = min(size.width, size.height) / 2
        let count = Self.rays.count
        let rotation: Double
        switch mode {
        case .thinking: rotation = t * 0.7
        case .working: rotation = t * 1.6
        case .compacting: rotation = -t * 1.1
        default: rotation = 0
        }

        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.rotate(by: .radians(rotation))

        for (i, base) in Self.rays.enumerated() {
            let phase = Double(i) / Double(count) * 2 * .pi
            let scale: Double
            switch mode {
            case .idle:
                scale = 0.82 + 0.05 * sin(t * 1.3 + phase)
            case .thinking:
                scale = 0.6 + 0.4 * (0.5 + 0.5 * sin(t * 4.5 - phase))
            case .working:
                scale = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 8 - phase * 2))
            case .waiting:
                scale = 0.7 + 0.3 * (0.5 + 0.5 * sin(t * 6))
            case .compacting:
                scale = 0.45 + 0.25 * (0.5 + 0.5 * sin(t * 3 + phase))
            case .done:
                scale = 0.95 + 0.05 * sin(t * 2)
            case .error:
                // Short rays that flicker unevenly, like a sputtering spark.
                let flicker = sin(t * 23 + phase * 3) * sin(t * 7.3 + phase)
                scale = 0.42 + 0.18 * max(0, flicker)
            }

            let inner = radius * 0.16
            let length = (radius - inner) * base * CGFloat(scale)
            let width = radius * 0.2

            var ray = context
            ray.rotate(by: .radians(phase))
            let rect = CGRect(x: -width / 2, y: -(inner + length), width: width, height: length)
            ray.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(color))
        }
        let core = radius * 0.22
        context.fill(Path(ellipseIn: CGRect(x: -core, y: -core, width: core * 2, height: core * 2)), with: .color(color))
    }
}

/// Each agent's own little animated mark: Claude's spark, a spinning hexagon with a blinking prompt for Codex,
/// a pointer with click ripples for Cursor.
struct AgentGlyph: View {
    let agent: Agent
    var active = true

    var body: some View {
        switch agent {
        case .claude: ClaudeSpark(mode: active ? .thinking : .idle, color: agent.color)
        case .codex: CodexGlyph(color: agent.color, active: active)
        case .cursor: CursorGlyph(color: agent.color, active: active)
        }
    }
}

/// A hexagon whose edges light up one after another around a blinking `>_`.
struct CodexGlyph: View {
    var color: Color
    var active = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let r = min(size.width, size.height) / 2 - 1
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let spin = active ? t * 0.6 : 0
                let head = active ? (t * 5).truncatingRemainder(dividingBy: 6) : -10
                for i in 0..<6 {
                    let a0 = spin + Double(i) / 6 * 2 * .pi - .pi / 2
                    let a1 = spin + Double(i + 1) / 6 * 2 * .pi - .pi / 2
                    var edge = Path()
                    edge.move(to: CGPoint(x: center.x + r * cos(a0), y: center.y + r * sin(a0)))
                    edge.addLine(to: CGPoint(x: center.x + r * cos(a1), y: center.y + r * sin(a1)))
                    // Distance behind the moving "head": the lit edge and a short fading tail.
                    let behind = (head - Double(i) + 6).truncatingRemainder(dividingBy: 6)
                    let light = active ? max(0.25, 1 - behind / 3) : 0.45
                    context.stroke(edge, with: .color(color.opacity(light)),
                                   style: StrokeStyle(lineWidth: max(1.2, r * 0.16), lineCap: .round))
                }
            }
            .overlay {
                HStack(spacing: 0.5) {
                    Text(">")
                    Text("_").opacity(!active || (t * 2).truncatingRemainder(dividingBy: 2) < 1 ? 1 : 0)
                }
                .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
            }
            .shadow(color: color.opacity(active ? 0.6 : 0.2), radius: 3)
        }
    }
}

/// A pointer that taps, sending out a ripple each time.
struct CursorGlyph: View {
    var color: Color
    var active = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let cycle = active ? t.truncatingRemainder(dividingBy: 1.8) / 1.8 : 0.9
            let press = cycle < 0.12 ? sin(cycle / 0.12 * .pi) : 0
            GeometryReader { geo in
                let s = min(geo.size.width, geo.size.height)
                ZStack {
                    ForEach(0..<2, id: \.self) { k in
                        let p = (cycle + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)
                        Circle()
                            .stroke(color.opacity(active ? (1 - p) * 0.7 : 0), lineWidth: 1.2)
                            .frame(width: s * (0.2 + 0.8 * p), height: s * (0.2 + 0.8 * p))
                            .offset(x: -s * 0.12, y: -s * 0.12)
                    }
                    Image(systemName: "cursorarrow")
                        .font(.system(size: s * 0.7, weight: .semibold))
                        .foregroundStyle(color)
                        .scaleEffect(1 - 0.12 * press)
                        .offset(x: s * 0.08, y: s * 0.06 + (active ? sin(t * 2.2) * s * 0.03 : 0))
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .shadow(color: color.opacity(active ? 0.5 : 0.15), radius: 3)
        }
    }
}
