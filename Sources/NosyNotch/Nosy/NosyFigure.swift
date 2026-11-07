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
    /// Accent of the active agent – tints the antenna glow (and the rim on Obsidian).
    var tint: Color = NosyPalette.spark
    var color: NosyColor = .obsidian

    static let designSize = CGSize(width: 60, height: 76)

    var body: some View {
        ClockTimeline(minimumInterval: 1.0 / 30.0) { now in
            let t = now.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let s = min(geo.size.width / Self.designSize.width, geo.size.height / Self.designSize.height)
                NosyPose(mood: mood, look: look, level: level, accessory: accessory, hanging: hanging, tint: tint,
                         color: color, t: t)
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
    let color: NosyColor
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

    private var fill: LinearGradient {
        LinearGradient(colors: [color.top, color.bottom], startPoint: .top, endPoint: .bottom)
    }

    /// Rim light and antenna glow: the agent's colour on Obsidian, the palette's own otherwise.
    private var rim: Color { color.rim ?? tint }

    private var legs: some View {
        let swing = hanging ? sin(t * 2.2) * 12 : 0
        return ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule().fill(fill)
                    .overlay(Capsule().stroke(rim.opacity(0.25), lineWidth: 0.7))
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(side * swing), anchor: .top)
                    .offset(x: side * 10, y: 30)
            }
        }
    }

    private var arms: some View {
        let (left, right) = armAngles
        let shoulder = hanging ? CGPoint(x: 20, y: 0) : CGPoint(x: 19, y: 8)
        return ZStack {
            arm(left).offset(x: -shoulder.x, y: shoulder.y)
            arm(right).offset(x: shoulder.x, y: shoulder.y)
        }
    }

    /// One stubby arm, rotated around its shoulder (the top of its frame).
    private func arm(_ angle: Double) -> some View {
        let raised = abs(angle) > 60
        return Capsule().fill(fill)
            .overlay(Capsule().stroke(rim.opacity(0.3), lineWidth: 0.7))
            .frame(width: 12, height: hanging ? 20 : 17)
            .offset(y: hanging ? 9 : (raised ? 2 : 7))
            .rotationEffect(.degrees(angle), anchor: .top)
    }

    /// Rotation of each arm around its shoulder: 0 = hanging down, 180 = straight up.
    private var armAngles: (Double, Double) {
        if hanging {
            let pull = mood == .happy ? sin(t * 7) * 6 : 0
            return (172 + pull, -172 - pull)
        }
        switch mood {
        case .happy, .charging: return (105 + sin(t * 10) * 10, -105 - sin(t * 10) * 10)
        case .needsYou: return (22, -118 + sin(t * 9) * 14)
        case .shocked: return (85, -85)
        case .grooving: return (30 + sin(t * .pi * 4) * 12, -30 + sin(t * .pi * 4) * 12)
        case .typing: return (40 + sin(t * 16) * 6, -40 + cos(t * 16) * 6)
        case .exhausted, .sleeping: return (8, -8)
        default: return (24, -24)
        }
    }

    private var antenna: some View {
        let lean: Double = hanging ? 35 : (mood == .grooving ? sin(t * .pi * 4) * 10 : sin(t * 1.3) * 6)
        let glow = 0.6 + 0.4 * sin(t * 2.5)
        let sparkSize = 7 + CGFloat(min(level, 10)) * 0.5
        return ZStack(alignment: .top) {
            Capsule().fill(rim.opacity(0.6)).frame(width: 1.6, height: 9).offset(y: 5)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [rim.opacity(0.7), .clear], center: .center, startRadius: 0, endRadius: sparkSize))
                    .frame(width: sparkSize * 2, height: sparkSize * 2)
                    .opacity(glow)
                if level >= 5 {
                    SparkleShape().fill(rim.opacity(0.35))
                        .frame(width: sparkSize * 1.7, height: sparkSize * 1.7)
                        .rotationEffect(.degrees(45 + t * 20))
                }
                SparkleShape().fill(rim)
                    .frame(width: sparkSize, height: sparkSize)
                    .rotationEffect(.degrees(mood == .charging ? t * 180 : 0))
            }
            .offset(y: -sparkSize / 2 + 4)
        }
        .frame(width: 20, height: 16, alignment: .top)
        .rotationEffect(.degrees(lean), anchor: .bottom)
        .offset(y: -32)
    }

    private var torso: some View {
        ZStack {
            BeanShape().fill(fill)
            if color.jelly {
                BeanShape().fill(RadialGradient(colors: [.white.opacity(0.35), .clear], center: UnitPoint(x: 0.5, y: 0.7),
                                                startRadius: 0, endRadius: 22))
            }
            BeanShape().stroke(LinearGradient(colors: [rim.opacity(0.85), rim.opacity(0.05)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
            Ellipse().fill(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 22, height: 11)
                .offset(x: 7, y: -16)
            Circle().fill(.white.opacity(0.7)).frame(width: 3.5).offset(x: 14, y: -11)
        }
        .frame(width: 50, height: 54)
        .offset(y: 3)
    }

    private var face: some View {
        ZStack {
            NosyEyes(mood: mood, look: look, time: t, ink: color.ink, spacing: 5)
                .frame(width: 35, height: 15)
                .shadow(color: rim.opacity(0.35), radius: 3)
            HStack(spacing: 20) {
                blushSpot
                blushSpot
            }
            .offset(y: 10)
            NosyMouth(mood: mood, t: t, ink: color.ink)
                .offset(y: 11)
        }
        .offset(y: 4)
    }

    private var blushSpot: some View {
        Ellipse().fill(RadialGradient(colors: [Color(red: 1, green: 0.5, blue: 0.6).opacity(mood == .giggle ? 0.95 : 0.7), .clear],
                                      center: .center, startRadius: 0, endRadius: 7))
            .frame(width: 14, height: 8)
    }

    /// Headphones and cap: dark on light Nosys, light grey on dark ones.
    private var gear: Color { color.isDark ? Color(white: 0.6) : Color(white: 0.14) }

    @ViewBuilder
    private var accessoryLayer: some View {
        switch effectiveAccessory {
        case .none:
            EmptyView()
        case .headphones:
            ZStack {
                Circle().trim(from: 0.55, to: 0.95)
                    .stroke(gear, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(0))
                    .offset(y: 4)
                RoundedRectangle(cornerRadius: 3).fill(gear)
                    .frame(width: 7, height: 13).offset(x: -24, y: 0)
                RoundedRectangle(cornerRadius: 3).fill(gear)
                    .frame(width: 7, height: 13).offset(x: 24, y: 0)
                Circle().fill(tint).frame(width: 2.5).offset(x: 24, y: -3)
            }
        case .glasses:
            HStack(spacing: 4) {
                Circle().stroke(Color(white: 0.12), lineWidth: 1.6).frame(width: 18, height: 18)
                Circle().stroke(Color(white: 0.12), lineWidth: 1.6).frame(width: 18, height: 18)
            }
            .overlay(Capsule().fill(Color(white: 0.12)).frame(width: 5, height: 1.6))
            .overlay {
                // Dark Nosys get light frames.
                if color.isDark {
                    HStack(spacing: 4) {
                        Circle().stroke(.white.opacity(0.75), lineWidth: 1.4).frame(width: 18, height: 18)
                        Circle().stroke(.white.opacity(0.75), lineWidth: 1.4).frame(width: 18, height: 18)
                    }
                }
            }
            .offset(y: 4)
        case .cap:
            ZStack {
                Ellipse().fill(gear).frame(width: 34, height: 16).offset(y: -19)
                Capsule().fill(gear).frame(width: 22, height: 4).offset(x: 13, y: -13)
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
    var ink: Color = NosyPalette.ink

    var body: some View {
        switch mood {
        case .happy, .charging, .waking, .grooving:
            // Open smile.
            HalfCircle().fill(ink)
                .frame(width: 8, height: 4.5)
        case .shocked, .needsYou:
            Ellipse().fill(ink)
                .frame(width: 4.5, height: mood == .shocked ? 5.5 : 4)
        case .sleeping:
            Circle().fill(ink.opacity(0.8))
                .frame(width: 2.5 + 1 * sin(t * 1.2))
        case .exhausted, .sleepy, .dizzy:
            Capsule().fill(ink)
                .frame(width: 6, height: 1.4)
        case .giggle:
            WaveMouth().stroke(ink, style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
                .frame(width: 8, height: 3)
        default:
            ArcShape(up: false).stroke(ink, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
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
