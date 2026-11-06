import SwiftUI

/// Nosy with body, arms and legs – drawn in a 60 × 76 pt box and scaled to the frame it gets.
///
/// `hanging` raises both arms so the paws hold on to whatever edge is right above (the bottom of the open notch).
struct NosyFigure: View {
    var mood: NosyMood
    var look: CGSize = .zero
    var level = 1
    var accessory: NosyAccessory = .none
    var hanging = false
    /// Accent of the active agent – tints the antenna glow.
    var tint: Color = NosyPalette.spark

    static let designSize = CGSize(width: 60, height: 76)

    var body: some View {
        ClockTimeline(minimumInterval: 1.0 / 30.0) { now in
            let t = now.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let s = min(geo.size.width / Self.designSize.width, geo.size.height / Self.designSize.height)
                NosyPose(mood: mood, look: look, level: level, accessory: accessory, hanging: hanging, tint: tint, t: t)
                    .frame(width: Self.designSize.width, height: Self.designSize.height)
                    .scaleEffect(s, anchor: .topLeading)
                    .frame(width: Self.designSize.width * s, height: Self.designSize.height * s, alignment: .topLeading)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

/// One frame of Nosy at time `t`.
private struct NosyPose: View {
    let mood: NosyMood
    let look: CGSize
    let level: Int
    let accessory: NosyAccessory
    let hanging: Bool
    let tint: Color
    let t: TimeInterval

    var body: some View {
        ZStack {
            legs
            arms
            antenna
            torso
            face
            accessoryLayer
            extras
        }
        .frame(width: 60, height: 76)
        .scaleEffect(x: squash.width, y: squash.height, anchor: .bottom)
        .rotationEffect(.degrees(tilt), anchor: hanging ? .top : .bottom)
        .offset(x: jitter, y: hop)
    }

    // MARK: Motion

    private var hop: CGFloat {
        switch mood {
        case .happy, .charging: return hanging ? -abs(sin(t * 7)) * 3 : -abs(sin(t * 6)) * 7
        case .waking: return -abs(sin(t * 5)) * 3
        case .grooving: return sin(t * .pi * 4) * 1.6
        case .needsYou: return -abs(sin(t * 4)) * 2
        case .giggle: return sin(t * 18) * 0.8
        default: return 0
        }
    }

    private var jitter: CGFloat {
        mood == .shocked ? sin(t * 55) * 1.3 : 0
    }

    private var tilt: Double {
        switch mood {
        case .grooving: return sin(t * .pi * 2) * 5
        case .dizzy: return sin(t * 3) * 7
        case .giggle: return sin(t * 9) * 4
        default: return hanging ? sin(t * 1.6) * 4 : 0
        }
    }

    private var squash: CGSize {
        let breath = 1 + 0.018 * sin(t * 2.1)
        switch mood {
        case .exhausted: return CGSize(width: 1.06, height: 0.9)
        case .sleeping: return CGSize(width: 1.02, height: 0.97 + 0.015 * sin(t * 1.2))
        case .happy, .charging:
            let land = max(0, cos(t * 12)) * 0.05
            return hanging ? CGSize(width: 1, height: breath) : CGSize(width: 1 + land, height: 1 - land)
        default: return CGSize(width: 1, height: breath)
        }
    }

    // MARK: Parts

    private var legs: some View {
        let swing = hanging ? sin(t * 2.2) * 14 : 0
        return ZStack {
            Capsule().fill(NosyPalette.foot)
                .frame(width: 8, height: 11)
                .rotationEffect(.degrees(swing), anchor: .top)
                .offset(x: -9, y: 28)
            Capsule().fill(NosyPalette.foot)
                .frame(width: 8, height: 11)
                .rotationEffect(.degrees(-swing), anchor: .top)
                .offset(x: 9, y: 28)
        }
    }

    private var arms: some View {
        let (left, right) = armAngles
        let shoulder = hanging ? CGPoint(x: 17, y: -6) : CGPoint(x: 19, y: 4)
        return ZStack {
            arm(left).offset(x: -shoulder.x, y: shoulder.y)
            arm(right).offset(x: shoulder.x, y: shoulder.y)
        }
    }

    /// One arm, rotated around its shoulder (the top of its frame).
    private func arm(_ angle: Double) -> some View {
        ZStack(alignment: .bottom) {
            Ellipse().fill(NosyPalette.limb)
                .frame(width: 9, height: hanging ? 12 : 14)
            // Hanging: round little paws that grip the edge.
            if hanging {
                Circle().fill(NosyPalette.limb)
                    .overlay(Circle().fill(.white.opacity(0.25)).frame(width: 4, height: 4).offset(x: -1, y: 1))
                    .frame(width: 10, height: 10)
                    .offset(y: 3)
            }
        }
        .frame(width: 10, height: 15, alignment: .top)
        .offset(y: 4)
        .rotationEffect(.degrees(angle), anchor: .top)
    }

    /// Rotation of each arm around its shoulder: 0 = hanging down, 180 = straight up.
    private var armAngles: (Double, Double) {
        if hanging {
            let pull = mood == .happy ? sin(t * 7) * 8 : 0
            return (166 + pull, -166 - pull)
        }
        switch mood {
        case .happy, .charging: return (135 + sin(t * 10) * 12, -135 - sin(t * 10) * 12)
        case .needsYou: return (25, -150 + sin(t * 9) * 25)
        case .shocked: return (95, -95)
        case .grooving: return (30 + sin(t * .pi * 4) * 12, -30 + sin(t * .pi * 4) * 12)
        case .typing: return (35 + sin(t * 16) * 6, -35 + cos(t * 16) * 6)
        case .exhausted, .sleeping: return (8, -8)
        default: return (22, -22)
        }
    }

    private var antenna: some View {
        let lean: Double = hanging ? 38 : (mood == .grooving ? sin(t * .pi * 4) * 10 : sin(t * 1.3) * 5)
        let glow = 0.25 + 0.15 * sin(t * 2.4)
        let sparkSize = 7 + CGFloat(min(level, 10)) * 0.6
        return ZStack(alignment: .top) {
            Capsule().fill(NosyPalette.top.opacity(0.9))
                .frame(width: 1.8, height: 10)
                .offset(y: 4)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(glow * 1.6), .clear], center: .center,
                                         startRadius: 0, endRadius: sparkSize))
                    .frame(width: sparkSize * 2, height: sparkSize * 2)
                if level >= 5 {
                    SparkleShape().fill(tint.opacity(0.35))
                        .frame(width: sparkSize * 1.7, height: sparkSize * 1.7)
                        .rotationEffect(.degrees(45 + t * 20))
                }
                SparkleShape().fill(NosyPalette.spark)
                    .frame(width: sparkSize, height: sparkSize)
                    .rotationEffect(.degrees(mood == .charging ? t * 180 : 0))
            }
            .offset(y: -sparkSize / 2)
        }
        .frame(width: 30, height: 18, alignment: .top)
        .rotationEffect(.degrees(lean), anchor: .bottom)
        .offset(y: -27)
    }

    private var torso: some View {
        ZStack {
            EggShape().fill(NosyPalette.body)
            EggShape().fill(
                RadialGradient(colors: [.white.opacity(0.28), .clear], center: UnitPoint(x: 0.7, y: 0.25),
                               startRadius: 0, endRadius: 26))
            Ellipse().fill(.white.opacity(0.55))
                .frame(width: 8, height: 4.5)
                .offset(x: 10, y: -20)
        }
        .frame(width: 48, height: 56)
        .offset(y: 4)
    }

    private var face: some View {
        ZStack {
            NosyEyes(mood: mood, look: look, time: t, ink: NosyPalette.ink, spacing: 6)
                .frame(width: 34, height: 14)
                .offset(y: 2)
            Ellipse().fill(NosyPalette.blush.opacity(mood == .giggle ? 0.8 : 0.45))
                .frame(width: 9, height: 5)
                .offset(x: -15, y: 12)
            Ellipse().fill(NosyPalette.blush.opacity(mood == .giggle ? 0.8 : 0.45))
                .frame(width: 9, height: 5)
                .offset(x: 15, y: 12)
            NosyMouth(mood: mood, t: t)
                .offset(y: 13)
        }
    }

    @ViewBuilder
    private var accessoryLayer: some View {
        switch effectiveAccessory {
        case .none:
            EmptyView()
        case .headphones:
            ZStack {
                Circle().trim(from: 0.55, to: 0.95)
                    .stroke(Color(white: 0.16), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(0))
                    .offset(y: 4)
                RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.14))
                    .frame(width: 7, height: 13).offset(x: -24, y: 0)
                RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.14))
                    .frame(width: 7, height: 13).offset(x: 24, y: 0)
                Circle().fill(tint).frame(width: 2.5).offset(x: 24, y: -3)
            }
        case .glasses:
            HStack(spacing: 4) {
                Circle().stroke(Color(white: 0.12), lineWidth: 1.6).frame(width: 16, height: 16)
                Circle().stroke(Color(white: 0.12), lineWidth: 1.6).frame(width: 16, height: 16)
            }
            .overlay(Capsule().fill(Color(white: 0.12)).frame(width: 5, height: 1.6))
            .offset(y: 2)
        case .cap:
            ZStack {
                Ellipse().fill(Color(white: 0.12)).frame(width: 34, height: 16).offset(y: -19)
                Capsule().fill(Color(white: 0.12)).frame(width: 22, height: 4).offset(x: 13, y: -13)
                Circle().fill(tint).frame(width: 3).offset(y: -25)
            }
        case .bow:
            ZStack {
                Ellipse().fill(Color(red: 1, green: 0.42, blue: 0.62)).frame(width: 9, height: 7).offset(x: -5)
                Ellipse().fill(Color(red: 1, green: 0.42, blue: 0.62)).frame(width: 9, height: 7).offset(x: 5)
                Circle().fill(Color(red: 0.9, green: 0.3, blue: 0.5)).frame(width: 4)
            }
            .rotationEffect(.degrees(-15))
            .offset(x: 13, y: -19)
        }
    }

    /// Headphones go on by themselves while music plays (once unlocked).
    private var effectiveAccessory: NosyAccessory {
        if mood == .grooving, level >= NosyAccessory.headphones.level { return .headphones }
        return accessory.level <= level ? accessory : .none
    }

    @ViewBuilder
    private var extras: some View {
        switch mood {
        case .sweating:
            let slide = NosyTime.fract(t / 1.6)
            DropShape().fill(Color(red: 0.55, green: 0.8, blue: 1))
                .frame(width: 4.5, height: 7)
                .offset(x: 19, y: -14 + slide * 8)
                .opacity(1 - slide * 0.7)
        case .sleeping:
            NosyZzz(t: t).offset(x: 20, y: -28)
        case .giggle:
            NosyHearts(t: t).offset(y: -30)
        case .charging:
            Image(systemName: "bolt.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NosyPalette.spark)
                .offset(x: 21, y: -20)
                .opacity(0.6 + 0.4 * sin(t * 6))
        default:
            EmptyView()
        }
    }
}

