public enum ChessScaffold {
    public struct Move: Equatable, Sendable {
        public var from: String
        public var to: String
    }

    /// Builds a square-to-square draft. No engine runs.
    public static func move(from: String, to: String) -> Move? {
        let from = from.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let to = to.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isSquare(from), isSquare(to), from != to else {
            return nil
        }
        return Move(from: from, to: to)
    }

    public static func isSquare(_ text: String) -> Bool {
        guard text.count == 2 else {
            return false
        }
        let chars = Array(text)
        guard let file = chars.first, let rank = chars.last else {
            return false
        }
        return ("a" ... "h").contains(file) && ("1" ... "8").contains(rank)
    }
}
