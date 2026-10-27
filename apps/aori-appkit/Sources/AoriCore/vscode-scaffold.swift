public enum VscodeScaffold {
    public struct Draft: Equatable, Sendable {
        public var folder: String
        public var text: String
    }

    /// Builds a local context draft. The draft has no token and no URL.
    public static func draft(folder: String, text: String) -> Draft? {
        let folder = folder.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !folder.isEmpty, !text.isEmpty else {
            return nil
        }
        guard !folder.contains(where: \.isNewline), !text.contains(where: \.isNewline) else {
            return nil
        }
        guard !folder.contains("://"), !text.contains("://") else {
            return nil
        }
        guard folder.count <= 256, text.count <= 256 else {
            return nil
        }
        return Draft(folder: folder, text: text)
    }
}
