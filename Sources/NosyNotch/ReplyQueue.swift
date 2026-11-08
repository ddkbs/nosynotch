import CoreGraphics
import Foundation

/// Prompts waiting for a busy session: each one goes out when the agent finishes its turn.
@MainActor
final class ReplyQueue: ObservableObject {
    struct Item: Identifiable, Equatable {
        let id = UUID()
        let text: String
    }

    static let maxItems = 3
    /// Gives the agent's prompt a moment to come back after its Stop hook.
    private static let deliveryDelay: TimeInterval = 1.2
    /// A queued prompt is pasted into another app, so it never interrupts you mid-sentence.
    private static let typingPause: TimeInterval = 1.5

    @Published private(set) var items: [String: [Item]] = [:]
    /// Why the next prompt of a session couldn't be sent.
    @Published private(set) var problems: [String: String] = [:]
    /// Sent, but the agent hasn't started on it yet: nothing else goes out meanwhile.
    private var inFlight = Set<String>()

    var session: (String) -> Session? = { _ in nil }
    var deliver: (String, Session, @escaping @MainActor (ReplySender.Result) -> Void) -> Void = {
        ReplySender.send($0, to: $1, returnFocus: true, completion: $2)
    }

    /// False when the queue for this session is full.
    func add(_ text: String, to sessionID: String) -> Bool {
        guard items[sessionID, default: []].count < Self.maxItems else { return false }
        items[sessionID, default: []].append(Item(text: text))
        problems[sessionID] = nil
        return true
    }

    func remove(_ id: Item.ID, from sessionID: String) {
        items[sessionID]?.removeAll { $0.id == id }
        if items[sessionID]?.isEmpty == true { clear(sessionID) }
    }

    /// Forgets the queues of sessions that are gone.
    func keep(_ sessionIDs: Set<String>) {
        for id in items.keys where !sessionIDs.contains(id) { clear(id) }
    }

    func sessionStarted(_ sessionID: String) {
        inFlight.remove(sessionID)
    }

    func sessionFinished(_ sessionID: String) {
        guard items[sessionID]?.isEmpty == false, !inFlight.contains(sessionID) else { return }
        inFlight.insert(sessionID)
        Clock.after(Self.deliveryDelay) { [weak self] in self?.attempt(sessionID) }
    }

    private func attempt(_ sessionID: String) {
        // You may have typed something yourself in the meantime; then the prompt waits for the next finish.
        guard let next = items[sessionID]?.first, let session = session(sessionID), session.state == .done else {
            inFlight.remove(sessionID)
            return
        }
        guard !Self.userIsBusy else {
            Clock.after(0.5) { [weak self] in self?.attempt(sessionID) }
            return
        }
        deliver(next.text, session) { [weak self] result in
            guard let self else { return }
            switch result {
            case .typed, .background:
                self.problems[sessionID] = nil
                self.remove(next.id, from: sessionID)
            case .needsAccessibility, .failed:
                self.problems[sessionID] = result.message
                self.inFlight.remove(sessionID)
            }
        }
    }

    private func clear(_ sessionID: String) {
        items[sessionID] = nil
        problems[sessionID] = nil
    }

    private static var userIsBusy: Bool {
        guard !Clock.isVirtual else { return false }
        let locked = (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
        return locked || CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown) < typingPause
    }
}
