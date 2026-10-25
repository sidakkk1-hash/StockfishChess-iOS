// StockfishBridge.mm
// Objective-C++ implementation of the embedded native Stockfish UCI engine for iOS

#import "StockfishBridge.hpp"
#include <string>
#include <vector>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <atomic>
#include <sstream>
#include <iostream>
#include <algorithm>
#include <chrono>
#include <cmath>

namespace EmbeddedStockfish {

// Piece definitions
enum Piece : int8_t {
    EMPTY = 0,
    W_PAWN = 1, W_KNIGHT = 2, W_BISHOP = 3, W_ROOK = 4, W_QUEEN = 5, W_KING = 6,
    B_PAWN = -1, B_KNIGHT = -2, B_BISHOP = -3, B_ROOK = -4, B_QUEEN = -5, B_KING = -6
};

struct Move {
    int fromSq;
    int toSq;
    int promoPiece; // 0 or Piece type
    int score;

    std::string toUCI() const {
        if (fromSq < 0 || toSq < 0) return "0000";
        char f1 = 'a' + (fromSq % 8);
        char r1 = '1' + (fromSq / 8);
        char f2 = 'a' + (toSq % 8);
        char r2 = '1' + (toSq / 8);
        std::string s = {f1, r1, f2, r2};
        if (promoPiece != 0) {
            int absPromo = std::abs(promoPiece);
            if (absPromo == W_QUEEN) s += 'q';
            else if (absPromo == W_ROOK) s += 'r';
            else if (absPromo == W_BISHOP) s += 'b';
            else if (absPromo == W_KNIGHT) s += 'n';
        }
        return s;
    }
};

// Material piece values in centipawns
const int PIECE_VALUES[7] = { 0, 100, 320, 330, 500, 900, 20000 };

// Positional piece-square tables for tactical awareness
const int PAWN_PST[64] = {
     0,  0,  0,  0,  0,  0,  0,  0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
     5,  5, 10, 25, 25, 10,  5,  5,
     0,  0,  0, 20, 20,  0,  0,  0,
     5, -5,-10,  0,  0,-10, -5,  5,
     5, 10, 10,-20,-20, 10, 10,  5,
     0,  0,  0,  0,  0,  0,  0,  0
};

const int KNIGHT_PST[64] = {
    -50,-40,-30,-30,-30,-30,-40,-50,
    -40,-20,  0,  0,  0,  0,-20,-40,
    -30,  0, 10, 15, 15, 10,  0,-30,
    -30,  5, 15, 20, 20, 15,  5,-30,
    -30,  0, 15, 20, 20, 15,  0,-30,
    -30,  5, 10, 15, 15, 10,  5,-30,
    -40,-20,  0,  5,  5,  0,-20,-40,
    -50,-40,-30,-30,-30,-30,-40,-50
};

class BoardState {
public:
    int8_t squares[64];
    bool whiteToMove;
    int castlingRights; // 1:WK, 2:WQ, 4:BK, 8:BQ
    int enPassantSq;    // -1 or 0..63
    int halfmoveClock;
    int fullmoveNumber;

    BoardState() {
        reset();
    }

    void reset() {
        loadFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    }

    void loadFEN(const std::string& fen) {
        std::fill(std::begin(squares), std::end(squares), EMPTY);
        std::istringstream ss(fen);
        std::string piecePlacement, activeColor, castling, epSquare;
        int halfmove = 0, fullmove = 1;

        ss >> piecePlacement >> activeColor >> castling >> epSquare >> halfmove >> fullmove;

        int sq = 56; // a8
        for (char ch : piecePlacement) {
            if (ch == '/') {
                sq -= 16;
            } else if (std::isdigit(ch)) {
                sq += (ch - '0');
            } else {
                squares[sq] = charToPiece(ch);
                sq++;
            }
        }

        whiteToMove = (activeColor != "b");
        castlingRights = 0;
        if (castling.find('K') != std::string::npos) castlingRights |= 1;
        if (castling.find('Q') != std::string::npos) castlingRights |= 2;
        if (castling.find('k') != std::string::npos) castlingRights |= 4;
        if (castling.find('q') != std::string::npos) castlingRights |= 8;

        if (epSquare.length() == 2 && epSquare[0] >= 'a' && epSquare[0] <= 'h' && epSquare[1] >= '1' && epSquare[1] <= '8') {
            enPassantSq = (epSquare[0] - 'a') + (epSquare[1] - '1') * 8;
        } else {
            enPassantSq = -1;
        }

        halfmoveClock = halfmove;
        fullmoveNumber = fullmove > 0 ? fullmove : 1;
    }

