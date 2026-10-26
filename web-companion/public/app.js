import { Chess } from '/chess.esm.js';

// --- State Variables ---
let game = new Chess();
let isFlipped = false;
let selectedSquare = null;
let legalMoves = [];
let moveHistory = []; // { ply, san, uci, fenBefore, fenAfter, moveNumber }
let currentPly = 0;
let autoAnalyze = true;
let targetDepth = 12;
let isAnalyzing = false;
let analyzedMoves = [];
let pendingPromotion = null;
let soundEnabled = true;
let showArrow = true;
let showHints = true;

const PIECE_UNICODE = {
    'p': '♟', 'n': '♞', 'b': '♝', 'r': '♜', 'q': '♛', 'k': '♚',
    'P': '♙', 'N': '♘', 'B': '♗', 'R': '♖', 'Q': '♕', 'K': '♔'
};

const FILES = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
const RANKS = ['8', '7', '6', '5', '4', '3', '2', '1'];

// --- Audio Synthesizer (Realistic Web Audio API) ---
const audioCtx = new (window.AudioContext || window.webkitAudioContext)();

function playSound(type) {
    if (!soundEnabled || !audioCtx) return;
    if (audioCtx.state === 'suspended') {
        audioCtx.resume();
    }
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.connect(gain);
    gain.connect(audioCtx.destination);

    const now = audioCtx.currentTime;
    if (type === 'move') {
        osc.frequency.setValueAtTime(320, now);
        osc.frequency.exponentialRampToValueAtTime(140, now + 0.08);
        gain.gain.setValueAtTime(0.3, now);
        gain.gain.exponentialRampToValueAtTime(0.01, now + 0.08);
        osc.start(now);
        osc.stop(now + 0.08);
    } else if (type === 'capture') {
        osc.frequency.setValueAtTime(450, now);
        osc.frequency.exponentialRampToValueAtTime(90, now + 0.12);
        gain.gain.setValueAtTime(0.45, now);
        gain.gain.exponentialRampToValueAtTime(0.01, now + 0.12);
        osc.start(now);
        osc.stop(now + 0.12);
    } else if (type === 'check') {
        osc.frequency.setValueAtTime(600, now);
        osc.frequency.exponentialRampToValueAtTime(400, now + 0.2);
        gain.gain.setValueAtTime(0.35, now);
        gain.gain.exponentialRampToValueAtTime(0.01, now + 0.2);
        osc.start(now);
        osc.stop(now + 0.2);
    }
}

// --- DOM References ---
const chessboard = document.getElementById('chessboard');
const chessboardWrapper = document.getElementById('chessboardWrapper');
const evalBarContainer = document.getElementById('evalBarContainer');
const evalWhitePart = document.getElementById('evalWhitePart');
const evalBlackPart = document.getElementById('evalBlackPart');
const evalScoreText = document.getElementById('evalScoreText');
const bestMoveArrow = document.getElementById('bestMoveArrow');
const plyIndicator = document.getElementById('plyIndicator');
const metricBestMove = document.getElementById('metricBestMove');
const metricScore = document.getElementById('metricScore');
const metricPV = document.getElementById('metricPV');
const depthSlider = document.getElementById('depthSlider');
const depthVal = document.getElementById('depthVal');
const chkAutoAnalyze = document.getElementById('chkAutoAnalyze');
const movesTable = document.getElementById('movesTable');
const movesCount = document.getElementById('movesCount');
const topPlayerName = document.getElementById('topPlayerName');
const bottomPlayerName = document.getElementById('bottomPlayerName');
const topTurnIndicator = document.getElementById('topTurnIndicator');
const bottomTurnIndicator = document.getElementById('bottomTurnIndicator');
const topCapturedPieces = document.getElementById('topCapturedPieces');
const bottomCapturedPieces = document.getElementById('bottomCapturedPieces');
const gameOverModal = document.getElementById('gameOverModal');
const gameOverTitle = document.getElementById('gameOverTitle');
const gameOverSubtitle = document.getElementById('gameOverSubtitle');
const promotionModal = document.getElementById('promotionModal');
const promoOptions = document.getElementById('promoOptions');
const pgnModal = document.getElementById('pgnModal');
const settingsModal = document.getElementById('settingsModal');
const reviewStatsCard = document.getElementById('reviewStatsCard');
const whiteAccVal = document.getElementById('whiteAccVal');
const blackAccVal = document.getElementById('blackAccVal');
const whiteBlundersCount = document.getElementById('whiteBlundersCount');
const blackBlundersCount = document.getElementById('blackBlundersCount');
const btnRunReview = document.getElementById('btnRunReview');
const reviewProgressContainer = document.getElementById('reviewProgressContainer');
const reviewProgressBar = document.getElementById('reviewProgressBar');
const reviewProgressText = document.getElementById('reviewProgressText');
const graphPath = document.getElementById('graphPath');
const graphDots = document.getElementById('graphDots');
const graphCursor = document.getElementById('graphCursor');
const graphContainer = document.getElementById('graphContainer');

