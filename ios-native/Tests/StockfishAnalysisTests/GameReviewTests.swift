import XCTest
@testable import StockfishAnalysis

final class GameReviewTests: XCTestCase {
    @MainActor
    func testWinProbabilityFormula() {
        let service = GameReviewService.shared
        
        // 0 centipawns should yield exactly 50% win probability
        let p0 = service.winningChance(cp: 0)
        XCTAssertEqual(p0, 50.0, accuracy: 0.1)
        
        // +300 centipawns should yield ~75% win chance
        let p300 = service.winningChance(cp: 300)
        XCTAssertGreaterThan(p300, 70.0)
        XCTAssertLessThan(p300, 85.0)
        
        // -300 centipawns should yield ~25% win chance
        let pNeg300 = service.winningChance(cp: -300)
        XCTAssertGreaterThan(pNeg300, 15.0)
        XCTAssertLessThan(pNeg300, 30.0)
    }
    
    @MainActor
    func testMoveClassificationCategories() {
        let service = GameReviewService.shared
        
        // Direct match with best move -> .best
        let clsBest = service.classifyMove(
            isWhite: true,
            playedMoveUci: "e2e4",
            bestMoveUci: "e2e4",
            evalBeforeCp: 20,
            evalAfterCp: 25
        )
        XCTAssertEqual(clsBest, .best)
        
        // Catastrophic blunder (e.g. going from +150 to -400)
        let clsBlunder = service.classifyMove(
            isWhite: true,
            playedMoveUci: "g2g4",
            bestMoveUci: "e2e4",
            evalBeforeCp: 150,
            evalAfterCp: -400
        )
        XCTAssertEqual(clsBlunder, .blunder)
        
        // Inaccuracy (slight win loss)
        let clsInacc = service.classifyMove(
            isWhite: true,
            playedMoveUci: "a2a3",
            bestMoveUci: "e2e4",
            evalBeforeCp: 30,
            evalAfterCp: -10
        )
        XCTAssertTrue(clsInacc == .inaccuracy || clsInacc == .good)
    }
}