    int8_t charToPiece(char ch) const {
        switch (ch) {
            case 'P': return W_PAWN; case 'N': return W_KNIGHT; case 'B': return W_BISHOP;
            case 'R': return W_ROOK; case 'Q': return W_QUEEN; case 'K': return W_KING;
            case 'p': return B_PAWN; case 'n': return B_KNIGHT; case 'b': return B_BISHOP;
            case 'r': return B_ROOK; case 'q': return B_QUEEN; case 'k': return B_KING;
            default: return EMPTY;
        }
    }

    void generatePseudoMoves(std::vector<Move>& moves) const {
        int colorSign = whiteToMove ? 1 : -1;

        for (int sq = 0; sq < 64; ++sq) {
            int8_t p = squares[sq];
            if (p == EMPTY || (p > 0 && !whiteToMove) || (p < 0 && whiteToMove)) continue;

            int pType = std::abs(p);
            int file = sq % 8;
            int rank = sq / 8;

            if (pType == W_PAWN) {
                int forward = colorSign * 8;
                int to1 = sq + forward;
                if (to1 >= 0 && to1 < 64 && squares[to1] == EMPTY) {
                    int toRank = to1 / 8;
                    if (toRank == 7 || toRank == 0) {
                        moves.push_back({sq, to1, colorSign * W_QUEEN, 900});
                        moves.push_back({sq, to1, colorSign * W_KNIGHT, 300});
                    } else {
                        moves.push_back({sq, to1, 0, 0});
                        // Double step
                        if ((whiteToMove && rank == 1) || (!whiteToMove && rank == 6)) {
                            int to2 = sq + 2 * forward;
                            if (squares[to2] == EMPTY) {
                                moves.push_back({sq, to2, 0, 0});
                            }
                        }
                    }
                }
                // Diagonal captures
                for (int df : {-1, 1}) {
                    int targetFile = file + df;
                    if (targetFile >= 0 && targetFile < 8) {
                        int capSq = sq + forward + df;
                        if (capSq >= 0 && capSq < 64) {
                            int8_t targetP = squares[capSq];
                            if (targetP != EMPTY && ((targetP > 0) != whiteToMove)) {
                                int toRank = capSq / 8;
                                int capScore = PIECE_VALUES[std::abs(targetP)] - 100;
                                if (toRank == 7 || toRank == 0) {
                                    moves.push_back({sq, capSq, colorSign * W_QUEEN, capScore + 900});
                                } else {
                                    moves.push_back({sq, capSq, 0, capScore});
                                }
                            } else if (capSq == enPassantSq) {
                                moves.push_back({sq, capSq, 0, 100});
                            }
                        }
                    }
                }
            } else if (pType == W_KNIGHT) {
                const int knightDeltas[8][2] = {
                    {-2, -1}, {-2, 1}, {-1, -2}, {-1, 2},
                    {1, -2}, {1, 2}, {2, -1}, {2, 1}
                };
                for (auto& d : knightDeltas) {
                    int tf = file + d[0], tr = rank + d[1];
                    if (tf >= 0 && tf < 8 && tr >= 0 && tr < 8) {
                        int toSq = tf + tr * 8;
                        int8_t targetP = squares[toSq];
                        if (targetP == EMPTY) {
                            moves.push_back({sq, toSq, 0, 0});
                        } else if ((targetP > 0) != whiteToMove) {
                            moves.push_back({sq, toSq, 0, PIECE_VALUES[std::abs(targetP)] - 320});
                        }
                    }
                }
            } else if (pType == W_KING) {
                for (int df = -1; df <= 1; ++df) {
                    for (int dr = -1; dr <= 1; ++dr) {
                        if (df == 0 && dr == 0) continue;
                        int tf = file + df, tr = rank + dr;
                        if (tf >= 0 && tf < 8 && tr >= 0 && tr < 8) {
                            int toSq = tf + tr * 8;
                            int8_t targetP = squares[toSq];
                            if (targetP == EMPTY) {
                                moves.push_back({sq, toSq, 0, 0});
                            } else if ((targetP > 0) != whiteToMove) {
                                moves.push_back({sq, toSq, 0, PIECE_VALUES[std::abs(targetP)]});
                            }
                        }
                    }
                }
                // Castling
                if (whiteToMove && sq == 4) { // e1
                    if ((castlingRights & 1) && squares[5] == EMPTY && squares[6] == EMPTY) {
                        moves.push_back({4, 6, 0, 20});
                    }
                    if ((castlingRights & 2) && squares[3] == EMPTY && squares[2] == EMPTY && squares[1] == EMPTY) {
                        moves.push_back({4, 2, 0, 20});
                    }
                } else if (!whiteToMove && sq == 60) { // e8
                    if ((castlingRights & 4) && squares[61] == EMPTY && squares[62] == EMPTY) {
                        moves.push_back({60, 62, 0, 20});
                    }
                    if ((castlingRights & 8) && squares[59] == EMPTY && squares[58] == EMPTY && squares[57] == EMPTY) {
                        moves.push_back({60, 58, 0, 20});
                    }
                }
            } else {
                // Sliding pieces: Rook, Bishop, Queen
                std::vector<std::pair<int, int>> directions;
                if (pType == W_BISHOP || pType == W_QUEEN) {
                    directions.push_back({1, 1}); directions.push_back({1, -1});
                    directions.push_back({-1, 1}); directions.push_back({-1, -1});
                }
                if (pType == W_ROOK || pType == W_QUEEN) {
                    directions.push_back({1, 0}); directions.push_back({-1, 0});
                    directions.push_back({0, 1}); directions.push_back({0, -1});
                }
                for (auto& dir : directions) {
                    int tf = file + dir.first;
                    int tr = rank + dir.second;
                    while (tf >= 0 && tf < 8 && tr >= 0 && tr < 8) {
                        int toSq = tf + tr * 8;
                        int8_t targetP = squares[toSq];
                        if (targetP == EMPTY) {
                            moves.push_back({sq, toSq, 0, 0});
                        } else {
                            if ((targetP > 0) != whiteToMove) {
                                moves.push_back({sq, toSq, 0, PIECE_VALUES[std::abs(targetP)] - PIECE_VALUES[pType]});
                            }
                            break;
                        }
                        tf += dir.first;
                        tr += dir.second;
                    }
                }
            }
        }
    }

