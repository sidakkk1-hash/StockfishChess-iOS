import Foundation

@MainActor
public final class GameReviewService: ObservableObject {
    public static let shared = GameReviewService()
    
    @Published public var isAnalyzing: Bool = false
    @Published public var progress: Double = 0.0
    @Published public var stats = GameReviewStats()
    @Published public var analyzedMoves: [MoveRecord] = []
    
    /// Converts a centipawn score to winning probability percentage (0 to 100)
    public func winningChance(cp: Int) -> Double {
        let cpClamped = max(-2000, min(2000, Double(cp)))
        return 50.0 + 50.0 * (2.0 / (1.0 + exp(-0.00368208 * cpClamped)) - 1.0)
    }
    
    /// Classifies move based on win probability loss and best move delta
    public func classifyMove(
        isWhite: Bool,
        playedMoveUci: String,
        bestMoveUci: String,
        evalBeforeCp: Int,
        evalAfterCp: Int
    ) -> BlunderClassification {
        // Direct match with best engine move
        if playedMoveUci == bestMoveUci {
            return .best
        }
        
        // Calculate perspective win chance
        let winBefore = isWhite ? winningChance(cp: evalBeforeCp) : (100.0 - winningChance(cp: evalBeforeCp))
        let winAfter = isWhite ? winningChance(cp: evalAfterCp) : (100.0 - winningChance(cp: evalAfterCp))
        let winLoss = max(0.0, winBefore - winAfter)
        
        if winLoss < 2.0 {
            return .excellent
        } else if winLoss < 5.0 {
            return .good
        } else if winLoss < 12.0 {
            return .inaccuracy
        } else if winLoss < 25.0 {
            return .mistake
        } else {
            return .blunder
        }
    }
    
    /// Analyzes a full array of move records using StockfishEngineService
    public func runReview(moves: [MoveRecord], depth: Int = 12) async {
        guard !moves.isEmpty else { return }
        isAnalyzing = true
        progress = 0.0
        stats = GameReviewStats()
        analyzedMoves = moves
        
        var whiteWinLossSum = 0.0
        var whiteMoveCount = 0
        var blackWinLossSum = 0.0
        var blackMoveCount = 0
        
        for index in 0..<analyzedMoves.count {
            let record = analyzedMoves[index]
            let isWhite = (record.ply % 2 != 0)
            
            do {
                // 1. Evaluate position before move to get best engine move and eval
                let evalBefore = try await StockfishEngineService.shared.evaluate(fen: record.fenBefore, depth: depth)
                let bestMove = evalBefore.bestMove ?? ""
                
                // 2. Evaluate position after move to get actual resulting eval
                let evalAfter = try await StockfishEngineService.shared.evaluate(fen: record.fenAfter, depth: depth)
                
                let classification = classifyMove(
                    isWhite: isWhite,
                    playedMoveUci: record.uci,
                    bestMoveUci: bestMove,
                    evalBeforeCp: evalBefore.scoreCentipawns,
                    evalAfterCp: evalAfter.scoreCentipawns
                )
                
                analyzedMoves[index].evalCentipawns = evalAfter.scoreCentipawns
                analyzedMoves[index].mateInMoves = evalAfter.mateIn
                analyzedMoves[index].bestMoveUci = bestMove
                analyzedMoves[index].classification = classification
                
                // Track statistics
                let winBefore = isWhite ? winningChance(cp: evalBefore.scoreCentipawns) : (100.0 - winningChance(cp: evalBefore.scoreCentipawns))
                let winAfter = isWhite ? winningChance(cp: evalAfter.scoreCentipawns) : (100.0 - winningChance(cp: evalAfter.scoreCentipawns))
                let loss = max(0.0, winBefore - winAfter)
                
                if isWhite {
                    whiteWinLossSum += loss
                    whiteMoveCount += 1
                    switch classification {
                    case .blunder: stats.whiteBlunders += 1
                    case .mistake: stats.whiteMistakes += 1
                    case .inaccuracy: stats.whiteInaccuracies += 1
                    default: break
                    }
                } else {
                    blackWinLossSum += loss
                    blackMoveCount += 1
                    switch classification {
                    case .blunder: stats.blackBlunders += 1
                    case .mistake: stats.blackMistakes += 1
                    case .inaccuracy: stats.blackInaccuracies += 1
                    default: break
                    }
                }
            } catch {
                print("[GameReviewService] Error evaluating ply \(record.ply): \(error.localizedDescription)")
            }
            
            progress = Double(index + 1) / Double(moves.count)
        }
        
        // Calculate Accuracy formula: 100 - (2 * avg win loss)
        if whiteMoveCount > 0 {
            let avgLoss = whiteWinLossSum / Double(whiteMoveCount)
            stats.whiteAccuracy = max(0.0, min(100.0, 100.0 - (1.8 * avgLoss)))
        }
        if blackMoveCount > 0 {
            let avgLoss = blackWinLossSum / Double(blackMoveCount)
            stats.blackAccuracy = max(0.0, min(100.0, 100.0 - (1.8 * avgLoss)))
        }
        
        isAnalyzing = false
    }
}
