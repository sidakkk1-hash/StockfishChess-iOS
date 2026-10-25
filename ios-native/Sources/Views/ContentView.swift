import SwiftUI

public struct ContentView: View {
    @StateObject private var engine = StockfishEngineService.shared
    @StateObject private var reviewService = GameReviewService.shared
    
    // Core Chess Rules Engine State
    private let chessEngine = ChessRulesEngine()
    @State private var currentFen: String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    @State private var isFlipped: Bool = false
    @State private var playerColor: PieceColor = .white
    @State private var selectedSquare: String? = nil
    @State private var legalMoveDestinations: [String] = []
    @State private var moves: [MoveRecord] = []
    @State private var currentPly: Int = 0
    @State private var isCheck: Bool = false
    @State private var isGameOver: Bool = false
    @State private var gameOverMessage: String = ""
    
    // Promotion Pending State
    @State private var pendingPromotionFrom: Square? = nil
    @State private var pendingPromotionTo: Square? = nil
    @State private var showPromotionSheet: Bool = false
    
    // UI Sheets & Settings
    @State private var showImportSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var targetDepth: Double = 14
    @State private var autoAnalyze: Bool = true
    @State private var boardThemeIndex: Int = 0
    @State private var soundEnabled: Bool = true
    
    // Material tracking
    @State private var capturedWhite: [ChessPiece] = []
    @State private var capturedBlack: [ChessPiece] = []
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#161512").edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 8) {
                    // 1. Top Status & Game Review Header
                    headerView
                    
                    // 2. Opponent Info Bar (Captured pieces & turn)
                    playerInfoBar(isTop: true)
                    
                    // 3. Main Board Area: Evaluation Bar + 8x8 Board
                    HStack(alignment: .top, spacing: 8) {
                        EvalBarView(eval: engine.currentEvaluation, isFlipped: isFlipped)
                            .frame(width: 24)
                        
                        ChessBoardView(
                            fen: $currentFen,
                            isFlipped: isFlipped,
                            selectedSquare: selectedSquare,
                            legalMoves: legalMoveDestinations,
                            lastMove: currentLastMove,
                            bestMove: autoAnalyze ? engine.currentEvaluation.bestMove : nil,
                            isCheck: isCheck,
                            onSquareTapped: handleSquareTap
                        )
                    }
                    .padding(.horizontal, 8)
                    
                    // 4. Bottom Player Info Bar (Captured pieces & turn)
                    playerInfoBar(isTop: false)
                    
