import SwiftUI

/// One moment on the clock, split up for display. Follows the Mac's 12 / 24-hour setting and language.
struct ClockFace: Equatable {
    let hour: String
    let minute: String
    /// "AM" / "PM" on a 12-hour clock.
    let period: String?
    let second: Int
    let weekday: String
    let shortWeekday: String
    let date: String

    init(_ now: Date) {
        // Recordings look the same on every Mac.
        let locale = Clock.isVirtual ? Locale(identifier: "en_GB") : Locale.autoupdatingCurrent
        var calendar = Calendar.current
        calendar.locale = locale
        let parts = calendar.dateComponents([.hour, .minute, .second], from: now)
        let hours = parts.hour ?? 0

        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? "HH"
        if format.contains("H") || format.contains("k") {
            hour = String(format: "%02d", hours)
            period = nil
        } else {
            hour = String(hours % 12 == 0 ? 12 : hours % 12)
            period = hours < 12 ? calendar.amSymbol : calendar.pmSymbol
        }
        minute = String(format: "%02d", parts.minute ?? 0)
        second = parts.second ?? 0

        let style = Date.FormatStyle(locale: locale, calendar: calendar)
        weekday = now.formatted(style.weekday(.wide))
        shortWeekday = now.formatted(style.weekday(.abbreviated)).replacingOccurrences(of: ".", with: "").uppercased()
        date = now.formatted(style.day().month(.wide))
    }
}

/// The digits: they roll when the minute changes, and the colon breathes in Nosy's gold.
private struct ClockDigits: View {
    let face: ClockFace
    let size: CGFloat
    var weight: Font.Weight = .semibold

    var body: some View {
        HStack(spacing: size * 0.04) {
            Text(face.hour).contentTransition(.numericText())
            Text(":")
                .foregroundStyle(NosyPalette.spark)
                .opacity(face.second.isMultiple(of: 2) ? 1 : 0.3)
                .animation(.easeInOut(duration: 0.8), value: face.second)
            Text(face.minute).contentTransition(.numericText())
        }
        .font(.system(size: size, weight: weight, design: .rounded).monospacedDigit())
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: face.minute)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: face.hour)
        .lineLimit(1)
        .fixedSize()
    }
}

/// The time on the right wing of the quiet notch. Dims while Nosy sleeps, counts down before a meeting.
struct ClockWing: View {
    var dimmed = false
    var meeting: Meeting?

    private static let countdownFrom: TimeInterval = 15 * 60

    var body: some View {
        PeriodicClock(every: 1) { now in
            if let meeting, case let left = meeting.start.timeIntervalSince(now), left > 0, left <= Self.countdownFrom {
                Text("in \(Int((left / 60).rounded(.up)))m")
                    .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(meeting.color)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: Int(left / 60))
                    .lineLimit(1)
                    .fixedSize()
                    .help(meeting.title)
            } else {
                ClockDigits(face: ClockFace(now), size: 11)
                    .foregroundStyle(.white.opacity(dimmed ? 0.5 : 0.92))
                    .animation(.easeInOut(duration: 0.6), value: dimmed)
            }
        }
    }
}

/// "SUN" – fills the left wing when Nosy is turned off.
struct ClockDayWing: View {
    var body: some View {
        PeriodicClock(every: 60) { now in
            Text(ClockFace(now).shortWeekday)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
                .fixedSize()
        }
    }
}

/// The big clock at the top of the hover view.
struct ClockCard: View {
    var body: some View {
        PeriodicClock(every: 1) { now in
            let face = ClockFace(now)
            HStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    ClockDigits(face: face, size: 42, weight: .medium)
                        .foregroundStyle(.white)
                    if let period = face.period {
                        Text(period)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(face.weekday)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(face.date)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .lineLimit(1)
            }
            .padding(.horizontal, 24)
            .frame(height: NotchViewModel.clockCardHeight)
        }
    }
}