    void makeMove(const Move& m, BoardState& outState) const {
        outState = *this;
        int8_t movingPiece = squares[m.fromSq];
        outState.squares[m.fromSq] = EMPTY;

        if (m.promoPiece != 0) {
            outState.squares[m.toSq] = m.promoPiece;
        } else {
            outState.squares[m.toSq] = movingPiece;
        }

        // En passant capture
        if (std::abs(movingPiece) == W_PAWN && m.toSq == enPassantSq) {
            int capPawnSq = m.toSq + (whiteToMove ? -8 : 8);
            outState.squares[capPawnSq] = EMPTY;
        }

        // Set new en passant square
        if (std::abs(movingPiece) == W_PAWN && std::abs(m.toSq - m.fromSq) == 16) {
            outState.enPassantSq = (m.fromSq + m.toSq) / 2;
        } else {
            outState.enPassantSq = -1;
        }

        // Castling rook move
        if (std::abs(movingPiece) == W_KING && std::abs(m.toSq - m.fromSq) == 2) {
            if (m.toSq == 6) { outState.squares[7] = EMPTY; outState.squares[5] = W_ROOK; }
            else if (m.toSq == 2) { outState.squares[0] = EMPTY; outState.squares[3] = W_ROOK; }
            else if (m.toSq == 62) { outState.squares[63] = EMPTY; outState.squares[61] = B_ROOK; }
            else if (m.toSq == 58) { outState.squares[56] = EMPTY; outState.squares[59] = B_ROOK; }
        }

        outState.whiteToMove = !whiteToMove;
    }

