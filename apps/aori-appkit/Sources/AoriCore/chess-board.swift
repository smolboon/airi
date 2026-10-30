import Foundation

public struct ChessPiece: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case pawn
        case knight
        case bishop
        case rook
        case queen
        case king
    }

    public enum Side: Equatable, Sendable {
        case white
        case black
    }

    public var kind: Kind
    public var side: Side

    public init(kind: Kind, side: Side) {
        self.kind = kind
        self.side = side
    }
}

/// A local board. No engine runs. Check, castling, en passant, and promotion are absent.
public struct ChessBoard: Equatable, Sendable {
    public private(set) var squares: [ChessPiece?]
    public private(set) var sideToMove: ChessPiece.Side

    public static let start = ChessBoard()

    public init() {
        var squares = Array<ChessPiece?>(repeating: nil, count: 64)
        let back: [ChessPiece.Kind] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for file in 0 ..< 8 {
            squares[file] = ChessPiece(kind: back[file], side: .white)
            squares[file + 8] = ChessPiece(kind: .pawn, side: .white)
            squares[file + 48] = ChessPiece(kind: .pawn, side: .black)
            squares[file + 56] = ChessPiece(kind: back[file], side: .black)
        }
        self.squares = squares
        self.sideToMove = .white
    }

    public init(squares: [ChessPiece?], sideToMove: ChessPiece.Side) {
        if squares.count == 64 {
            self.squares = squares
        } else {
            self.squares = Array(repeating: nil, count: 64)
        }
        self.sideToMove = sideToMove
    }

    /// Returns the board after a legal piece move. A nil result leaves the caller board unchanged.
    public func after(from: String, to: String) -> ChessBoard? {
        guard let fromIndex = Self.index(from), let toIndex = Self.index(to), fromIndex != toIndex else {
            return nil
        }
        guard let piece = squares[fromIndex], piece.side == sideToMove else {
            return nil
        }
        guard legal(piece: piece, from: fromIndex, to: toIndex) else {
            return nil
        }
        var next = self
        next.squares[toIndex] = piece
        next.squares[fromIndex] = nil
        next.sideToMove = piece.side == .white ? .black : .white
        return next
    }

    private static func index(_ square: String) -> Int? {
        guard ChessScaffold.isSquare(square) else {
            return nil
        }
        let chars = Array(square)
        guard let fileCode = chars[0].asciiValue, let rankCode = chars[1].asciiValue else {
            return nil
        }
        let file = Int(fileCode - Character("a").asciiValue!)
        let rank = Int(rankCode - Character("1").asciiValue!)
        return file + rank * 8
    }

    private func legal(piece: ChessPiece, from: Int, to: Int) -> Bool {
        let fromFile = from % 8
        let fromRank = from / 8
        let toFile = to % 8
        let toRank = to / 8
        let fileDelta = toFile - fromFile
        let rankDelta = toRank - fromRank
        switch piece.kind {
        case .pawn:
            return legalPawn(
                piece,
                fromFile: fromFile,
                fromRank: fromRank,
                to: to,
                toRank: toRank,
                fileDelta: fileDelta,
                rankDelta: rankDelta
            )
        case .knight:
            let fileSteps = abs(fileDelta)
            let rankSteps = abs(rankDelta)
            guard (fileSteps == 1 && rankSteps == 2) || (fileSteps == 2 && rankSteps == 1) else {
                return false
            }
            return canLand(piece, at: to)
        case .bishop:
            return slide(piece, fromFile: fromFile, fromRank: fromRank, fileDelta: fileDelta, rankDelta: rankDelta, to: to, diagonal: true, straight: false)
        case .rook:
            return slide(piece, fromFile: fromFile, fromRank: fromRank, fileDelta: fileDelta, rankDelta: rankDelta, to: to, diagonal: false, straight: true)
        case .queen:
            return slide(piece, fromFile: fromFile, fromRank: fromRank, fileDelta: fileDelta, rankDelta: rankDelta, to: to, diagonal: true, straight: true)
        case .king:
            guard abs(fileDelta) <= 1, abs(rankDelta) <= 1 else {
                return false
            }
            return canLand(piece, at: to)
        }
    }

    private func legalPawn(
        _ piece: ChessPiece,
        fromFile: Int,
        fromRank: Int,
        to: Int,
        toRank: Int,
        fileDelta: Int,
        rankDelta: Int
    ) -> Bool {
        if toRank == 0 || toRank == 7 {
            return false
        }
        let forward = piece.side == .white ? 1 : -1
        let startRank = piece.side == .white ? 1 : 6
        if fileDelta == 0 && rankDelta == forward {
            return squares[to] == nil
        }
        if fileDelta == 0 && rankDelta == forward * 2 && fromRank == startRank {
            let skipped = fromFile + (fromRank + forward) * 8
            return squares[to] == nil && squares[skipped] == nil
        }
        if abs(fileDelta) == 1 && rankDelta == forward {
            guard let occupier = squares[to] else {
                return false
            }
            return occupier.side != piece.side
        }
        return false
    }

    private func slide(
        _ piece: ChessPiece,
        fromFile: Int,
        fromRank: Int,
        fileDelta: Int,
        rankDelta: Int,
        to: Int,
        diagonal: Bool,
        straight: Bool
    ) -> Bool {
        let fileSteps = abs(fileDelta)
        let rankSteps = abs(rankDelta)
        let isDiagonal = fileSteps == rankSteps && fileSteps > 0
        let isStraight = (fileDelta == 0 || rankDelta == 0) && fileSteps + rankSteps > 0
        if !isDiagonal && !isStraight {
            return false
        }
        if isDiagonal && !diagonal {
            return false
        }
        if isStraight && !straight {
            return false
        }
        let stepFile = fileDelta == 0 ? 0 : fileDelta / abs(fileDelta)
        let stepRank = rankDelta == 0 ? 0 : rankDelta / abs(rankDelta)
        var file = fromFile + stepFile
        var rank = fromRank + stepRank
        while file != to % 8 || rank != to / 8 {
            if squares[file + rank * 8] != nil {
                return false
            }
            file += stepFile
            rank += stepRank
        }
        return canLand(piece, at: to)
    }

    private func canLand(_ piece: ChessPiece, at index: Int) -> Bool {
        guard let occupier = squares[index] else {
            return true
        }
        return occupier.side != piece.side
    }
}
