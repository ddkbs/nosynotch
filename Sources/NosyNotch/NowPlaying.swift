import AppKit
import CoreImage
import CoreServices
import OSLog
import SwiftUI

/// What is playing in Spotify or Apple Music right now.
///
/// Track changes arrive as distributed notifications that both apps broadcast on their own
/// (`com.spotify.client.PlaybackStateChanged`, `com.apple.Music.playerInfo`) – no permission needed.
/// Controls (play/pause, skip, seek) go through AppleScript; macOS asks once per player for permission.
/// Since macOS 15.4 the private MediaRemote framework is closed to third-party apps, so we talk to the
/// players directly.
@MainActor
final class NowPlaying: ObservableObject {
    enum Source: String {
        case spotify, music

        var bundleID: String {
            switch self {
            case .spotify: return "com.spotify.client"
            case .music: return "com.apple.Music"
            }
        }

        var appName: String {
            switch self {
            case .spotify: return "Spotify"
            case .music: return "Music"
            }
        }
    }

    struct Track: Equatable {
        let id: String
        let title: String
        let artist: String
        let album: String
        /// Seconds, if known.
        let duration: TimeInterval?
        let source: Source
    }

    @Published private(set) var track: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var artwork: NSImage?
    /// Colour picked from the artwork, brightened so it reads on black.
    @Published private(set) var accent: Color = .white
    /// Playback position at `positionDate`.
    @Published private(set) var positionAnchor: TimeInterval = 0
    @Published private(set) var positionDate = Clock.now()

    /// Called after the track or play state changed.
    var onChange: (() -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var distributed: [DistributedObserver] = []
    private let log = Logger(subsystem: "dev.davidkubus.nosynotch", category: "media")
    private var artworkTask: Task<Void, Never>?
    private let scripts = DispatchQueue(label: "nosynotch.now-playing", qos: .userInitiated)
    /// Separate queue for state reads so a slow permission check never delays play/pause.
    private let permissions = DispatchQueue(label: "nosynotch.now-playing.read", qos: .utility)

    init(observeSystem: Bool = true) {
        guard observeSystem else { return }
        // Background apps get distributed notifications held back unless they ask for immediate delivery.
        distributed.append(DistributedObserver("com.spotify.client.PlaybackStateChanged") { [weak self] info in
            self?.handleSpotify(info)
        })
        distributed.append(DistributedObserver("com.apple.Music.playerInfo") { [weak self] info in
            self?.handleMusic(info)
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                guard let self, let track = self.track, track.source.bundleID == bundleID else { return }
                self.clear()
            }
        })
        refreshFromPlayers()
    }

    // MARK: - Derived state

    func position(at date: Date = Clock.now()) -> TimeInterval {
        var p = positionAnchor
        if isPlaying { p += date.timeIntervalSince(positionDate) }
        if let d = track?.duration { p = min(p, d) }
        return max(0, p)
    }

    // MARK: - Controls

    func togglePlayPause() {
        guard let track else { return }
        setPlaying(!isPlaying, position: position())
        run("playpause", on: track.source)
    }

    func next() {
        guard let track else { return }
        run("next track", on: track.source)
    }

    func previous() {
        guard let track else { return }
        run(track.source == .spotify ? "previous track" : "back track", on: track.source)
    }

    func seek(to fraction: Double) {
        guard let track, let duration = track.duration else { return }
        let target = duration * min(max(fraction, 0), 1)
        setPlaying(isPlaying, position: target)
        run("set player position to \(Int(target))", on: track.source)
    }

