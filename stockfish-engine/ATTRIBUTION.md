# Stockfish License & Attribution Notice

This project incorporates and provides integration with **Stockfish**, the world-leading open-source chess engine.

* **Upstream Project**: [Stockfish](https://github.com/official-stockfish/Stockfish)
* **Authors**: The Stockfish Developers (see [Stockfish AUTHORS](https://github.com/official-stockfish/Stockfish/blob/master/AUTHORS))
* **License**: GNU General Public License version 3 (GPL-3.0) or later.
* **Full License Text**: See [LICENSE](../LICENSE) in the root of this repository.

## GPL-3.0 Compliance & Source Code Availability

In accordance with the requirements of the GNU General Public License v3.0:
1. **Source Code Distribution**: Any distribution of this application or binaries that link or combine with Stockfish includes full access to the source code of both Stockfish and this application under GPL-3.0.
2. **Upstream Source**: The original, complete Stockfish source code is publicly accessible at [https://github.com/official-stockfish/Stockfish](https://github.com/official-stockfish/Stockfish).
3. **No DRM / Access Restrictions**: Stockfish is distributed without digital rights management (DRM) or proprietary obfuscation that restricts user inspection, modification, or re-compilation.
4. **Patches & Build Scripts**: All scripts and C++/Swift bridging code used to compile Stockfish for iOS and WebAssembly targets are provided openly in `stockfish-engine/` and `ios-native/`.

## Neural Network (NNUE) Weights Notice

Stockfish relies on NNUE (Efficiently Updatable Neural Networks) evaluation files.
* Default NNUE networks are trained on open chess datasets and distributed under the same open terms.
* When compiling for iOS, the network is either embedded directly into the binary data segment (`EMBEDDED_NET=yes`) or loaded from the app's read-only application bundle.
