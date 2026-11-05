import Foundation

/// Reads the Claude Code transcript (JSONL) to find the last thing the assistant said.
enum Transcript {
    static func lastAssistantText(at path: String) -> String? {
        let expanded = (path as NSString).expandingTildeInPath
        guard let handle = FileHandle(forReadingAtPath: expanded) else { return nil }
        defer { try? handle.close() }

        // Only read the tail; transcripts can get large.
        let size = (try? handle.seekToEnd()) ?? 0
        let window: UInt64 = 256 * 1024
        try? handle.seek(toOffset: size > window ? size - window : 0)
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { return nil }

        for line in text.split(separator: "\n").reversed() {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  obj["type"] as? String == "assistant",
                  let message = obj["message"] as? [String: Any]
            else { continue }

            if let content = message["content"] as? [[String: Any]] {
                let texts = content.compactMap { block -> String? in
                    guard block["type"] as? String == "text" else { return nil }
                    return block["text"] as? String
                }
                let joined = texts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                if !joined.isEmpty { return joined }
            } else if let content = message["content"] as? String, !content.isEmpty {
                return content
            }
        }
        return nil
    }
}
