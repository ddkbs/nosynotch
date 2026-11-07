import AppKit
import ApplicationServices

/// One line of a conversation, read from the agent's transcript.
struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id: String
    let role: Role
    let text: String
}

/// Reads the last messages of a Claude Code (`~/.claude/projects/…jsonl`) or Codex (`rollout-*.jsonl`) transcript.
enum ChatTranscript {
    static func messages(at path: String, limit: Int = 12) -> [ChatMessage] {
        guard let text = tail(of: path) else { return [] }
        var result: [ChatMessage] = []
        for (index, line) in text.split(separator: "\n").enumerated() {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let message = claudeMessage(obj, index: index) ?? codexMessage(obj, index: index) {
                // Several assistant text blocks in a row read as one answer.
                if let last = result.last, last.role == .assistant, message.role == .assistant {
                    result[result.count - 1] = ChatMessage(id: last.id, role: .assistant, text: last.text + "\n\n" + message.text)
                } else {
                    result.append(message)
                }
            }
        }
        return Array(result.suffix(limit))
    }

    private static func claudeMessage(_ obj: [String: Any], index: Int) -> ChatMessage? {
        guard let type = obj["type"] as? String, type == "user" || type == "assistant",
              obj["isMeta"] as? Bool != true, obj["isSidechain"] as? Bool != true,
              let message = obj["message"] as? [String: Any] else { return nil }
        let role: ChatMessage.Role = type == "user" ? .user : .assistant
        var text = ""
        if let content = message["content"] as? String {
            text = content
        } else if let blocks = message["content"] as? [[String: Any]] {
            // Tool calls and tool results aren't conversation.
            text = blocks.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined(separator: "\n")
        }
        return make(role: role, text: text, id: (obj["uuid"] as? String) ?? "c\(index)")
    }

    private static func codexMessage(_ obj: [String: Any], index: Int) -> ChatMessage? {
        guard obj["type"] as? String == "response_item", let payload = obj["payload"] as? [String: Any],
              payload["type"] as? String == "message", let roleName = payload["role"] as? String,
              roleName == "user" || roleName == "assistant",
              let blocks = payload["content"] as? [[String: Any]] else { return nil }
        let text = blocks.compactMap { block -> String? in
            let type = block["type"] as? String
            return type == "input_text" || type == "output_text" ? block["text"] as? String : nil
        }.joined(separator: "\n")
        return make(role: roleName == "user" ? .user : .assistant, text: text, id: "x\(index)")
    }

    private static func make(role: ChatMessage.Role, text: String, id: String) -> ChatMessage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Injected context (slash-command plumbing, environment blocks, system reminders) – not something anyone typed.
        let hidden = ["<command-", "<local-command", "<environment_context", "<user_instructions", "<system-reminder",
                      "Caveat: The messages below", "[Request interrupted"]
        if role == .user, hidden.contains(where: { trimmed.hasPrefix($0) }) { return nil }
        let short = trimmed.count > 1_500 ? String(trimmed.prefix(1_499)) + "…" : trimmed
        return ChatMessage(id: id, role: role, text: short)
    }

    private static func tail(of path: String, bytes: UInt64 = 384 * 1024) -> String? {
        let expanded = (path as NSString).expandingTildeInPath
        guard let handle = FileHandle(forReadingAtPath: expanded) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > bytes ? size - bytes : 0)
        guard let data = try? handle.readToEnd() else { return nil }
        var text = String(decoding: data, as: UTF8.self)
        // Drop the (probably cut) first line when we started in the middle.
        if size > bytes, let newline = text.firstIndex(of: "\n") { text = String(text[text.index(after: newline)...]) }
        return text
    }
}

/// Sends a reply from the notch to the session.
@MainActor
enum ReplySender {
    enum Result: Equatable {
        case typed(app: String)
        case background
        case needsAccessibility
        case failed(String)

        var message: String {
            switch self {
            case .typed(let app): return "Sent to \(app)"
            case .background: return "Sent – running in the background"
            case .needsAccessibility: return "Allow Nosy Notch under Privacy & Security → Accessibility, then send again."
            case .failed(let why): return why
            }
        }
    }

    static func send(_ text: String, to session: Session, completion: @escaping @MainActor (Result) -> Void) {
        let mode = Preferences.replyMode
        if mode == "background", session.agent != .cursor {
            return completion(runInBackground(text, session: session))
        }
        typeIntoApp(text, session: session, completion: completion)
    }

    /// Brings the session's app to the front, pastes the text into it and presses Return.
    private static func typeIntoApp(_ text: String, session: Session, completion: @escaping @MainActor (Result) -> Void) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return completion(.needsAccessibility) }

        TerminalActivator.activate(session)
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? session.agent.name
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let copy = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
            return copy
        } ?? []

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            MainActor.assumeIsolated {
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                key(9, command: true)          // ⌘V
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    MainActor.assumeIsolated {
                        key(36)                // Return
                        let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? appName
                        completion(.typed(app: front))
                    }
                }
                // Put back whatever was on the clipboard.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    MainActor.assumeIsolated {
                        pasteboard.clearContents()
                        if !saved.isEmpty { pasteboard.writeObjects(saved) }
                    }
                }
            }
        }
    }

    private static func key(_ code: CGKeyCode, command: Bool = false) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
            if command { event?.flags = .maskCommand }
            event?.post(tap: .cghidEventTap)
        }
    }

    /// `claude --resume <id> -p <text>` / `codex exec resume <id> <text>` in the session's folder. The answer lands in
    /// the transcript (and the notch shows the run like any other).
    private static func runInBackground(_ text: String, session: Session) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // The id and the text are passed as arguments ($1, $2), never pasted into the command line.
        let command = session.agent == .codex ? #"codex exec resume "$1" "$2""# : #"claude --resume "$1" -p "$2""#
        process.arguments = ["-lc", command, "nosynotch", session.id, text]
        if let cwd = session.cwd { process.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            return .background
        } catch {
            return .failed("Couldn't start \(session.agent.name): \(error.localizedDescription)")
        }
    }
}
