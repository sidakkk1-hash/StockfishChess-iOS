import SwiftUI

public struct EvalBarView: View {
    public var eval: EngineEvaluation
    public var isFlipped: Bool
    
    public init(eval: EngineEvaluation, isFlipped: Bool = false) {
        self.eval = eval
        self.isFlipped = isFlipped
    }
    
    private var whiteWinPercentage: Double {
        if let mate = eval.mateIn {
            return mate > 0 ? 100.0 : 0.0
        }
        let cp = max(-1500, min(1500, Double(eval.scoreCentipawns)))
        return 50.0 + 50.0 * (2.0 / (1.0 + exp(-0.00368208 * cp)) - 1.0)
    }
    
    public var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let whiteFrac = isFlipped ? (100.0 - whiteWinPercentage) / 100.0 : whiteWinPercentage / 100.0
            let whiteHeight = max(0, min(totalHeight, totalHeight * CGFloat(whiteFrac)))
            
            ZStack(alignment: isFlipped ? .top : .bottom) {
                // Black side background
                Rectangle()
                    .fill(Color(hex: "#262421"))
                
                // White side fill
                Rectangle()
                    .fill(Color(hex: "#ffffff"))
                    .frame(height: whiteHeight)
                    .animation(.easeInOut(duration: 0.3), value: whiteHeight)
                
                // Score text overlay
                VStack {
                    if isFlipped {
                        if whiteFrac < 0.5 {
                            scoreText
                                .foregroundColor(.white)
                                .padding(.top, 4)
                            Spacer()
                        } else {
                            Spacer()
                            scoreText
                                .foregroundColor(.black)
                                .padding(.bottom, 4)
                        }
                    } else {
                        if whiteFrac >= 0.5 {
                            Spacer()
                            scoreText
                                .foregroundColor(.black)
                                .padding(.bottom, 4)
                        } else {
                            scoreText
                                .foregroundColor(.white)
                                .padding(.top, 4)
                            Spacer()
                        }
                    }
                }
            }
            .frame(width: 24)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .frame(width: 24)
    }
    
    private var scoreText: some View {
        Text(eval.formattedScore)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
    }
}
