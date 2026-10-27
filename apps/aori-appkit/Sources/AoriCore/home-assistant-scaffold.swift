public enum HomeAssistantScaffold {
    public static let blockedKeys = [
        "token",
        "access_token",
        "password",
        "api_key",
        "url",
        "base_url",
        "authorization",
    ]

    public struct Draft: Equatable, Sendable {
        public var entity: String
    }

    /// Builds an entity draft. A URL and a token are refused.
    public static func draft(entity: String) -> Draft? {
        let entity = entity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = entity.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return nil
        }
        guard parts.allSatisfy(isEntityPart) else {
            return nil
        }
        return Draft(entity: entity)
    }

    /// Drops credential fields. Other fields stay.
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

    private static func isEntityPart(_ part: Substring) -> Bool {
        guard !part.isEmpty, part.count <= 64 else {
            return false
        }
        return part.unicodeScalars.allSatisfy { scalar in
            switch scalar {
            case "a" ... "z", "0" ... "9", "_":
                return true
            default:
                return false
            }
        }
    }
}
