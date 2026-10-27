import Foundation

public enum DiscordScaffold {
    public struct Draft: Equatable, Sendable {
        public var channel: String
        public var text: String
    }

    /// Builds a channel message. The draft has no token.
    public static func draft(channel: String, text: String) -> Draft? {
        let channel = channel.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !channel.isEmpty, !text.isEmpty else {
            return nil
        }
        return Draft(channel: channel, text: text)
    }
}
