import AppKit
import SwiftUI

/// A Pomodoro-style focus timer that lives in the notch.
@MainActor
final class FocusTimer: ObservableObject {
    enum Phase { case focus, rest }

    static let shared = FocusTimer()

    @Published private(set) var phase: Phase = .focus
    @Published private(set) var endsAt: Date?
    @Published private(set) var minutes = 25
    /// Ticks once a second while running, so views can redraw.
    @Published private(set) var now = Clock.now()

    var onFinished: ((Phase, Int) -> Void)?
    var onChange: (() -> Void)?
    private var ticker: Timer?

    var isRunning: Bool { endsAt != nil }
    var isFocusing: Bool { isRunning && phase == .focus }

    var remaining: TimeInterval { max(0, (endsAt ?? now).timeIntervalSince(now)) }
    var progress: Double { isRunning ? 1 - remaining / Double(minutes * 60) : 0 }

    /// "24:59"
    var remainingText: String {
        let s = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    func start(_ phase: Phase = .focus, minutes: Int? = nil) {
        self.phase = phase
        self.minutes = minutes ?? (phase == .focus ? Preferences.focusMinutes : Preferences.breakMinutes)
        now = Clock.now()
        endsAt = now.addingTimeInterval(Double(self.minutes * 60))
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        onChange?()
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        endsAt = nil
        onChange?()
    }

    private func tick() {
        now = Clock.now()
        guard let endsAt, now >= endsAt else { return }
        let finished = phase, length = minutes
        stop()
        onFinished?(finished, length)
    }
}

/// The timer as a ring with the minutes left in the middle (compact notch wing).
struct FocusRing: View {
    @ObservedObject var timer: FocusTimer
    var size: CGFloat = 18

    var body: some View {
        let color = timer.phase == .focus ? NosyPalette.top : Theme.success
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: 2.2)
            Circle()
                .trim(from: 0, to: max(0.02, 1 - timer.progress))
                .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((timer.remaining / 60).rounded(.up)))")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(width: size, height: size)
        .animation(.linear(duration: 1), value: timer.progress)
    }
}

/// Start / stop button for the hover card: "▶ 25 min" or a ring with "12:34" and ✕.
struct FocusButton: View {
    @ObservedObject var timer: FocusTimer
    @State private var hovering = false

    var body: some View {
        Button {
            timer.isRunning ? timer.stop() : timer.start(.focus)
        } label: {
            HStack(spacing: 5) {
                if timer.isRunning {
                    FocusRing(timer: timer, size: 14)
                    Text(timer.remainingText)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(hovering ? 0.9 : 0.4))
                } else {
                    TintedSymbol(name: "timer", size: 10, color: NosyPalette.top)
                    Text("\(Preferences.focusMinutes)m")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(hovering ? 0.95 : 0.7))
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 24)
            .fixedSize()
            .background(Capsule().fill(.white.opacity(hovering ? 0.14 : 0.07)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(timer.isRunning ? "Stop the timer" : "Start a \(Preferences.focusMinutes)-minute focus session")
    }
}
