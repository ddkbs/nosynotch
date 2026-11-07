import Foundation

/// User settings, stored in UserDefaults. The keys are shared with `@AppStorage` in `SettingsView`.
enum Preferences {
    enum Key {
        static let soundDone = "soundDone"
        static let soundAttention = "soundAttention"
        static let soundError = "soundError"
        static let systemNotifications = "systemNotifications"
        static let notificationSeconds = "notificationSeconds"
        static let mediaEnabled = "mediaEnabled"
        static let mediaShowWhenPaused = "mediaShowWhenPaused"
        static let approvalsInNotch = "approvalsInNotch"
        static let quietWhenFocused = "quietWhenFocused"
        static let usageEnabled = "usageEnabled"
        static let remindAfterFiveMinutes = "remindAfterFiveMinutes"
        static let usageAgents = "usageAgents"
        static let contextEnabled = "contextEnabled"
        static let headGestures = "headGestures"
        static let notifyLimitReset = "notifyLimitReset"
        static let cursorApprovals = "cursorApprovals"
        static let mutedUntil = "mutedUntil"
        static let liveEqualizer = "liveEqualizer"
        static let port = "port"
        static let nosyEnabled = "nosyEnabled"
        static let nosyPet = "nosyPet.enabled"
        static let nosyAccessory = "nosyAccessory"
        static let shelfEnabled = "shelfEnabled"
        static let nosyColor = "nosyColor"
        static let batteryEnabled = "batteryEnabled"
        static let bluetoothEnabled = "bluetoothEnabled"
    }

    private static let defaults = UserDefaults.standard

    static func register() {
        // Earlier versions had a single sound switch.
        if defaults.object(forKey: "soundEnabled") as? Bool == false, defaults.object(forKey: Key.soundDone) == nil {
            for key in [Key.soundDone, Key.soundAttention, Key.soundError] { defaults.set(false, forKey: key) }
        }
        defaults.register(defaults: [
            Key.soundDone: true,
            Key.soundAttention: true,
            Key.soundError: true,
            Key.systemNotifications: false,
            Key.notificationSeconds: 6.0,
            Key.mediaEnabled: true,
            Key.mediaShowWhenPaused: false,
            Key.approvalsInNotch: true,
            Key.quietWhenFocused: true,
            Key.usageEnabled: true,
            Key.remindAfterFiveMinutes: true,
            Key.usageAgents: "all",
            Key.contextEnabled: true,
            Key.headGestures: false,
            Key.notifyLimitReset: true,
            Key.cursorApprovals: true,
            Key.liveEqualizer: false,
            Key.port: Int(EventServer.defaultPort),
            Key.nosyEnabled: true,
            Key.nosyPet: true,
            Key.nosyAccessory: NosyAccessory.none.rawValue,
            Key.shelfEnabled: true,
            Key.nosyColor: NosyColor.obsidian.rawValue,
            Key.batteryEnabled: true,
            Key.bluetoothEnabled: false,
        ])
    }

    static var soundDone: Bool { defaults.object(forKey: Key.soundDone) as? Bool ?? true }
    static var soundAttention: Bool { defaults.object(forKey: Key.soundAttention) as? Bool ?? true }
    static var soundError: Bool { defaults.object(forKey: Key.soundError) as? Bool ?? true }

    static var systemNotifications: Bool {
        get { defaults.bool(forKey: Key.systemNotifications) }
        set { defaults.set(newValue, forKey: Key.systemNotifications) }
    }

    /// How long "done", "needs you" and "error" stay open before the notch closes again.
    static var notificationSeconds: TimeInterval {
        let value = defaults.object(forKey: Key.notificationSeconds) as? Double ?? 6
        return min(max(value, 2), 30)
    }

    /// Show Spotify / Apple Music in the notch while Claude is idle.
    static var mediaEnabled: Bool {
        get { defaults.object(forKey: Key.mediaEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.mediaEnabled) }
    }