// --- Initialization ---
let isInitialized = false;

function init() {
    if (isInitialized) return;
    isInitialized = true;
    console.log('[App] Initializing chess app (once)...');
    renderBoard();
    updateStatus();
    runEngineAnalysis();
    setupEventListeners();
}

// --- Board Rendering ---
function renderBoard() {
    chessboard.innerHTML = '';
    const displayRanks = isFlipped ? [...RANKS].reverse() : RANKS;
    const displayFiles = isFlipped ? [...FILES].reverse() : FILES;

    const currentLastMove = getCurrentLastMove();
    const inCheck = game.inCheck();
    const turn = game.turn();

    for (let r = 0; r < 8; r++) {
        for (let f = 0; f < 8; f++) {
            const rank = displayRanks[r];
            const file = displayFiles[f];
            const sqName = `${file}${rank}`;
            const isLight = (r + f) % 2 === 0;

            const sqEl = document.createElement('div');
            sqEl.className = `square ${isLight ? 'light' : 'dark'}`;
            sqEl.dataset.square = sqName;

            // Highlight selected
            if (sqName === selectedSquare) {
                sqEl.classList.add('selected');
            }

            // Highlight last move
            if (currentLastMove && (sqName === currentLastMove.from || sqName === currentLastMove.to)) {
                sqEl.classList.add('last-move');
            }

            // Highlight king under check
            if (inCheck) {
                const pieceOnSq = game.get(sqName);
                if (pieceOnSq && pieceOnSq.type === 'k' && pieceOnSq.color === turn) {
                    sqEl.classList.add('in-check');
                }
            }

            // Coordinates
            if (f === 0) {
                const rLabel = document.createElement('span');
                rLabel.className = 'coord-rank';
                rLabel.textContent = rank;
                sqEl.appendChild(rLabel);
            }
            if (r === 7) {
                const fLabel = document.createElement('span');
                fLabel.className = 'coord-file';
                fLabel.textContent = file;
                sqEl.appendChild(fLabel);
            }

            // Piece rendering
            const piece = game.get(sqName);
            if (piece) {
                const pieceEl = document.createElement('span');
                pieceEl.className = `piece ${piece.color === 'w' ? 'white-piece' : 'black-piece'}`;
                const glyphKey = piece.color === 'w' ? piece.type.toUpperCase() : piece.type.toLowerCase();
                pieceEl.textContent = PIECE_UNICODE[glyphKey] || '';
                sqEl.appendChild(pieceEl);
            }

            // Legal move hints
            if (showHints && legalMoves.includes(sqName)) {
                if (piece) {
                    const ring = document.createElement('div');
                    ring.className = 'capture-ring';
                    sqEl.appendChild(ring);
                } else {
                    const dot = document.createElement('div');
                    dot.className = 'move-dot';
                    sqEl.appendChild(dot);
                }
            }

            sqEl.addEventListener('click', () => onSquareClick(sqName));
            chessboard.appendChild(sqEl);
        }
    }
}

// --- Square Click Handling ---
function onSquareClick(square) {
    if (game.isGameOver()) return;

    if (selectedSquare) {
        // Destination clicked
        if (legalMoves.includes(square)) {
            const piece = game.get(selectedSquare);
            const isPromotion = piece && piece.type === 'p' &&
                ((piece.color === 'w' && square.endsWith('8')) || (piece.color === 'b' && square.endsWith('1')));

            if (isPromotion) {
                pendingPromotion = { from: selectedSquare, to: square };
                showPromotionDialog(piece.color);
                selectedSquare = null;
                legalMoves = [];
                renderBoard();
                return;
            }

            makePlayerMove(selectedSquare, square);
            selectedSquare = null;
            legalMoves = [];
            return;
        }

        // Tapped another friendly piece: change selection
        const targetPiece = game.get(square);
        if (targetPiece && targetPiece.color === game.turn()) {
            selectedSquare = square;
            const moves = game.moves({ square: square, verbose: true });
            legalMoves = moves.map(m => m.to);
            renderBoard();
            return;
        }

        // Deselect
        selectedSquare = null;
        legalMoves = [];
        renderBoard();
    } else {
        // Initial select
        const piece = game.get(square);
        if (piece && piece.color === game.turn()) {
            selectedSquare = square;
            const moves = game.moves({ square: square, verbose: true });
            legalMoves = moves.map(m => m.to);
            renderBoard();
        }
    }
}

