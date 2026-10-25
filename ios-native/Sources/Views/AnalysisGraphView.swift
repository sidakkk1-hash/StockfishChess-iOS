import SwiftUI

public struct AnalysisGraphView: View {
    public var moves: [MoveRecord]
    public var currentPly: Int
    public var onSelectPly: (Int) -> Void
    
    public init(moves: [MoveRecord], currentPly: Int, onSelectPly: @escaping (Int) -> Void) {
        self.moves = moves
        self.currentPly = currentPly
        self.onSelectPly = onSelectPly
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EVALUATION TRAJECTORY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let midY = height / 2.0
                
                ZStack {
                    // Centerline (0.00 equal eval)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: midY))
                        path.addLine(to: CGPoint(x: width, y: midY))
                    }
                    .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    
                    if moves.count > 1 {
                        let stepX = width / CGFloat(max(1, moves.count - 1))
                        
                        // Eval curve path
                        Path { path in
                            for (idx, m) in moves.enumerated() {
                                let cp = m.evalCentipawns ?? 0
                                let clampedCp = max(-800, min(800, cp))
                                // Map +800 cp to top (y=4), -800 cp to bottom (y=height-4)
                                let normalized = CGFloat(clampedCp + 800) / 1600.0
                                let y = height - (normalized * (height - 8)) - 4
                                let x = CGFloat(idx) * stepX
                                
                                if idx == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#1baca6"), Color(hex: "#78a942")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2.5
                        )
                        
                        // Blunder and mistake dots
                        ForEach(Array(moves.enumerated()), id: \.offset) { idx, m in
                            let cp = m.evalCentipawns ?? 0
                            let clampedCp = max(-800, min(800, cp))
                            let normalized = CGFloat(clampedCp + 800) / 1600.0
                            let y = height - (normalized * (height - 8)) - 4
                            let x = CGFloat(idx) * stepX
                            
                            if let classification = m.classification, classification == .blunder || classification == .mistake {
                                Circle()
                                    .fill(Color(hex: classification.colorHex))
                                    .frame(width: 8, height: 8)
                                    .position(x: x, y: y)
                            }
                            
                            // Current ply cursor
                            if m.ply == currentPly {
                                Circle()
                                    .stroke(Color.yellow, lineWidth: 2)
                                    .background(Circle().fill(Color.white))
                                    .frame(width: 10, height: 10)
                                    .position(x: x, y: y)
                            }
                        }
                    } else {
                        Text("Import a PGN or start analysis to plot game evaluation")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !moves.isEmpty else { return }
                            let stepX = width / CGFloat(max(1, moves.count - 1))
                            let tappedIdx = Int(round(value.location.x / stepX))
                            let clampedIdx = max(0, min(moves.count - 1, tappedIdx))
                            onSelectPly(moves[clampedIdx].ply)
                        }
                )
            }
            .frame(height: 70)
            .background(Color(hex: "#1e1e1e"))
            .cornerRadius(6)
        }
    }
}
