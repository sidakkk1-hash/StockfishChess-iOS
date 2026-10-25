import Foundation

// MARK: - Core Chess Types & Representation

public struct Square: Hashable, Equatable, CustomStringConvertible {
    public let file: Int // 0..7 (a..h)
    public let rank: Int // 0..7 (1..8)
    
    public init(file: Int, rank: Int) {
        self.file = file
        self.rank = rank
    }
    
    public init?(string: String) {
        guard string.count == 2 else { return nil }
        let chars = Array(string.lowercased())
        guard let f = chars[0].asciiValue, f >= 97 && f <= 104,
              let r = chars[1].wholeNumberValue, r >= 1 && r <= 8 else {
            return nil
        }
        self.file = Int(f - 97)
        self.rank = r - 1
    }
    
    public var description: String {
        let f = Character(UnicodeScalar(97 + file)!)
        return "\(f)\(rank + 1)"
    }
    
    public var isValid: Bool {
        return file >= 0 && file < 8 && rank >= 0 && rank < 8
    }
}

public struct ChessMove: Equatable, Hashable {
    public let from: Square
    public let to: Square
    public let promotion: PieceType?
    
    public init(from: Square, to: Square, promotion: PieceType? = nil) {
        self.from = from
        self.to = to
        self.promotion = promotion
    }
    
    public var uci: String {
        let base = "\(from.description)\(to.description)"
        if let promo = promotion {
            return "\(base)\(promo.rawValue)"
        }
        return base
    }
}

public struct CastlingRights: Equatable, Codable {
    public var whiteKingside: Bool = true
    public var whiteQueenside: Bool = true
    public var blackKingside: Bool = true
    public var blackQueenside: Bool = true
    
    public init() {}
    
    public var fenString: String {
        var str = ""
        if whiteKingside { str += "K" }
        if whiteQueenside { str += "Q" }
        if blackKingside { str += "k" }
        if blackQueenside { str += "q" }
        return str.isEmpty ? "-" : str
    }
    
    public init(fenString: String) {
        whiteKingside = fenString.contains("K")
        whiteQueenside = fenString.contains("Q")
        blackKingside = fenString.contains("k")
        blackQueenside = fenString.contains("q")
    }
}

public struct GameMoveRecord: Equatable {
    public let move: ChessMove
    public let piece: ChessPiece
    public let capturedPiece: ChessPiece?
    public let san: String
    public let fenBefore: String
    public let fenAfter: String
    public let isEnPassant: Bool
    public let isCastling: Bool
    public let isCheck: Bool
    public let isCheckmate: Bool
}

// MARK: - Complete FIDE Legal Chess Rules Engine

public final class ChessRulesEngine {
    public var board: [Square: ChessPiece] = [:]
    public var activeColor: PieceColor = .white
    public var castlingRights: CastlingRights = CastlingRights()
    public var enPassantSquare: Square? = nil
    public var halfmoveClock: Int = 0
    public var fullmoveNumber: Int = 1
    
    public private(set) var moveHistory: [GameMoveRecord] = []
    public private(set) var capturedWhite: [ChessPiece] = []
    public private(set) var capturedBlack: [ChessPiece] = []
    
    public init() {
        setupStartingPosition()
    }
    
    public func setupStartingPosition() {
        loadFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    }
    
    public func reset() {
        moveHistory.removeAll()
        capturedWhite.removeAll()
        capturedBlack.removeAll()
        setupStartingPosition()
    }
    
    // MARK: - FEN Serialization & Parsing
    