function makePlayerMove(from, to, promotion = 'q') {
    const fenBefore = game.fen();
    try {
        const moveResult = game.move({ from, to, promotion });
        if (!moveResult) return;

        playSound(moveResult.captured ? 'capture' : (game.inCheck() ? 'check' : 'move'));

        const fenAfter = game.fen();
        const ply = moveHistory.length + 1;
        const moveNumber = Math.floor(moveHistory.length / 2) + 1;

        moveHistory.push({
            ply,
            moveNumber,
            san: moveResult.san,
            uci: `${from}${to}${promotion || ''}`,
            fenBefore,
            fenAfter
        });

        currentPly = moveHistory.length;
        if (bestMoveArrow) bestMoveArrow.style.display = 'none';
        if (metricBestMove) metricBestMove.textContent = '...';
        renderBoard();
        updateStatus();
        renderMovesTable();
        updateGraph();

        if (autoAnalyze) {
            runEngineAnalysis();
        }
    } catch (e) {
        console.error("Illegal move:", e);
    }
}

function showPromotionDialog(color) {
    promoOptions.innerHTML = '';
    const choices = ['q', 'r', 'b', 'n'];
    choices.forEach(ch => {
        const btn = document.createElement('button');
        btn.className = 'promo-btn';
        const glyphKey = color === 'w' ? ch.toUpperCase() : ch;
        btn.textContent = PIECE_UNICODE[glyphKey];
        btn.addEventListener('click', () => {
            promotionModal.style.display = 'none';
            if (pendingPromotion) {
                makePlayerMove(pendingPromotion.from, pendingPromotion.to, ch);
                pendingPromotion = null;
            }
        });
        promoOptions.appendChild(btn);
    });
    promotionModal.style.display = 'flex';
}

// --- Status, Turn & Captured Pieces ---
function updateStatus() {
    const turn = game.turn();
    const isWhiteTurn = turn === 'w';

    // Turn indicators
    if (isFlipped) {
        topTurnIndicator.className = `turn-indicator ${isWhiteTurn ? 'active' : ''}`;
        bottomTurnIndicator.className = `turn-indicator ${!isWhiteTurn ? 'active' : ''}`;
        topPlayerName.textContent = 'White';
        bottomPlayerName.textContent = 'Black';
    } else {
        topTurnIndicator.className = `turn-indicator ${!isWhiteTurn ? 'active' : ''}`;
        bottomTurnIndicator.className = `turn-indicator ${isWhiteTurn ? 'active' : ''}`;
        topPlayerName.textContent = 'Black';
        bottomPlayerName.textContent = 'White';
    }

    plyIndicator.textContent = currentPly > 0 ? `Ply ${currentPly} / ${moveHistory.length}` : 'Start';
    movesCount.textContent = `${moveHistory.length} moves`;

    // Calculate captured pieces
    calculateCapturedPieces();

    // Check game over
    if (game.isGameOver()) {
        let title = 'Game Over';
        let sub = 'Draw';
        if (game.isCheckmate()) {
            title = 'Checkmate!';
            sub = isWhiteTurn ? 'Black won by checkmate' : 'White won by checkmate';
        } else if (game.isStalemate()) {
            title = 'Stalemate';
            sub = 'Game drawn by stalemate';
        } else if (game.isThreefoldRepetition()) {
            title = 'Draw';
            sub = 'Draw by threefold repetition';
        } else if (game.isInsufficientMaterial()) {
            title = 'Draw';
            sub = 'Draw by insufficient material';
        }
        gameOverTitle.textContent = title;
        gameOverSubtitle.textContent = sub;
        gameOverModal.style.display = 'flex';
    } else {
        gameOverModal.style.display = 'none';
    }
}

