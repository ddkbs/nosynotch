import Foundation
import Testing
import SwiftUI
@testable import NosyNotch

/// Characterization of time-based rules before replacing polling.
/// Maintenance passes are invoked explicitly: these tests don't assert a timer implementation.
@Suite(.serialized)
@MainActor
struct BehaviorTests {
    private func withClock(_ body: (Date) throws -> Void) rethrows {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        Clock.startVirtual(at: date)
        defer { Clock.stopVirtual() }
        try body(date)
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let suite = "NosyNotchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    private func event(_ name: String, id: String = "test") -> HookEvent {
        HookEvent(name: name, sessionID: id, agent: .codex)
    }

    @Test
    func testVirtualClockRunsDueWorkInOrderAndHonorsCancellation() async {
        withClock { start in
            var fired: [String] = []
            let cancelled = DispatchWorkItem { fired.append("cancelled") }
            Clock.after(2, execute: cancelled)
            Clock.after(3) {
                fired.append("third")
                Clock.after(1) { fired.append("nested") }
            }
            Clock.after(1) { fired.append("first") }
            cancelled.cancel()
            Clock.advance(to: start + 0.9)
            #expect(fired.isEmpty)
            Clock.advance(to: start + 4)
            #expect(fired == ["first", "third", "nested"])
            #expect(Clock.now() == start + 4)
        }
    }

    @Test
    func testFinishedReminderIsNotEarlyAndOnlyFiresOnce() async {
        withClock { start in
            let store = SessionStore(startTimers: false, remindersEnabled: { true })
            var reminders = 0
            store.onReminder = { _ in reminders += 1 }
            store.handle(event("UserPromptSubmit"))
            store.handle(event("Stop"))
            Clock.advance(to: start + 299)
            store.performMaintenance()
            #expect(reminders == 0)
            Clock.advance(to: start + 300)
            store.performMaintenance()
            store.performMaintenance()
            #expect(reminders == 1)
        }
    }

    @Test
    func testSeenDismissedAndEndedSessionsHaveNoReminder() async {
        withClock { start in
            let store = SessionStore(startTimers: false, remindersEnabled: { true })
            var reminders = 0
            store.onReminder = { _ in reminders += 1 }
            for id in ["seen", "dismissed", "ended"] { store.handle(event("Stop", id: id)) }
            store.markSeen("seen")
            store.dismiss("dismissed")
            store.handle(event("SessionEnd", id: "ended"))
            Clock.advance(to: start + 301)
            store.performMaintenance()
            #expect(reminders == 0)
            #expect(store.sessions.count == 1)
        }
    }

    @Test
    func testWaitingReminderResetsAfterWorkResumes() async {
        withClock { start in
            let store = SessionStore(startTimers: false, remindersEnabled: { true })
            var reminders = 0
            store.onReminder = { _ in reminders += 1 }
            store.handle(event("PermissionRequest"))
            Clock.advance(to: start + 200)
            store.handle(event("UserPromptSubmit"))
            store.handle(event("PermissionRequest"))
            Clock.advance(to: start + 300)
            store.performMaintenance()
            #expect(reminders == 0)
            Clock.advance(to: start + 500)
            store.performMaintenance()
            store.performMaintenance()
            #expect(reminders == 1)
        }
    }

    @Test
    func testReminderPreferenceCanBeDisabledAndEnabled() async {
        withClock { start in
            var enabled = false
            let store = SessionStore(startTimers: false, remindersEnabled: { enabled })
            var reminders = 0
            store.onReminder = { _ in reminders += 1 }
            store.handle(event("Stop"))
            Clock.advance(to: start + 301)
            store.performMaintenance()
            #expect(reminders == 0)
            enabled = true
            store.performMaintenance()
            #expect(reminders == 1)
        }
    }