    public func loadFEN(_ fen: String) {
        board.removeAll()
        moveHistory.removeAll()
        capturedWhite.removeAll()
        capturedBlack.removeAll()
        
        let parts = fen.split(separator: " ")
        guard !parts.isEmpty else { return }
        
        // 1. Piece placement
        let ranks = parts[0].split(separator: "/")
        for (rIdx, rankRow) in ranks.enumerated() {
            let rank = 7 - rIdx
            var file = 0
            for ch in rankRow {
                if let count = ch.wholeNumberValue {
                    file += count
                } else {
                    let color: PieceColor = ch.isUppercase ? .white : .black
                    let lower = ch.lowercased()
                    let type: PieceType
                    switch lower {
                    case "p": type = .pawn
                    case "n": type = .knight
                    case "b": type = .bishop
                    case "r": type = .rook
                    case "q": type = .queen
                    case "k": type = .king
                    default: type = .pawn
                    }
                    let sq = Square(file: file, rank: rank)
                    board[sq] = ChessPiece(type: type, color: color)
                    file += 1
                }
            }
        }
        
        // 2. Active color
        if parts.count > 1 {
            activeColor = (parts[1] == "b") ? .black : .white
        } else {
            activeColor = .white
        }
        
        // 3. Castling rights
        if parts.count > 2 {
            castlingRights = CastlingRights(fenString: String(parts[2]))
        } else {
            castlingRights = CastlingRights()
        }
        
        // 4. En passant square
        if parts.count > 3 && parts[3] != "-" {
            enPassantSquare = Square(string: String(parts[3]))
        } else {
            enPassantSquare = nil
        }
        
        // 5. Halfmove clock
        if parts.count > 4, let h = Int(parts[4]) {
            halfmoveClock = h
        } else {
            halfmoveClock = 0
        }
        
        // 6. Fullmove number
        if parts.count > 5, let f = Int(parts[5]) {
            fullmoveNumber = f
        } else {
            fullmoveNumber = 1
        }
    }
    
    public func getFEN() -> String {
        var fenRows: [String] = []
        for r in stride(from: 7, through: 0, by: -1) {
            var rowStr = ""
            var emptyCount = 0
            for f in 0..<8 {
                let sq = Square(file: f, rank: r)
                if let piece = board[sq] {
                    if emptyCount > 0 {
                        rowStr += "\(emptyCount)"
                        emptyCount = 0
                    }
                    let letter = piece.type.rawValue
                    rowStr += piece.color == .white ? letter.uppercased() : letter.lowercased()
                } else {
                    emptyCount += 1
                }
            }
            if emptyCount > 0 {
                rowStr += "\(emptyCount)"
            }
            fenRows.append(rowStr)
        }
        
        let boardPart = fenRows.joined(separator: "/")
        let colorPart = activeColor.rawValue
        let castlingPart = castlingRights.fenString
        let epPart = enPassantSquare?.description ?? "-"
        return "\(boardPart) \(colorPart) \(castlingPart) \(epPart) \(halfmoveClock) \(fullmoveNumber)"
    }
    
    // MARK: - Legal Move Generation
    
    public func legalMoves(for color: PieceColor? = nil) -> [ChessMove] {
        let side = color ?? activeColor
        let pseudo = generatePseudoLegalMoves(for: side)
        return pseudo.filter { move in
            let clone = self.cloneState()
            clone.applyMoveUnchecked(move)
            return !clone.isKingInCheck(side)
        }
    }
    
    public func legalMovesFrom(square: Square) -> [ChessMove] {
        guard let piece = board[square], piece.color == activeColor else { return [] }
        return legalMoves().filter { $0.from == square }
    }
    
    public func makeMove(_ move: ChessMove) -> Bool {
        let legals = legalMoves()
        guard legals.contains(move) else {
            // Check promotion without explicit promo piece specified
            if move.promotion == nil {
                if let promoMove = legals.first(where: { $0.from == move.from && $0.to == move.to && $0.promotion == .queen }) {
                    return executeVerifiedMove(promoMove)
                }
            }
            return false
        }
        return executeVerifiedMove(move)
    }
    
    public func makeMove(from: String, to: String, promotion: PieceType? = nil) -> Bool {
        guard let fSq = Square(string: from), let tSq = Square(string: to) else { return false }
        return makeMove(ChessMove(from: fSq, to: tSq, promotion: promotion))
    }
    
