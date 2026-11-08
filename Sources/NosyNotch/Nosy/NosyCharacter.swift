import SwiftUI

/// How Nosy feels right now. Derived from what the agents, the music and you are doing (see `NotchViewModel.nosyMood`).
enum NosyMood: Equatable {
    /// Nothing going on, eyes wander or follow the pointer.
    case idle
    /// Low energy – heavy eyelids. Never sad, just a bit tired.
    case sleepy
    /// Eyes closed, little z's.
    case sleeping
    /// Just woke up: "oh! hi."
    case waking
    /// An agent is thinking.
    case working
    /// An agent runs a tool – eyes look down at the "keyboard".
    case typing
    /// A turn has been running for a long time – a little sweat drop.
    case sweating
    /// Compacting context – spiral eyes.
    case dizzy
    /// Waiting for you – wide eyes, waving.
    case needsYou
    /// Done – ^^ eyes, jumping.
    case happy
    /// An API error – ✕✕ eyes, trembling.
    case shocked
    /// A usage limit is used up – flat and droopy until it resets.
    case exhausted
    /// Music plays – head bobs to the beat.
    case grooving
    /// You poked or petted Nosy.
    case giggle
    /// The Mac was plugged in.
    case charging

    var bounces: Bool { self == .happy || self == .charging || self == .waking }
}

/// Things Nosy can wear, unlocked by level.
enum NosyAccessory: String, CaseIterable, Identifiable {
    case none, headphones, glasses, cap, bow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Nothing"
        case .headphones: return "Headphones"
        case .glasses: return "Glasses"
        case .cap: return "Cap"
        case .bow: return "Bow"
        }
    }

    /// What it takes to wear it.
    enum Unlock: Equatable {
        case level(Int)
        case streak(days: Int)
        case tasks(Int)
    }

    static let headphonesLevel = 2

    var unlock: Unlock {
        switch self {
        case .none: return .level(1)
        case .headphones: return .level(Self.headphonesLevel)
        case .glasses: return .level(4)
        case .cap: return .level(6)
        case .bow: return .level(8)
        }
    }

    /// "Lv 4", "7 days", "50 tasks" on a locked item.
    var lockedLabel: String {
        switch unlock {
        case .level(let level): return "Lv \(level)"
        case .streak(let days): return "\(days) days"
        case .tasks(let tasks): return "\(tasks) tasks"
        }
    }
}

/// Nosy's colour (Settings → Nosy → Wardrobe). Obsidian takes the active agent's colour as its rim light.
enum NosyColor: String, CaseIterable, Identifiable {
    case obsidian, midnight, plum, lavender, peach, mint, pearl, jelly

    var id: String { rawValue }
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    var top: Color {
        switch self {
        case .obsidian: return Color(white: 0.2)
        case .midnight: return Color(red: 0.25, green: 0.28, blue: 0.62)
        case .plum: return Color(red: 0.46, green: 0.25, blue: 0.62)
        case .lavender: return Color(red: 0.82, green: 0.77, blue: 1)
        case .peach: return Color(red: 1, green: 0.8, blue: 0.68)
        case .mint: return Color(red: 0.82, green: 0.97, blue: 0.89)
        case .pearl: return .white
        case .jelly: return Color(red: 1, green: 0.55, blue: 0.78).opacity(0.78)
        }
    }

    var bottom: Color {
        switch self {
        case .obsidian: return Color(white: 0.03)
        case .midnight: return Color(red: 0.06, green: 0.07, blue: 0.22)
        case .plum: return Color(red: 0.13, green: 0.05, blue: 0.22)
        case .lavender: return Color(red: 0.56, green: 0.47, blue: 0.95)
        case .peach: return Color(red: 1, green: 0.52, blue: 0.44)
        case .mint: return Color(red: 0.38, green: 0.8, blue: 0.62)
        case .pearl: return Color(red: 0.82, green: 0.81, blue: 0.9)
        case .jelly: return Color(red: 0.5, green: 0.38, blue: 1).opacity(0.88)
        }
    }

    /// nil = the active agent's colour.
    var rim: Color? {
        switch self {
        case .obsidian: return nil
        case .midnight: return Color(red: 0.56, green: 0.66, blue: 1)
        case .plum: return Color(red: 0.88, green: 0.55, blue: 1)
        case .peach: return Color(red: 1, green: 0.85, blue: 0.5)
        case .pearl: return Color(red: 0.72, green: 0.68, blue: 1)
        case .lavender, .mint, .jelly: return .white
        }
    }

    var isDark: Bool { self == .obsidian || self == .midnight || self == .plum }

    /// Mouth and closed-eye strokes.
    var ink: Color {
        switch self {
        case .obsidian, .midnight, .plum: return .white.opacity(0.85)
        case .mint: return Color(red: 0.1, green: 0.25, blue: 0.18)
        default: return NosyPalette.ink
        }
    }

    var jelly: Bool { self == .jelly }
}

