import SwiftUI

public struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @Binding public var playerColor: PieceColor
    @Binding public var targetDepth: Double
    @Binding public var autoAnalyze: Bool
    @Binding public var boardThemeIndex: Int
    @Binding public var soundEnabled: Bool
    
    public init(
        playerColor: Binding<PieceColor>,
        targetDepth: Binding<Double>,
        autoAnalyze: Binding<Bool>,
        boardThemeIndex: Binding<Int>,
        soundEnabled: Binding<Bool>
    ) {
        self._playerColor = playerColor
        self._targetDepth = targetDepth
        self._autoAnalyze = autoAnalyze
        self._boardThemeIndex = boardThemeIndex
        self._soundEnabled = soundEnabled
    }
    
    private let boardThemes = ["Classic Green", "Warm Wood", "Midnight Blue", "Modern Charcoal"]
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("GAMEPLAY")) {
                    Picker("Player Side", selection: $playerColor) {
                        Text("Play as White").tag(PieceColor.white)
                        Text("Play as Black").tag(PieceColor.black)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Toggle("Sound Effects", isOn: $soundEnabled)
                }
                
                Section(header: Text("BOARD AESTHETICS")) {
                    Picker("Theme", selection: $boardThemeIndex) {
                        ForEach(0..<boardThemes.count, id: \.self) { idx in
                            Text(boardThemes[idx]).tag(idx)
                        }
                    }
                }
                
                Section(header: Text("STOCKFISH 19 LOCAL ENGINE")) {
                    Toggle("Continuous Analysis", isOn: $autoAnalyze)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Engine Depth")
                            Spacer()
                            Text("\(Int(targetDepth)) plies")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "#1baca6"))
                        }
                        
                        Slider(value: $targetDepth, in: 8...22, step: 1)
                        
                        Text("Higher depths calculate deeper tactical lines and mate sequences using the local NNUE network, but require more processing.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("ABOUT & LICENSING")) {
                    HStack {
                        Text("Engine")
                        Spacer()
                        Text("Stockfish 19 (Embedded NNUE)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("License")
                        Spacer()
                        Text("GNU General Public License v3.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Offline Verification")
                        Spacer()
                        Text("100% Local (0 Network Calls)")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
