import Foundation
import Testing
@testable import NosyNotch

struct TranscriptTests {
    private func withTranscript(_ body: (URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(dir.appendingPathComponent("conversation.jsonl"))
    }

    private func claude(_ role: String, _ text: String) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: ["type": role, "uuid": UUID().uuidString,
                                                               "message": ["content": text]])
        data.append(10)
        return data
    }

    @Test
    func testClaudeAppendPartialWriteAndAtomicReplacement() throws {
        try withTranscript { file in
            var data = try claude("user", "hello")
            try data.write(to: file)
            #expect(ChatTranscript.messages(at: file.path).map(\.text) == ["hello"])
            let answer = try claude("assistant", "world")
            let split = answer.count / 2
            data.append(answer.prefix(split))
            try data.write(to: file)
            #expect(ChatTranscript.messages(at: file.path).map(\.text) == ["hello"])
            data.append(answer.suffix(answer.count - split))
            try data.write(to: file)
            #expect(ChatTranscript.messages(at: file.path).map(\.text) == ["hello", "world"])
            #expect(Transcript.lastAssistantText(at: file.path) == "world")
            try claude("user", "replacement").write(to: file, options: .atomic)
            #expect(ChatTranscript.messages(at: file.path).map(\.text) == ["replacement"])
            try FileManager.default.removeItem(at: file)
            #expect(ChatTranscript.messages(at: file.path).isEmpty)
        }
    }

    @Test
    func testCodexMessagesExcludeToolTraffic() throws {
        try withTranscript { file in
            let records: [[String: Any]] = [
                ["type": "response_item", "payload": ["type": "message", "role": "user", "content": [["type": "input_text", "text": "question"]]]],
                ["type": "response_item", "payload": ["type": "function_call", "name": "exec_command"]],
                ["type": "response_item", "payload": ["type": "message", "role": "assistant", "content": [["type": "output_text", "text": "answer"]]]]
            ]
            var data = Data()
            for record in records { data.append(try JSONSerialization.data(withJSONObject: record)); data.append(10) }
            try data.write(to: file)
            #expect(ChatTranscript.messages(at: file.path).map(\.text) == ["question", "answer"])
        }
    }

    @Test
    func testClaudeMergesAssistantBlocksAndIgnoresMetadata() throws {
        try withTranscript { file in
            var data = try claude("assistant", "first")
            data.append(try claude("assistant", "second"))
            data.append(try JSONSerialization.data(withJSONObject: ["type": "user", "isMeta": true, "message": ["content": "hidden"]]))
            try data.write(to: file)
            #expect(ChatTranscript.messages(at: file.path).map(\.text) == ["first\n\nsecond"])
        }
    }
}
