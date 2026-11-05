import Foundation

/// "Launch at login" via a LaunchAgent – the same file `npx nosynotch autostart` writes, so both stay in sync.
enum LoginItem {
    static let label = "dev.davidkubus.nosynotch"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard let executable = Bundle.main.executablePath else { return }
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": [executable],
                "RunAtLoad": true,
                "ProcessType": "Interactive",
            ]
            try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
        } else if isEnabled {
            // Just remove the file: unloading the agent now would quit this very app.
            try FileManager.default.removeItem(at: plistURL)
        }
    }
}