    func openPlayer() {
        guard let track,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: track.source.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    /// Shows a fixed track without talking to any player (used by the GIF recorder).
    func preview(_ track: Track?, artwork: NSImage?, playing: Bool, position: TimeInterval = 0) {
        self.track = track
        self.isPlaying = playing
        self.positionAnchor = position
        self.positionDate = Clock.now()
        setArtwork(artwork)
        onChange?()
    }

    // MARK: - Notifications

    private func handleSpotify(_ info: [AnyHashable: Any]) {
        let state = info["Player State"] as? String ?? ""
        guard state != "Stopped", let id = info["Track ID"] as? String else { return clear() }
        // Ads come through as spotify:ad:… – keep showing whatever was there before.
        if id.hasPrefix("spotify:ad:") { return }
        let track = Track(id: id,
                          title: info["Name"] as? String ?? "",
                          artist: info["Artist"] as? String ?? "",
                          album: info["Album"] as? String ?? "",
                          duration: (info["Duration"] as? Double).map { $0 / 1000 },
                          source: .spotify)
        apply(track, playing: state == "Playing", position: info["Playback Position"] as? Double)
    }

    private func handleMusic(_ info: [AnyHashable: Any]) {
        let state = info["Player State"] as? String ?? ""
        guard state != "Stopped", let title = info["Name"] as? String else { return clear() }
        let id = (info["PersistentID"] as? NSNumber)?.stringValue ?? (info["PersistentID"] as? String) ?? title
        let track = Track(id: id,
                          title: title,
                          artist: info["Artist"] as? String ?? "",
                          album: info["Album"] as? String ?? "",
                          duration: (info["Total Time"] as? Double).map { $0 / 1000 },
                          source: .music)
        apply(track, playing: state == "Playing", position: nil)
        // Music doesn't send the position; ask for it if we're already allowed to.
        refresh(.music)
    }

    private func apply(_ new: Track, playing: Bool, position: TimeInterval?) {
        let changedTrack = new.id != track?.id
        track = new
        if let position {
            setPlaying(playing, position: position)
        } else {
            setPlaying(playing, position: changedTrack ? 0 : self.position())
        }
        if changedTrack {
            log.notice("\(new.source.rawValue, privacy: .public) track changed, playing: \(playing, privacy: .public)")
            loadArtwork(for: new, url: nil)
        }
        onChange?()
    }

    private func setPlaying(_ playing: Bool, position: TimeInterval) {
        isPlaying = playing
        positionAnchor = position
        positionDate = Clock.now()
    }

    private func clear() {
        guard track != nil else { return }
        artworkTask?.cancel()
        track = nil
        isPlaying = false
        setArtwork(nil)
        onChange?()
    }

    // MARK: - AppleScript

    /// On launch, pick up a track that is already playing – but only from players we may already script,
    /// so starting the app never pops up a permission dialog.
    private func refreshFromPlayers() {
        for source in [Source.spotify, .music] where isRunning(source) {
            refresh(source)
        }
    }

    /// Reads the current track via AppleScript – only if we already have permission, so it never prompts.
    private func refresh(_ source: Source) {
        let script: String
        switch source {
        case .spotify:
            script = """
            tell application "Spotify"
              set t to current track
              return {player state as string, name of t, artist of t, album of t, id of t, duration of t, player position, artwork url of t}
            end tell
            """
        case .music:
            script = """
            tell application "Music"
              set t to current track
              return {player state as string, name of t, artist of t, album of t, persistent ID of t, duration of t, player position, ""}
            end tell
            """
        }
        permissions.async { [weak self] in
            // AEDeterminePermissionToAutomateTarget blocks; it must never run on the main thread.
            guard Self.hasAutomationPermission(for: source) else { return }
            var error: NSDictionary?
            guard let result = NSAppleScript(source: script)?.executeAndReturnError(&error),
                  result.numberOfItems >= 8 else { return }
            let items = (1...8).map { result.atIndex($0)?.stringValue ?? "" }
            let numbers = (1...8).map { result.atIndex($0)?.doubleValue ?? 0 }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let state = items[0]
                guard state == "playing" || state == "paused" else { return }
                let duration = source == .spotify ? numbers[5] / 1000 : numbers[5]
                let track = Track(id: items[4], title: items[1], artist: items[2], album: items[3],
                                  duration: duration > 0 ? duration : nil, source: source)
                let changed = track.id != self.track?.id
                self.track = track
                self.setPlaying(state == "playing", position: numbers[6])
                if changed || self.artwork == nil { self.loadArtwork(for: track, url: URL(string: items[7])) }
                self.onChange?()
            }
        }
    }

