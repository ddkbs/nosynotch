import Foundation
import Combine
import Testing
@testable import NosyNotch

@MainActor
struct FileObserverTests {
    private func received(_ stream: AsyncStream<Void>, timeout: UInt64 = 2_000_000_000) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                return await iterator.next() != nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeout)
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
    }

    @Test
    func appendReplaceDeleteRecreateAndCancel() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("chat.jsonl")
        try Data("first".utf8).write(to: file)
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        defer { continuation.finish() }
        let observer = FileChangeObserver(path: file.path) { continuation.yield(()) }
        defer { observer.cancel() }

        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(" appended".utf8))
        try handle.close()
        #expect(await received(stream))
        #expect(try String(contentsOf: file) == "first appended")

        try Data("replacement".utf8).write(to: file, options: .atomic)
        #expect(await received(stream))
        try FileManager.default.removeItem(at: file)
        #expect(await received(stream))
        try Data("recreated".utf8).write(to: file)
        #expect(await received(stream))
        #expect(try String(contentsOf: file) == "recreated")

        observer.cancel()
        try Data("closed".utf8).write(to: file)
        #expect(!(await received(stream, timeout: 250_000_000)))
    }

    @Test
    func missingFileAppearsAndUnrelatedDirectoryWritesAreIgnored() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("chat.jsonl")
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        defer { continuation.finish() }
        var notifications = 0
        let observer = FileChangeObserver(path: file.path) { notifications += 1; continuation.yield(()) }
        defer { observer.cancel() }
        try Data("unrelated".utf8).write(to: dir.appendingPathComponent("other"))
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(notifications == 0)
        try Data("created".utf8).write(to: file)
        #expect(await received(stream))
    }
    @Test
    func chatUpdatesFromFileAndClosingCancelsUpdates() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("chat.jsonl")
        func write(_ text: String) throws {
            var data = try JSONSerialization.data(withJSONObject: ["type": "user", "uuid": text,
                                                                  "message": ["content": text]])
            data.append(10)
            try data.write(to: file, options: .atomic)
        }
        try write("initial")
        let store = SessionStore(startTimers: false)
        let payload = try JSONSerialization.data(withJSONObject: ["hook_event_name": "SessionStart",
            "session_id": "chat", "transcript_path": file.path])
        let event = try #require(HookEvent(data: payload))
        store.handle(event)
        let model = NotchViewModel(store: store, media: NowPlaying(observeSystem: false),
                                  pet: NosyPet(persist: false), startTimers: false)
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        defer { continuation.finish() }
        let subscription = model.$chatMessages.sink { messages in
            if messages.map(\.text) == ["updated"] { continuation.yield(()) }
        }
        defer { subscription.cancel(); model.closeChat() }
        model.openChat(try #require(store.sessions["chat"]))
        try write("updated")
        #expect(await received(stream))
        #expect(model.chatMessages.map(\.text) == ["updated"])
        model.closeChat()
        try write("after close")
        try await Task.sleep(nanoseconds: 250_000_000)
        #expect(model.chatMessages.isEmpty)
        #expect(model.chatSessionID == nil)
        model.openChat(try #require(store.sessions["chat"]))
        // Reopening must observe the latest file, not a stale cached transcript.
        let (reopened, reopenedContinuation) = AsyncStream<Void>.makeStream()
        let reopenedSubscription = model.$chatMessages.sink { messages in
            if messages.map(\.text) == ["after close"] { reopenedContinuation.yield(()) }
        }
        defer { reopenedSubscription.cancel(); reopenedContinuation.finish() }
        #expect(await received(reopened))
    }

}
