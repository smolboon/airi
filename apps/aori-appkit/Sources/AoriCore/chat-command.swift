import Foundation

/// Local chat commands. They do not open a host and they do not start speech.
public enum ChatCommand {
    public static func reply(to text: String) -> String? {
        if let greeting = LocalTool.reply(to: text) {
            return greeting
        }
        return DiscordCommand.reply(to: text)
    }
}
