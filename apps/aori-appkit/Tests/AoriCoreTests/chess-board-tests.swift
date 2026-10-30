import XCTest
@testable import AoriCore

final class ChessBoardTests: XCTestCase {
    func testOpeningMovesFollowThePieceRules() {
        let start = ChessBoard.start
        let afterPawn = start.after(from: "e2", to: "e4")
        XCTAssertNotNil(afterPawn)
        XCTAssertEqual(afterPawn?.sideToMove, .black)
        XCTAssertNil(start.after(from: "e2", to: "e5"))
        XCTAssertNil(start.after(from: "e7", to: "e5"))
        XCTAssertNil(start.after(from: "a1", to: "a3"))
        XCTAssertNil(start.after(from: "e1", to: "g1"))
        XCTAssertNotNil(start.after(from: "g1", to: "f3"))
        XCTAssertNotNil(start.after(from: "b1", to: "c3"))

        var board = ChessBoard.start
        board = board.after(from: "e2", to: "e4")!
        board = board.after(from: "d7", to: "d5")!
        let capture = board.after(from: "e4", to: "d5")
        XCTAssertNotNil(capture)
        XCTAssertEqual(capture?.sideToMove, .black)
        XCTAssertNil(board.after(from: "e4", to: "d4"))
        XCTAssertNil(board.after(from: "e4", to: "e3"))
        XCTAssertNotNil(board.after(from: "e4", to: "e5"))
    }

    func testNamedGapsStayAbsent() {
        var squares = Array<ChessPiece?>(repeating: nil, count: 64)
        squares[square("e7")] = ChessPiece(kind: .pawn, side: .white)
        let promotion = ChessBoard(squares: squares, sideToMove: .white)
        XCTAssertNil(promotion.after(from: "e7", to: "e8"))

        squares = Array(repeating: nil, count: 64)
        squares[square("e5")] = ChessPiece(kind: .pawn, side: .white)
        squares[square("d5")] = ChessPiece(kind: .pawn, side: .black)
        let passant = ChessBoard(squares: squares, sideToMove: .white)
        XCTAssertNil(passant.after(from: "e5", to: "d6"))

        squares = Array(repeating: nil, count: 64)
        squares[square("e1")] = ChessPiece(kind: .king, side: .white)
        squares[square("a2")] = ChessPiece(kind: .pawn, side: .white)
        squares[square("e8")] = ChessPiece(kind: .rook, side: .black)
        let inCheck = ChessBoard(squares: squares, sideToMove: .white)
        XCTAssertNotNil(inCheck.after(from: "a2", to: "a3"))
    }

    func testCommandKeepsTheBoardAndRejectsABadMove() {
        var board = ChessBoard.start
        XCTAssertEqual(ChessCommand.reply(to: "chess e2 e4", board: &board), "e2 to e4.")
        XCTAssertEqual(board.sideToMove, .black)
        XCTAssertEqual(ChessCommand.reply(to: "chess e2 e4", board: &board), "That move is illegal.")
        XCTAssertEqual(board.sideToMove, .black)
        XCTAssertEqual(ChessCommand.reply(to: "chess e7 e5", board: &board), "e7 to e5.")
        XCTAssertEqual(ChessCommand.reply(to: "chess", board: &board), "Chess needs two different squares.")
        XCTAssertEqual(ChessCommand.reply(to: "chess e2 e2", board: &board), "Chess needs two different squares.")
        XCTAssertNil(ChessCommand.reply(to: "Chess e2 e4", board: &board))
        XCTAssertNil(ChessCommand.reply(to: "hello", board: &board))
    }

    private func square(_ text: String) -> Int {
        let chars = Array(text)
        let file = Int(chars[0].asciiValue! - Character("a").asciiValue!)
        let rank = Int(chars[1].asciiValue! - Character("1").asciiValue!)
        return file + rank * 8
    }
}
