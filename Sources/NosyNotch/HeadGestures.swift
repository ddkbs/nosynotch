import CoreMotion
import Foundation

/// Nod to allow, shake your head to deny – with AirPods (or other headphones with head tracking).
///
/// Off by default (Settings → Permissions). Motion updates only run while a permission request is shown in the
/// notch, so there is no tracking the rest of the time. The first start asks for "Motion & Fitness" access
/// (`NSMotionUsageDescription`).
@MainActor
final class HeadGestures: ObservableObject {
    enum Gesture { case nod, shake }

    /// Headphones with head tracking are connected and sending data.
    @Published private(set) var isTracking = false

    var onGesture: ((Gesture) -> Void)?

    private let manager = CMHeadphoneMotionManager()
    private var running = false
    private var startedAt = Date()

    // Recent samples (time, pitch, yaw) relative to where the head was when tracking started.
    private var samples: [(t: TimeInterval, pitch: Double, yaw: Double)] = []
    private var baseline: (pitch: Double, yaw: Double)?
    private var lastGesture = Date.distantPast

    static var isSupported: Bool { CMHeadphoneMotionManager.authorizationStatus() != .denied }

    func setActive(_ active: Bool) {
        active ? start() : stop()
    }

    private func start() {
        guard !running, manager.isDeviceMotionAvailable else { return }
        running = true
        startedAt = Date()
        samples.removeAll()
        baseline = nil
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            MainActor.assumeIsolated {
                guard let self, let motion else { return }
                self.isTracking = true
                self.process(pitch: motion.attitude.pitch, yaw: motion.attitude.yaw)
            }
        }
    }

    private func stop() {
        guard running else { return }
        running = false
        isTracking = false
        manager.stopDeviceMotionUpdates()
    }

    private func process(pitch: Double, yaw: Double) {
        let now = Date().timeIntervalSinceReferenceDate
        if baseline == nil { baseline = (pitch, yaw) }
        guard let base = baseline else { return }
        samples.append((now, pitch - base.pitch, Self.wrap(yaw - base.yaw)))
        samples.removeAll { now - $0.t > 1.2 }

        // Give the user a moment to read the request before a gesture counts.
        guard Date().timeIntervalSince(startedAt) > 0.6, Date().timeIntervalSince(lastGesture) > 1.5 else { return }

        if isNod() {
            fire(.nod)
        } else if isShake() {
            fire(.shake)
        }
    }

    /// Head goes clearly down and comes back up within ~1 s, without much turning.
    private func isNod() -> Bool {
        guard let low = samples.min(by: { $0.pitch < $1.pitch }), low.pitch < -0.22,
              let last = samples.last, last.t > low.t, last.pitch > low.pitch + 0.16 else { return false }
        let maxYaw = samples.map { abs($0.yaw) }.max() ?? 0
        return maxYaw < 0.25
    }

    /// Head turns left and right (or right and left) at least once each, clearly.
    private func isShake() -> Bool {
        var swings = 0
        var lastSide = 0
        for s in samples {
            let side = s.yaw > 0.2 ? 1 : (s.yaw < -0.2 ? -1 : 0)
            if side != 0 && side != lastSide {
                if lastSide != 0 { swings += 1 }
                lastSide = side
            }
        }
        return swings >= 2
    }

    private func fire(_ gesture: Gesture) {
        lastGesture = Date()
        samples.removeAll()
        onGesture?(gesture)
    }

    private static func wrap(_ angle: Double) -> Double {
        var a = angle
        while a > .pi { a -= 2 * .pi }
        while a < -.pi { a += 2 * .pi }
        return a
    }
}