    @Test
    func testInterruptedWorkTimeoutsAndActivityRefresh() async {
        withClock { start in
            let store = SessionStore(startTimers: false)
            store.handle(event("UserPromptSubmit", id: "thinking"))
            store.handle(event("PreCompact", id: "compacting"))
            store.handle(event("PreToolUse", id: "tool"))
            Clock.advance(to: start + 600)
            store.performMaintenance()
            #expect(store.sessions["thinking"]?.state == .thinking)
            store.handle(event("UserPromptSubmit", id: "fresh"))
            Clock.advance(to: start + 601)
            store.performMaintenance()
            #expect(store.sessions["thinking"]?.state == .idle)
            #expect(store.sessions["compacting"]?.state == .idle)
            #expect(store.sessions["tool"]!.state.isActive)
            #expect(store.sessions["fresh"]?.state == .thinking)
            Clock.advance(to: start + 1801)
            store.performMaintenance()
            #expect(store.sessions["tool"]?.state == .idle)
            #expect(store.sessions["tool"]?.turnStartedAt == nil)
        }
    }

    @Test
    func testSeenAndUnseenSessionsExpireAtDifferentAges() async {
        withClock { start in
            let store = SessionStore(startTimers: false)
            store.handle(event("Stop", id: "seen"))
            store.handle(event("Stop", id: "unseen"))
            store.markSeen("seen")
            Clock.advance(to: start + 3601)
            store.performMaintenance()
            #expect(store.sessions["seen"] == nil)
            #expect(store.sessions["unseen"] != nil)
            Clock.advance(to: start + 12 * 3600 + 1)
            store.performMaintenance()
            #expect(store.sessions.isEmpty)
        }
    }

    @Test
    func testLimitResetThresholdBoundaryAndNoDuplicateAcrossReload() async {
        withClock { start in
            withDefaults { defaults in
                let store = UsageStore(load: false, defaults: defaults, resetNotificationsEnabled: { true })
                var resets: [String] = []
                store.onReset = { _, label in resets.append(label) }
                store.set(AgentUsage(fiveHour: UsageWindow(usedPercent: 80, resetsAt: start + 60),
                                     week: UsageWindow(usedPercent: 79.9, resetsAt: start + 60)), for: .claude)
                Clock.advance(to: start + 59)
                store.checkResets()
                #expect(resets.isEmpty)
                Clock.advance(to: start + 60)
                store.checkResets()
                store.checkResets()
                #expect(resets == ["5-hour"])
                let reloaded = UsageStore(defaults: defaults, startTimers: false, resetNotificationsEnabled: { true })
                reloaded.onReset = { _, label in resets.append(label) }
                reloaded.checkResets()
                #expect(resets.count == 1)
                #expect(reloaded.claude?.fiveHour?.usedPercent == 80)
            }
        }
    }

    @Test
    func testLateResetsAndPreferenceChange() async {
        withClock { start in
            withDefaults { defaults in
                var enabled = false
                let store = UsageStore(load: false, defaults: defaults, resetNotificationsEnabled: { enabled })
                var resets = 0
                store.onReset = { _, _ in resets += 1 }
                store.set(AgentUsage(fiveHour: UsageWindow(usedPercent: 95, resetsAt: start - 60),
                                     week: UsageWindow(usedPercent: 100, resetsAt: start - 12 * 3600)), for: .codex)
                store.checkResets()
                #expect(resets == 0)
                enabled = true
                store.checkResets()
                #expect(resets == 1)
            }
        }
    }

    @Test
    func testFreshUsageDoesNotLosePendingReset() async {
        withClock { start in
            withDefaults { defaults in
                let store = UsageStore(load: false, defaults: defaults, resetNotificationsEnabled: { true })
                var resets = 0
                store.onReset = { _, _ in resets += 1 }
                store.set(AgentUsage(fiveHour: UsageWindow(usedPercent: 90, resetsAt: start + 10)), for: .claude)
                Clock.advance(to: start + 11)
                store.set(AgentUsage(fiveHour: UsageWindow(usedPercent: 2, resetsAt: start + 3600)), for: .claude)
                #expect(resets == 1)
                #expect(store.claude?.fiveHour?.usedPercent == 2)
            }
        }
    }

