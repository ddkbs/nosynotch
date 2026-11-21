import Foundation
import Darwin

/// Watches both the inode and its directory so append, atomic replace and recreation are handled.
@MainActor
final class FileChangeObserver {
    private var file: DispatchSourceFileSystemObject?
    private var directory: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?
    private var active = true
    private var lastStamp: Stamp?
    private struct Stamp: Equatable {
        let inode: UInt64
        let size: UInt64
        let modified: Date
    }
    private let path: String
    private let onChange: () -> Void

    init(path: String, onChange: @escaping () -> Void) {
        self.path = (path as NSString).expandingTildeInPath
        self.onChange = onChange
        lastStamp = stamp()
        attachFile()
        directory = watch((self.path as NSString).deletingLastPathComponent) { [weak self] in
            self?.attachFile()
            self?.changed()
        }
    }

    deinit { file?.cancel(); directory?.cancel(); pending?.cancel() }

    func cancel() {
        active = false
        file?.cancel(); file = nil
        directory?.cancel(); directory = nil
        pending?.cancel(); pending = nil
    }

    private func attachFile() {
        guard active else { return }
        file?.cancel()
        file = watch(path) { [weak self] in self?.changed() }
    }

    private func watch(_ path: String, _ callback: @escaping @MainActor () -> Void) -> DispatchSourceFileSystemObject? {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .rename, .delete, .revoke], queue: .main)
        source.setEventHandler { MainActor.assumeIsolated(callback) }
        source.setCancelHandler { close(fd) }
        source.resume()
        return source
    }

    private func stamp() -> Stamp? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let inode = attributes[.systemFileNumber] as? NSNumber,
              let size = attributes[.size] as? NSNumber,
              let modified = attributes[.modificationDate] as? Date else { return nil }
        return Stamp(inode: inode.uint64Value, size: size.uint64Value, modified: modified)
    }

    private func changed() {
        guard active else { return }
        let stamp = stamp()
        guard stamp != lastStamp else { return }
        lastStamp = stamp
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { if self?.active == true { self?.onChange() } } }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
    }
}
