class Game2048 {
    constructor() {
        this.grid = [];
        this.score = 0;
        this.bestScore = parseInt(sessionStorage.getItem('player_bestscore')) || 0;
        this.gameWon = false;
        this.gameOver = false;

        this.init();
        this.setupControls();
    }

    /* ========== Inizializzazione ========== */

    init() {
        this.initGrid();
        this.addRandomTile();
        this.addRandomTile();
        this.updateDisplay();
        this.updateScore();
    }

    initGrid() {
        for (let i = 0; i < 4; i++) {
            this.grid[i] = [0, 0, 0, 0];
        }
    }

    /* ========== Gestione tessere ========== */

    addRandomTile() {
        const emptyCells = this.getEmptyCells();

        if (emptyCells.length > 0) {
            const randomCell = emptyCells[Math.floor(Math.random() * emptyCells.length)];
            this.grid[randomCell.row][randomCell.col] = Math.random() < 0.6 ? 2 : 4;
        }
    }

    getEmptyCells() {
        const empty = [];
        for (let i = 0; i < 4; i++) {
            for (let j = 0; j < 4; j++) {
                if (this.grid[i][j] === 0) {
                    empty.push({ row: i, col: j });
                }
            }
        }
        return empty;
    }

    /* ========== Controlli di gioco ========== */

    setupControls() {
        document.addEventListener('keydown', (e) => {
            if (this.gameOver) return;

            const moves = {
                'ArrowUp': () => this.moveUp(),
                'ArrowDown': () => this.moveDown(),
                'ArrowLeft': () => this.moveLeft(),
                'ArrowRight': () => this.moveRight()
            };

            if (moves[e.key]) {
                e.preventDefault();
                const moved = moves[e.key]();

                if (moved) {
                    this.addRandomTile();
                    this.updateDisplay();
                    this.updateScore();
                    this.checkGameStatus();
                }
            }
        });
    }

    /* ========== Movimenti ========== */

    moveLeft() {
        return this.moveHorizontal(false);
    }

    moveRight() {
        return this.moveHorizontal(true);
    }

    moveUp() {
        return this.moveVertical(false);
    }

    moveDown() {
        return this.moveVertical(true);
    }

    moveHorizontal(reverse) {
        let moved = false;

        for (let i = 0; i < 4; i++) {
            const row = this.grid[i].filter(val => val !== 0);
            const mergedRow = this.mergeTiles(row, reverse);
            const newRow = this.padRow(mergedRow, reverse);

            for (let j = 0; j < 4; j++) {
                if (this.grid[i][j] !== newRow[j]) {
                    moved = true;
                }
                this.grid[i][j] = newRow[j];
            }
        }

        return moved;
    }

    moveVertical(reverse) {
        let moved = false;

        for (let j = 0; j < 4; j++) {
            const column = this.extractColumn(j);
            const mergedColumn = this.mergeTiles(column, reverse);
            const newColumn = this.padRow(mergedColumn, reverse);

            for (let i = 0; i < 4; i++) {
                if (this.grid[i][j] !== newColumn[i]) {
                    moved = true;
                }
                this.grid[i][j] = newColumn[i];
            }
        }

        return moved;
    }

    extractColumn(colIndex) {
        const column = [];
        for (let i = 0; i < 4; i++) {
            if (this.grid[i][colIndex] !== 0) {
                column.push(this.grid[i][colIndex]);
            }
        }
        return column;
    }

    mergeTiles(tiles, reverse) {
        const indices = reverse
            ? Array.from({ length: tiles.length - 1 }, (_, i) => tiles.length - 1 - i)
            : Array.from({ length: tiles.length - 1 }, (_, i) => i);

        for (const i of indices) {
            const nextIndex = reverse ? i - 1 : i + 1;

            if (tiles[i] === tiles[nextIndex]) {
                tiles[i] *= 2;
                this.score += tiles[i];
                tiles[nextIndex] = 0;

                if (tiles[i] === 2048 && !this.gameWon) {
                    this.gameWon = true;
                    this.showGameWon();
                }
            }
        }

        return tiles.filter(val => val !== 0);
    }

    padRow(row, reverse) {
        while (row.length < 4) {
            reverse ? row.unshift(0) : row.push(0);
        }
        return row;
    }

    /* ========== Aggiornamento interfaccia ========== */

    updateDisplay() {
        const container = document.getElementById('tessera');
        container.innerHTML = '';

        for (let i = 0; i < 4; i++) {
            for (let j = 0; j < 4; j++) {
                if (this.grid[i][j] !== 0) {
                    const tile = this.createTile(this.grid[i][j], i, j);
                    container.appendChild(tile);
                }
            }
        }
    }

