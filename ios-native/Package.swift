// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StockfishAnalysis",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "StockfishAnalysis",
            targets: ["StockfishAnalysis"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "StockfishBridge",
            path: "Sources/Bridge",
            publicHeadersPath: "."
        ),
        .target(
            name: "StockfishAnalysis",
            dependencies: ["StockfishBridge"],
            path: "Sources",
            exclude: ["Bridge"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "StockfishAnalysisTests",
            dependencies: ["StockfishAnalysis"],
            path: "Tests"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
