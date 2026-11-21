import AppKit

/// A replaceable wall-clock deadline. No repeating timer is created.
@MainActor
final class Deadline {
    private var work: DispatchWorkItem?
    private var timer: Timer?
    private var generation = 0
    private var date: Date?
    private var action: (() -> Void)?
    private var observers: [NSObjectProtocol] = []

    init() {
        for name in [Notification.Name("NSSystemClockDidChangeNotification"), .NSSystemTimeZoneDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.rearm() }
            })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
                                                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rearm() }
        })
    }

    deinit {
        timer?.invalidate()
        work?.cancel()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func cancel() {
        generation += 1
        timer?.invalidate()
        timer = nil
        work?.cancel()
        work = nil
        date = nil
        action = nil
    }

    func schedule(at date: Date?, _ action: @escaping () -> Void) {
        cancel()
        guard let date else { return }
        self.date = date
        self.action = action
        arm()
    }

    /// Reevaluate time-dependent rules after waking or a wall-clock/time-zone change.
    private func rearm() {
        guard let action else { return }
        cancel()
        action()
    }

    private func arm() {
        guard let date else { return }
        let generation = self.generation
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == generation, let action = self.action else { return }
                if Clock.now() < date { self.arm(); return }
                self.cancel()
                action()
            }
        }
        work = item
        if Clock.isVirtual {
            Clock.after(max(0, date.timeIntervalSince(Clock.now())), execute: item)
        } else {
            let timer = Timer(fire: max(Date(), date), interval: 0, repeats: false) { _ in item.perform() }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }
}
