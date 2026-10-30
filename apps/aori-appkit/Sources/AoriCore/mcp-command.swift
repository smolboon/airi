import Foundation

/// A local MCP reply. No process starts. A server command is dropped.
public enum McpCommand {
    public static func reply(to text: String) -> String? {
        guard text == "mcp" || text.hasPrefix("mcp ") else {
            return nil
        }
        let rest = text == "mcp" ? "" : String(text.dropFirst("mcp ".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if rest.isEmpty {
            return "MCP needs a local tool call."
        }
        if rest == "tools" {
            return "MCP tools: greeting."
        }
        if rest == "call greeting" {
            return PluginHost.greetingText
        }
        if rest.hasPrefix("call ") {
            let name = String(rest.dropFirst("call ".count))
            return "MCP denied \(name)."
        }
        let kept = McpScaffold.kept(fields(from: rest))
        if kept.isEmpty {
            return "MCP dropped the server command."
        }
        let names = kept.keys.sorted().joined(separator: ", ")
        return "MCP kept \(names)."
    }

    private static func fields(from rest: String) -> [String: String] {
        if rest.contains("=") {
            var result: [String: String] = [:]
            for token in rest.split(separator: " ") {
                let parts = token.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else {
                    continue
                }
                result[parts[0]] = parts[1]
            }
            return result
        }
        let parts = rest.split(separator: " ").map(String.init)
        var result: [String: String] = [:]
        var index = 0
        while index + 1 < parts.count {
            result[parts[index]] = parts[index + 1]
            index += 2
        }
        return result
    }
}
