import XCTest
@testable import StockfishAnalysis

final class ChessRulesTests: XCTestCase {
    var engine: ChessRulesEngine!
    
    override func setUp() {
        super.setUp()
        engine = ChessRulesEngine()
    }
    
    func testStartingPosition() {
        XCTAssertEqual(engine.board.count, 32)
        XCTAssertEqual(engine.activeColor, .white)
        XCTAssertFalse(engine.isCheck)
        XCTAssertFalse(engine.isCheckmate)
        
        let legals = engine.legalMoves()
        // 16 pawn moves (8 single, 8 double) + 4 knight moves = 20 legal moves
        XCTAssertEqual(legals.count, 20)
    }
    
    func testPawnMovesAndDoubleStep() {
        // e2 -> e4
        let e2 = Square(string: "e2")!
        let e4 = Square(string: "e4")!
        let move = ChessMove(from: e2, to: e4)
        
        let success = engine.makeMove(move)
        XCTAssertTrue(success)
        XCTAssertEqual(engine.activeColor, .black)
        XCTAssertEqual(engine.enPassantSquare, Square(string: "e3"))
        XCTAssertNil(engine.board[e2])
        XCTAssertNotNil(engine.board[e4])
    }
    
    func testEnPassantCapture() {
        // 1. e4 a6 2. e5 d5 3. exd6 (en passant)
        _ = engine.makeMove(from: "e2", to: "e4")
        _ = engine.makeMove(from: "a7", to: "a6")
        _ = engine.makeMove(from: "e4", to: "e5")
        _ = engine.makeMove(from: "d7", to: "d5") // creates d6 e.p. square
        
        XCTAssertEqual(engine.enPassantSquare, Square(string: "d6"))
        
        let epMove = ChessMove(from: Square(string: "e5")!, to: Square(string: "d6")!)
        XCTAssertTrue(engine.legalMoves().contains(epMove))
        
        let success = engine.makeMove(epMove)
        XCTAssertTrue(success)
        // Black's d5 pawn should be captured
        XCTAssertNil(engine.board[Square(string: "d5")!])
        XCTAssertEqual(engine.capturedBlack.count, 1)
        XCTAssertEqual(engine.capturedBlack.first?.type, .pawn)
    }
    
    func testCastlingKingsideAndQueenside() {
        // Load position with cleared castling lanes
        // White king at e1, rooks at a1, h1
        engine.loadFEN("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
        
        let e1 = Square(string: "e1")!
        let g1 = Square(string: "g1")!
        let c1 = Square(string: "c1")!
        
        let moves = engine.legalMovesFrom(square: e1)
        XCTAssertTrue(moves.contains(ChessMove(from: e1, to: g1)))
        XCTAssertTrue(moves.contains(ChessMove(from: e1, to: c1)))
        
        // Execute kingside castling
        let success = engine.makeMove(ChessMove(from: e1, to: g1))
        XCTAssertTrue(success)
        XCTAssertEqual(engine.board[g1]?.type, .king)
        XCTAssertEqual(engine.board[Square(string: "f1")!]?.type, .rook)
    }
    
    func testCastlingThroughCheckIsIllegal() {
        // Black rook at e8 attacks e1 directly (King is in check)
        engine.loadFEN("4r2k/8/8/8/8/8/8/R3K2R w KQ - 0 1")
        XCTAssertTrue(engine.isCheck)
        
        let e1 = Square(string: "e1")!
        let g1 = Square(string: "g1")!
        let moves = engine.legalMovesFrom(square: e1)
        XCTAssertFalse(moves.contains(ChessMove(from: e1, to: g1)))
    }
    
    func testPawnPromotion() {
        engine.loadFEN("8/4P3/8/8/8/8/8/4K2k w - - 0 1")
        let e7 = Square(string: "e7")!
        let e8 = Square(string: "e8")!
        
        let promoQueen = ChessMove(from: e7, to: e8, promotion: .queen)
        XCTAssertTrue(engine.legalMoves().contains(promoQueen))
        
        let success = engine.makeMove(promoQueen)
        XCTAssertTrue(success)
        XCTAssertEqual(engine.board[e8]?.type, .queen)
        XCTAssertEqual(engine.board[e8]?.color, .white)
    }
    
    func testCheckmateScholarMate() {
        // 1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6 4. Qxf7#
        _ = engine.makeMove(from: "e2", to: "e4")
        _ = engine.makeMove(from: "e7", to: "e5")
        _ = engine.makeMove(from: "d1", to: "h5")
        _ = engine.makeMove(from: "b8", to: "c6")
        _ = engine.makeMove(from: "f1", to: "c4")
        _ = engine.makeMove(from: "g8", to: "f6")
        let mateMove = engine.makeMove(from: "h5", to: "f7")
        
        XCTAssertTrue(mateMove)
        XCTAssertTrue(engine.isCheck)
        XCTAssertTrue(engine.isCheckmate)
        XCTAssertTrue(engine.isGameOver)
        XCTAssertEqual(engine.gameResult, "White won by checkmate")
    }
    
    func testStalemate() {
        // King trapped without being in check
        engine.loadFEN("k7/8/1Q6/8/8/8/8/7K b - - 0 1")
        XCTAssertFalse(engine.isCheck)
        XCTAssertTrue(engine.isStalemate)
        XCTAssertTrue(engine.isGameOver)
        XCTAssertEqual(engine.gameResult, "Draw by stalemate")
    }
}
