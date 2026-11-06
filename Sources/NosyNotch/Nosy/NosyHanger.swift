import SwiftUI

/// Nosy hanging from the bottom edge of the open notch.
struct NosyHanger: View {
    var mood: NosyMood
    @ObservedObject var gaze: NosyGaze
    @ObservedObject var pet: NosyPet
    var tint: Color
    var onPet: () -> Void

    static let size = CGSize(width: 46, height: 58)

    var body: some View {
        NosyFigure(mood: mood, look: gaze.look, level: Preferences.nosyPet ? pet.level : 1,
                   accessory: Preferences.nosyAccessory, hanging: true, tint: tint)
            .frame(width: Self.size.width, height: Self.size.height)
            .contentShape(Rectangle())
            .onTapGesture(perform: onPet)
            .help("Nosy · Level \(pet.level)")
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: gaze.look)
    }
}

/// Coming out of / diving into the notch like into a puddle of tar: Nosy turns black, squeezes and slips up
/// into the edge. `progress` 1 = fully out, 0 = gone inside.
struct NosyTarModifier: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let p = max(0, min(1.15, progress))
        let ink = min(1, max(0, (p - 0.15) / 0.6))
        content
            .colorMultiply(Color(white: ink))
            .scaleEffect(x: 0.45 + 0.55 * p, y: 0.25 + 0.75 * p, anchor: .top)
            .offset(y: -18 * (1 - min(1, p)))
            .opacity(p < 0.05 ? 0 : 1)
    }
}

extension AnyTransition {
    /// Drips out of the notch, dives back in.
    static var nosyTar: AnyTransition {
        .modifier(active: NosyTarModifier(progress: 0), identity: NosyTarModifier(progress: 1))
    }
}

/// The splash when Nosy dives in: black drops fly out of the edge and fall back, a ring ripples outwards.
struct NosySplash: View {
    let start: Date

    static let duration: TimeInterval = 0.9

    private static let drops: [(angle: Double, speed: Double, size: CGFloat)] = [
        (-160, 62, 4.5), (-140, 80, 3.5), (-118, 54, 3), (-100, 90, 2.6), (-80, 86, 3.2),
        (-62, 58, 3.8), (-40, 76, 3), (-22, 60, 4.2), (-150, 40, 2.4), (-30, 44, 2.6),
        (-90, 50, 5), (-125, 70, 2.2),
    ]

    var body: some View {
        ClockTimeline(minimumInterval: 1.0 / 60.0) { now in
            let t = now.timeIntervalSince(start)
            if t >= 0 && t < Self.duration {
                splash(t)
            }
        }
        .allowsHitTesting(false)
    }

    private func splash(_ t: TimeInterval) -> some View {
        let f = t / Self.duration
        return ZStack {
            // Ripple on the edge.
            Ellipse()
                .stroke(Color.black.opacity(0.7 * (1 - f)), lineWidth: 2)
                .frame(width: 20 + 90 * f, height: 6 + 14 * f)
            Ellipse()
                .fill(Color.black)
                .frame(width: 34 * (1 - f), height: 9 * (1 - f))
            ForEach(Self.drops.indices, id: \.self) { i in
                let d = Self.drops[i]
                // Drops leave the edge downwards/sideways (screen y grows down), then gravity pulls them back down.
                let a = d.angle * .pi / 180
                let x = cos(a) * d.speed * t * 1.6
                let y = -sin(a) * d.speed * t * 1.1 + 160 * t * t
                Circle()
                    .fill(Color.black)
                    .frame(width: d.size * (1 - f * 0.5), height: d.size * (1 - f * 0.5))
                    .offset(x: x, y: y)
                    .opacity(1 - f * f)
            }
        }
    }
}
