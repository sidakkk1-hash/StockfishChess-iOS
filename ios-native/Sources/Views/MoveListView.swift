import SwiftUI

public struct MoveListView: View {
    public var moves: [MoveRecord]
    public var currentPly: Int
    public var onSelectPly: (Int) -> Void
    
    public init(moves: [MoveRecord], currentPly: Int, onSelectPly: @escaping (Int) -> Void) {
        self.moves = moves
        self.currentPly = currentPly
        self.onSelectPly = onSelectPly
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    let movePairs = stride(from: 0, to: moves.count, by: 2).map { i -> (Int, MoveRecord, MoveRecord?) in
                        let whiteMove = moves[i]
                        let blackMove = (i + 1 < moves.count) ? moves[i + 1] : nil
                        return (whiteMove.moveNumber, whiteMove, blackMove)
                    }
                    
                    ForEach(movePairs, id: \.0) { moveNum, whiteMove, blackMove in
                        HStack(spacing: 8) {
                            Text("\(moveNum).")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 32, alignment: .leading)
                            
                            // White Move Item
                            moveButton(for: whiteMove)
                            
                            // Black Move Item
                            if let bm = blackMove {
                                moveButton(for: bm)
                            } else {
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(moveNum % 2 == 0 ? Color.black.opacity(0.15) : Color.clear)
                        .cornerRadius(4)
                        .id(moveNum)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: currentPly) { newPly in
                let moveNum = (newPly + 1) / 2
                withAnimation {
                    proxy.scrollTo(moveNum, anchor: .center)
                }
            }
        }
    }
    
    private func moveButton(for move: MoveRecord) -> some View {
        Button(action: {
            onSelectPly(move.ply)
        }) {
            HStack(spacing: 4) {
                Text(move.san)
                    .font(.system(size: 13, weight: move.ply == currentPly ? .bold : .medium))
                    .foregroundColor(move.ply == currentPly ? Color(hex: "#f7f769") : .primary)
                
                if let cls = move.classification {
                    Image(systemName: cls.icon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: cls.colorHex))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(move.ply == currentPly ? Color.gray.opacity(0.3) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