function calculateCapturedPieces() {
    const fullSet = { p: 8, n: 2, b: 2, r: 2, q: 1 };
    const whitePresent = { p: 0, n: 0, b: 0, r: 0, q: 0 };
    const blackPresent = { p: 0, n: 0, b: 0, r: 0, q: 0 };

    const board = game.board();
    for (const row of board) {
        for (const sq of row) {
            if (sq) {
                if (sq.type !== 'k') {
                    if (sq.color === 'w') whitePresent[sq.type]++;
                    else blackPresent[sq.type]++;
                }
            }
        }
    }

    let capturedWhiteStr = '';
    let capturedBlackStr = '';

    for (const [type, count] of Object.entries(fullSet)) {
        const whiteDiff = count - whitePresent[type];
        if (whiteDiff > 0) capturedWhiteStr += PIECE_UNICODE[type.toUpperCase()].repeat(whiteDiff);
        const blackDiff = count - blackPresent[type];
        if (blackDiff > 0) capturedBlackStr += PIECE_UNICODE[type.toLowerCase()].repeat(blackDiff);
    }

    if (isFlipped) {
        topCapturedPieces.textContent = capturedBlackStr;
        bottomCapturedPieces.textContent = capturedWhiteStr;
    } else {
        topCapturedPieces.textContent = capturedWhiteStr;
        bottomCapturedPieces.textContent = capturedBlackStr;
    }
}

function getCurrentLastMove() {
    if (currentPly > 0 && currentPly <= moveHistory.length) {
        const uci = moveHistory[currentPly - 1].uci;
        return {
            from: uci.substring(0, 2),
            to: uci.substring(2, 4)
        };
    }
    return null;
}

// --- Stockfish Engine Communication ---
async function runEngineAnalysis() {
    if (!autoAnalyze) return;
    const currentFen = game.fen();
    try {
        const response = await fetch('/api/evaluate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ fen: currentFen, depth: targetDepth })
        });
        const data = await response.json();
        updateEngineMetrics(data);
    } catch (err) {
        console.error("Engine evaluation error:", err);
    }
}

function updateEngineMetrics(evalData) {
    if (!evalData) return;
    const best = evalData.bestMove || '—';
    metricBestMove.textContent = best;

    let scoreFormatted = '+0.00';
    let whiteFrac = 0.5;

    if (evalData.mateIn !== null) {
        scoreFormatted = `M${evalData.mateIn > 0 ? '+' + evalData.mateIn : evalData.mateIn}`;
        whiteFrac = evalData.mateIn > 0 ? 0.98 : 0.02;
    } else {
        const cp = evalData.scoreCp || 0;
        const scoreVal = (cp / 100.0).toFixed(2);
        scoreFormatted = cp > 0 ? `+${scoreVal}` : scoreVal;

        // Winning chance formula
        const clamped = Math.max(-1500, Math.min(1500, cp));
        const winChance = 50.0 + 50.0 * (2.0 / (1.0 + Math.exp(-0.00368208 * clamped)) - 1.0);
        whiteFrac = winChance / 100.0;
    }

    metricScore.textContent = scoreFormatted;
    evalScoreText.textContent = scoreFormatted;

    // Update Eval Bar
    const displayWhiteFrac = isFlipped ? (1.0 - whiteFrac) : whiteFrac;
    evalWhitePart.style.flex = displayWhiteFrac;
    evalBlackPart.style.flex = (1.0 - displayWhiteFrac);

    // Update PV Line
    metricPV.textContent = evalData.pv && evalData.pv.length > 0 ? evalData.pv.slice(0, 6).join(' ') : '—';

    // Draw Best Move Arrow
    if (showArrow && best && best.length >= 4) {
        drawBestMoveArrow(best.substring(0, 2), best.substring(2, 4));
    } else {
        bestMoveArrow.style.display = 'none';
    }
}

