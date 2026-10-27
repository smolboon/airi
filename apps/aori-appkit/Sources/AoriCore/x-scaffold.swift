import Foundation

public enum XScaffold {
    public static let blockedKeys = [
        "api_key",
        "api_secret",
        "access_token",
        "access_token_secret",
        "token",
    ]

    /// Drops credential fields. X stays unavailable.
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
