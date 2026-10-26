import SwiftUI

public struct ChessBoardView: View {
    @Binding public var fen: String
    public var isFlipped: Bool
    public var selectedSquare: String?
    public var legalMoves: [String]
    public var lastMove: (from: String, to: String)?
    public var bestMove: String?
    public var isCheck: Bool
    public var onSquareTapped: (String) -> Void
    
    private let files = ["a", "b", "c", "d", "e", "f", "g", "h"]
    private let ranks = ["8", "7", "6", "5", "4", "3", "2", "1"]
    
    public init(
        fen: Binding<String>,
        isFlipped: Bool = false,
        selectedSquare: String? = nil,
        legalMoves: [String] = [],
        lastMove: (from: String, to: String)? = nil,
        bestMove: String? = nil,
        isCheck: Bool = false,
        onSquareTapped: @escaping (String) -> Void
    ) {
        self._fen = fen
        self.isFlipped = isFlipped
        self.selectedSquare = selectedSquare
        self.legalMoves = legalMoves
        self.lastMove = lastMove
        self.bestMove = bestMove
        self.isCheck = isCheck
        self.onSquareTapped = onSquareTapped
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let squareSize = size / 8.0
            
            let displayRanks = isFlipped ? ranks.reversed() : ranks
            let displayFiles = isFlipped ? files.reversed() : files
            let piecesMap = parsePiecesFromFEN(fen)
            
            ZStack {
                // 1. Grid of Squares
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { f in
                                let rank = displayRanks[r]
                                let file = displayFiles[f]
                                let squareName = "\(file)\(rank)"
                                let isLight = ((r + f) % 2 == 0)
                                
                                ZStack {
                                    // Base square background
                                    Rectangle()
                                        .fill(squareColor(isLight: isLight, square: squareName, piecesMap: piecesMap))
                                    
                                    // Coordinates labels
                                    if f == 0 {
                                        Text(rank)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(isLight ? Color(hex: "#779556") : Color(hex: "#ebecd0"))
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                            .padding(2)
                                    }
                                    if r == 7 {
                                        Text(file)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(isLight ? Color(hex: "#779556") : Color(hex: "#ebecd0"))
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                            .padding(2)
                                    }
                                    
                                    // Piece rendering with bold solid glyphs & high-contrast outlines
                                    if let piece = piecesMap[squareName] {
                                        Text(pieceGlyph(piece.type))
                                            .font(.system(size: squareSize * 0.78, weight: .bold))
                                            .foregroundColor(piece.color == .white ? Color(hex: "#ffffff") : Color(hex: "#1b1917"))
                                            .shadow(color: piece.color == .white ? Color(hex: "#141414") : Color(hex: "#ffffff").opacity(0.25), radius: piece.color == .white ? 1.5 : 0.6, x: 0, y: 1)
                                            .shadow(color: piece.color == .white ? Color(hex: "#141414") : Color.clear, radius: 0.5, x: 1, y: 0)
                                            .shadow(color: piece.color == .white ? Color(hex: "#141414") : Color.clear, radius: 0.5, x: -1, y: 0)
                                            .shadow(color: piece.color == .white ? Color(hex: "#141414") : Color.clear, radius: 0.5, x: 0, y: -1)
                                    }
                                    
                                    // Legal move indicator: dot for empty, ring for capture
                                    if legalMoves.contains(squareName) {
                                        if piecesMap[squareName] != nil {
                                            Circle()
                                                .strokeBorder(Color.red.opacity(0.6), lineWidth: 4)
                                                .frame(width: squareSize * 0.82, height: squareSize * 0.82)
                                        } else {
                                            Circle()
                                                .fill(Color.black.opacity(0.24))
                                                .frame(width: squareSize * 0.32, height: squareSize * 0.32)
                                        }
                                    }
                                }
                                .frame(width: squareSize, height: squareSize)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSquareTapped(squareName)
                                }
                            }
                        }
                    }
                }
                
                // 2. Best Move Arrow Overlay
                if let bm = bestMove, bm.count >= 4 {
                    let fromStr = String(bm.prefix(2))
                    let toStr = String(bm.dropFirst(2).prefix(2))
                    if let fromPoint = squareCenter(square: fromStr, squareSize: squareSize, isFlipped: isFlipped),
                       let toPoint = squareCenter(square: toStr, squareSize: squareSize, isFlipped: isFlipped) {
                        ArrowShape(from: fromPoint, to: toPoint, headSize: squareSize * 0.38)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#1baca6").opacity(0.85), Color(hex: "#78a942").opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(width: size, height: size)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#312e2b"), lineWidth: 3)
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func squareCenter(square: String, squareSize: CGFloat, isFlipped: Bool) -> CGPoint? {
        guard square.count == 2 else { return nil }
        let fChar = square.prefix(1)
        let rChar = square.suffix(1)
        guard let fIdx = files.firstIndex(of: String(fChar)),
              let rIdx = ranks.firstIndex(of: String(rChar)) else { return nil }
        
        let col = isFlipped ? (7 - fIdx) : fIdx
        let row = isFlipped ? (7 - rIdx) : rIdx
        
        let x = (CGFloat(col) + 0.5) * squareSize
        let y = (CGFloat(row) + 0.5) * squareSize
        return CGPoint(x: x, y: y)
    }
    
    private func squareColor(isLight: Bool, square: String, piecesMap: [String: ChessPiece]) -> Color {
        // King under check highlight
        if isCheck, let piece = piecesMap[square], piece.type == .king {
            let activeColor = fen.contains(" w ") ? PieceColor.white : PieceColor.black
            if piece.color == activeColor {
                return Color(hex: "#cb3737").opacity(0.85) // Red check alert
            }
        }
        
        if square == selectedSquare {
            return Color(hex: "#f7f769").opacity(0.8) // Selected square
        }
        if let lm = lastMove, (square == lm.from || square == lm.to) {
            return Color(hex: "#ced84b").opacity(0.7) // Last move highlight
        }
        return isLight ? Color(hex: "#ebecd0") : Color(hex: "#779556")
    }
    
    private func parsePiecesFromFEN(_ fen: String) -> [String: ChessPiece] {
        var map: [String: ChessPiece] = [:]
        let parts = fen.split(separator: " ")
        guard let boardPart = parts.first else { return map }
        
        let rankRows = boardPart.split(separator: "/")
        for (rIdx, row) in rankRows.enumerated() {
            let rank = 8 - rIdx
            var fileIdx = 0
            for ch in row {
                if let emptyCount = ch.wholeNumberValue {
                    fileIdx += emptyCount
                } else {
                    let file = files[fileIdx]
                    let square = "\(file)\(rank)"
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
                    map[square] = ChessPiece(type: type, color: color)
                    fileIdx += 1
                }
            }
        }
        return map
    }
    
    private func pieceGlyph(_ type: PieceType) -> String {
        switch type {
        case .king: return "♚"
        case .queen: return "♛"
        case .rook: return "♜"
        case .bishop: return "♝"
        case .knight: return "♞"
        case .pawn: return "♟"
        }
    }
}

// Visual arrow shape for engine suggested move
public struct ArrowShape: Shape {
    public var from: CGPoint
    public var to: CGPoint
    public var headSize: CGFloat
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > headSize else { return path }
        
        let unitX = dx / length
        let unitY = dy / length
        let normalX = -unitY
        let normalY = unitX
        
        let shaftWidth: CGFloat = 8.0
        let headBase = CGPoint(
            x: to.x - unitX * headSize,
            y: to.y - unitY * headSize
        )
        
        // Arrow shaft
        let p1 = CGPoint(x: from.x + normalX * (shaftWidth / 2), y: from.y + normalY * (shaftWidth / 2))
        let p2 = CGPoint(x: headBase.x + normalX * (shaftWidth / 2), y: headBase.y + normalY * (shaftWidth / 2))
        let p3 = CGPoint(x: headBase.x + normalX * (headSize * 0.45), y: headBase.y + normalY * (headSize * 0.45))
        let p4 = to
        let p5 = CGPoint(x: headBase.x - normalX * (headSize * 0.45), y: headBase.y - normalY * (headSize * 0.45))
        let p6 = CGPoint(x: headBase.x - normalX * (shaftWidth / 2), y: headBase.y - normalY * (shaftWidth / 2))
        let p7 = CGPoint(x: from.x - normalX * (shaftWidth / 2), y: from.y - normalY * (shaftWidth / 2))
        
        path.move(to: p1)
        path.addLine(to: p2)
        path.addLine(to: p3)
        path.addLine(to: p4)
        path.addLine(to: p5)
        path.addLine(to: p6)
        path.addLine(to: p7)
        path.closeSubpath()
        
        return path
    }
}
