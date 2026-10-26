import Foundation
import Combine

public enum EngineError: LocalizedError {
    case engineNotInitialized
    case missingEngineBinary
    case missingNNUEWeights(String)
    case timeout
    case executionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .engineNotInitialized:
            return "Stockfish engine is not initialized or still starting up."
        case .missingEngineBinary:
            return "Stockfish engine executable or dynamic library was not found in the application bundle."
        case .missingNNUEWeights(let file):
            return "Required NNUE evaluation network '\(file)' is missing or corrupt. Check app bundle resources."
        case .timeout:
            return "Engine response timed out during position evaluation."
        case .executionFailed(let reason):
            return "Engine error: \(reason)"
        }
    }
}

@MainActor
public final class StockfishEngineService: ObservableObject {
    public static let shared = StockfishEngineService()
    
    @Published public var currentEvaluation = EngineEvaluation()
    @Published public var isReady: Bool = false
    @Published public var engineError: EngineError? = nil
    @Published public var targetDepth: Int = 16
    
    private var isAnalyzing: Bool = false
    private var analysisContinuation: CheckedContinuation<EngineEvaluation, Error>?
    
    public init() {
        startEngine()
    }
    
    public func startEngine() {
        // Validate bundle resources
        guard validateEngineResources() else {
            return
        }
        
        StockfishBridge.sharedInstance().onOutput = { [weak self] line in
            guard let self = self else { return }
            self.handleEngineOutput(line)
        }
        
        StockfishBridge.sharedInstance().onError = { [weak self] errorMsg in
            guard let self = self else { return }
            self.engineError = .executionFailed(errorMsg)
        }
        
        let success = StockfishBridge.sharedInstance().startEngine()
        if !success {
            self.engineError = .missingEngineBinary
            return
        }
        
        // Initial UCI handshake
        sendCommand("uci")
    }
    
    public func sendCommand(_ command: String) {
        StockfishBridge.sharedInstance().sendCommand(command)
    }
    
    public func stop() {
        StockfishBridge.sharedInstance().stopCalculation()
        currentEvaluation.isCalculating = false
    }
    
    public func evaluate(fen: String, depth: Int? = nil) async throws -> EngineEvaluation {
        stop()
        
        if let cont = analysisContinuation {
            analysisContinuation = nil
            cont.resume(returning: currentEvaluation)
        }
        
        let searchDepth = depth ?? targetDepth
        currentEvaluation.isCalculating = true
        currentEvaluation.statusMessage = "Analyzing depth \(searchDepth)..."
        
        return try await withCheckedThrowingContinuation { continuation in
            self.analysisContinuation = continuation
            self.sendCommand("position fen \(fen)")
            self.sendCommand("go depth \(searchDepth)")
        }
    }
    
    public func startAnalysis(fen: String, depth: Int? = nil) {
        stop()
        if let cont = analysisContinuation {
            analysisContinuation = nil
            cont.resume(returning: currentEvaluation)
        }
        let searchDepth = depth ?? targetDepth
        currentEvaluation.isCalculating = true
        currentEvaluation.statusMessage = "Analyzing depth \(searchDepth)..."
        sendCommand("position fen \(fen)")
        sendCommand("go depth \(searchDepth)")
    }
    
    private func handleEngineOutput(_ rawLine: String) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty { return }
        
        // Error detection
        if line.contains("Network file") && line.contains("not found") {
            engineError = .missingNNUEWeights("nn-network.nnue")
            return
        }
        
        if line == "uciok" {
            sendCommand("isready")
        } else if line == "readyok" {
            isReady = true
            currentEvaluation.statusMessage = "Stockfish 19 Engine Ready"
        } else if line.starts(with: "info") {
            parseInfoLine(line)
        } else if line.starts(with: "bestmove") {
            parseBestMoveLine(line)
        }
    }
    
    private func parseInfoLine(_ line: String) {
        let parts = line.split(separator: " ").map(String.init)
        var i = 0
        while i < parts.count {
            let key = parts[i]
            if key == "depth", i + 1 < parts.count, let d = Int(parts[i+1]) {
                currentEvaluation.depth = d
                i += 2
            } else if key == "score", i + 2 < parts.count {
                let type = parts[i+1]
                let val = parts[i+2]
                if type == "cp", let cp = Int(val) {
                    currentEvaluation.scoreCentipawns = cp
                    currentEvaluation.mateIn = nil
                } else if type == "mate", let m = Int(val) {
                    currentEvaluation.mateIn = m
                }
                i += 3
            } else if key == "nodes", i + 1 < parts.count, let n = Int(parts[i+1]) {
                currentEvaluation.nodes = n
                i += 2
            } else if key == "nps", i + 1 < parts.count, let nps = Int(parts[i+1]) {
                currentEvaluation.nps = nps
                i += 2
            } else if key == "pv", i + 1 < parts.count {
                let pvArray = Array(parts[(i+1)...])
                currentEvaluation.pv = pvArray
                if let first = pvArray.first, first.count >= 4 {
                    // Update bestMove immediately during iterative deepening
                    currentEvaluation.bestMove = first
                }
                break
            } else {
                i += 1
            }
        }
    }
    
    private func parseBestMoveLine(_ line: String) {
        let parts = line.split(separator: " ").map(String.init)
        if parts.count >= 2 {
            let move = parts[1]
            if move == "0000" || move == "(none)" {
                return // Ignore aborted search placeholder
            }
            currentEvaluation.bestMove = move
            currentEvaluation.isCalculating = false
            currentEvaluation.statusMessage = "Analysis Complete: \(move)"
            
            if let cont = analysisContinuation {
                analysisContinuation = nil
                cont.resume(returning: currentEvaluation)
            }
        }
    }
    
    private func validateEngineResources() -> Bool {
        // Validate bundle exists
        guard let _ = Bundle.main.resourcePath else {
            engineError = .missingEngineBinary
            return false
        }
        return true
    }
}
