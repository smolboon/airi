import Foundation

public enum SatoriScaffold {
    public struct Draft: Equatable, Sendable {
        public var platform: String
        public var text: String
    }

    /// Builds an event draft. The draft has no token.
    public static func draft(platform: String, text: String) -> Draft? {
        let platform = platform.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !platform.isEmpty, !text.isEmpty else {
            return nil
        }
        return Draft(platform: platform, text: text)
    }
}
