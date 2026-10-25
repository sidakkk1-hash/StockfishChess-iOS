const initEngine = require("stockfish");

console.log("Initializing Stockfish 'lite-single' Engine...");

let sentReady = false;
let sentSearch = false;

const engine = initEngine("lite-single", function onMessage(chunk) {
    const text = String(chunk);
    // Split into lines
    const lines = text.split(/[\r\n]+/);
    for (const rawLine of lines) {
        const line = rawLine.trim();
        if (!line) continue;
        console.log("[SF OUT]:", line);

        if (!sentReady && (line.includes("uciok") || line === "uciok")) {
            sentReady = true;
            console.log("-> uciok received. Sending isready...");
            engine.processCommand("isready");
        } else if (sentReady && !sentSearch && (line.includes("readyok") || line === "readyok")) {
            sentSearch = true;
            console.log("-> readyok received. Testing tactical puzzle position (Scholar's Mate defense or Queen blunder)...");
            engine.processCommand("position fen rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2");
            engine.processCommand("go depth 12");
        } else if (/bestmove\s+(\S+)/.test(line)) {
            const bestmove = line.match(/bestmove\s+(\S+)/)[1];
            console.log("\n=================================");
            console.log("TEST PASSED: Best Move calculated:", bestmove);
            console.log("=================================\n");
            if (engine.terminate) engine.terminate();
            process.exit(0);
        }
    }
});

engine.processCommand("uci");

setTimeout(() => {
    console.error("Test timed out after 15 seconds.");
    if (engine.terminate) engine.terminate();
    process.exit(1);
}, 15000);