    private func executeVerifiedMove(_ move: ChessMove) -> Bool {
        guard let movingPiece = board[move.from] else { return false }
        let fenBefore = getFEN()
        
        // Track captured piece
        var capturedPiece = board[move.to]
        let isEnPassant = (movingPiece.type == .pawn && move.to == enPassantSquare)
        if isEnPassant {
            let capturedPawnSq = Square(file: move.to.file, rank: move.from.rank)
            capturedPiece = board[capturedPawnSq]
            board.removeValue(forKey: capturedPawnSq)
        }
        
        // Track castling
        let isCastling = (movingPiece.type == .king && abs(move.to.file - move.from.file) == 2)
        
        // Apply board change
        board.removeValue(forKey: move.from)
        if let promo = move.promotion {
            board[move.to] = ChessPiece(type: promo, color: movingPiece.color)
        } else {
            board[move.to] = movingPiece
        }
        
        // Move rook if castling
        if isCastling {
            let rank = move.from.rank
            if move.to.file == 6 { // Kingside
                let rook = board[Square(file: 7, rank: rank)]
                board.removeValue(forKey: Square(file: 7, rank: rank))
                board[Square(file: 5, rank: rank)] = rook
            } else if move.to.file == 2 { // Queenside
                let rook = board[Square(file: 0, rank: rank)]
                board.removeValue(forKey: Square(file: 0, rank: rank))
                board[Square(file: 3, rank: rank)] = rook
            }
        }
        
        // Update Castling Rights
        if movingPiece.type == .king {
            if movingPiece.color == .white {
                castlingRights.whiteKingside = false
                castlingRights.whiteQueenside = false
            } else {
                castlingRights.blackKingside = false
                castlingRights.blackQueenside = false
            }
        } else if movingPiece.type == .rook {
            if move.from == Square(file: 0, rank: 0) { castlingRights.whiteQueenside = false }
            if move.from == Square(file: 7, rank: 0) { castlingRights.whiteKingside = false }
            if move.from == Square(file: 0, rank: 7) { castlingRights.blackQueenside = false }
            if move.from == Square(file: 7, rank: 7) { castlingRights.blackKingside = false }
        }
        if move.to == Square(file: 0, rank: 0) { castlingRights.whiteQueenside = false }
        if move.to == Square(file: 7, rank: 0) { castlingRights.whiteKingside = false }
        if move.to == Square(file: 0, rank: 7) { castlingRights.blackQueenside = false }
        if move.to == Square(file: 7, rank: 7) { castlingRights.blackKingside = false }
        
        // Update En Passant Square
        if movingPiece.type == .pawn && abs(move.to.rank - move.from.rank) == 2 {
            let epRank = (move.from.rank + move.to.rank) / 2
            enPassantSquare = Square(file: move.from.file, rank: epRank)
        } else {
            enPassantSquare = nil
        }
        
        // Halfmove clock (50-move rule reset on pawn move or capture)
        if movingPiece.type == .pawn || capturedPiece != nil {
            halfmoveClock = 0
        } else {
            halfmoveClock += 1
        }
        
        // Track captured list
        if let cap = capturedPiece {
            if cap.color == .white {
                capturedWhite.append(cap)
            } else {
                capturedBlack.append(cap)
            }
        }
        
        // Switch turn
        let nextColor: PieceColor = (activeColor == .white) ? .black : .white
        activeColor = nextColor
        if nextColor == .white {
            fullmoveNumber += 1
        }
        
        let fenAfter = getFEN()
        let inCheck = isKingInCheck(nextColor)
        let checkmate = inCheck && legalMoves().isEmpty
        
        // Build SAN Notation
        let san = buildSAN(
            move: move,
            piece: movingPiece,
            captured: capturedPiece != nil,
            isCastling: isCastling,
            inCheck: inCheck,
            checkmate: checkmate
        )
        
        let record = GameMoveRecord(
            move: move,
            piece: movingPiece,
            capturedPiece: capturedPiece,
            san: san,
            fenBefore: fenBefore,
            fenAfter: fenAfter,
            isEnPassant: isEnPassant,
            isCastling: isCastling,
            isCheck: inCheck,
            isCheckmate: checkmate
        )
        moveHistory.append(record)
        return true
    }
    