function drawBestMoveArrow(from, to) {
    // Verify move is strictly legal for the player whose turn it currently is
    const legals = game.moves({ verbose: true });
    const isLegalNow = legals.some(m => m.from === from && m.to === to);
    if (!isLegalNow) {
        bestMoveArrow.style.display = 'none';
        return;
    }

    const f1 = from[0], r1 = from[1];
    const f2 = to[0], r2 = to[1];

    const displayFiles = isFlipped ? [...FILES].reverse() : FILES;
    const displayRanks = isFlipped ? [...RANKS].reverse() : RANKS;

    const col1 = displayFiles.indexOf(f1);
    const row1 = displayRanks.indexOf(r1);
    const col2 = displayFiles.indexOf(f2);
    const row2 = displayRanks.indexOf(r2);

    if (col1 === -1 || row1 === -1 || col2 === -1 || row2 === -1) {
        bestMoveArrow.style.display = 'none';
        return;
    }

    const x1 = (col1 + 0.5) * 12.5;
    const y1 = (row1 + 0.5) * 12.5;
    const x2 = (col2 + 0.5) * 12.5;
    const y2 = (row2 + 0.5) * 12.5;

    bestMoveArrow.setAttribute('x1', x1);
    bestMoveArrow.setAttribute('y1', y1);
    bestMoveArrow.setAttribute('x2', x2);
    bestMoveArrow.setAttribute('y2', y2);
    bestMoveArrow.style.display = 'block';
}

// --- Moves Table & History ---
function renderMovesTable() {
    movesTable.innerHTML = '';
    const moves = analyzedMoves.length > 0 ? analyzedMoves : moveHistory;

    for (let i = 0; i < moves.length; i += 2) {
        const white = moves[i];
        const black = (i + 1 < moves.length) ? moves[i + 1] : null;
        const moveNum = Math.floor(i / 2) + 1;

        const row = document.createElement('div');
        row.className = 'move-row';

        const numEl = document.createElement('span');
        numEl.className = 'move-num';
        numEl.textContent = `${moveNum}.`;
        row.appendChild(numEl);

        // White move cell
        const whiteCell = document.createElement('div');
        whiteCell.className = `move-cell ${white.ply === currentPly ? 'active-ply' : ''}`;
        whiteCell.innerHTML = `<span>${white.san}</span>`;
        if (white.classification) {
            whiteCell.innerHTML += `<span class="move-badge badge-${white.classification.toLowerCase()}">${white.classification}</span>`;
        }
        whiteCell.addEventListener('click', () => jumpToPly(white.ply));
        row.appendChild(whiteCell);

        // Black move cell
        if (black) {
            const blackCell = document.createElement('div');
            blackCell.className = `move-cell ${black.ply === currentPly ? 'active-ply' : ''}`;
            blackCell.innerHTML = `<span>${black.san}</span>`;
            if (black.classification) {
                blackCell.innerHTML += `<span class="move-badge badge-${black.classification.toLowerCase()}">${black.classification}</span>`;
            }
            blackCell.addEventListener('click', () => jumpToPly(black.ply));
            row.appendChild(blackCell);
        }

        movesTable.appendChild(row);
    }
}

function jumpToPly(ply) {
    currentPly = Math.max(0, Math.min(moveHistory.length, ply));
    if (currentPly === 0) {
        game.reset();
    } else {
        const targetFen = moveHistory[currentPly - 1].fenAfter;
        game.load(targetFen);
    }
    selectedSquare = null;
    legalMoves = [];
    renderBoard();
    updateStatus();
    renderMovesTable();
    updateGraphCursor();
    if (autoAnalyze) {
        runEngineAnalysis();
    }
}

// --- Full Game Review ---
async function runFullGameReview() {
    if (moveHistory.length === 0 || isAnalyzing) return;
    isAnalyzing = true;
    btnRunReview.disabled = true;
    reviewProgressContainer.style.display = 'flex';
    reviewProgressBar.style.width = '10%';
    reviewProgressText.textContent = 'Evaluating moves with Stockfish 19...';

    try {
        const res = await fetch('/api/review', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ moves: moveHistory, depth: 10 })
        });
        const reviewData = await res.json();
        analyzedMoves = reviewData.analyzedMoves;

        reviewProgressBar.style.width = '100%';
        reviewProgressText.textContent = 'Review Complete!';

        // Update stats card
        whiteAccVal.textContent = `${reviewData.stats.whiteAccuracy}%`;
        blackAccVal.textContent = `${reviewData.stats.blackAccuracy}%`;
        whiteBlundersCount.textContent = `${reviewData.stats.whiteBlunders} blunders`;
        blackBlundersCount.textContent = `${reviewData.stats.blackBlunders} blunders`;
        reviewStatsCard.style.display = 'flex';

        renderMovesTable();
        updateGraph();
    } catch (err) {
        console.error("Game review error:", err);
        reviewProgressText.textContent = 'Error during review.';
    } finally {
        isAnalyzing = false;
        btnRunReview.disabled = false;
        setTimeout(() => {
            reviewProgressContainer.style.display = 'none';
        }, 2000);
    }
}

