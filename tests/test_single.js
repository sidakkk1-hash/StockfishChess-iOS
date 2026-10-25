const initEngine = require("stockfish");

console.log("Testing Single-Threaded Full WASM Stockfish Engine...");
const sf = initEngine("single", (l) => {
    const line = String(l).trim();
    if (line.includes("bestmove")) {
        console.log("FULL WASM SUCCESS:", line);
        if (sf.terminate) sf.terminate();
        process.exit(0);
    }
});

sf.processCommand("uci");
sf.processCommand("isready");
sf.processCommand("position startpos");
sf.processCommand("go depth 6");

setTimeout(() => {
    console.error("Single WASM timeout");
    process.exit(1);
}, 12000);