struct NosyMouth: View {
    let mood: NosyMood
    let t: TimeInterval

    var body: some View {
        switch mood {
        case .happy, .charging, .waking, .grooving:
            // Open smile.
            HalfCircle().fill(NosyPalette.ink)
                .frame(width: 8, height: 4.5)
        case .shocked, .needsYou:
            Ellipse().fill(NosyPalette.ink)
                .frame(width: 4.5, height: mood == .shocked ? 5.5 : 4)
        case .sleeping:
            Circle().fill(NosyPalette.ink.opacity(0.8))
                .frame(width: 2.5 + 1 * sin(t * 1.2))
        case .exhausted, .sleepy, .dizzy:
            Capsule().fill(NosyPalette.ink)
                .frame(width: 6, height: 1.4)
        case .giggle:
            WaveMouth().stroke(NosyPalette.ink, style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
                .frame(width: 8, height: 3)
        default:
            ArcShape(up: false).stroke(NosyPalette.ink, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .frame(width: 7, height: 2.5)
        }
    }
}

/// Lower half of a circle (open-mouth smile).
struct HalfCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 1.9))
        p.closeSubpath()
        return p
    }
}

/// "w" mouth.
struct WaveMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX + rect.width / 4, y: rect.maxY * 1.6))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - rect.width / 4, y: rect.maxY * 1.6))
        return p
    }
}

/// Little z's floating up.
struct NosyZzz: View {
    let t: TimeInterval
    var color: Color = .white

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let phase = NosyTime.fract(t / 2.4 + Double(i) / 3)
                Text("z")
                    .font(.system(size: 6 + phase * 6, weight: .heavy, design: .rounded))
                    .foregroundStyle(color.opacity(0.85 * (1 - phase)))
                    .offset(x: phase * 8, y: -phase * 14)
            }
        }
    }
}

/// Hearts floating up while you pet Nosy.
struct NosyHearts: View {
    let t: TimeInterval

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let phase = NosyTime.fract(t / 1.4 + Double(i) / 3)
                HeartShape().fill(Color(red: 1, green: 0.45, blue: 0.6).opacity(1 - phase))
                    .frame(width: 6, height: 5.5)
                    .offset(x: CGFloat(i - 1) * 9 + sin(phase * 6) * 2, y: -phase * 12)
            }
        }
    }
}
