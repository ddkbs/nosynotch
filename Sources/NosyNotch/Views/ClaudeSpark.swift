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

/// Each agent's own animated mark, reacting to what the session does: Claude's spark, Codex's hexagon with a
/// blinking prompt, Cursor's turning cube.
struct AgentGlyph: View {
    let agent: Agent
    var mode: SparkMode = .thinking
    var color: Color? = nil

    var body: some View {
        let tint = color ?? agent.color
        switch agent {
        case .claude: ClaudeSpark(mode: mode, color: tint)
        case .codex: CodexGlyph(color: tint, mode: mode)
        case .cursor: CursorGlyph(color: tint, mode: mode)
        }
    }
}

extension SparkMode {
    /// How fast the agent marks move: 0 = still, negative = backwards (compacting).
    var speed: Double {
        switch self {
        case .idle, .done: return 0
        case .thinking: return 1
        case .working: return 2.2
        case .compacting: return -1
        case .waiting, .error: return 0.4
        }
    }

    var animates: Bool { self != .idle && self != .done }
}

/// A hexagon whose edges light up one after another around a blinking `>_`.
struct CodexGlyph: View {
    var color: Color
    var mode: SparkMode = .thinking

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !mode.animates)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(t * 6)
            let flicker = mode == .error ? (sin(t * 23) * sin(t * 7.3) > 0.2 ? 0.35 : 1) : 1
            Canvas { context, size in
                let r = min(size.width, size.height) / 2 - 1
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let spin = t * 0.6 * mode.speed
                let head = (t * 5 * abs(mode.speed)).truncatingRemainder(dividingBy: 6)
                for i in 0..<6 {
                    let k = mode.speed < 0 ? 5 - i : i
                    let a0 = spin + Double(k) / 6 * 2 * .pi - .pi / 2
                    let a1 = spin + Double(k + 1) / 6 * 2 * .pi - .pi / 2
                    var edge = Path()
                    edge.move(to: CGPoint(x: center.x + r * cos(a0), y: center.y + r * sin(a0)))
                    edge.addLine(to: CGPoint(x: center.x + r * cos(a1), y: center.y + r * sin(a1)))
                    let light: Double
                    switch mode {
                    case .idle: light = 0.5
                    case .done: light = 1
                    case .waiting: light = 0.45 + 0.55 * pulse
                    default:
                        // The lit edge runs around, with a short fading tail.
                        let behind = (head - Double(i) + 6).truncatingRemainder(dividingBy: 6)
                        light = max(0.25, 1 - behind / 3)
                    }
                    context.stroke(edge, with: .color(color.opacity(light * flicker)),
                                   style: StrokeStyle(lineWidth: max(1.2, r * 0.17), lineCap: .round))
                }
            }
            .overlay {
                HStack(spacing: 0.5) {
                    Text(">")
                    Text("_").opacity(!mode.animates || (t * 2).truncatingRemainder(dividingBy: 2) < 1 ? 1 : 0)
                }
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .minimumScaleFactor(0.5)
                .foregroundStyle(color.opacity(flicker))
            }
            .shadow(color: color.opacity(mode == .idle ? 0.2 : 0.6), radius: 3)
        }
    }
}

/// An isometric cube that turns while the agent works – lit top, shaded sides.
struct CursorGlyph: View {
    var color: Color
    var mode: SparkMode = .thinking

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !mode.animates)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(t * 6)
            let flicker = mode == .error ? (sin(t * 23) * sin(t * 7.3) > 0.2 ? 0.4 : 1) : 1
            Canvas { context, size in
                let s = min(size.width, size.height)
                let center = CGPoint(x: size.width / 2, y: size.height / 2 + s * 0.02)
                let yaw = .pi / 4 + t * 1.1 * mode.speed
                let tilt = 0.6155          // isometric: atan(1/√2)
                let half = s * 0.3

                func project(_ p: (Double, Double, Double)) -> CGPoint {
                    // Rotate around the vertical axis, then tilt towards the viewer.
                    let x = p.0 * cos(yaw) - p.2 * sin(yaw)
                    let z = p.0 * sin(yaw) + p.2 * cos(yaw)
                    let y = p.1 * cos(tilt) - z * sin(tilt)
                    return CGPoint(x: center.x + x * half, y: center.y - y * half)
                }
                let v: [(Double, Double, Double)] = [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1),
                                                     (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)]
                // Faces with outward normals (x, z) for the sides; top is always visible from above.
                let sides: [([Int], (Double, Double))] = [([0, 1, 5, 4], (0, -1)), ([1, 2, 6, 5], (1, 0)),
                                                          ([2, 3, 7, 6], (0, 1)), ([3, 0, 4, 7], (-1, 0))]
                let glow = mode == .waiting ? 0.7 + 0.3 * pulse : 1
                for (idx, normal) in sides {
                    // Deeper z is drawn lower, so the viewer sits on the +z side, above the cube.
                    let nz = normal.0 * sin(yaw) + normal.1 * cos(yaw)
                    guard nz > 0 else { continue }
                    var face = Path()
                    face.addLines(idx.map { project(v[$0]) })
                    face.closeSubpath()
                    let nx = normal.0 * cos(yaw) - normal.1 * sin(yaw)
                    let shade = 0.28 + 0.3 * (1 - abs(nx))
                    context.fill(face, with: .color(color.opacity(shade * glow * flicker)))
                    context.stroke(face, with: .color(color.opacity(0.9 * flicker)), lineWidth: max(0.8, s * 0.04))
                }
                var top = Path()
                top.addLines([4, 5, 6, 7].map { project(v[$0]) })
                top.closeSubpath()
                context.fill(top, with: .color(color.opacity(0.85 * glow * flicker)))
                context.stroke(top, with: .color(color.opacity(flicker)), lineWidth: max(0.8, s * 0.04))
            }
            .shadow(color: color.opacity(mode == .idle ? 0.2 : 0.55), radius: 3)
        }
    }
}