/// A soft bean: narrow, round top, fuller and flatter towards the bottom.
struct BeanShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, x = rect.minX, y = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x + w / 2, y: y))
        p.addCurve(to: CGPoint(x: x + w, y: y + h * 0.66),
                   control1: CGPoint(x: x + w * 0.88, y: y),
                   control2: CGPoint(x: x + w, y: y + h * 0.34))
        p.addCurve(to: CGPoint(x: x + w / 2, y: y + h),
                   control1: CGPoint(x: x + w, y: y + h * 0.94),
                   control2: CGPoint(x: x + w * 0.78, y: y + h))
        p.addCurve(to: CGPoint(x: x, y: y + h * 0.66),
                   control1: CGPoint(x: x + w * 0.22, y: y + h),
                   control2: CGPoint(x: x, y: y + h * 0.94))
        p.addCurve(to: CGPoint(x: x + w / 2, y: y),
                   control1: CGPoint(x: x, y: y + h * 0.34),
                   control2: CGPoint(x: x + w * 0.12, y: y))
        p.closeSubpath()
        return p
    }
}

enum NosyPalette {
    static let top = Color(red: 0.70, green: 0.64, blue: 1.0)       // lavender
    static let middle = Color(red: 0.88, green: 0.63, blue: 0.90)   // pink
    static let bottom = Color(red: 1.0, green: 0.62, blue: 0.49)    // peach
    static let limb = Color(red: 0.92, green: 0.64, blue: 0.79)
    static let foot = Color(red: 0.95, green: 0.60, blue: 0.53)
    static let iris = Color(red: 0.48, green: 0.24, blue: 0.08)
    static let ink = Color(red: 0.23, green: 0.10, blue: 0.16)
    static let blush = Color(red: 1.0, green: 0.54, blue: 0.54)
    static let spark = Color(red: 1.0, green: 0.82, blue: 0.48)

    static var body: LinearGradient {
        LinearGradient(colors: [top, middle, bottom], startPoint: .top, endPoint: .bottom)
    }
}

/// Deterministic little helpers so every animation runs on the (possibly virtual) clock.
enum NosyTime {
    /// True for ~0.13 s every few seconds, at slightly random moments.
    static func isBlinking(_ t: TimeInterval, seed: Double = 0) -> Bool {
        let period = 3.6
        let cycle = floor(t / period)
        let at = fract(sin((cycle + seed) * 12.9898) * 43_758.5453) * (period - 0.4)
        let local = t - cycle * period
        return local >= at && local < at + 0.13
    }

    static func fract(_ x: Double) -> Double { x - floor(x) }
}

// MARK: - Eyes

/// One eye. `style` decides whether it's open, closed, ^, ✕ …
struct NosyEye: View {
    enum Style: Equatable { case open, closed, happy, cross, spiral, squint, halfLid, wide }

    var style: Style
    /// -1…1 in both directions: where the iris looks.
    var look: CGSize = .zero
    /// Colour of strokes (closed / happy / cross): dark on the body, white inside the notch.
    var ink: Color = NosyPalette.ink
    var mirrored = false
    var time: TimeInterval = 0

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack { content(d) }
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private func content(_ d: CGFloat) -> some View {
        switch style {
        case .open, .wide, .halfLid:
            openEye(d)
        case .closed:
            ArcShape(up: false).stroke(ink, style: StrokeStyle(lineWidth: max(1.2, d * 0.14), lineCap: .round))
                .frame(width: d * 0.8, height: d * 0.32)
                .offset(y: d * 0.12)
        case .happy:
            ArcShape(up: true).stroke(ink, style: StrokeStyle(lineWidth: max(1.2, d * 0.15), lineCap: .round))
                .frame(width: d * 0.8, height: d * 0.4)
        case .cross:
            CrossShape().stroke(ink, style: StrokeStyle(lineWidth: max(1.2, d * 0.15), lineCap: .round))
                .frame(width: d * 0.62, height: d * 0.62)
        case .spiral:
            SpiralShape().stroke(ink, style: StrokeStyle(lineWidth: max(1, d * 0.11), lineCap: .round))
                .frame(width: d * 0.8, height: d * 0.8)
                .rotationEffect(.radians(time * (mirrored ? -5 : 5)))
        case .squint:
            ChevronShape(pointsRight: !mirrored)
                .stroke(ink, style: StrokeStyle(lineWidth: max(1.2, d * 0.15), lineCap: .round, lineJoin: .round))
                .frame(width: d * 0.5, height: d * 0.62)
        }
    }

    private func openEye(_ d: CGFloat) -> some View {
        let scale: CGFloat = style == .wide ? 1.12 : 1
        let size = d * scale
        let iris = size * 0.78
        let travel = (size - iris) / 2 + size * 0.04
        let dx = look.width * travel
        let dy = look.height * travel
        return ZStack {
            Circle().fill(.white)
            Circle().fill(NosyPalette.iris)
                .frame(width: iris, height: iris)
                .offset(x: dx, y: dy)
            Circle().fill(.white)
                .frame(width: size * 0.3, height: size * 0.3)
                .offset(x: dx + size * 0.16, y: dy - size * 0.16)
            Circle().fill(.white.opacity(0.9))
                .frame(width: size * 0.13, height: size * 0.13)
                .offset(x: dx - size * 0.12, y: dy + size * 0.15)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .mask {
            // Heavy eyelids: only the lower half of the eye stays open.
            if style == .halfLid {
                Rectangle().frame(height: size * 0.5).offset(y: size * 0.25)
            } else {
                Rectangle()
            }
        }
    }
}

/// Both eyes, laid out and styled for a mood.
struct NosyEyes: View {
    var mood: NosyMood
    var look: CGSize = .zero
    var time: TimeInterval
    var ink: Color = NosyPalette.ink
    var spacing: CGFloat

