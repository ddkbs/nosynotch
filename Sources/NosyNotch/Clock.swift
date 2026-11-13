import Foundation
import SwiftUI

/// The app's idea of "now".
///
/// Normally the wall clock. While `Recorder` renders a scene it switches to a virtual clock that it advances by
/// exactly one frame per snapshot, so every frame shows the moment `frame / fps` – however long rendering takes.
/// Timers that drive the notch (flash timeouts, approval timeouts, …) go through `after(_:_:)` so they fire on the
/// same timeline.
enum Clock {
    /// The virtual time while recording, nil otherwise. Only touched on the main thread.
    nonisolated(unsafe) private(set) static var virtual: Date?
    nonisolated(unsafe) private static var pending: [(due: Date, work: DispatchWorkItem)] = []

    static var isVirtual: Bool { virtual != nil }

    static func now() -> Date { virtual ?? Date() }

    /// Runs `work` on the main queue after `seconds` – on the virtual timeline while recording.
    static func after(_ seconds: TimeInterval, execute work: DispatchWorkItem) {
        guard let virtual else {
            return DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
        }
        pending.append((virtual + seconds, work))
    }

    static func after(_ seconds: TimeInterval, _ block: @escaping @MainActor () -> Void) {
        after(seconds, execute: DispatchWorkItem { MainActor.assumeIsolated(block) })
    }

    // MARK: Recording

    /// Switches to a virtual clock starting at `date` and drops anything scheduled on an earlier timeline.
    @MainActor static func startVirtual(at date: Date) {
        virtual = date
        pending.removeAll()
    }

    /// Moves the virtual clock to `date` and runs everything that has become due, in order.
    @MainActor static func advance(to date: Date) {
        guard virtual != nil else { return }
        while let next = pending.indices.filter({ pending[$0].due <= date }).min(by: { pending[$0].due < pending[$1].due }) {
            let (due, work) = pending.remove(at: next)
            virtual = max(virtual ?? due, due)
            if !work.isCancelled { work.perform() }
        }
        virtual = date
    }

    @MainActor static func stopVirtual() {
        virtual = nil
        pending.removeAll()
    }
}

extension EnvironmentValues {
    /// Set by the recorder: the virtual time every `ClockTimeline` below shows instead of the wall clock.
    @Entry var virtualDate: Date?
}

/// A drop-in for `TimelineView(.animation(…))` that follows the recorder's virtual clock while recording.
struct ClockTimeline<Content: View>: View {
    var minimumInterval: Double?
    var paused = false
    @ViewBuilder var content: (Date) -> Content

    @Environment(\.virtualDate) private var virtualDate

    init(minimumInterval: Double? = nil, paused: Bool = false, @ViewBuilder content: @escaping (Date) -> Content) {
        self.minimumInterval = minimumInterval
        self.paused = paused
        self.content = content
    }

    var body: some View {
        if let virtualDate {
            // A paused timeline holds still; a fixed date keeps it deterministic.
            content(paused ? Date(timeIntervalSinceReferenceDate: 0) : virtualDate)
        } else {
            TimelineView(.animation(minimumInterval: minimumInterval, paused: paused)) { timeline in
                content(timeline.date)
            }
        }
    }
}

/// Like `ClockTimeline`, but redraws only at the dates `schedule` lists – for views that change rarely.
struct ScheduledClock<Schedule: TimelineSchedule, Content: View>: View {
    var schedule: Schedule
    @ViewBuilder var content: (Date) -> Content

    @Environment(\.virtualDate) private var virtualDate

    var body: some View {
        if let virtualDate {
            content(virtualDate)
        } else {
            TimelineView(schedule) { content($0.date) }
        }
    }
}

/// A drop-in for `TimelineView(.periodic(from: .now, by:))` that follows the recorder's virtual clock.
struct PeriodicClock<Content: View>: View {
    var interval: TimeInterval
    @ViewBuilder var content: (Date) -> Content

    @Environment(\.virtualDate) private var virtualDate

    init(every interval: TimeInterval, @ViewBuilder content: @escaping (Date) -> Content) {
        self.interval = interval
        self.content = content
    }

    var body: some View {
        if let virtualDate {
            let t = virtualDate.timeIntervalSinceReferenceDate
            content(Date(timeIntervalSinceReferenceDate: (t / interval).rounded(.down) * interval))
        } else {
            TimelineView(.periodic(from: .now, by: interval)) { content($0.date) }
        }
    }
}
