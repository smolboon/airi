import Foundation

/// A local Discord draft. The reply does not leave this machine.
public enum DiscordCommand {
    private static let credentialKeys = [
        "token",
        "api_key",
        "access_token",
        "authorization",
        "password",
    ]

    public static func reply(to text: String) -> String? {
        guard text == "discord" || text.hasPrefix("discord ") else {
            return nil
        }
        let rest = text == "discord" ? "" : String(text.dropFirst("discord ".count))
        if containsCredential(rest) {
            return "Discord dropped a credential."
        }
        if rest.lowercased().contains("://") {
            return "Discord refused a URL."
        }
        let parts = rest.split(
            separator: " ",
            maxSplits: 1,
            omittingEmptySubsequences: true
        ).map(String.init)
        let channel = parts.first ?? ""
        let body = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        guard let draft = DiscordScaffold.draft(channel: channel, text: body) else {
            return "Discord needs a channel and text."
        }
        return "Discord draft for \(draft.channel): \(draft.text)."
    }

    private static func containsCredential(_ text: String) -> Bool {
        let lower = text.lowercased()
        for key in credentialKeys {
            if lower.contains(key + "=") {
                return true
            }
        }
        return false
    }
}
