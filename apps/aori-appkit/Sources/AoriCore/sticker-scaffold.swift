public enum StickerScaffold {
    public static let emotions = [
        "happy",
        "sad",
        "confused",
        "surprised",
        "thanks",
        "celebrate",
        "angry",
        "tired",
        "affectionate",
        "awkward",
        "agree",
        "disagree",
    ]

    public struct Draft: Equatable, Sendable {
        public var name: String
        public var emotion: String
    }

    /// Builds an emotion draft. No image is stored. A URL is refused.
    public static func draft(name: String, emotion: String) -> Draft? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let emotion = emotion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard emotions.contains(emotion) else {
            return nil
        }
        guard !name.isEmpty, name.count <= 80 else {
            return nil
        }
        guard !name.contains(where: \.isNewline), !name.contains("://") else {
            return nil
        }
        guard !name.lowercased().contains("airi") else {
            return nil
        }
        return Draft(name: name, emotion: emotion)
    }
}