    @Test
    func testFocusCompletesOnceAtDeadlineEvenAfterLongGap() async {
        withClock { start in
            let timer = FocusTimer(startTimers: false)
            var completions = 0
            timer.onFinished = { phase, minutes in
                #expect(phase == .focus)
                #expect(minutes == 1)
                completions += 1
            }
            timer.start(.focus, minutes: 1)
            Clock.advance(to: start + 59)
            timer.tick()
            #expect(timer.remainingText == "0:01")
            #expect(completions == 0)
            Clock.advance(to: start + 600)
            timer.tick()
            timer.tick()
            #expect(completions == 1)
            #expect(!(timer.isRunning))
        }
    }

    @Test
    func testStoppingAndRestartingFocusCancelsOldCompletion() async {
        withClock { start in
            let timer = FocusTimer(startTimers: false)
            var completions = 0
            timer.onFinished = { _, _ in completions += 1 }
            timer.start(.focus, minutes: 1)
            timer.stop()
            Clock.advance(to: start + 61)
            timer.tick()
            #expect(completions == 0)
            timer.start(.rest, minutes: 2)
            Clock.advance(to: start + 121)
            timer.tick()
            #expect(timer.isRunning)
            Clock.advance(to: start + 181)
            timer.tick()
            #expect(completions == 1)
            #expect(!(timer.isRunning))
        }
    }

    @Test
    func testEnergyDecayFloorBackwardTimeAndFeeding() async {
        withClock { start in
            let pet = NosyPet(persist: false)
            var state = NosyPet.State()
            state.energy = 0.7
            state.lastDecay = start
            pet.set(state)
            Clock.advance(to: start + 3600)
            pet.decay()
            #expect(abs(pet.energy - 0.68) <= 0.000001)
            Clock.advance(to: start)
            pet.decay()
            #expect(abs(pet.energy - 0.68) <= 0.000001)
            Clock.advance(to: start + 100 * 3600)
            pet.decay()
            #expect(pet.energy == NosyPet.energyFloor)
            pet.feed(duration: 0)
            #expect(abs(pet.energy - (NosyPet.energyFloor + 0.06)) <= 0.000001)
            #expect(pet.state.totalTasks == 1)
        }
    }

    @Test
    func testEnergyPersistsAndAccountsForOfflineTime() async {
        withClock { start in
            withDefaults { defaults in
                let pet = NosyPet(defaults: defaults, startTimers: false)
                var state = NosyPet.State()
                state.lastDecay = start
                state.energy = 0.8
                pet.set(state)
                pet.feed(duration: 0)
                Clock.advance(to: start + 2 * 3600)
                let reloaded = NosyPet(defaults: defaults, startTimers: false)
                #expect(abs(reloaded.energy - 0.82) <= 0.000001)
                #expect(reloaded.state.totalTasks == 1)
            }
        }
    }

    @Test
    func testDailyCountersAndStreakAcrossDays() async {
        withClock { start in
            let pet = NosyPet(persist: false)
            pet.feed(duration: 30)
            pet.feed(duration: 30)
            #expect(pet.tasksToday == 2)
            #expect(pet.streak == 1)
            Clock.advance(to: start + 86400)
            #expect(pet.tasksToday == 0)
            pet.feed(duration: 60)
            #expect(pet.streak == 2)
            Clock.advance(to: start + 3 * 86400)
            #expect(pet.streak == 0)
            pet.feed(duration: 0)
            #expect(pet.streak == 1)
            #expect(pet.state.bestStreak == 2)
        }
    }

    private func meeting(_ id: String, start: Date, duration: TimeInterval = 1800) -> Meeting {
        Meeting(id: id, title: id, start: start, end: start + duration,
                color: .blue, location: nil, joinURL: nil)
    }

    @Test
    func testCalendarSelectsNextAndNotifiesAtTenMinutesOnce() async {
        withClock { start in
            let calendar = CalendarMonitor()
            let first = meeting("first", start: start + 900)
            let second = meeting("second", start: start + 3000)
            var notices = 0
            calendar.onNotice = { _ in notices += 1 }
            calendar.updateUpcoming([second, first])
            #expect(calendar.next?.id == "first")
            #expect(notices == 0)
            Clock.advance(to: start + 300)
            calendar.updateUpcoming([first, second])
            calendar.updateUpcoming([first, second])
            #expect(notices == 1)
            Clock.advance(to: first.end)
            calendar.updateUpcoming([first, second])
            #expect(calendar.next?.id == "second")
        }
    }