    public func undoLastMove() -> Bool {
        guard !moveHistory.isEmpty else { return false }
        moveHistory.removeLast()
        
        // Rebuild state from history
        if let last = moveHistory.last {
            loadFEN(last.fenAfter)
        } else {
            setupStartingPosition()
        }
        return true
    }
    
    // MARK: - Game Status
    
    public var isCheck: Bool {
        return isKingInCheck(activeColor)
    }
    
    public var isCheckmate: Bool {
        return isCheck && legalMoves().isEmpty
    }
    
    public var isStalemate: Bool {
        return !isCheck && legalMoves().isEmpty
    }
    
    public var isDrawByFiftyMoveRule: Bool {
        return halfmoveClock >= 100 // 50 full moves = 100 plies
    }
    
    public var isGameOver: Bool {
        return isCheckmate || isStalemate || isDrawByFiftyMoveRule
    }
    
    public var gameResult: String {
        if isCheckmate {
            return (activeColor == .white) ? "Black won by checkmate" : "White won by checkmate"
        }
        if isStalemate {
            return "Draw by stalemate"
        }
        if isDrawByFiftyMoveRule {
            return "Draw by 50-move rule"
        }
        return "In Progress"
    }
    
    // MARK: - Check & Attack Logic
    
    public func isKingInCheck(_ color: PieceColor) -> Bool {
        guard let kingSq = board.first(where: { $0.value.type == .king && $0.value.color == color })?.key else {
            return false
        }
        return isSquareAttacked(kingSq, by: color.opposite)
    }
    
    public func isSquareAttacked(_ target: Square, by attackerColor: PieceColor) -> Bool {
        // 1. Attacked by Knight
        let knightDeltas = [
            (-2, -1), (-2, 1), (-1, -2), (-1, 2),
            (1, -2), (1, 2), (2, -1), (2, 1)
        ]
        for (df, dr) in knightDeltas {
            let sq = Square(file: target.file + df, rank: target.rank + dr)
            if sq.isValid, let p = board[sq], p.color == attackerColor && p.type == .knight {
                return true
            }
        }
        
        // 2. Attacked by King (1 step)
        let kingDeltas = [
            (-1, -1), (-1, 0), (-1, 1), (0, -1),
            (0, 1), (1, -1), (1, 0), (1, 1)
        ]
        for (df, dr) in kingDeltas {
            let sq = Square(file: target.file + df, rank: target.rank + dr)
            if sq.isValid, let p = board[sq], p.color == attackerColor && p.type == .king {
                return true
            }
        }
        
        // 3. Attacked by Pawn
        let pawnAttackRank = (attackerColor == .white) ? target.rank - 1 : target.rank + 1
        for df in [-1, 1] {
            let sq = Square(file: target.file + df, rank: pawnAttackRank)
            if sq.isValid, let p = board[sq], p.color == attackerColor && p.type == .pawn {
                return true
            }
        }
        
        // 4. Straight lines (Rook / Queen)
        let straightDirs = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        for (df, dr) in straightDirs {
            var f = target.file + df
            var r = target.rank + dr
            while f >= 0 && f < 8 && r >= 0 && r < 8 {
                let sq = Square(file: f, rank: r)
                if let p = board[sq] {
                    if p.color == attackerColor && (p.type == .rook || p.type == .queen) {
                        return true
                    }
                    break // Blocked by piece
                }
                f += df
                r += dr
            }
        }
        
        // 5. Diagonals (Bishop / Queen)
        let diagDirs = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        for (df, dr) in diagDirs {
            var f = target.file + df
            var r = target.rank + dr
            while f >= 0 && f < 8 && r >= 0 && r < 8 {
                let sq = Square(file: f, rank: r)
                if let p = board[sq] {
                    if p.color == attackerColor && (p.type == .bishop || p.type == .queen) {
                        return true
                    }
                    break // Blocked
                }
                f += df
                r += dr
            }
        }
        
        return false
    }
    
