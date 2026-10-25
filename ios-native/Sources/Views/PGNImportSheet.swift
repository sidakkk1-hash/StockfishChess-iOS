import SwiftUI

public struct PGNImportSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding public var currentFen: String
    public var onImportPGN: (String) -> Void
    public var onImportFEN: (String) -> Void
    
    @State private var selectedTab: Int = 0
    @State private var pgnText: String = ""
    @State private var fenText: String = ""
    @State private var errorMessage: String? = nil
    
    public init(
        currentFen: Binding<String>,
        onImportPGN: @escaping (String) -> Void,
        onImportFEN: @escaping (String) -> Void
    ) {
        self._currentFen = currentFen
        self.onImportPGN = onImportPGN
        self.onImportFEN = onImportFEN
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Picker("Import Mode", selection: $selectedTab) {
                    Text("PGN Game").tag(0)
                    Text("FEN Position").tag(1)
                    Text("Sample Classics").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if selectedTab == 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paste completed game PGN (from Chess.com, Lichess, or institute):")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $pgnText)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(4)
                            .background(Color(hex: "#1e1e1e"))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    }
                    .padding(.horizontal)
                } else if selectedTab == 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter Forsyth-Edwards Notation (FEN):")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        TextField("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", text: $fenText)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(8)
                            .background(Color(hex: "#1e1e1e"))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        
                        HStack {
                            Button("Starting Board") {
                                fenText = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
                            }
                            Button("Scholar's Defense") {
                                fenText = "r1bqkb1r/pppp1ppp/2n5/4p2Q/2B1n3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 4"
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                } else {
                    // Sample classic games
                    List {
                        Button("Opera Game (Paul Morphy vs Allies, 1858)") {
                            loadMorphyOperaGame()
                            selectedTab = 0
                        }
                        Button("Kasparov's Immortal (Kasparov vs Topalov, 1999)") {
                            loadKasparovImmortal()
                            selectedTab = 0
                        }
                        Button("Game of the Century (Fischer vs Byrne, 1956)") {
                            loadFischerGame()
                            selectedTab = 0
                        }
                    }
                }
                
                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                if selectedTab != 2 {
                    Button(action: handleImport) {
                        Text("Load & Analyze Position")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#78a942"))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Import Chess Game")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func handleImport() {
        if selectedTab == 0 {
            let clean = pgnText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else {
                errorMessage = "PGN text cannot be empty."
                return
            }
            onImportPGN(clean)
            presentationMode.wrappedValue.dismiss()
        } else if selectedTab == 1 {
            let clean = fenText.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = clean.split(separator: " ")
            guard parts.count >= 2 else {
                errorMessage = "Invalid FEN format. Must contain at least board and active color."
                return
            }
            onImportFEN(clean)
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func loadMorphyOperaGame() {
        pgnText = """
        [Event "Paris Opera House"]
        [Site "Paris"]
        [Date "1858.11.02"]
        [White "Paul Morphy"]
        [Black "Duke Karl / Count Isouard"]
        [Result "1-0"]
        
        1. e4 e5 2. Nf3 d6 3. d4 Bg4 4. dxe5 Bxf3 5. Qxf3 dxe5 6. Bc4 Nf6 7. Qb3 Qe7 8. Nc3 c6 9. Bg5 b5 10. Nxb5 cxb5 11. Bxb5+ Nbd7 12. O-O-O Rd8 13. Rxd7 Rxd7 14. Rd1 Qe6 15. Bxd7+ Nxd7 16. Qb8+ Nxb8 17. Rd8# 1-0
        """
    }
    
    private func loadKasparovImmortal() {
        pgnText = """
        [Event "Hoogovens Group A"]
        [Site "Wijk aan Zee"]
        [Date "1999.01.20"]
        [White "Garry Kasparov"]
        [Black "Veselin Topalov"]
        [Result "1-0"]
        
        1. e4 d6 2. d4 Nf6 3. Nc3 g6 4. Be3 Bg7 5. Qd2 c6 6. f3 b5 7. Nge2 Nbd7 8. Bh6 Bxh6 9. Qxh6 Bb7 10. a3 e5 11. O-O-O Qe7 12. Kb1 a6 13. Nc1 O-O-O 14. Nb3 exd4 15. Rxd4 c5 16. Rd1 Nb6 17. g3 Kb8 18. Na5 Ba8 19. Bh3 d5 20. Qf4+ Ka7 21. Rhe1 d4 22. Nd5 Nbxd5 23. exd5 Qd6 24. Rxd4 cxd4 25. Re7+ Kb6 26. Qxd4+ Kxa5 27. b4+ Ka4 28. Qc3 Qxd5 29. Ra7 Bb7 30. Rxb7 Qc4 31. Qxf6 Kxa3 32. Qxa6+ Kxb4 33. c3+ Kxc3 34. Qa1+ Kd2 35. Qb2+ Kd1 36. Bf1 Rd2 37. Rd7 Rxd7 38. Bxc4 bxc4 39. Qxh8 Rd3 40. Qa8 c3 41. Qa4+ Ke1 42. f4 f5 43. Kc1 Rd2 44. Qa7 1-0
        """
    }
    
    private func loadFischerGame() {
        pgnText = """
        [Event "Third Rosenwald Trophy"]
        [Site "New York"]
        [Date "1956.10.17"]
        [White "Donald Byrne"]
        [Black "Bobby Fischer"]
        [Result "0-1"]
        
        1. Nf3 Nf6 2. c4 g6 3. Nc3 Bg7 4. d4 O-O 5. Bf4 d5 6. Qb3 dxc4 7. Qxc4 c6 8. e4 Nbd7 9. Rd1 Nb6 10. Qc5 Bg4 11. Bg5 Na4 12. Qa3 Nxc3 13. bxc3 Nxe4 14. Bxe7 Qb6 15. Bc4 Nxc3 16. Bc5 Rfe8+ 17. Kf1 Be6 18. Bxb6 Bxc4+ 19. Kg1 Ne2+ 20. Kf1 Nxd4+ 21. Kg1 Ne2+ 22. Kf1 Nc3+ 23. Kg1 axb6 24. Qb4 Ra4 25. Qxb6 Nxd1 0-1
        """
    }
}
