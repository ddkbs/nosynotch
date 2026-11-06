import SwiftUI

/// Where Nosy looks – the pointer relative to the notch. Its own object so only the eyes redraw when the mouse moves.
@MainActor
final class NosyGaze: ObservableObject {
    /// -1…1 horizontally (left/right of the notch) and 0…1 vertically (straight below → far down).
    @Published private(set) var look: CGSize = .zero
    /// How close the pointer is to the notch (1 = on it, 0 = far away).
    @Published private(set) var nearness: Double = 0

    func update(mouse: CGPoint, notchCenter: CGPoint) {
        let dx = (mouse.x - notchCenter.x) / 320
        let dy = (notchCenter.y - mouse.y) / 260
        let next = CGSize(width: max(-1, min(1, dx)), height: max(-0.2, min(1, dy)))
        let distance = hypot(mouse.x - notchCenter.x, mouse.y - notchCenter.y)
        let near = max(0, min(1, 1 - (distance - 60) / 240))
        if abs(next.width - look.width) > 0.02 || abs(next.height - look.height) > 0.02 { look = next }
        if abs(near - nearness) > 0.03 || (near == 0) != (nearness == 0) { nearness = near }
    }
}

/// Nosy inside the notch: only the eyes look out of the black.
struct NosyWingEyes: View {
    var mood: NosyMood
    var look: CGSize = .zero
    var tint: Color = NosyPalette.spark

    var body: some View {
        ClockTimeline(minimumInterval: 1.0 / 30.0) { now in
            let t = now.timeIntervalSinceReferenceDate
            ZStack {
                // A soft glow so the eyes sit in the notch instead of on it.
                Ellipse()
                    .fill(RadialGradient(colors: [tint.opacity(0.28), .clear], center: .center, startRadius: 0, endRadius: 16))
                    .frame(width: 34, height: 20)
                NosyEyes(mood: mood, look: look, time: t, ink: .white, spacing: 3.5)
                    .frame(width: 22, height: 9.5)
                    .offset(y: bob(t))
                if mood == .sleeping {
                    NosyZzz(t: t).scaleEffect(0.8).offset(x: 14, y: -2)
                }
                if mood == .giggle {
                    NosyHearts(t: t).scaleEffect(0.7).offset(y: -4)
                }
            }
        }
    }

    private func bob(_ t: TimeInterval) -> CGFloat {
        switch mood {
        case .happy, .charging, .waking: return -abs(sin(t * 6)) * 1.5
        case .grooving: return sin(t * .pi * 4) * 1
        case .shocked: return sin(t * 50) * 0.6
        default: return 0
        }
    }
}

/// The wing eyes, following the live pointer.
struct NosyLiveWingEyes: View {
    var mood: NosyMood
    @ObservedObject var gaze: NosyGaze
    var tint: Color

    var body: some View {
        NosyWingEyes(mood: mood, look: gaze.look, tint: tint)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: gaze.look)
    }
}

/// Right wing while Nosy peeks: its energy as a tiny ring, or a "z" while it sleeps.
struct NosyPeekBadge: View {
    var asleep: Bool
    var energy: Double
    var showsEnergy: Bool

    var body: some View {
        if asleep {
            Text("z")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        } else if showsEnergy {
            NosyEnergyRing(energy: energy)
                .frame(width: 13, height: 13)
        }
    }
}

/// Energy as a small ring with a sparkle in the middle.
struct NosyEnergyRing: View {
    var energy: Double
    var lineWidth: CGFloat = 2.5

    var color: Color {
        energy < 0.25 ? Theme.amber : NosyPalette.spark
    }

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.04, min(1, energy)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.easeOut(duration: 0.6), value: energy)
    }
}