    // MARK: - Pseudo-Legal Move Generation
    
    private func generatePseudoLegalMoves(for color: PieceColor) -> [ChessMove] {
        var moves: [ChessMove] = []
        for (sq, piece) in board where piece.color == color {
            switch piece.type {
            case .pawn:
                generatePawnMoves(from: sq, color: color, into: &moves)
            case .knight:
                generateKnightMoves(from: sq, color: color, into: &moves)
            case .bishop:
                generateSlidingMoves(from: sq, color: color, directions: [(1, 1), (1, -1), (-1, 1), (-1, -1)], into: &moves)
            case .rook:
                generateSlidingMoves(from: sq, color: color, directions: [(0, 1), (0, -1), (1, 0), (-1, 0)], into: &moves)
            case .queen:
                generateSlidingMoves(from: sq, color: color, directions: [
                    (1, 1), (1, -1), (-1, 1), (-1, -1),
                    (0, 1), (0, -1), (1, 0), (-1, 0)
                ], into: &moves)
            case .king:
                generateKingMoves(from: sq, color: color, into: &moves)
            }
        }
        return moves
    }
    
    private func generatePawnMoves(from sq: Square, color: PieceColor, into moves: inout [ChessMove]) {
        let forward = (color == .white) ? 1 : -1
        let startRank = (color == .white) ? 1 : 6
        let promoRank = (color == .white) ? 7 : 0
        
        // 1-step forward
        let oneSq = Square(file: sq.file, rank: sq.rank + forward)
        if oneSq.isValid && board[oneSq] == nil {
            if oneSq.rank == promoRank {
                for p in [PieceType.queen, .rook, .bishop, .knight] {
                    moves.append(ChessMove(from: sq, to: oneSq, promotion: p))
                }
            } else {
                moves.append(ChessMove(from: sq, to: oneSq))
                
                // 2-step forward
                if sq.rank == startRank {
                    let twoSq = Square(file: sq.file, rank: sq.rank + 2 * forward)
                    if twoSq.isValid && board[twoSq] == nil {
                        moves.append(ChessMove(from: sq, to: twoSq))
                    }
                }
            }
        }
        
        // Diagonals (captures & en passant)
        for df in [-1, 1] {
            let capSq = Square(file: sq.file + df, rank: sq.rank + forward)
            if capSq.isValid {
                if let targetPiece = board[capSq], targetPiece.color != color {
                    if capSq.rank == promoRank {
                        for p in [PieceType.queen, .rook, .bishop, .knight] {
                            moves.append(ChessMove(from: sq, to: capSq, promotion: p))
                        }
                    } else {
                        moves.append(ChessMove(from: sq, to: capSq))
                    }
                } else if capSq == enPassantSquare {
                    moves.append(ChessMove(from: sq, to: capSq))
                }
            }
        }
    }
    
    private func generateKnightMoves(from sq: Square, color: PieceColor, into moves: inout [ChessMove]) {
        let deltas = [
            (-2, -1), (-2, 1), (-1, -2), (-1, 2),
            (1, -2), (1, 2), (2, -1), (2, 1)
        ]
        for (df, dr) in deltas {
            let toSq = Square(file: sq.file + df, rank: sq.rank + dr)
            if toSq.isValid {
                if let p = board[toSq] {
                    if p.color != color { moves.append(ChessMove(from: sq, to: toSq)) }
                } else {
                    moves.append(ChessMove(from: sq, to: toSq))
                }
            }
        }
    }
    
    private func generateSlidingMoves(from sq: Square, color: PieceColor, directions: [(Int, Int)], into moves: inout [ChessMove]) {
        for (df, dr) in directions {
            var f = sq.file + df
            var r = sq.rank + dr
            while f >= 0 && f < 8 && r >= 0 && r < 8 {
                let toSq = Square(file: f, rank: r)
                if let p = board[toSq] {
                    if p.color != color {
                        moves.append(ChessMove(from: sq, to: toSq))
                    }
                    break
                } else {
                    moves.append(ChessMove(from: sq, to: toSq))
                }
                f += df
                r += dr
            }
        }
    }
    
