import Foundation

enum Preferences {
    private static let defaults = UserDefaults.standard

    static func register() {
        defaults.register(defaults: [
            "soundEnabled": true,
            "systemNotifications": false,
            "port": Int(EventServer.defaultPort),
        ])
    }

    static var soundEnabled: Bool {
        get { defaults.bool(forKey: "soundEnabled") }
        set { defaults.set(newValue, forKey: "soundEnabled") }
    }

    static var systemNotifications: Bool {
        get { defaults.bool(forKey: "systemNotifications") }
        set { defaults.set(newValue, forKey: "systemNotifications") }
    }

    /// Show Spotify / Apple Music in the notch while Claude is idle.
    static var mediaEnabled: Bool {
        get { defaults.object(forKey: "mediaEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "mediaEnabled") }
    }

    static var port: UInt16 {
        UInt16(clamping: defaults.integer(forKey: "port"))
    }
}
