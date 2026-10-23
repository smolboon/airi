public enum McpScaffold {
    public static let blockedKeys = [
        "server-cmd",
        "server_cmd",
        "server-args",
        "server_args",
        "command",
        "cmd",
        "args",
        "token",
        "url",
        "api_key",
        "authorization",
    ]

    /// Drops a server command and credential fields. MCP stays unavailable.
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