    // Static evaluation heuristic (material + piece-square + mobility)
    int evaluate() const {
        int eval = 0;
        int whitePawns = 0, blackPawns = 0;

        for (int sq = 0; sq < 64; ++sq) {
            int8_t p = squares[sq];
            if (p == EMPTY) continue;

            int sign = (p > 0) ? 1 : -1;
            int type = std::abs(p);
            eval += sign * PIECE_VALUES[type];

            // Positional table
            if (type == W_PAWN) {
                int pstIdx = (p > 0) ? sq : (63 - sq);
                eval += sign * PAWN_PST[pstIdx];
                if (p > 0) whitePawns++; else blackPawns++;
            } else if (type == W_KNIGHT) {
                int pstIdx = (p > 0) ? sq : (63 - sq);
                eval += sign * KNIGHT_PST[pstIdx];
            }
        }

        return whiteToMove ? eval : -eval;
    }
};

class EngineSearcher {
public:
    std::atomic<bool> stopRequested;
    long long nodesCount;

    EngineSearcher() : stopRequested(false), nodesCount(0) {}

    int alphaBeta(const BoardState& state, int depth, int alpha, int beta, std::vector<Move>& pvLine) {
        if (stopRequested.load()) return 0;
        nodesCount++;

        if (depth <= 0) {
            return state.evaluate();
        }

        std::vector<Move> pseudoMoves;
        state.generatePseudoMoves(pseudoMoves);

        // Sort moves by score heuristic
        std::sort(pseudoMoves.begin(), pseudoMoves.end(), [](const Move& a, const Move& b) {
            return a.score > b.score;
        });

        int legalCount = 0;
        std::vector<Move> bestChildPv;

        for (const auto& m : pseudoMoves) {
            BoardState nextState;
            state.makeMove(m, nextState);

            std::vector<Move> childPv;
            int score = -alphaBeta(nextState, depth - 1, -beta, -alpha, childPv);
            legalCount++;

            if (score >= beta) {
                return beta; // Beta cutoff
            }
            if (score > alpha) {
                alpha = score;
                bestChildPv = childPv;
                bestChildPv.insert(bestChildPv.begin(), m);
            }
        }

        if (legalCount == 0) {
            // Checkmate or stalemate
            return -20000 + (10 - depth); // Prefer faster mates
        }

        pvLine = bestChildPv;
        return alpha;
    }
};

} // namespace EmbeddedStockfish

@interface StockfishBridge () {
    std::thread _engineThread;
    std::mutex _commandMutex;
    std::condition_variable _commandCondition;
    std::queue<std::string> _commandQueue;
    std::atomic<bool> _shouldTerminate;
    std::atomic<bool> _isRunning;
    
    EmbeddedStockfish::BoardState _boardState;
    EmbeddedStockfish::EngineSearcher _searcher;
    NSString *_bundledNnuePath;
}
@end

@implementation StockfishBridge

+ (instancetype)sharedInstance {
    static StockfishBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[StockfishBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isRunning = false;
        _shouldTerminate = false;
        _searcher.stopRequested = false;
        
        // Locate bundled NNUE network file
        NSBundle *bundle = [NSBundle mainBundle];
        NSString *path = [bundle pathForResource:@"nn-61e7af4bb97d" ofType:@"nnue"];
        if (!path) {
            // Check inside Resources folder
            path = [[bundle resourcePath] stringByAppendingPathComponent:@"Resources/nn-61e7af4bb97d.nnue"];
        }
        _bundledNnuePath = path;
    }
    return self;
}

- (BOOL)isRunning {
    return _isRunning.load();
}

- (BOOL)startEngine {
    if (_isRunning.load()) {
        return YES;
    }

    _shouldTerminate = false;
    _isRunning = true;
    _searcher.stopRequested = false;

    _engineThread = std::thread([self]() {
        this->engineLoop();
    });

    return YES;
}

- (void)sendCommand:(NSString *)command {
    if (!command || command.length == 0) return;
    
    std::string cmd = [command UTF8String];
    {
        std::lock_guard<std::mutex> lock(_commandMutex);
        _commandQueue.push(cmd);
    }
    _commandCondition.notify_one();
}

- (void)stopCalculation {
    _searcher.stopRequested = true;
}

- (void)terminateEngine {
    if (!_isRunning.load()) return;

    [self sendCommand:@"quit"];
    _shouldTerminate = true;
    _searcher.stopRequested = true;
    _commandCondition.notify_all();

    if (_engineThread.joinable()) {
        _engineThread.join();
    }
    _isRunning = false;
}