    @Test
    func testCalendarDeletionRescheduleAndExpiredNoticeWindow() async {
        withClock { start in
            let calendar = CalendarMonitor()
            var notices = 0
            calendar.onNotice = { _ in notices += 1 }
            calendar.updateUpcoming([meeting("same", start: start + 500)])
            #expect(notices == 1)
            calendar.updateUpcoming([])
            #expect(calendar.next == nil)
            calendar.updateUpcoming([meeting("same", start: start + 600)])
            #expect(notices == 2)
            calendar.updateUpcoming([meeting("late", start: start - 60)])
            #expect(notices == 2)
        }
    }

    @Test
    func testCalendarDoesNotInvalidateUnchangedSnapshot() async {
        withClock { start in
            let calendar = CalendarMonitor()
            var changes = 0
            calendar.onChange = { changes += 1 }
            let snapshot = [meeting("future", start: start + 3600)]
            calendar.updateUpcoming(snapshot)
            calendar.updateUpcoming(snapshot)
            #expect(changes == 1)
            calendar.updateUpcoming([])
            #expect(changes == 2)
        }
    }

    @Test
    func testSleepDayNightAndActivityKeepsNosyAwake() async {
        withClock { start in
            let store = SessionStore(startTimers: false)
            let model = NotchViewModel(store: store, media: NowPlaying(observeSystem: false),
                                       pet: NosyPet(persist: false), startTimers: false)
            Clock.advance(to: start + NotchViewModel.sleepAfter)
            model.updateSleep()
            #expect(!(model.isAsleep))
            Clock.advance(to: start + NotchViewModel.sleepAfter + 1)
            model.updateSleep()
            #expect(model.isAsleep)
            store.handle(event("UserPromptSubmit"))
            model.updateSleep()
            #expect(!(model.isAsleep))
            store.handle(event("Interrupt"))
            model.updateSleep()
            let night = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: start)!
            Clock.advance(to: night)
            store.handle(event("UserPromptSubmit"))
            model.updateSleep()
            store.handle(event("Interrupt"))
            model.updateSleep()
            Clock.advance(to: night + NotchViewModel.sleepAfterAtNight)
            model.updateSleep()
            #expect(!(model.isAsleep))
            Clock.advance(to: night + NotchViewModel.sleepAfterAtNight + 1)
            model.updateSleep()
            #expect(model.isAsleep)
        }
    }
    @Test
    func testPointerEntryExitAndHoverPresentation() async {
        withClock { _ in
            let model = NotchViewModel(store: SessionStore(startTimers: false),
                                       media: NowPlaying(observeSystem: false),
                                       pet: NosyPet(persist: false), startTimers: false)
            let center = CGPoint(x: 500, y: 800)
            model.updateGaze(mouse: CGPoint(x: 0, y: 0), notchCenter: center)
            model.recompute()
            #expect(model.presentation == .hidden)
            model.updateGaze(mouse: center, notchCenter: center)
            #expect(model.presentation == .peek)
            model.isHovering = true
            #expect(model.presentation == .expanded)
            model.isHovering = false
            model.updateGaze(mouse: CGPoint(x: 0, y: 0), notchCenter: center)
            #expect(model.presentation == .hidden)
        }
    }

    @Test
    func testPointerExitMarginPreventsFlicker() async {
        withClock { _ in
            let model = NotchViewModel(store: SessionStore(startTimers: false),
                                       media: NowPlaying(observeSystem: false),
                                       pet: NosyPet(persist: false), startTimers: false)
            model.notchSize = CGSize(width: 100, height: 30)
            let center = CGPoint(x: 500, y: 800)
            let outsideEdge = CGPoint(x: 551, y: 800)
            model.updateGaze(mouse: outsideEdge, notchCenter: center)
            model.recompute()
            #expect(model.presentation == .hidden)
            model.updateGaze(mouse: center, notchCenter: center)
            model.updateGaze(mouse: outsideEdge, notchCenter: center)
            #expect(model.presentation == .peek)
            model.updateGaze(mouse: CGPoint(x: 557, y: 800), notchCenter: center)
            #expect(model.presentation == .hidden)
        }
    }

    @Test
    func testAutomaticSessionReminderCancellationAndExpiry() async {
        withClock { start in
            let store = SessionStore(remindersEnabled: { true })
            var reminders = 0
            store.onReminder = { _ in reminders += 1 }
            store.handle(event("Stop"))
            Clock.advance(to: start + 299)
            #expect(reminders == 0)
            Clock.advance(to: start + 300)
            #expect(reminders == 1)
            store.dismiss("test")
            store.handle(event("Stop", id: "cancel"))
            store.markSeen("cancel")
            Clock.advance(to: start + 601)
            #expect(reminders == 1)
            Clock.advance(to: start + 3901)
            #expect(store.sessions.isEmpty)
        }
    }

    @Test
    func testAutomaticLimitResetAndPreferenceCancellation() async {
        withClock { start in
            withDefaults { defaults in
                var enabled = true
                let store = UsageStore(defaults: defaults, resetNotificationsEnabled: { enabled })
                var resets = 0
                store.onReset = { _, _ in resets += 1 }
                store.set(AgentUsage(fiveHour: UsageWindow(usedPercent: 90, resetsAt: start + 10)), for: .codex)
                Clock.advance(to: start + 10)
                #expect(resets == 1)
                store.set(AgentUsage(fiveHour: UsageWindow(usedPercent: 90, resetsAt: start + 20)), for: .codex)
                enabled = false
                store.checkResets()
                Clock.advance(to: start + 20)
                #expect(resets == 1)
                enabled = true
                store.checkResets()
                #expect(resets == 2)
            }
        }
    }

    @Test
    func testAutomaticFocusAndCancelledDeadline() async {
        withClock { start in
            let timer = FocusTimer()
            var completions = 0
            timer.onFinished = { _, _ in completions += 1 }
            timer.start(.focus, minutes: 1)
            Clock.advance(to: start + 60)
            #expect(completions == 1)
            timer.start(.rest, minutes: 1)
            timer.stop()
            Clock.advance(to: start + 180)
            #expect(completions == 1)
        }
    }

    @Test
    func testAutomaticCalendarBoundariesAndStop() async {
        withClock { start in
            let first = meeting("first", start: start + 900)
            let second = meeting("second", start: start + 3000)
            let calendar = CalendarMonitor(snapshotProvider: { [first, second] })
            var notices = 0
            calendar.onNotice = { _ in notices += 1 }
            calendar.start()
            Clock.advance(to: start + 300)
            #expect(notices == 1)
            Clock.advance(to: first.end)
            #expect(calendar.next?.id == "second")
            calendar.stop()
            Clock.advance(to: start + 10000)
            #expect(calendar.next == nil)
            #expect(notices == 2)
        }
    }

    @Test
    func testAutomaticSleepAndWakeOnHover() async {
        withClock { start in
            let model = NotchViewModel(store: SessionStore(startTimers: false),
                                      media: NowPlaying(observeSystem: false), pet: NosyPet(persist: false))
            Clock.advance(to: start + NotchViewModel.sleepAfter + 1)
            #expect(model.isAsleep)
            model.isHovering = true
            #expect(!model.isAsleep)
            model.isHovering = false
            Clock.advance(to: Clock.now() + NotchViewModel.sleepAfter + 1)
            #expect(model.isAsleep)
        }
    }

    @Test
    func testDeadlineReplacementCancellationAndTimeChange() async {
        withClock { start in
            let deadline = Deadline()
            var fired = 0
            deadline.schedule(at: start + 1) { fired += 100 }
            deadline.schedule(at: start + 2) { fired += 1 }
            Clock.advance(to: start + 1)
            #expect(fired == 0)
            NotificationCenter.default.post(name: .NSSystemTimeZoneDidChange, object: nil)
            #expect(fired == 1)
            Clock.advance(to: start + 3)
            #expect(fired == 1)
            deadline.schedule(at: start + 5) { fired += 1 }
            deadline.cancel()
            Clock.advance(to: start + 10)
            #expect(fired == 1)
        }
    }

}
