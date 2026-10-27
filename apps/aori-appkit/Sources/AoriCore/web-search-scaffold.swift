public enum WebSearchScaffold {
    public static let blockedKeys = [
        "api_key",
        "token",
        "key",
        "authorization",
    ]

    /// Drops credential fields. Web search stays unavailable.
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