    createTile(value, row, col) {
        const tile = document.createElement('div');
        tile.className = `tile tile-${value}`;
        tile.textContent = value;
        tile.style.transform = `translate(${col * 80}px, ${row * 80}px)`;
        return tile;
    }

    updateScore() {
        document.getElementById('score').textContent = this.score;

        if (this.score > this.bestScore) {
            this.bestScore = this.score;
            sessionStorage.setItem('player_bestscore', this.bestScore);
        }

        document.getElementById('best-score').textContent = this.bestScore;
    }

    /* ========== Gestione stato gioco ========== */

    checkGameStatus() {
        if (this.hasAvailableMoves()) return;

        this.gameOver = true;
        this.showGameOver();
        this.saveScoreIfBetter();
    }

    hasAvailableMoves() {
        for (let i = 0; i < 4; i++) {
            for (let j = 0; j < 4; j++) {
                if (this.grid[i][j] === 0) return true;
                if (j < 3 && this.grid[i][j] === this.grid[i][j + 1]) return true;
                if (i < 3 && this.grid[i][j] === this.grid[i + 1][j]) return true;
            }
        }
        return false;
    }

    showGameOver() {
        document.getElementById('game-over').style.display = 'flex';
        this.loadLeaderboard('game-over');
    }

    showGameWon() {
        document.getElementById('game-won').style.display = 'flex';
        this.loadLeaderboard('game-won');
    }

    /* ========== Gestione classifica ========== */

    loadLeaderboard(containerId) {
        fetch('../php/classifica.php')
            .then(res => res.json())
            .then(data => this.displayLeaderboard(data, containerId))
            .catch(error => console.error('Errore nel caricamento della classifica:', error));
    }

    displayLeaderboard(leaderboard, containerId) {
        const container = document.getElementById(containerId);
        const existingTable = container.querySelector('.leaderboard');

        if (existingTable) {
            existingTable.remove();
        }

        const leaderboardDiv = this.createLeaderboardTable(leaderboard);
        const button = container.querySelector('.btn');
        container.insertBefore(leaderboardDiv, button);
    }

    createLeaderboardTable(leaderboard) {
        const leaderboardDiv = document.createElement('div');
        leaderboardDiv.className = 'leaderboard';

        const table = document.createElement('table');
        table.className = 'classifica-table';

        table.appendChild(this.createTableHeader());
        table.appendChild(this.createTableBody(leaderboard));

        leaderboardDiv.appendChild(table);
        return leaderboardDiv;
    }

    createTableHeader() {
        const thead = document.createElement('thead');
        const headerRow = document.createElement('tr');

        ['Username', 'Score'].forEach(text => {
            const th = document.createElement('th');
            th.textContent = text;
            headerRow.appendChild(th);
        });

        thead.appendChild(headerRow);
        return thead;
    }

    createTableBody(leaderboard) {
        const tbody = document.createElement('tbody');

        leaderboard.forEach(player => {
            const row = document.createElement('tr');

            [player.name, player.score].forEach(text => {
                const td = document.createElement('td');
                td.textContent = text;
                row.appendChild(td);
            });

            tbody.appendChild(row);
        });

        return tbody;
    }

    /* ========== Salvataggio punteggio ========== */

    saveScoreIfBetter() {
        const playerName = sessionStorage.getItem('player_username');

        if (playerName && this.score === this.bestScore) {
            this.updateBestScoreInDatabase(playerName, this.score);
        }
    }

    updateBestScoreInDatabase(playerName, newBestScore) {
        fetch('../php/update_best_score.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                name: playerName,
                bestScore: newBestScore
            })
        })
        .then(response => response.text())
        .then(data => {
            console.log('Risposta server:', data);

            if (data.includes('aggiornato con successo') || data.includes('Record creato')) {
                sessionStorage.setItem('player_bestscore', newBestScore);
                this.bestScore = newBestScore;
                this.updateScore();
            }
        })
        .catch(error => {
            console.error('Errore aggiornamento best score:', error);
            alert('Errore durante il salvataggio del punteggio');
        });
    }

    /* ========== Riavvio gioco ========== */

    restart() {
        this.grid = [];
        this.score = 0;
        this.gameWon = false;
        this.gameOver = false;

        document.getElementById('game-over').style.display = 'none';
        document.getElementById('game-won').style.display = 'none';

        this.init();
    }
}

/* ========== Funzioni globali ========== */

let game;

window.onload = function() {
    game = new Game2048();
};

function restartGame() {
    game.restart();
}

function saveScore() {
    const playerName = sessionStorage.getItem('player_username');
    if (playerName && game.score > 0) {
        game.updateBestScoreInDatabase(playerName, game.score);
    }
}

function logout() {
    sessionStorage.removeItem('player_username');
    sessionStorage.removeItem('player_bestscore');
    window.location.href = './index.html';
}