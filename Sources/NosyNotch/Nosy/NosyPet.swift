import Foundation

/// The little Tamagotchi part: finished tasks feed Nosy, days with tasks make a streak, XP make it level up.
///
/// Deliberately guilt-free: energy never drops below a floor, Nosy never gets sad or sick, a missed day just
/// starts a new streak (the best one is kept). Everything stays in UserDefaults on this Mac.
@MainActor
final class NosyPet: ObservableObject {
    struct State: Codable, Equatable {
        var energy: Double = 0.7
        var xp: Double = 0
        var streak = 0
        var bestStreak = 0
        var lastActiveDay: String?
        var today: String?
        var tasksToday = 0
        var secondsToday: Double = 0
        var totalTasks = 0
        var lastDecay = Date()
    }

    static let energyFloor = 0.12
    static let decayPerHour = 0.02
    private static let defaultsKey = "nosyPet"

    @Published private(set) var state: State
    private let persist: Bool
    private var timer: Timer?

    init(persist: Bool = true) {
        self.persist = persist
        if persist, let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(State.self, from: data) {
            state = saved
        } else {
            state = State()
        }
        decay()
        guard persist else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.decay() }
        }
    }

    var energy: Double { state.energy }
    var level: Int { Self.level(forXP: state.xp) }

    /// 0…1 on the way to the next level.
    var levelProgress: Double {
        let lo = Self.xpNeeded(for: level), hi = Self.xpNeeded(for: level + 1)
        return min(1, max(0, (state.xp - lo) / (hi - lo)))
    }

    /// Today's numbers – zero once the day changed.
    var tasksToday: Int { state.today == Self.dayString(Clock.now()) ? state.tasksToday : 0 }
    var secondsToday: Double { state.today == Self.dayString(Clock.now()) ? state.secondsToday : 0 }

    /// The streak as it stands today: still alive if the last active day was today or yesterday.
    var streak: Int {
        guard let last = state.lastActiveDay else { return 0 }
        let now = Clock.now()
        return last == Self.dayString(now) || last == Self.dayString(now.addingTimeInterval(-86_400)) ? state.streak : 0
    }

    var isLowOnEnergy: Bool { state.energy < 0.25 }

    /// A task finished: more energy, some XP, today's counters and the streak. Returns the new level on a level-up.
    @discardableResult
    func feed(duration: TimeInterval?) -> Int? {
        decay()
        let before = level
        let seconds = max(0, duration ?? 0)
        let now = Clock.now()
        let day = Self.dayString(now)

        state.energy = min(1, state.energy + 0.06 + min(seconds / 1200, 0.1))
        state.xp += 10 + min(seconds / 30, 30)
        state.totalTasks += 1

        if state.today != day {
            state.today = day
            state.tasksToday = 0
            state.secondsToday = 0
        }
        state.tasksToday += 1
        state.secondsToday += seconds

        if state.lastActiveDay != day {
            let yesterday = Self.dayString(now.addingTimeInterval(-86_400))
            state.streak = state.lastActiveDay == yesterday ? state.streak + 1 : 1
            state.bestStreak = max(state.bestStreak, state.streak)
            state.lastActiveDay = day
        }
        save()
        return level > before ? level : nil
    }

    /// Energy slowly runs down over time – but never below the floor.
    func decay() {
        let now = Clock.now()
        let hours = max(0, now.timeIntervalSince(state.lastDecay) / 3600)
        guard hours > 0.01 else { return }
        state.energy = max(Self.energyFloor, state.energy - hours * Self.decayPerHour)
        state.lastDecay = now
        save()
    }

    func reset() {
        state = State()
        save()
    }

    /// For previews and the demo.
    func set(_ state: State) {
        self.state = state
    }

    private func save() {
        guard persist, let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    // MARK: - Levels

    /// Total XP needed to reach `level` (level 1 needs none).
    nonisolated static func xpNeeded(for level: Int) -> Double {
        level <= 1 ? 0 : 120 * pow(Double(level - 1), 1.7)
    }

    nonisolated static func level(forXP xp: Double) -> Int {
        var level = 1
        while xpNeeded(for: level + 1) <= xp, level < 99 { level += 1 }
        return level
    }

    nonisolated static func dayString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
