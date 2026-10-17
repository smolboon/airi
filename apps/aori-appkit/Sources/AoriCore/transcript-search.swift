import Foundation

public struct TranscriptMatch: Equatable, Sendable {
    public var messages: [ChatMessage]
    public var notes: [MemoryNote]

    public init(messages: [ChatMessage], notes: [MemoryNote]) {
        self.messages = messages
        self.notes = notes
    }
}

public enum TranscriptSearch {
    /// Matches every word in the query. The check is case insensitive.
    public static func match(query: String, messages: [ChatMessage], notes: [MemoryNote]) -> TranscriptMatch {
        let words = query
            .lowercased()
            .split { $0.isWhitespace }
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else {
            return TranscriptMatch(messages: messages, notes: [])
        }
        let messagesHit = messages.filter { message in
            let haystack = message.content.lowercased()
            return words.allSatisfy { haystack.contains($0) }
        }
        let notesHit = notes.filter { note in
            let haystack = note.text.lowercased()
            return words.allSatisfy { haystack.contains($0) }
        }
        return TranscriptMatch(messages: messagesHit, notes: notesHit)
    }
}
