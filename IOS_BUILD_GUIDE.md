# iOS Native Stockfish Chess Analysis App — Build & Architecture Guide

This repository contains a full-featured native iOS Chess Analysis App with an embedded offline Stockfish 19 engine, complete legal chess rules, real-time evaluation bar, game review with accuracy percentages and blunder classification, PGN/FEN tools, and an interactive evaluation trajectory graph.

---

## 1. Project Architecture

The native iOS application is structured as a Swift Package with SwiftUI components and an Objective-C++ bridge to the Stockfish engine:

```
ios-native/
├── Package.swift                    # Swift Package definition (iOS 17+, macOS 14+, C++20)
├── Sources/
│   ├── StockfishAnalysisApp.swift   # App entry point
│   ├── Bridge/
│   │   ├── StockfishBridge.hpp      # Objective-C++ interface for UCI thread communication
│   │   └── StockfishBridge.mm       # Engine thread runner, command queue & output dispatcher
│   ├── Models/
│   │   ├── ChessTypes.swift         # Data structures: MoveRecord, EngineEvaluation, BlunderClassification
│   │   └── ChessRulesEngine.swift   # FIDE chess legal rules: pin checks, castling, en passant, promotion
│   ├── Services/
│   │   ├── StockfishEngineService.swift # Async/await engine actor with depth, CP & Mate evaluation
│   │   ├── GameReviewService.swift      # Full game analyzer: win probability loss, blunder classification, accuracy %
│   │   └── PGNParserService.swift       # PGN header extraction, token cleaner, and PGN exporter
│   └── Views/
│       ├── ContentView.swift        # Main application layout, turn tracking, promotion sheet, quick actions
│       ├── ChessBoardView.swift     # Interactive 8x8 board, legal move hints, in-check glow & Stockfish arrow
│       ├── EvalBarView.swift        # Smooth vertical evaluation bar with CP / Mate score overlay
│       ├── AnalysisGraphView.swift  # Evaluation trajectory curve with blunder/mistake dots & scrubbing cursor
│       ├── MoveListView.swift       # Move list with blunder badges (Brilliant, Best, Blunder, etc.)
│       ├── PGNImportSheet.swift     # PGN/FEN importer with classic games (Morphy, Kasparov, Fischer)
│       └── SettingsView.swift       # Board themes, engine depth slider, and starting side picker
└── Tests/
    └── StockfishAnalysisTests/
        ├── ChessRulesTests.swift    # Legal moves, castling, en passant, promotion, checkmate, stalemate
        ├── PGNTests.swift           # PGN parser, tag extraction, move cleaner, and PGN exporter
        └── GameReviewTests.swift    # Win probability formula, move classification thresholds, accuracy %
```

---

## 2. Mathematical Formulas Used

### A. Centipawn to Winning Chance
Winning probability $W$ (0 to 100%) as a function of centipawn evaluation $cp$:
$$W(cp) = 50 + 50 \times \left( \frac{2}{1 + e^{-0.00368208 \times \text{clamp}(cp, -2000, 2000)}} - 1 \right)$$

### B. Move Classification
Let $\Delta W = W_{\text{before}} - W_{\text{after}}$ for the active player:
* **Best**: Played move matches the engine's primary UCI recommendation.
* **Excellent**: $\Delta W < 2.0\%$
* **Good**: $\Delta W < 5.0\%$
* **Inaccuracy**: $\Delta W < 12.0\%$
* **Mistake**: $\Delta W < 25.0\%$
* **Blunder**: $\Delta W \ge 25.0\%$

### C. Accuracy Percentage
$$\text{Accuracy} = \max\left(0, \min\left(100, 100 - 1.8 \times \overline{\Delta W}\right)\right)$$

---

## 3. How to Build & Run on iOS (macOS / Xcode)

### Option A: Open with Xcode
1. Transfer the `chess-analysis-app/ios-native/` folder to a Mac running macOS Sonoma (14.0+) or later.
2. In Xcode, select **File > Open** and open `Package.swift`.
3. In the scheme dropdown, select your connected iPhone or an iOS Simulator (e.g., iPhone 15 Pro).
4. Press **Cmd + R** to build and run the app.

### Option B: Command Line Build (`xcodebuild`)
```bash
cd ios-native
swift test
xcodebuild -scheme StockfishAnalysis -destination 'generic/platform=iOS' -configuration Release
```

### Option C: Sideloading onto iPhone without a Paid Developer Account
1. Open the project in Xcode and set your Personal Apple ID in **Signing & Capabilities**.
2. Build an unsigned `.ipa` or `.app` bundle.
3. Use **AltStore**, **Sideloadly**, or **TrollStore** to install and sign the app directly to your device.

---

## 4. Local Web Companion App (Runs on Windows / Any OS)

To test the complete chess engine and full game analysis right now on Windows without needing a Mac:
```bash
# Start the local Stockfish server:
node web-companion/server.js

# Open in browser:
http://127.0.0.1:3000/
```

Features active in the web companion:
* 100% offline Stockfish 19 engine.
* Interactive 8x8 chessboard with sound effects, drag/tap moves, and legal move indicators.
* Live evaluation bar and best-move arrow.
* Move list with blunder badges (Brilliant, Best, Blunder, Inaccuracy, Mistake).
* Full Game Review with White/Black accuracy percentages.
* Interactive evaluation trajectory graph with clickable move scrubbing.
* PGN Import/Export and preloaded classic games (Morphy Opera Game, Kasparov Immortal, Fischer Game of the Century).

---

## 5. Licensing & Attribution (GPL-3.0)
* **Stockfish**: Licensed under the **GNU General Public License v3.0**.
* Any distribution of this application must provide corresponding source code and retain original copyright notices. See [ATTRIBUTION.md](file:///C:/Users/sidak/.gemini/antigravity-ide/scratch/chess-analysis-app/stockfish-engine/ATTRIBUTION.md) for full licensing information.
