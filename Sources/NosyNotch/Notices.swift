import AppKit
import SwiftUI
import IOBluetooth
import IOKit.ps

/// Small system moments the notch shows for a few seconds: power, headphones, the focus timer, meetings.
enum Notice: Equatable {
    case charging(percent: Int)
    case lowBattery(percent: Int)
    case device(name: String, symbol: String, batteries: [Battery])
    case timerDone(wasFocus: Bool, minutes: Int)
    case meeting(Meeting)

    struct Battery: Equatable {
        let label: String
        let percent: Int
    }

    var seconds: TimeInterval {
        switch self {
        case .charging, .device: return 3.5
        case .lowBattery, .timerDone: return 6
        case .meeting: return 12
        }
    }
}

// MARK: - Power

/// Watches the battery: plugging in shows a charging animation, 20 % unplugged shows a heads-up (once per discharge).
@MainActor
final class PowerMonitor {
    struct State: Equatable {
        var percent: Int
        var charging: Bool
        var pluggedIn: Bool
    }

    var onNotice: ((Notice) -> Void)?
    private(set) var state: State?
    private var source: CFRunLoopSource?
    private var warnedLow = false
    static let lowThreshold = 20

    func start() {
        guard source == nil else { return }
        state = Self.read()
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.update() }
        }, context)?.takeRetainedValue() else { return }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func update() {
        guard let next = Self.read() else { return }
        let previous = state
        state = next
        guard Preferences.batteryEnabled, let previous else { return }
        if next.pluggedIn && !previous.pluggedIn {
            warnedLow = false
            onNotice?(.charging(percent: next.percent))
        }
        if !next.pluggedIn && next.percent <= Self.lowThreshold && !warnedLow {
            warnedLow = true
            onNotice?(.lowBattery(percent: next.percent))
        }
    }

    /// The internal battery, nil on Macs without one.
    nonisolated static func read() -> State? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                  desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = desc[kIOPSCurrentCapacityKey] as? Int,
                  let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            return State(percent: Int((Double(current) / Double(max) * 100).rounded()),
                         charging: desc[kIOPSIsChargingKey] as? Bool ?? false,
                         pluggedIn: desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue)
        }
        return nil
    }
}

// MARK: - Bluetooth headphones

/// Headphones connecting via Bluetooth: name, matching symbol and battery levels (AirPods report left / right / case).
@MainActor
final class HeadphoneMonitor: NSObject {
    var onNotice: ((Notice) -> Void)?
    private var notification: IOBluetoothUserNotification?
    private var startedAt = Date()

    func start() {
        guard notification == nil, Preferences.bluetoothEnabled else { return }
        startedAt = Date()
        notification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
    }

    func stop() {
        notification?.unregister()
        notification = nil
    }

    @objc private func connected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // Registering reports every device that's already connected – that's not news.
        guard Date().timeIntervalSince(startedAt) > 3, Preferences.bluetoothEnabled else { return }
        guard device.deviceClassMajor == UInt32(kBluetoothDeviceClassMajorAudio) else { return }
        let name = device.name ?? "Headphones"
        // The battery levels arrive a moment after the connection.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            MainActor.assumeIsolated {
                self?.onNotice?(.device(name: name, symbol: Self.symbol(for: name), batteries: Self.batteries(of: device)))
            }
        }
    }

    static func symbol(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("airpods max") { return "airpodsmax" }
        if n.contains("airpods pro") { return "airpodspro" }
        if n.contains("airpods") { return "airpods" }
        if n.contains("beats") { return "beats.headphones" }
        return "headphones"
    }

    /// IOBluetooth knows AirPods' battery levels but doesn't document them – ask carefully.
    static func batteries(of device: IOBluetoothDevice) -> [Notice.Battery] {
        let keys = [("L", "batteryPercentLeft"), ("R", "batteryPercentRight"), ("Case", "batteryPercentCase"),
                    ("", "batteryPercentSingle")]
        return keys.compactMap { label, key in
            guard device.responds(to: NSSelectorFromString(key)),
                  let value = (device.value(forKey: key) as? NSNumber)?.intValue, value > 0, value <= 100 else { return nil }
            return Notice.Battery(label: label, percent: value)
        }
    }
}

// MARK: - Meetings

/// A calendar event the notch tells you about.
struct Meeting: Equatable, Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let color: Color
    let location: String?
    /// Zoom / Meet / Teams / Webex link found in the event.
    let joinURL: URL?

    /// "in 10 min" / "now" / "at 14:30".
    var startsText: String {
        let minutes = Int((start.timeIntervalSince(Clock.now()) / 60).rounded())
        if minutes <= 0 { return Clock.now() < end ? "now" : "ended" }
        if minutes < 60 { return "in \(minutes) min" }
        return "at \(start.formatted(date: .omitted, time: .shortened))"
    }

    var shortLocation: String? {
        guard let location, !location.isEmpty, !location.hasPrefix("http") else { return nil }
        return location.count > 28 ? String(location.prefix(27)) + "…" : location
    }
}
