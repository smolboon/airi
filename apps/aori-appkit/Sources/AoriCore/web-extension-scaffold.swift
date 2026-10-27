public enum WebExtensionScaffold {
    public static let blockedKeys = [
        "url",
        "cookie",
        "token",
        "authorization",
        "api_key",
    ]

    public struct Draft: Equatable, Sendable {
        public var title: String
        public var text: String
    }

    /// Builds a page draft. A URL is refused. No cookie is stored.
    public static func draft(title: String, text: String) -> Draft? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !text.isEmpty else {
            return nil
        }
        guard !title.contains(where: \.isNewline), !text.contains(where: \.isNewline) else {
            return nil
        }
        guard !title.contains("://"), !text.contains("://") else {
            return nil
        }
        guard title.count <= 256, text.count <= 256 else {
            return nil
        }
        return Draft(title: title, text: text)
    }

    /// Drops address and credential fields. Other fields stay.
    public static func kept(_ fields: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in fields {
            let name = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !name.isEmpty, !blockedKeys.contains(name) else {
                continue
            }
            result[name] = value
        }
        return result
    }
}
