const http = require('http');
const fs = require('fs');
const path = require('path');
const initEngine = require('stockfish');

const PORT = 3000;
const PUBLIC_DIR = path.join(__dirname, 'public');

// Initialize Stockfish ASM engine
let engine = null;
let currentEval = {
    depth: 0,
    scoreCp: 0,
    mateIn: null,
    bestMove: null,
    pv: []
};

let isSearching = false;
let currentResolve = null;
let stopResolve = null;
let currentSearchId = 0;
let activeSearchId = 0;

function getEngine() {
    if (engine) return engine;
    console.log('[Stockfish] Initializing offline Stockfish engine...');
    engine = initEngine('asm', (chunk) => {
        const text = String(chunk);
        const lines = text.split(/[\r\n]+/);
        for (const rawLine of lines) {
            const line = rawLine.trim();
            if (!line) continue;
            
            if (line === 'readyok' && stopResolve) {
                const cb = stopResolve;
                stopResolve = null;
                cb();
            } else if (line.startsWith('info') && activeSearchId === currentSearchId) {
                parseInfoLine(line);
            } else if (line.startsWith('bestmove')) {
                isSearching = false;
                const parts = line.split(/\s+/);
                if (parts.length >= 2) {
                    currentEval.bestMove = parts[1];
                }
                if (currentResolve && activeSearchId === currentSearchId) {
                    const res = currentResolve;
                    currentResolve = null;
                    res({ ...currentEval });
                }
            }
        }
    });
    
    engine.processCommand('uci');
    engine.processCommand('isready');
    return engine;
}

function parseInfoLine(line) {
    const parts = line.split(/\s+/);
    let i = 0;
    while (i < parts.length) {
        const key = parts[i];
        if (key === 'depth' && i + 1 < parts.length) {
            currentEval.depth = parseInt(parts[i + 1], 10);
            i += 2;
        } else if (key === 'score' && i + 2 < parts.length) {
            const type = parts[i + 1];
            const val = parseInt(parts[i + 2], 10);
            if (type === 'cp') {
                currentEval.scoreCp = val;
                currentEval.mateIn = null;
            } else if (type === 'mate') {
                currentEval.mateIn = val;
            }
            i += 3;
        } else if (key === 'pv' && i + 1 < parts.length) {
            currentEval.pv = parts.slice(i + 1);
            break;
        } else {
            i++;
        }
    }
}

function evaluatePosition(fen, depth = 12) {
    return new Promise((resolve) => {
        const eng = getEngine();
        currentSearchId++;
        const thisSearchId = currentSearchId;
        
        const launchSearch = () => {
            currentEval = { depth: 0, scoreCp: 0, mateIn: null, bestMove: null, pv: [] };
            activeSearchId = thisSearchId;
            currentResolve = resolve;
            isSearching = true;
            eng.processCommand(`position fen ${fen}`);
            eng.processCommand(`go depth ${depth}`);
        };

        if (isSearching) {
            if (currentResolve && activeSearchId !== thisSearchId) {
                const oldRes = currentResolve;
                currentResolve = null;
                oldRes({ ...currentEval });
            }
            stopResolve = () => {
                launchSearch();
            };
            eng.processCommand('stop');
            eng.processCommand('isready');
        } else {
            launchSearch();
        }
        
        // Safety timeout
        setTimeout(() => {
            if (currentResolve === resolve) {
                currentResolve = null;
                resolve({ ...currentEval });
            }
        }, 12000);
    });
}

// Ensure engine starts early
getEngine();

