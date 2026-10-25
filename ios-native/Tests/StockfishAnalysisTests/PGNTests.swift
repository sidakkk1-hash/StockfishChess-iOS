import XCTest
@testable import StockfishAnalysis

final class PGNTests: XCTestCase {
    func testPGNParserExtractsHeadersAndMoves() {
        let samplePGN = """
        [Event "World Championship"]
        [Site "Reykjavik"]
        [Date "1972.07.23"]
        [White "Spassky, Boris V"]
        [Black "Fischer, Robert J"]
        [Result "0-1"]

        1. d4 Nf6 2. c4 e6 3. Nf3 d5 4. Nc3 Be7 0-1
        """
        
        let parsed = PGNParserService.shared.parse(pgn: samplePGN)
        XCTAssertEqual(parsed.whitePlayer, "Spassky, Boris V")
        XCTAssertEqual(parsed.blackPlayer, "Fischer, Robert J")
        XCTAssertEqual(parsed.result, "0-1")
        XCTAssertEqual(parsed.moves.count, 8)
        XCTAssertEqual(parsed.moves[0], "d4")
        XCTAssertEqual(parsed.moves[1], "Nf6")
        XCTAssertEqual(parsed.moves[7], "Be7")
    }
    
    func testPGNExport() {
        let moves = [
            MoveRecord(moveNumber: 1, ply: 1, san: "e4", uci: "e2e4", fenBefore: "", fenAfter: ""),
            MoveRecord(moveNumber: 1, ply: 2, san: "e5", uci: "e7e5", fenBefore: "", fenAfter: ""),
            MoveRecord(moveNumber: 2, ply: 3, san: "Nf3", uci: "g1f3", fenBefore: "", fenAfter: "")
        ]
        
        let pgn = PGNParserService.shared.exportPGN(moves: moves, headers: [
            "White": "Alice",
            "Black": "Bob",
            "Result": "*"
        ])
        
        XCTAssertTrue(pgn.contains("[White \"Alice\"]"))
        XCTAssertTrue(pgn.contains("[Black \"Bob\"]"))
        XCTAssertTrue(pgn.contains("1. e4 e5 2. Nf3 *"))
    }
}