                    // 5. Game Over Banner if applicable
                    if isGameOver {
                        HStack {
                            Image(systemName: "flag.checkered")
                            Text(gameOverMessage)
                                .font(.system(size: 13, weight: .bold))
                            Spacer()
                            Button("New Game") {
                                resetGame()
                            }
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#78a942"))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#262421"))
                        .cornerRadius(6)
                        .padding(.horizontal, 8)
                    }
                    
                    // 6. Interactive Evaluation Graph
                    AnalysisGraphView(
                        moves: reviewService.analyzedMoves.isEmpty ? moves : reviewService.analyzedMoves,
                        currentPly: currentPly,
                        onSelectPly: selectPly
                    )
                    .padding(.horizontal, 8)
                    
                    // 7. Move Navigation & Quick Actions Bar
                    navigationBar
                    
                    // 8. Engine Panel: Depth, Best Move, PV Line
                    engineDetailsCard
                    
                    // 9. Move List with Blunder Badges
                    MoveListView(
                        moves: reviewService.analyzedMoves.isEmpty ? moves : reviewService.analyzedMoves,
                        currentPly: currentPly,
                        onSelectPly: selectPly
                    )
                    .frame(maxHeight: 120)
                    .background(Color(hex: "#21201d"))
                    .cornerRadius(8)
                    .padding(.horizontal, 8)
                }
                .padding(.top, 4)
            }
            .navigationBarTitle("Stockfish Chess", displayMode: .inline)
            .navigationBarItems(
                leading: HStack(spacing: 12) {
                    Button(action: { isFlipped.toggle() }) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Button(action: undoMove) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 14))
                    }
                    .disabled(moves.isEmpty)
                },
                trailing: HStack(spacing: 14) {
                    Button(action: resetGame) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    Button(action: { showImportSheet = true }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Button(action: { showSettingsSheet = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            )
            .sheet(isPresented: $showImportSheet) {
                PGNImportSheet(
                    currentFen: $currentFen,
                    onImportPGN: loadPGNString,
                    onImportFEN: loadFENString
                )
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(
                    playerColor: $playerColor,
                    targetDepth: $targetDepth,
                    autoAnalyze: $autoAnalyze,
                    boardThemeIndex: $boardThemeIndex,
                    soundEnabled: $soundEnabled
                )
            }
            .actionSheet(isPresented: $showPromotionSheet) {
                ActionSheet(
                    title: Text("Pawn Promotion"),
                    message: Text("Select piece to promote to:"),
                    buttons: [
                        .default(Text("Queen ♛")) { finishPromotion(to: .queen) },
                        .default(Text("Rook ♜")) { finishPromotion(to: .rook) },
                        .default(Text("Bishop ♝")) { finishPromotion(to: .bishop) },
                        .default(Text("Knight ♞")) { finishPromotion(to: .knight) },
                        .cancel {
                            pendingPromotionFrom = nil
                            pendingPromotionTo = nil
                        }
                    ]
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Header & Review Status
    
    private var headerView: some View {
        HStack {
            if reviewService.isAnalyzing {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(String(format: "Reviewing Game... %.0f%%", reviewService.progress * 100.0))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#1baca6"))
                }
            } else if reviewService.stats.whiteAccuracy > 0 || reviewService.stats.blackAccuracy > 0 {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.white).frame(width: 8, height: 8)
                        Text(String(format: "%.1f%% Acc", reviewService.stats.whiteAccuracy))
                            .font(.system(size: 11, weight: .bold))
                        Text("(\(reviewService.stats.whiteBlunders) blunders)")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#cb3737"))
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(Color.black).frame(width: 8, height: 8)
                        Text(String(format: "%.1f%% Acc", reviewService.stats.blackAccuracy))
                            .font(.system(size: 11, weight: .bold))
                        Text("(\(reviewService.stats.blackBlunders) blunders)")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#cb3737"))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(hex: "#262421"))
                .cornerRadius(6)
            } else {
                HStack {
                    Circle()
                        .fill(engine.isReady ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Stockfish 19 (Offline NNUE)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Full Game Review") {
                        Task {
                            await reviewService.runReview(moves: moves, depth: Int(targetDepth))
                        }
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#78a942"))
                    .disabled(moves.isEmpty)
                }
                .padding(.horizontal, 12)
            }
        }
    }
    
    // MARK: - Player Info Bars
    
    private func playerInfoBar(isTop: Bool) -> some View {
        let isBlackSide = isFlipped ? !isTop : isTop
        let activeSide = (currentFen.contains(" w ") ? PieceColor.white : PieceColor.black)
        let isSideTurn = isBlackSide ? (activeSide == .black) : (activeSide == .white)
        let sideColor = isBlackSide ? "Black" : "White"
        let captured = isBlackSide ? capturedWhite : capturedBlack
        
        return HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(isBlackSide ? Color.black : Color.white)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                
                Text(sideColor)
                    .font(.system(size: 12, weight: isSideTurn ? .bold : .regular))
                    .foregroundColor(isSideTurn ? Color(hex: "#f7f769") : .primary)
                
                if isSideTurn && !isGameOver {
                    Text("• Turn")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "#78a942"))
                }
            }
            
            Spacer()
            
            // Captured pieces symbols
            HStack(spacing: 2) {
                ForEach(captured.prefix(8), id: \.id) { piece in
                    Text(pieceSymbol(piece))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                if captured.count > 8 {
                    Text("+\(captured.count - 8)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
    
    // MARK: - Navigation Bar
    
    private var navigationBar: some View {
        HStack(spacing: 16) {
            Button(action: { selectPly(0) }) {
                Image(systemName: "backward.end.fill")
            }
            .disabled(moves.isEmpty || currentPly == 0)
            
            Button(action: { if currentPly > 0 { selectPly(currentPly - 1) } }) {
                Image(systemName: "chevron.left")
            }
            .disabled(currentPly == 0)
            
            Text("Ply \(currentPly) / \(moves.count)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(width: 100)
            
            Button(action: { if currentPly < moves.count { selectPly(currentPly + 1) } }) {
                Image(systemName: "chevron.right")
            }
            .disabled(currentPly == moves.count)
            
            Button(action: { selectPly(moves.count) }) {
                Image(systemName: "forward.end.fill")
            }
            .disabled(currentPly == moves.count)
        }
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(.primary)
    }
    
    // MARK: - Engine Details Card
    
    private var engineDetailsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Best: ")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Text(engine.currentEvaluation.bestMove ?? "—")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(hex: "#1baca6"))
                
                Spacer()
                
                Text("Depth: \(Int(targetDepth))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Slider(value: $targetDepth, in: 8...22, step: 1) { _ in
                    runAnalysisForCurrentPosition()
                }
                .frame(width: 100)
            }
            
            if !engine.currentEvaluation.pv.isEmpty {
                Text("Line: " + engine.currentEvaluation.pv.prefix(6).joined(separator: " "))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            if let err = engine.engineError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(err.localizedDescription)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(8)
        .background(Color(hex: "#262421"))
        .cornerRadius(6)
        .padding(.horizontal, 8)
    }
    
    // MARK: - Tap & Gameplay Handlers
    
    private func handleSquareTap(_ square: String) {
        guard let tappedSq = Square(string: square) else { return }
        
        // If a square was already selected
        if let sel = selectedSquare, let fromSq = Square(string: sel) {
            // Check if user tapped one of the valid destination squares
            if legalMoveDestinations.contains(square) {
                // Check if this move is a pawn promotion
                if let movingPiece = chessEngine.board[fromSq], movingPiece.type == .pawn {
                    if (movingPiece.color == .white && tappedSq.rank == 7) ||
                       (movingPiece.color == .black && tappedSq.rank == 0) {
                        pendingPromotionFrom = fromSq
                        pendingPromotionTo = tappedSq
                        showPromotionSheet = true
                        selectedSquare = nil
                        legalMoveDestinations.removeAll()
                        return
                    }
                }
                
                // Execute standard move
                executeMove(ChessMove(from: fromSq, to: tappedSq))
                selectedSquare = nil
                legalMoveDestinations.removeAll()
                return
            }
            
            // If user tapped a different friendly piece, switch selection
            if let p = chessEngine.board[tappedSq], p.color == chessEngine.activeColor {
                selectedSquare = square
                let validMoves = chessEngine.legalMovesFrom(square: tappedSq)
                legalMoveDestinations = validMoves.map { $0.to.description }
                return
            }
            
            // Deselect
            selectedSquare = nil
            legalMoveDestinations.removeAll()
        } else {
            // No square selected yet: select if it's the current player's piece
            if let p = chessEngine.board[tappedSq], p.color == chessEngine.activeColor {
                selectedSquare = square
                let validMoves = chessEngine.legalMovesFrom(square: tappedSq)
                legalMoveDestinations = validMoves.map { $0.to.description }
            }
        }
    }
    
    private func finishPromotion(to promoType: PieceType) {
        guard let from = pendingPromotionFrom, let to = pendingPromotionTo else { return }
        executeMove(ChessMove(from: from, to: to, promotion: promoType))
        pendingPromotionFrom = nil
        pendingPromotionTo = nil
    }
    
    private func executeMove(_ move: ChessMove) {
        let fenBefore = chessEngine.getFEN()
        let success = chessEngine.makeMove(move)
        guard success else { return }
        
        let fenAfter = chessEngine.getFEN()
        currentFen = fenAfter
        isCheck = chessEngine.isCheck
        isGameOver = chessEngine.isGameOver
        gameOverMessage = chessEngine.gameResult
        capturedWhite = chessEngine.capturedWhite
        capturedBlack = chessEngine.capturedBlack
        
        // Append to MoveRecord history
        let ply = moves.count + 1
        let moveNum = (moves.count / 2) + 1
        let san = chessEngine.moveHistory.last?.san ?? move.uci
        let record = MoveRecord(
            moveNumber: moveNum,
            ply: ply,
            san: san,
            uci: move.uci,
            fenBefore: fenBefore,
            fenAfter: fenAfter
        )
        moves.append(record)
        currentPly = moves.count
        
        if autoAnalyze {
            runAnalysisForCurrentPosition()
        }
    }
    
    private func undoMove() {
        guard chessEngine.undoLastMove() else { return }
        _ = moves.popLast()
        currentPly = moves.count
        currentFen = chessEngine.getFEN()
        isCheck = chessEngine.isCheck
        isGameOver = chessEngine.isGameOver
        capturedWhite = chessEngine.capturedWhite
        capturedBlack = chessEngine.capturedBlack
        
        if autoAnalyze {
            runAnalysisForCurrentPosition()
        }
    }
    
    private func selectPly(_ ply: Int) {
        currentPly = max(0, min(moves.count, ply))
        if currentPly == 0 {
            currentFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        } else {
            currentFen = moves[currentPly - 1].fenAfter
        }
        if autoAnalyze {
            runAnalysisForCurrentPosition()
        }
    }
    
    private func runAnalysisForCurrentPosition() {
        Task {
            do {
                _ = try await engine.evaluate(fen: currentFen, depth: Int(targetDepth))
            } catch {
                print("Analysis error: \(error)")
            }
        }
    }
    
    private func resetGame() {
        engine.stop()
        chessEngine.reset()
        moves.removeAll()
        reviewService.analyzedMoves.removeAll()
        reviewService.stats = GameReviewStats()
        currentPly = 0
        currentFen = chessEngine.getFEN()
        isCheck = false
        isGameOver = false
        capturedWhite.removeAll()
        capturedBlack.removeAll()
        selectedSquare = nil
        legalMoveDestinations.removeAll()
        
        if autoAnalyze {
            runAnalysisForCurrentPosition()
        }
    }
    
    private func loadFENString(_ fen: String) {
        engine.stop()
        chessEngine.loadFEN(fen)
        moves.removeAll()
        reviewService.analyzedMoves.removeAll()
        reviewService.stats = GameReviewStats()
        currentPly = 0
        currentFen = chessEngine.getFEN()
        isCheck = chessEngine.isCheck
        isGameOver = chessEngine.isGameOver
        capturedWhite.removeAll()
        capturedBlack.removeAll()
        
        if autoAnalyze {
            runAnalysisForCurrentPosition()
        }
    }
    
    private func loadPGNString(_ pgn: String) {
        let parsed = PGNParserService.shared.parse(pgn: pgn)
        resetGame()
        
        for (i, san) in parsed.moves.enumerated() {
            let ply = i + 1
            let moveNum = (i / 2) + 1
            let fenBefore = chessEngine.getFEN()
            
            // Try matching SAN to legal moves
            let legals = chessEngine.legalMoves()
            if let matched = legals.first(where: { m in
                // Check direct UCI or SAN match
                m.uci == san || m.to.description == san
            }) {
                _ = chessEngine.makeMove(matched)
            }
            let fenAfter = chessEngine.getFEN()
            
            let record = MoveRecord(
                moveNumber: moveNum,
                ply: ply,
                san: san,
                uci: san,
                fenBefore: fenBefore,
                fenAfter: fenAfter
            )
            moves.append(record)
        }
        selectPly(0)
    }
    
    private var currentLastMove: (from: String, to: String)? {
        guard currentPly > 0, currentPly <= moves.count else { return nil }
        let uci = moves[currentPly - 1].uci
        guard uci.count >= 4 else { return nil }
        let from = String(uci.prefix(2))
        let to = String(uci.dropFirst(2).prefix(2))
        return (from, to)
    }
    
    private func pieceSymbol(_ piece: ChessPiece) -> String {
        switch piece.type {
        case .pawn: return "♟"
        case .knight: return "♞"
        case .bishop: return "♝"
        case .rook: return "♜"
        case .queen: return "♛"
        case .king: return "♚"
        }
    }
}
