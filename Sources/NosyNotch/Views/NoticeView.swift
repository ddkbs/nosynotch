import SwiftUI

/// The card for a `Notice`: icon on the left, title and detail on the right.
struct NoticeView: View {
    let notice: Notice
    var onAction: (() -> Void)?
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            icon
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                detail
            }
            Spacer(minLength: 0)
            if let action = actionTitle, let onAction {
                NotchButton(title: action, style: .prominent, action: onAction)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .overlay(alignment: .topTrailing) {
            DismissButton(action: onDismiss).padding(.top, 8).padding(.trailing, 14)
        }
    }

    private var title: String {
        switch notice {
        case .charging: return "Charging"
        case .lowBattery: return "Battery low"
        case .device(let name, _, _): return name
        case .timerDone(let wasFocus, _): return wasFocus ? "Focus time's up" : "Break's over"
        case .meeting(let m): return m.title
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch notice {
        case .charging(let p):
            Text("\(p) % – plugged in")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
        case .lowBattery(let p):
            Text("\(p) % left – time to find a charger")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
        case .device(_, _, let batteries):
            if batteries.isEmpty {
                Text("Connected").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
            } else {
                HStack(spacing: 10) {
                    ForEach(batteries, id: \.label) { battery in
                        HStack(spacing: 4) {
                            if !battery.label.isEmpty {
                                Text(battery.label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                            }
                            BatteryGlyph(percent: battery.percent, charging: false)
                                .frame(width: 20, height: 9)
                            Text("\(battery.percent)%").font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
            }
        case .timerDone(let wasFocus, let minutes):
            Text(wasFocus ? "\(minutes) min of focus done – stretch, drink something." : "Ready for the next round?")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
        case .meeting(let m):
            HStack(spacing: 6) {
                Circle().fill(m.color).frame(width: 7, height: 7)
                Text(m.startsText).font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                if let location = m.shortLocation {
                    Text("· \(location)").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                }
            }
            .lineLimit(1)
        }
    }

    private var actionTitle: String? {
        switch notice {
        case .meeting(let m): return m.joinURL == nil ? nil : "Join"
        case .timerDone(let wasFocus, _): return wasFocus ? "Break" : "Focus"
        default: return nil
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch notice {
        case .charging(let p):
            ChargingIcon(percent: p)
        case .lowBattery(let p):
            ZStack {
                Circle().fill(Theme.amber.opacity(0.16))
                BatteryGlyph(percent: p, charging: false).frame(width: 26, height: 12)
            }
        case .device(_, let symbol, _):
            ZStack {
                Circle().fill(.white.opacity(0.08))
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
            }
        case .timerDone:
            ZStack {
                Circle().fill(NosyPalette.top.opacity(0.18))
                TintedSymbol(name: "timer", size: 19, color: NosyPalette.top)
            }
        case .meeting(let m):
            ZStack {
                Circle().fill(m.color.opacity(0.18))
                TintedSymbol(name: m.joinURL == nil ? "calendar" : "video.fill", size: 17, color: m.color)
            }
        }
    }
}

/// A little battery with a fill level.
struct BatteryGlyph: View {
    let percent: Int
    var charging: Bool

    private var color: Color {
        if charging { return Theme.success }
        return percent <= 20 ? Theme.danger : (percent <= 35 ? Theme.amber : .white.opacity(0.85))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            HStack(spacing: 1) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: h * 0.28).stroke(.white.opacity(0.5), lineWidth: 1)
                    RoundedRectangle(cornerRadius: h * 0.18)
                        .fill(color)
                        .frame(width: max(1.5, (w - 4) * 0.9 * CGFloat(min(100, max(0, percent))) / 100))
                        .padding(2)
                }
                .frame(width: w * 0.9)
                RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.5)).frame(width: w * 0.06, height: h * 0.4)
            }
        }
    }
}

/// Plugged in: the battery fills up to its level, a bolt pulses.
struct ChargingIcon: View {
    let percent: Int
    @State private var filled = false

    var body: some View {
        ZStack {
            Circle().fill(Theme.success.opacity(0.16))
            BatteryGlyph(percent: filled ? percent : 0, charging: true)
                .frame(width: 28, height: 13)
            Image(systemName: "bolt.fill")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 1)
                .scaleEffect(filled ? 1 : 0.4)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.9).delay(0.15)) { filled = true } }
    }
}

/// An SF Symbol drawn as a tinted bitmap – looks the same on screen and in the GIF recorder (whose snapshots
/// lose the colour of plain tinted symbols).
struct TintedSymbol: View {
    let name: String
    var size: CGFloat
    var weight: NSFont.Weight = .semibold
    var color: Color

    var body: some View {
        if let image = Self.image(name, size: size, weight: weight, color: NSColor(color)) {
            Image(nsImage: image)
        } else {
            Image(systemName: name).font(.system(size: size, weight: .semibold)).foregroundStyle(color)
        }
    }

    static func image(_ name: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    }
}
