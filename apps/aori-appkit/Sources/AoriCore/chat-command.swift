import Foundation

/// Local chat commands. They do not open a host and they do not start speech.
public enum ChatCommand {
    public static func reply(to text: String, chess: inout ChessBoard) -> String? {
        if let greeting = LocalTool.reply(to: text) {
            return greeting
        }
        if let discord = DiscordCommand.reply(to: text) {
            return discord
        }
        if let chessMove = ChessCommand.reply(to: text, board: &chess) {
            return chessMove
        }
        return McpCommand.reply(to: text)
    }
}