    /// Keep the cover in the notch while the music is paused.
    static var mediaShowWhenPaused: Bool { defaults.bool(forKey: Key.mediaShowWhenPaused) }

    /// Show Allow / Deny buttons in the notch for permission requests.
    static var approvalsInNotch: Bool { defaults.object(forKey: Key.approvalsInNotch) as? Bool ?? true }

    /// "Done" while you're already looking at that app: small check in the notch, no sound, no banner.
    static var quietWhenFocused: Bool { defaults.object(forKey: Key.quietWhenFocused) as? Bool ?? true }

    /// Remind again when a "done" stayed unseen or a question unanswered for 5 minutes.
    static var remindAfterFiveMinutes: Bool { defaults.object(forKey: Key.remindAfterFiveMinutes) as? Bool ?? true }

    /// Sounds and macOS banners are off until this date (`.distantFuture` = until you unmute).
    static var mutedUntil: Date? {
        get {
            guard let date = defaults.object(forKey: Key.mutedUntil) as? Date, date > Date() else { return nil }
            return date
        }
        set { defaults.set(newValue, forKey: Key.mutedUntil) }
    }

    static var isMuted: Bool { mutedUntil != nil }

    /// Which agents' limits to show: "all", "claude" or "codex".
    static var usageAgents: String { defaults.string(forKey: Key.usageAgents) ?? "all" }

    static func showsUsage(for agent: Agent) -> Bool {
        let choice = usageAgents
        return choice == "all" || choice == agent.rawValue
    }

    /// Nod (AirPods) to allow, shake to deny. Off unless you turn it on.
    static var headGestures: Bool { defaults.bool(forKey: Key.headGestures) }

    /// Tell me when a usage limit resets – only if it was at least `limitResetThreshold` % used.
    static var notifyLimitReset: Bool { defaults.object(forKey: Key.notifyLimitReset) as? Bool ?? true }
    static let limitResetThreshold: Double = 80

    /// Cursor shell / MCP commands outside its sandbox wait for Allow / Deny in the notch.
    static var cursorApprovals: Bool { defaults.object(forKey: Key.cursorApprovals) as? Bool ?? true }

    /// Context-window fill ring per session in the hover list.
    static var contextEnabled: Bool { defaults.object(forKey: Key.contextEnabled) as? Bool ?? true }

    /// Usage-limit bars in the hover view.
    static var usageEnabled: Bool { defaults.object(forKey: Key.usageEnabled) as? Bool ?? true }

    /// Bigger equalizer that follows the actual music (needs the "audio recording" permission).
    static var liveEqualizer: Bool { defaults.bool(forKey: Key.liveEqualizer) }

    /// Nosy lives in the notch (eyes in the wing, hanging below the open notch). Off = the classic glyphs.
    static var nosyEnabled: Bool { defaults.object(forKey: Key.nosyEnabled) as? Bool ?? true }

    /// Energy, level and streak.
    static var nosyPet: Bool { defaults.object(forKey: Key.nosyPet) as? Bool ?? true }

    static var nosyAccessory: NosyAccessory {
        NosyAccessory(rawValue: defaults.string(forKey: Key.nosyAccessory) ?? "") ?? .none
    }

    static var nosyColor: NosyColor {
        NosyColor(rawValue: defaults.string(forKey: Key.nosyColor) ?? "") ?? .obsidian
    }

    /// Charging animation when plugged in, heads-up at 20 %.
    static var batteryEnabled: Bool { defaults.object(forKey: Key.batteryEnabled) as? Bool ?? true }

    /// Headphones connecting via Bluetooth (needs the Bluetooth permission, so off until you turn it on).
    static var bluetoothEnabled: Bool { defaults.bool(forKey: Key.bluetoothEnabled) }

    /// Drag files onto the notch: Shelf and AirDrop.
    static var shelfEnabled: Bool { defaults.object(forKey: Key.shelfEnabled) as? Bool ?? true }

    static var port: UInt16 {
        UInt16(clamping: defaults.integer(forKey: Key.port))
    }
}