// --- Evaluation Graph ---
function updateGraph() {
    const moves = analyzedMoves.length > 0 ? analyzedMoves : moveHistory;
    graphDots.innerHTML = '';

    if (moves.length === 0) {
        graphPath.setAttribute('d', 'M0,50 L400,50');
        graphCursor.style.display = 'none';
        return;
    }

    const stepX = 400 / Math.max(1, moves.length - 1);
    let pathD = '';

    moves.forEach((m, idx) => {
        const cp = m.evalCp || 0;
        const clampedCp = Math.max(-800, Math.min(800, cp));
        // Normalized: +800 -> 5, -800 -> 95
        const y = 95 - (((clampedCp + 800) / 1600) * 90);
        const x = idx * stepX;

        if (idx === 0) pathD += `M${x},${y} `;
        else pathD += `L${x},${y} `;

        // Blunder/mistake dots
        if (m.classification === 'Blunder' || m.classification === 'Mistake') {
            const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
            circle.setAttribute('cx', x);
            circle.setAttribute('cy', y);
            circle.setAttribute('r', '4');
            circle.setAttribute('fill', m.classification === 'Blunder' ? '#cb3737' : '#e65722');
            graphDots.appendChild(circle);
        }
    });

    graphPath.setAttribute('d', pathD);
    updateGraphCursor();
}

function updateGraphCursor() {
    const moves = analyzedMoves.length > 0 ? analyzedMoves : moveHistory;
    if (moves.length === 0 || currentPly === 0) {
        graphCursor.style.display = 'none';
        return;
    }
    const idx = currentPly - 1;
    const stepX = 400 / Math.max(1, moves.length - 1);
    const m = moves[idx];
    const cp = m.evalCp || 0;
    const clampedCp = Math.max(-800, Math.min(800, cp));
    const y = 95 - (((clampedCp + 800) / 1600) * 90);
    const x = idx * stepX;

    graphCursor.setAttribute('cx', x);
    graphCursor.setAttribute('cy', y);
    graphCursor.style.display = 'block';
}

// --- PGN Export / Import ---
function exportCurrentPGN() {
    const dateStr = new Date().toISOString().split('T')[0].replace(/-/g, '.');
    let pgn = `[Event "Stockfish 19 Offline Analysis"]\n`;
    pgn += `[Site "Local Device"]\n`;
    pgn += `[Date "${dateStr}"]\n`;
    pgn += `[White "White"]\n`;
    pgn += `[Black "Black"]\n`;
    pgn += `[Result "${game.isGameOver() ? (game.isCheckmate() ? (game.turn() === 'w' ? '0-1' : '1-0') : '1/2-1/2') : '*'}"]\n\n`;

    let movesStr = '';
    for (let i = 0; i < moveHistory.length; i++) {
        const m = moveHistory[i];
        if (i % 2 === 0) {
            movesStr += `${Math.floor(i / 2) + 1}. ${m.san} `;
        } else {
            movesStr += `${m.san} `;
        }
    }
    pgn += movesStr.trim() + ' *\n';
    return pgn;
}

function loadPGNText(pgnText) {
    try {
        const newGame = new Chess();
        newGame.loadPgn(pgnText);

        // Replay moves to build moveHistory
        game.reset();
        moveHistory = [];
        analyzedMoves = [];
        reviewStatsCard.style.display = 'none';

        const history = newGame.history({ verbose: true });
        for (const m of history) {
            const fenBefore = game.fen();
            const moveRes = game.move(m);
            const fenAfter = game.fen();
            moveHistory.push({
                ply: moveHistory.length + 1,
                moveNumber: Math.floor(moveHistory.length / 2) + 1,
                san: moveRes.san,
                uci: `${moveRes.from}${moveRes.to}${moveRes.promotion || ''}`,
                fenBefore,
                fenAfter
            });
        }
        currentPly = moveHistory.length;
        renderBoard();
        updateStatus();
        renderMovesTable();
        updateGraph();
        if (autoAnalyze) runEngineAnalysis();
    } catch (e) {
        alert("Invalid PGN format: " + e.message);
    }
}