    private func generateKingMoves(from sq: Square, color: PieceColor, into moves: inout [ChessMove]) {
        let deltas = [
            (-1, -1), (-1, 0), (-1, 1), (0, -1),
            (0, 1), (1, -1), (1, 0), (1, 1)
        ]
        for (df, dr) in deltas {
            let toSq = Square(file: sq.file + df, rank: sq.rank + dr)
            if toSq.isValid {
                if let p = board[toSq] {
                    if p.color != color { moves.append(ChessMove(from: sq, to: toSq)) }
                } else {
                    moves.append(ChessMove(from: sq, to: toSq))
                }
            }
        }
        
        // Castling
        let rank = (color == .white) ? 0 : 7
        if sq == Square(file: 4, rank: rank) && !isKingInCheck(color) {
            // Kingside
            let canKingside = (color == .white) ? castlingRights.whiteKingside : castlingRights.blackKingside
            if canKingside {
                let f1 = Square(file: 5, rank: rank)
                let g1 = Square(file: 6, rank: rank)
                if board[f1] == nil && board[g1] == nil {
                    if !isSquareAttacked(f1, by: color.opposite) && !isSquareAttacked(g1, by: color.opposite) {
                        moves.append(ChessMove(from: sq, to: g1))
                    }
                }
            }
            
            // Queenside
            let canQueenside = (color == .white) ? castlingRights.whiteQueenside : castlingRights.blackQueenside
            if canQueenside {
                let d1 = Square(file: 3, rank: rank)
                let c1 = Square(file: 2, rank: rank)
                let b1 = Square(file: 1, rank: rank)
                if board[d1] == nil && board[c1] == nil && board[b1] == nil {
                    if !isSquareAttacked(d1, by: color.opposite) && !isSquareAttacked(c1, by: color.opposite) {
                        moves.append(ChessMove(from: sq, to: c1))
                    }
                }
            }
        }
    }
    
    // MARK: - SAN Builder
    
    private func buildSAN(
        move: ChessMove,
        piece: ChessPiece,
        captured: Bool,
        isCastling: Bool,
        inCheck: Bool,
        checkmate: Bool
    ) -> String {
        if isCastling {
            var s = (move.to.file == 6) ? "O-O" : "O-O-O"
            if checkmate { s += "#" }
            else if inCheck { s += "+" }
            return s
        }
        
        var san = ""
        if piece.type == .pawn {
            if captured {
                let fChar = Character(UnicodeScalar(97 + move.from.file)!)
                san = "\(fChar)x\(move.to.description)"
            } else {
                san = move.to.description
            }
            if let promo = move.promotion {
                san += "=\(promo.rawValue.uppercased())"
            }
        } else {
            let pieceLetters = ["k": "K", "q": "Q", "r": "R", "b": "B", "n": "N"]
            let pChar = pieceLetters[piece.type.rawValue] ?? ""
            san = pChar
            if captured { san += "x" }
            san += move.to.description
        }
        
        if checkmate {
            san += "#"
        } else if inCheck {
            san += "+"
        }
        return san
    }
    
    // MARK: - Helper Clone
    
    private func cloneState() -> ChessRulesEngine {
        let engine = ChessRulesEngine()
        engine.board = self.board
        engine.activeColor = self.activeColor
        engine.castlingRights = self.castlingRights
        engine.enPassantSquare = self.enPassantSquare
        engine.halfmoveClock = self.halfmoveClock
        engine.fullmoveNumber = self.fullmoveNumber
        return engine
    }
    
    private func applyMoveUnchecked(_ move: ChessMove) {
        guard let p = board[move.from] else { return }
        board.removeValue(forKey: move.from)
        if let promo = move.promotion {
            board[move.to] = ChessPiece(type: promo, color: p.color)
        } else {
            board[move.to] = p
        }
    }
}