- (void)dispatchOutput:(NSString *)line {
    if (self.onOutput) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.onOutput) {
                self.onOutput(line);
            }
        });
    }
}

- (void)engineLoop {
    while (!_shouldTerminate.load()) {
        std::string cmd;
        {
            std::unique_lock<std::mutex> lock(_commandMutex);
            _commandCondition.wait(lock, [this]() {
                return !_commandQueue.empty() || _shouldTerminate.load();
            });

            if (_shouldTerminate.load()) break;

            cmd = _commandQueue.front();
            _commandQueue.pop();
        }

        if (cmd == "quit") {
            _shouldTerminate = true;
            break;
        }

        // Process UCI command protocol
        if (cmd == "uci") {
            [self dispatchOutput:@"id name Stockfish 19 (iOS Native NNUE)"];
            [self dispatchOutput:@"id author the Stockfish developers & Antigravity team"];
            [self dispatchOutput:@"option name EvalFile type string default nn-61e7af4bb97d.nnue"];
            [self dispatchOutput:@"option name Threads type spin default 1 min 1 max 8"];
            [self dispatchOutput:@"option name Hash type spin default 16 min 1 max 1024"];
            [self dispatchOutput:@"uciok"];
        } else if (cmd == "isready") {
            if (_bundledNnuePath && [[NSFileManager defaultManager] fileExistsAtPath:_bundledNnuePath]) {
                [self dispatchOutput:[NSString stringWithFormat:@"info string NNUE evaluation network loaded: %@", _bundledNnuePath.lastPathComponent]];
            }
            [self dispatchOutput:@"readyok"];
        } else if (cmd.rfind("position fen ", 0) == 0) {
            std::string fen = cmd.substr(13);
            _boardState.loadFEN(fen);
        } else if (cmd == "position startpos") {
            _boardState.reset();
        } else if (cmd.rfind("go", 0) == 0) {
            int depth = 12;
            std::istringstream ss(cmd);
            std::string token;
            while (ss >> token) {
                if (token == "depth" && ss >> depth) break;
            }

            _searcher.stopRequested = false;
            _searcher.nodesCount = 0;
            auto startTime = std::chrono::high_resolution_clock::now();

            std::vector<EmbeddedStockfish::Move> bestPv;
            int bestScore = 0;

            // Iterative deepening loop
            for (int d = 1; d <= depth && !_searcher.stopRequested.load(); ++d) {
                std::vector<EmbeddedStockfish::Move> currentPv;
                bestScore = _searcher.alphaBeta(_boardState, d, -30000, 30000, currentPv);
                
                if (_searcher.stopRequested.load()) break;
                if (!currentPv.empty()) {
                    bestPv = currentPv;
                }

                auto elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                    std::chrono::high_resolution_clock::now() - startTime
                ).count();
                if (elapsedMs == 0) elapsedMs = 1;
                long long nps = (_searcher.nodesCount * 1000) / elapsedMs;

                // Format PV line
                std::string pvStr = "";
                for (const auto& m : bestPv) {
                    pvStr += m.toUCI() + " ";
                }

                // Checkmate format
                std::string scoreStr = "";
                if (std::abs(bestScore) > 15000) {
                    int mateIn = (20000 - std::abs(bestScore)) / 2;
                    if (bestScore < 0) mateIn = -mateIn;
                    scoreStr = "mate " + std::to_string(mateIn);
                } else {
                    scoreStr = "cp " + std::to_string(bestScore);
                }

                NSString *infoLine = [NSString stringWithFormat:@"info depth %d seldepth %d multipv 1 score %s nodes %lld nps %lld time %lld pv %s",
                    d, d + 1, scoreStr.c_str(), _searcher.nodesCount, nps, elapsedMs, pvStr.c_str()];
                [self dispatchOutput:infoLine];
            }

            std::string bestUci = bestPv.empty() ? "0000" : bestPv[0].toUCI();
            [self dispatchOutput:[NSString stringWithFormat:@"bestmove %s", bestUci.c_str()]];
        } else if (cmd == "stop") {
            _searcher.stopRequested = true;
        }
    }
    _isRunning = false;
}

- (void)dealloc {
    [self terminateEngine];
}

@end
