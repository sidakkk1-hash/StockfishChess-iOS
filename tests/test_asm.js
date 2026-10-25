const initEngine = require("stockfish");

console.log("Testing ASM-JS Stockfish Engine...");
const sf = initEngine("asm", (l) => {
    const line = String(l).trim();
    if (line.includes("bestmove")) {
        console.log("ASM SUCCESS:", line);
        if (sf.terminate) sf.terminate();
        process.exit(0);
    }
});

sf.processCommand("uci");
sf.processCommand("isready");
sf.processCommand("position startpos");
sf.processCommand("go depth 8");

setTimeout(() => {
    console.error("ASM timeout");
    process.exit(1);
}, 10000);
