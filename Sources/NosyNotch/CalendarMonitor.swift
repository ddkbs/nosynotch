import AppKit
import EventKit
import SwiftUI

/// The next meeting from your calendars, and a heads-up 10 minutes before it starts. Opt-in – macOS asks for
/// calendar access the first time. Nothing leaves the Mac.
@MainActor
final class CalendarMonitor: ObservableObject {
    @Published private(set) var next: Meeting?
    @Published private(set) var accessDenied = false

    var onNotice: ((Notice) -> Void)?
    var onChange: (() -> Void)?

    static let headsUpMinutes = 10.0
    /// Created only when the calendar is turned on – an event store talks to the privacy daemon right away.
    private lazy var store = EKEventStore()
    private let deadline = Deadline()
    private var snapshot: [Meeting] = []
    private var horizon: Date?
    private var observer: NSObjectProtocol?
    private var notified = Set<String>()
    private var running = false
    private let snapshotProvider: (() -> [Meeting])?

    init(snapshotProvider: (() -> [Meeting])? = nil) { self.snapshotProvider = snapshotProvider }

    /// EventKit needs the usage text from the app bundle; `swift run` has none.
    private var canAsk: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    func start() {
        guard !running else { return }
        if snapshotProvider != nil { running = true; refresh(); return }
        guard Preferences.calendarEnabled, canAsk else { return }
        running = true
        store.requestFullAccessToEvents { [weak self] granted, _ in
            Task { @MainActor in
                guard let self else { return }
                self.accessDenied = !granted
                guard granted, self.running else { return }
                self.refresh()
                self.observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: self.store,
                                                                       queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refresh() }
                }
            }
        }
    }

    func stop() {
        running = false
        deadline.cancel()
        snapshot = []
        horizon = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        next = nil
        onChange?()
    }

    func refresh() {
        let now = Clock.now()
        if let snapshotProvider {
            snapshot = snapshotProvider()
            horizon = now + 12 * 3600
            updateUpcoming(snapshot, now: now)
            scheduleUpdate()
            return
        }
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-60), end: now.addingTimeInterval(12 * 3600),
                                                 calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > now && $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }
        snapshot = events.map(Self.meeting)
        horizon = now + 12 * 3600
        updateUpcoming(snapshot, now: now)
        scheduleUpdate()
    }

    /// Evaluates a fetched snapshot without accessing EventKit or asking for calendar permissions.
    func updateUpcoming(_ meetings: [Meeting], now: Date = Clock.now()) {
        let meeting = meetings.filter { $0.end > now }.min { $0.start < $1.start }
        if meeting != next {
            next = meeting
            onChange?()
        }
        guard let meeting else { return }
        let minutes = meeting.start.timeIntervalSince(now) / 60
        let key = "\(meeting.id)-\(Int(meeting.start.timeIntervalSince1970))"
        if minutes <= Self.headsUpMinutes, minutes > -1, !notified.contains(key) {
            notified.insert(key)
            onNotice?(.meeting(meeting))
        }
    }

    private func scheduleUpdate() {
        guard running else { deadline.cancel(); return }
        let now = Clock.now()
        var dates = [horizon].compactMap { $0 }
        if let next {
            dates.append(next.end)
            let reminder = next.start - Self.headsUpMinutes * 60
            if reminder > now { dates.append(reminder) }
        }
        deadline.schedule(at: dates.min()) { [weak self] in
            guard let self, self.running else { return }
            self.refresh()
        }
    }

    static func meeting(_ event: EKEvent) -> Meeting {
        Meeting(id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title?.isEmpty == false ? event.title : "Meeting",
                start: event.startDate, end: event.endDate,
                color: event.calendar.map { Color(nsColor: $0.color) } ?? Theme.codex,
                location: event.location,
                joinURL: joinURL(in: [event.url?.absoluteString, event.location, event.notes]))
    }

    private static let meetingHosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com",
                                       "webex.com", "whereby.com", "around.co", "meet.jit.si", "facetime.apple.com"]

    /// The first video-call link in the event's URL, location or notes.
    static func joinURL(in texts: [String?]) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for text in texts.compactMap({ $0 }) {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                guard let url = match.url, let host = url.host?.lowercased() else { continue }
                if meetingHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return url }
            }
        }
        return nil
    }
}

/// "● Daily standup · in 25 min   [Join]" in the hover view.
struct CalendarRow: View {
    let meeting: Meeting

    var body: some View {
        PeriodicClock(every: 60) { _ in content }
    }

    private var content: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(meeting.color).frame(width: 4, height: 18)
            Text(meeting.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
            Text(meeting.startsText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(meeting.color)
                .lineLimit(1)
                .fixedSize()
            if let location = meeting.shortLocation {
                Text(location)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if let url = meeting.joinURL {
                NotchButton(title: "Join", style: .quiet) { NSWorkspace.shared.open(url) }
            }
        }
        .padding(.horizontal, 24)
        .frame(height: NotchViewModel.calendarRowHeight)
    }
}