const server = http.createServer(async (req, res) => {
    // API routes
    if (req.url.startsWith('/api/evaluate') && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', async () => {
            try {
                const data = JSON.parse(body || '{}');
                const fen = data.fen || 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
                const depth = Math.max(4, Math.min(20, parseInt(data.depth, 10) || 12));
                const result = await evaluatePosition(fen, depth);
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify(result));
            } catch (err) {
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    if (req.url.startsWith('/api/review') && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', async () => {
            try {
                const data = JSON.parse(body || '{}');
                const moves = data.moves || [];
                const depth = Math.max(6, Math.min(14, parseInt(data.depth, 10) || 10));
                
                // Helper win chance formula
                function winChance(cp) {
                    const clamped = Math.max(-2000, Math.min(2000, cp));
                    return 50.0 + 50.0 * (2.0 / (1.0 + Math.exp(-0.00368208 * clamped)) - 1.0);
                }
                
                const analyzedMoves = [];
                let whiteLossSum = 0;
                let whiteMovesCount = 0;
                let blackLossSum = 0;
                let blackMovesCount = 0;
                let whiteBlunders = 0, whiteMistakes = 0, whiteInaccuracies = 0;
                let blackBlunders = 0, blackMistakes = 0, blackInaccuracies = 0;
                
                for (let i = 0; i < moves.length; i++) {
                    const m = moves[i];
                    const isWhite = (m.ply % 2 !== 0);
                    
                    // 1. Eval position before
                    const evalBefore = await evaluatePosition(m.fenBefore, depth);
                    // 2. Eval position after
                    const evalAfter = await evaluatePosition(m.fenAfter, depth);
                    
                    const bestMoveUci = evalBefore.bestMove || '';
                    const playedUci = m.uci || '';
                    
                    // Calculate classification
                    let classification = 'Good';
                    const winBefore = isWhite ? winChance(evalBefore.scoreCp) : (100 - winChance(evalBefore.scoreCp));
                    const winAfter = isWhite ? winChance(evalAfter.scoreCp) : (100 - winChance(evalAfter.scoreCp));
                    const winLoss = Math.max(0, winBefore - winAfter);
                    
                    if (playedUci === bestMoveUci) {
                        classification = 'Best';
                    } else if (winLoss < 2.0) {
                        classification = 'Excellent';
                    } else if (winLoss < 5.0) {
                        classification = 'Good';
                    } else if (winLoss < 12.0) {
                        classification = 'Inaccuracy';
                    } else if (winLoss < 25.0) {
                        classification = 'Mistake';
                    } else {
                        classification = 'Blunder';
                    }
                    
                    if (isWhite) {
                        whiteLossSum += winLoss;
                        whiteMovesCount++;
                        if (classification === 'Blunder') whiteBlunders++;
                        else if (classification === 'Mistake') whiteMistakes++;
                        else if (classification === 'Inaccuracy') whiteInaccuracies++;
                    } else {
                        blackLossSum += winLoss;
                        blackMovesCount++;
                        if (classification === 'Blunder') blackBlunders++;
                        else if (classification === 'Mistake') blackMistakes++;
                        else if (classification === 'Inaccuracy') blackInaccuracies++;
                    }
                    
                    analyzedMoves.push({
                        ...m,
                        evalCp: evalAfter.scoreCp,
                        mateIn: evalAfter.mateIn,
                        bestMoveUci: bestMoveUci,
                        classification: classification,
                        winLoss: winLoss.toFixed(1)
                    });
                }
                
                const whiteAccuracy = whiteMovesCount > 0 ? Math.max(0, Math.min(100, 100 - (1.8 * (whiteLossSum / whiteMovesCount)))) : 100;
                const blackAccuracy = blackMovesCount > 0 ? Math.max(0, Math.min(100, 100 - (1.8 * (blackLossSum / blackMovesCount)))) : 100;
                
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                    analyzedMoves,
                    stats: {
                        whiteAccuracy: parseFloat(whiteAccuracy.toFixed(1)),
                        blackAccuracy: parseFloat(blackAccuracy.toFixed(1)),
                        whiteBlunders,
                        whiteMistakes,
                        whiteInaccuracies,
                        blackBlunders,
                        blackMistakes,
                        blackInaccuracies
                    }
                }));
            } catch (err) {
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    // Static files
    let reqPath = req.url.split('?')[0];
    if (reqPath === '/') reqPath = '/index.html';
    
    // Serve chess.esm.js bundle if requested
    if (reqPath === '/chess.esm.js') {
        const chessJsPath = path.join(__dirname, '..', 'node_modules', 'chess.js', 'dist', 'esm', 'chess.js');
        try {
            const content = fs.readFileSync(chessJsPath);
            res.writeHead(200, { 'Content-Type': 'application/javascript' });
            return res.end(content);
        } catch (e) {}
    }

    const filePath = path.join(PUBLIC_DIR, reqPath);
    if (!fs.existsSync(filePath)) {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        return res.end('File Not Found');
    }

    const ext = path.extname(filePath).toLowerCase();
    const mimeTypes = {
        '.html': 'text/html',
        '.css': 'text/css',
        '.js': 'application/javascript',
        '.json': 'application/json',
        '.svg': 'image/svg+xml',
        '.png': 'image/png'
    };

    res.writeHead(200, { 'Content-Type': mimeTypes[ext] || 'text/plain' });
    fs.createReadStream(filePath).pipe(res);
});

server.listen(PORT, '127.0.0.1', () => {
    console.log(`[Stockfish Chess] Server listening on http://127.0.0.1:${PORT}`);
});
