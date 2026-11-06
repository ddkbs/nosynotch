import AppKit
import UniformTypeIdentifiers

/// Files parked in the notch: drop them on the notch, drag them out again later. Only references are kept –
/// the files stay where they are.
@MainActor
final class Shelf: ObservableObject {
    @Published private(set) var items: [URL] = []

    private static let defaultsKey = "shelfItems"
    private let persist: Bool

    init(persist: Bool = true) {
        self.persist = persist
        guard persist else { return }
        let paths = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
        items = paths.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    var isEmpty: Bool { items.isEmpty }

    func add(_ urls: [URL]) {
        for url in urls where !items.contains(url) { items.append(url) }
        save()
    }

    func remove(_ url: URL) {
        items.removeAll { $0 == url }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    /// Drop files that were moved or deleted in the meantime.
    func prune() {
        let existing = items.filter { FileManager.default.fileExists(atPath: $0.path) }
        if existing != items { items = existing; save() }
    }

    private func save() {
        guard persist else { return }
        UserDefaults.standard.set(items.map(\.path), forKey: Self.defaultsKey)
    }
}

/// Sends files with AirDrop – macOS shows its own AirDrop window to pick the device.
@MainActor
enum AirDrop {
    static func send(_ urls: [URL]) {
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return }
        NSApp.activate(ignoringOtherApps: true)
        if service.canPerform(withItems: urls) {
            service.perform(withItems: urls)
        } else {
            NSSound.beep()
        }
    }
}

enum FileDrop {
    /// File URLs out of drag-and-drop item providers.
    static func urls(from providers: [NSItemProvider], completion: @escaping @MainActor ([URL]) -> Void) {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url, url.isFileURL {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            MainActor.assumeIsolated { completion(urls) }
        }
    }
}
