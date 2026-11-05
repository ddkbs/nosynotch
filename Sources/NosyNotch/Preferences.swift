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
        static let port = "port"
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
            Key.port: Int(EventServer.defaultPort),
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

    static var port: UInt16 {
        UInt16(clamping: defaults.integer(forKey: Key.port))
    }
}
