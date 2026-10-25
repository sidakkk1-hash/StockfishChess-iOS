import Foundation

public enum PieceColor: String, Codable {
    case white = "w"
    case black = "b"
    
    public var opposite: PieceColor {
        return self == .white ? .black : .white
    }
}

public enum PieceType: String, Codable {
    case pawn = "p"
    case knight = "n"
    case bishop = "b"
    case rook = "r"
    case queen = "q"
    case king = "k"
}

public struct ChessPiece: Identifiable, Equatable, Codable {
    public let id: String
    public let type: PieceType
    public let color: PieceColor
    
    public init(type: PieceType, color: PieceColor, id: String = UUID().uuidString) {
        self.type = type
        self.color = color
        self.id = id
    }
}

public enum BlunderClassification: String, CaseIterable, Codable {
    case brilliant = "Brilliant"
    case best = "Best"
    case excellent = "Excellent"
    case good = "Good"
    case inaccuracy = "Inaccuracy"
    case mistake = "Mistake"
    case blunder = "Blunder"
    case book = "Book"
    case forced = "Forced"
    
    public var icon: String {
        switch self {
        case .brilliant: return "sparkles"
        case .best: return "star.fill"
        case .excellent: return "hand.thumbsup.fill"
        case .good: return "checkmark"
        case .inaccuracy: return "questionmark"
        case .mistake: return "exclamationmark"
        case .blunder: return "exclamationmark.triangle.fill"
        case .book: return "book.closed.fill"
        case .forced: return "arrow.right"
        }
    }
    
    public var colorHex: String {
        switch self {
        case .brilliant: return "#1baca6"
        case .best: return "#95b542"
        case .excellent: return "#78a942"
        case .good: return "#5c8bb0"
        case .inaccuracy: return "#e58f2a"
        case .mistake: return "#e65722"
        case .blunder: return "#cb3737"
        case .book: return "#a88865"
        case .forced: return "#888888"
        }
    }
}

public struct MoveRecord: Identifiable, Equatable, Codable {
    public let id: String
    public let moveNumber: Int
    public let ply: Int
    public let san: String
    public let uci: String
    public let fenBefore: String
    public let fenAfter: String
    public var evalCentipawns: Int?
    public var mateInMoves: Int?
    public var bestMoveUci: String?
    public var classification: BlunderClassification?
    
    public init(
        id: String = UUID().uuidString,
        moveNumber: Int,
        ply: Int,
        san: String,
        uci: String,
        fenBefore: String,
        fenAfter: String,
        evalCentipawns: Int? = nil,
        mateInMoves: Int? = nil,
        bestMoveUci: String? = nil,
        classification: BlunderClassification? = nil
    ) {
        self.id = id
        self.moveNumber = moveNumber
        self.ply = ply
        self.san = san
        self.uci = uci
        self.fenBefore = fenBefore
        self.fenAfter = fenAfter
        self.evalCentipawns = evalCentipawns
        self.mateInMoves = mateInMoves
        self.bestMoveUci = bestMoveUci
        self.classification = classification
    }
}

public struct EngineEvaluation: Equatable {
    public var depth: Int = 0
    public var scoreCentipawns: Int = 0
    public var mateIn: Int? = nil
    public var nodes: Int = 0
    public var nps: Int = 0
    public var pv: [String] = []
    public var bestMove: String? = nil
    public var isCalculating: Bool = false
    public var statusMessage: String = "Engine Ready"
    public var errorMessage: String? = nil
    
    public init() {}
    
    public var formattedScore: String {
        if let mate = mateIn {
            return "M\(mate > 0 ? "+\(mate)" : "\(mate)")"
        }
        let score = Double(scoreCentipawns) / 100.0
        return String(format: "%+.2f", score)
    }
}

public struct GameReviewStats: Equatable, Codable {
    public var whiteAccuracy: Double = 0.0
    public var blackAccuracy: Double = 0.0
    public var whiteBlunders: Int = 0
    public var whiteMistakes: Int = 0
    public var whiteInaccuracies: Int = 0
    public var blackBlunders: Int = 0
    public var blackMistakes: Int = 0
    public var blackInaccuracies: Int = 0
    
    public init() {}
}
