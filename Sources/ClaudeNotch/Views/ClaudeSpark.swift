import SwiftUI

enum SparkMode: Equatable {
    case idle, thinking, working, waiting, compacting, done

    init(_ state: ActivityState) {
        switch state {
        case .idle: self = .idle
        case .thinking: self = .thinking
        case .tool: self = .working
        case .waiting: self = .waiting
        case .compacting: self = .compacting
        case .done: self = .done
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
