import Foundation

public enum TelegramScaffold {
    public struct Preview: Equatable, Sendable {
        public var chatID: String
        public var text: String
    }

    /// Builds a chat preview. The preview has no token.
    public static func preview(chatID: String, text: String) -> Preview? {
        let chatID = chatID.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !chatID.isEmpty, !text.isEmpty else {
            return nil
        }
        return Preview(chatID: chatID, text: text)
    }
}
