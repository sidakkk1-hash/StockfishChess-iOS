import Foundation

public struct ParsedPGNGame {
    public var headers: [String: String] = [:]
    public var moves: [String] = [] // SAN move strings
    
    public var whitePlayer: String { headers["White"] ?? "White" }
    public var blackPlayer: String { headers["Black"] ?? "Black" }
    public var result: String { headers["Result"] ?? "*" }
    public var date: String { headers["Date"] ?? "" }
    public var event: String { headers["Event"] ?? "Casual Game" }
}

public final class PGNParserService {
    public static let shared = PGNParserService()
    
    public func parse(pgn: String) -> ParsedPGNGame {
        var game = ParsedPGNGame()
        let lines = pgn.components(separatedBy: .newlines)
        var moveText = ""
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.starts(with: "[") && line.contains("\"") {
                // Header tag: [Key "Value"]
                let scanner = Scanner(string: line)
                _ = scanner.scanString("[")
                if let key = scanner.scanUpToString(" ")?.trimmingCharacters(in: .whitespaces),
                   let _ = scanner.scanString("\""),
                   let val = scanner.scanUpToString("\"") {
                    game.headers[key] = val
                }
            } else if !line.isEmpty && !line.starts(with: "%") {
                moveText += " " + line
            }
        }
        
        // Remove curly comments { ... }
        let noComments = moveText.replacingOccurrences(of: "\\{[^}]*\\}", with: "", options: .regularExpression)
        // Remove numeric evaluation annotations ($1, $2, etc.)
        let cleanText = noComments.replacingOccurrences(of: "\\$\\d+", with: "", options: .regularExpression)
        
        // Tokenize and extract moves (strip "1.", "1...", "1-0", "0-1", "1/2-1/2", "*")
        let tokens = cleanText.components(separatedBy: .whitespacesAndNewlines)
        for token in tokens {
            let t = token.trimmingCharacters(in: .punctuationCharacters.subtracting(Set("+#!?")))
            if t.isEmpty { continue }
            if t.contains(".") || t == "1-0" || t == "0-1" || t == "1/2-1/2" || t == "*" {
                continue
            }
            game.moves.append(t)
        }
        
        return game
    }
    
    public func exportPGN(
        moves: [MoveRecord],
        headers: [String: String] = [:]
    ) -> String {
        var pgn = ""
        let defaultHeaders = [
            "Event": "Stockfish Analysis Game",
            "Site": "iOS Offline Engine",
            "Date": ISO8601DateFormatter().string(from: Date()),
            "Round": "1",
            "White": "Player 1",
            "Black": "Player 2",
            "Result": "*"
        ]
        
        let merged = defaultHeaders.merging(headers) { (_, new) in new }
        for (k, v) in merged.sorted(by: { $0.key < $1.key }) {
            pgn += "[\(k) \"\(v)\"]\n"
        }
        pgn += "\n"
        
        var moveStrings: [String] = []
        for (idx, record) in moves.enumerated() {
            let moveNum = (idx / 2) + 1
            if idx % 2 == 0 {
                moveStrings.append("\(moveNum). \(record.san)")
            } else {
                moveStrings.append(record.san)
            }
        }
        
        let result = merged["Result"] ?? "*"
        moveStrings.append(result)
        pgn += moveStrings.joined(separator: " ") + "\n"
        return pgn
    }
}
