const { Chess } = require('chess.js');
const initEngine = require('stockfish');

console.log("=== Testing chess.js and Stockfish integration ===");

const chess = new Chess();
console.log("Initial FEN:", chess.fen());

// Play Scholar's mate
chess.move('e4');
chess.move('e5');
chess.move('Qh5');
chess.move('Nc6');
chess.move('Bc4');
chess.move('Nf6');
const blunderMove = chess.move('Qxf7#');

console.log("Move made:", blunderMove.san);
console.log("Is checkmate:", chess.isCheckmate());
console.log("PGN:\n" + chess.pgn());

// Test Stockfish ASM
const engine = initEngine('asm', (line) => {
    const text = String(line).trim();
    if (text.includes('score cp') || text.includes('score mate')) {
        console.log("[Engine Eval Line]:", text);
    }
    if (text.includes('bestmove')) {
        console.log("[Engine BestMove]:", text);
        if (engine.terminate) engine.terminate();
        console.log("=== TEST COMPLETED SUCCESSFULLY ===");
        process.exit(0);
    }
});

engine.processCommand('uci');
engine.processCommand('isready');
engine.processCommand('position fen r1bqkb1r/pppp1ppp/2n5/4p2Q/2B1n3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 4');
engine.processCommand('go depth 10');

setTimeout(() => {
    console.error("Engine timeout!");
    process.exit(1);
}, 10000);