// --- Event Listeners ---
function setupEventListeners() {
    document.getElementById('btnFlipBoard').addEventListener('click', () => {
        isFlipped = !isFlipped;
        renderBoard();
        updateStatus();
        if (showArrow && metricBestMove.textContent.length >= 4) {
            const bm = metricBestMove.textContent;
            drawBestMoveArrow(bm.substring(0, 2), bm.substring(2, 4));
        }
    });

    document.getElementById('btnUndo').addEventListener('click', () => {
        if (moveHistory.length === 0) return;
        moveHistory.pop();
        if (analyzedMoves.length > 0) analyzedMoves.pop();
        jumpToPly(moveHistory.length);
    });

    document.getElementById('btnReset').addEventListener('click', () => {
        if (confirm("Start a new chess game?")) {
            game.reset();
            moveHistory = [];
            analyzedMoves = [];
            currentPly = 0;
            reviewStatsCard.style.display = 'none';
            renderBoard();
            updateStatus();
            renderMovesTable();
            updateGraph();
            runEngineAnalysis();
        }
    });

    document.getElementById('btnStart').addEventListener('click', () => jumpToPly(0));
    document.getElementById('btnPrev').addEventListener('click', () => jumpToPly(currentPly - 1));
    document.getElementById('btnNext').addEventListener('click', () => jumpToPly(currentPly + 1));
    document.getElementById('btnEnd').addEventListener('click', () => jumpToPly(moveHistory.length));

    chkAutoAnalyze.addEventListener('change', (e) => {
        autoAnalyze = e.target.checked;
        if (autoAnalyze) runEngineAnalysis();
        else bestMoveArrow.style.display = 'none';
    });

    depthSlider.addEventListener('input', (e) => {
        targetDepth = parseInt(e.target.value, 10);
        depthVal.textContent = targetDepth;
    });

    depthSlider.addEventListener('change', () => {
        if (autoAnalyze) runEngineAnalysis();
    });

    btnRunReview.addEventListener('click', runFullGameReview);
    document.getElementById('btnGameOverReview').addEventListener('click', () => {
        gameOverModal.style.display = 'none';
        runFullGameReview();
    });
    document.getElementById('btnGameOverNew').addEventListener('click', () => {
        gameOverModal.style.display = 'none';
        document.getElementById('btnReset').click();
    });

    // Graph scrubbing
    graphContainer.addEventListener('click', (e) => {
        const moves = analyzedMoves.length > 0 ? analyzedMoves : moveHistory;
        if (moves.length === 0) return;
        const rect = graphContainer.getBoundingClientRect();
        const clickX = e.clientX - rect.left;
        const fraction = Math.max(0, Math.min(1, clickX / rect.width));
        const targetIdx = Math.round(fraction * (moves.length - 1));
        jumpToPly(moves[targetIdx].ply);
    });

    // PGN Modal
    document.getElementById('btnPGN').addEventListener('click', () => {
        document.getElementById('txtPGNOutput').value = exportCurrentPGN();
        pgnModal.style.display = 'flex';
    });
    document.getElementById('btnClosePGN').addEventListener('click', () => {
        pgnModal.style.display = 'none';
    });

    document.querySelectorAll('.modal-tabs .tab-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.modal-tabs .tab-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
            btn.classList.add('active');
            document.getElementById(btn.dataset.tab).classList.add('active');
        });
    });

    document.getElementById('btnApplyPGN').addEventListener('click', () => {
        const text = document.getElementById('txtPGNInput').value.trim();
        if (text) {
            loadPGNText(text);
            pgnModal.style.display = 'none';
        }
    });

    document.getElementById('btnCopyPGN').addEventListener('click', () => {
        const text = document.getElementById('txtPGNOutput');
        text.select();
        navigator.clipboard.writeText(text.value);
        alert("PGN copied to clipboard!");
    });

    document.getElementById('btnApplyFEN').addEventListener('click', () => {
        const fen = document.getElementById('txtFENInput').value.trim();
        if (fen) {
            try {
                game.load(fen);
                moveHistory = [];
                analyzedMoves = [];
                currentPly = 0;
                renderBoard();
                updateStatus();
                renderMovesTable();
                updateGraph();
                runEngineAnalysis();
                pgnModal.style.display = 'none';
            } catch (err) {
                alert("Invalid FEN: " + err.message);
            }
        }
    });

    document.querySelectorAll('.fen-presets .btn-preset').forEach(btn => {
        btn.addEventListener('click', () => {
            document.getElementById('txtFENInput').value = btn.dataset.fen;
        });
    });

    // Classic Games
    const CLASSIC_PGNS = {
        morphy: `[Event "Paris Opera"]
[White "Paul Morphy"]
[Black "Duke Karl / Count Isouard"]
[Result "1-0"]

1. e4 e5 2. Nf3 d6 3. d4 Bg4 4. dxe5 Bxf3 5. Qxf3 dxe5 6. Bc4 Nf6 7. Qb3 Qe7 8. Nc3 c6 9. Bg5 b5 10. Nxb5 cxb5 11. Bxb5+ Nbd7 12. O-O-O Rd8 13. Rxd7 Rxd7 14. Rd1 Qe6 15. Bxd7+ Nxd7 16. Qb8+ Nxb8 17. Rd8# 1-0`,

        kasparov: `[Event "Hoogovens Group A"]
[White "Garry Kasparov"]
[Black "Veselin Topalov"]
[Result "1-0"]

1. e4 d6 2. d4 Nf6 3. Nc3 g6 4. Be3 Bg7 5. Qd2 c6 6. f3 b5 7. Nge2 Nbd7 8. Bh6 Bxh6 9. Qxh6 Bb7 10. a3 e5 11. O-O-O Qe7 12. Kb1 a6 13. Nc1 O-O-O 14. Nb3 exd4 15. Rxd4 c5 16. Rd1 Nb6 17. g3 Kb8 18. Na5 Ba8 19. Bh3 d5 20. Qf4+ Ka7 21. Rhe1 d4 22. Nd5 Nbxd5 23. exd5 Qd6 24. Rxd4 cxd4 25. Re7+ Kb6 26. Qxd4+ Kxa5 27. b4+ Ka4 28. Qc3 Qxd5 29. Ra7 Bb7 30. Rxb7 Qc4 31. Qxf6 Kxa3 32. Qxa6+ Kxb4 33. c3+ Kxc3 34. Qa1+ Kd2 35. Qb2+ Kd1 36. Bf1 Rd2 37. Rd7 Rxd7 38. Bxc4 bxc4 39. Qxh8 Rd3 40. Qa8 c3 41. Qa4+ Ke1 42. f4 f5 43. Kc1 Rd2 44. Qa7 1-0`,

        fischer: `[Event "Third Rosenwald Trophy"]
[White "Donald Byrne"]
[Black "Bobby Fischer"]
[Result "0-1"]

1. Nf3 Nf6 2. c4 g6 3. Nc3 Bg7 4. d4 O-O 5. Bf4 d5 6. Qb3 dxc4 7. Qxc4 c6 8. e4 Nbd7 9. Rd1 Nb6 10. Qc5 Bg4 11. Bg5 Na4 12. Qa3 Nxc3 13. bxc3 Nxe4 14. Bxe7 Qb6 15. Bc4 Nxc3 16. Bc5 Rfe8+ 17. Kf1 Be6 18. Bxb6 Bxc4+ 19. Kg1 Ne2+ 20. Kf1 Nxd4+ 21. Kg1 Ne2+ 22. Kf1 Nc3+ 23. Kg1 axb6 24. Qb4 Ra4 25. Qxb6 Nxd1 0-1`
    };

    document.querySelectorAll('.classic-item').forEach(item => {
        item.addEventListener('click', () => {
            const id = item.dataset.id;
            if (CLASSIC_PGNS[id]) {
                loadPGNText(CLASSIC_PGNS[id]);
                pgnModal.style.display = 'none';
            }
        });
    });

    // Settings Modal
    document.getElementById('btnSettings').addEventListener('click', () => {
        settingsModal.style.display = 'flex';
    });
    document.getElementById('btnCloseSettings').addEventListener('click', () => {
        settingsModal.style.display = 'none';
    });

    document.getElementById('selectTheme').addEventListener('change', (e) => {
        chessboardWrapper.className = `chessboard-wrapper ${e.target.value}`;
    });

    document.getElementById('chkSound').addEventListener('change', (e) => {
        soundEnabled = e.target.checked;
    });

    document.getElementById('chkShowArrow').addEventListener('change', (e) => {
        showArrow = e.target.checked;
        if (!showArrow) bestMoveArrow.style.display = 'none';
        else if (metricBestMove.textContent.length >= 4) {
            const bm = metricBestMove.textContent;
            drawBestMoveArrow(bm.substring(0, 2), bm.substring(2, 4));
        }
    });

    document.getElementById('chkShowHints').addEventListener('change', (e) => {
        showHints = e.target.checked;
        renderBoard();
    });
}

// Start app
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init, { once: true });
} else {
    init();
}