    private func run(_ command: String, on source: Source) {
        let script = "tell application \"\(source.appName)\" to \(command)"
        scripts.async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            if let error { NSLog("NosyNotch: \(source.appName) script failed: \(error)") }
        }
    }

    private func isRunning(_ source: Source) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: source.bundleID).isEmpty
    }

    /// True if we may already send Apple Events to the player (never prompts, but blocks – call off-main).
    private nonisolated static func hasAutomationPermission(for source: Source) -> Bool {
        var target = AEAddressDesc()
        let bundleID = source.bundleID
        let created = bundleID.withCString { ptr in
            AECreateDesc(DescType(typeApplicationBundleID), ptr, strlen(ptr), &target)
        }
        guard created == noErr else { return false }
        defer { AEDisposeDesc(&target) }
        return AEDeterminePermissionToAutomateTarget(&target, AEEventClass(typeWildCard), AEEventID(typeWildCard), false) == noErr
    }

    // MARK: - Artwork

    private func loadArtwork(for track: Track, url: URL?) {
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            let image = await Self.fetchArtwork(for: track, knownURL: url)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.track?.id == track.id else { return }
                self.log.notice("artwork loaded: \(image != nil, privacy: .public)")
                self.setArtwork(image)
            }
        }
    }

    private func setArtwork(_ image: NSImage?) {
        artwork = image
        accent = image.flatMap(Self.accentColor(of:)) ?? .white
    }

    /// Spotify: oEmbed (no login needed). Music: iTunes Search API. Both return a cover URL.
    private nonisolated static func fetchArtwork(for track: Track, knownURL: URL?) async -> NSImage? {
        var imageURL = knownURL.flatMap { $0.scheme == "https" ? $0 : nil }
        if imageURL == nil {
            switch track.source {
            case .spotify:
                let parts = track.id.split(separator: ":")
                guard parts.count == 3, parts[1] == "track" else { return nil }
                var components = URLComponents(string: "https://open.spotify.com/oembed")!
                components.queryItems = [URLQueryItem(name: "url", value: "https://open.spotify.com/track/\(parts[2])")]
                if let json = await fetchJSON(components.url!), let thumb = json["thumbnail_url"] as? String {
                    imageURL = URL(string: thumb)
                }
            case .music:
                var components = URLComponents(string: "https://itunes.apple.com/search")!
                components.queryItems = [
                    URLQueryItem(name: "term", value: "\(track.artist) \(track.title)"),
                    URLQueryItem(name: "entity", value: "song"),
                    URLQueryItem(name: "limit", value: "1"),
                ]
                if let json = await fetchJSON(components.url!),
                   let first = (json["results"] as? [[String: Any]])?.first,
                   let art = first["artworkUrl100"] as? String {
                    imageURL = URL(string: art.replacingOccurrences(of: "100x100bb", with: "300x300bb"))
                }
            }
        }
        guard let imageURL, let (data, _) = try? await URLSession.shared.data(from: imageURL) else { return nil }
        return NSImage(data: data)
    }

    private nonisolated static func fetchJSON(_ url: URL) async -> [String: Any]? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func accentColor(of image: NSImage) -> Color? {
        guard let tiff = image.tiffRepresentation, let input = CIImage(data: tiff),
              let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: input, kCIInputExtentKey: CIVector(cgRect: input.extent)]),
              let output = filter.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()])
            .render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                    format: .RGBA8, colorSpace: nil)
        let average = NSColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                              blue: CGFloat(pixel[2]) / 255, alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        average.usingColorSpace(.deviceRGB)?.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        // Grey covers stay grey-white; everything else gets enough punch to glow on black.
        let saturation = s < 0.12 ? s : max(s, 0.5)
        return Color(hue: Double(h), saturation: Double(saturation), brightness: Double(max(b, 0.85)))
    }
}

/// Selector-based observer so we can use `.deliverImmediately` (the block API has no suspension behaviour).
private final class DistributedObserver: NSObject {
    private let handler: @MainActor ([AnyHashable: Any]) -> Void

    init(_ name: String, handler: @escaping @MainActor ([AnyHashable: Any]) -> Void) {
        self.handler = handler
        super.init()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(receive(_:)),
                                                            name: .init(name), object: nil,
                                                            suspensionBehavior: .deliverImmediately)
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func receive(_ note: Notification) {
        let info = note.userInfo ?? [:]
        if Thread.isMainThread {
            MainActor.assumeIsolated { handler(info) }
        } else {
            DispatchQueue.main.async { MainActor.assumeIsolated { self.handler(info) } }
        }
    }
}