    var body: some View {
        let style = Self.style(for: mood, blinking: NosyTime.isBlinking(time))
        HStack(spacing: spacing) {
            NosyEye(style: style, look: effectiveLook, ink: ink, mirrored: false, time: time)
            NosyEye(style: style, look: effectiveLook, ink: ink, mirrored: true, time: time)
        }
    }

    /// Some moods decide where to look themselves.
    private var effectiveLook: CGSize {
        switch mood {
        case .typing: return CGSize(width: look.width * 0.4, height: 0.75)
        case .working: return CGSize(width: 0.35 * sin(time * 0.9), height: -0.55)
        case .needsYou: return CGSize(width: 0.7, height: 0.6)
        case .grooving: return CGSize(width: 0.5 * sin(time * 2.2), height: 0)
        default: return look
        }
    }

    static func style(for mood: NosyMood, blinking: Bool) -> NosyEye.Style {
        switch mood {
        case .sleeping: return .closed
        case .happy, .charging, .waking: return .happy
        case .shocked: return .cross
        case .dizzy: return .spiral
        case .giggle: return .squint
        case .sleepy, .exhausted: return blinking ? .closed : .halfLid
        case .needsYou: return blinking ? .closed : .wide
        case .grooving: return .happy
        default: return blinking ? .closed : .open
        }
    }
}

// MARK: - Shapes

struct ArcShape: Shape {
    /// ^ (happy) or ‿ (closed).
    var up: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        if up {
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.6))
        } else {
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.6))
        }
        return p
    }
}

struct CrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return p
    }
}

struct ChevronShape: Shape {
    var pointsRight: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tipX = pointsRight ? rect.maxX : rect.minX
        let backX = pointsRight ? rect.minX : rect.maxX
        p.move(to: CGPoint(x: backX, y: rect.minY))
        p.addLine(to: CGPoint(x: tipX, y: rect.midY))
        p.addLine(to: CGPoint(x: backX, y: rect.maxY))
        return p
    }
}

struct SpiralShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let maxR = min(rect.width, rect.height) / 2
        let turns = 2.2
        let steps = 48
        for i in 0...steps {
            let f = Double(i) / Double(steps)
            let a = f * turns * 2 * .pi
            let r = maxR * f
            let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

/// Nosy's body: a soft egg.
struct EggShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x = rect.minX, y = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x + w / 2, y: y))
        p.addCurve(to: CGPoint(x: x + w, y: y + h * 0.6),
                   control1: CGPoint(x: x + w * 0.85, y: y),
                   control2: CGPoint(x: x + w, y: y + h * 0.3))
        p.addCurve(to: CGPoint(x: x + w / 2, y: y + h),
                   control1: CGPoint(x: x + w, y: y + h * 0.88),
                   control2: CGPoint(x: x + w * 0.8, y: y + h))
        p.addCurve(to: CGPoint(x: x, y: y + h * 0.6),
                   control1: CGPoint(x: x + w * 0.2, y: y + h),
                   control2: CGPoint(x: x, y: y + h * 0.88))
        p.addCurve(to: CGPoint(x: x + w / 2, y: y),
                   control1: CGPoint(x: x, y: y + h * 0.3),
                   control2: CGPoint(x: x + w * 0.15, y: y))
        p.closeSubpath()
        return p
    }
}

/// The ✦ on Nosy's antenna – the same sparkle as in the menu bar.
struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let i = r * 0.28
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + i, y: c.y - i))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + i, y: c.y + i))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - i, y: c.y + i))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - i, y: c.y - i))
        p.closeSubpath()
        return p
    }
}

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.3),
                   control1: CGPoint(x: rect.midX - w * 0.1, y: rect.maxY - h * 0.2),
                   control2: CGPoint(x: rect.minX, y: rect.minY + h * 0.6))
        p.addArc(center: CGPoint(x: rect.minX + w * 0.25, y: rect.minY + h * 0.3), radius: w * 0.25,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: rect.minX + w * 0.75, y: rect.minY + h * 0.3), radius: w * 0.25,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                   control1: CGPoint(x: rect.maxX, y: rect.minY + h * 0.6),
                   control2: CGPoint(x: rect.midX + w * 0.1, y: rect.maxY - h * 0.2))
        return p
    }
}

struct DropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.width / 2),
                       control: CGPoint(x: rect.maxX, y: rect.midY - rect.height * 0.1))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY - rect.width / 2), radius: rect.width / 2,
                 startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.midY - rect.height * 0.1))
        return p
    }
}
