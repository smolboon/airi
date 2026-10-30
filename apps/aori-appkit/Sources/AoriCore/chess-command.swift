import Foundation

/// One local chess move. No engine runs.
public enum ChessCommand {
    public static func reply(to text: String, board: inout ChessBoard) -> String? {
        guard text == "chess" || text.hasPrefix("chess ") else {
            return nil
        }
        let rest = text == "chess" ? "" : String(text.dropFirst("chess ".count))
        let parts = rest.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count == 2 else {
            return "Chess needs two different squares."
        }
        let from = parts[0].lowercased()
        let to = parts[1].lowercased()
        guard ChessScaffold.isSquare(from), ChessScaffold.isSquare(to), from != to else {
            return "Chess needs two different squares."
        }
        guard let next = board.after(from: from, to: to) else {
            return "That move is illegal."
        }
        board = next
        return "\(from) to \(to)."
    }
}
