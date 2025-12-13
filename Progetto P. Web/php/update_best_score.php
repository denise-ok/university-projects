<?php

/* ========== Configurazione database ========== */

define('DB_HOST', 'localhost');
define('DB_NAME', 'rosselli_596763');
define('DB_USER', 'root');
define('DB_PASS', '');

/* ========== Connessione al database ========== */

$conn = mysqli_connect(DB_HOST, DB_USER, DB_PASS, DB_NAME);

if (!$conn) {
    die("Connessione fallita: " . mysqli_connect_error());
}

/* ========== Gestione richiesta POST ========== */

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $input = json_decode(file_get_contents("php://input"));

    $playerName = $input->name ?? '';
    $newBestScore = $input->bestScore ?? 0;

    if (!isValidInput($playerName, $newBestScore)) {
        echo "Dati non validi";
    } else {
        handleScoreUpdate($conn, $playerName, $newBestScore);
    }
}

mysqli_close($conn);

/* ========== Funzioni ========== */

function isValidInput($playerName, $score) {
    return !empty($playerName) && $score > 0;
}

function handleScoreUpdate($conn, $playerName, $newBestScore) {
    $currentBestScore = getCurrentBestScore($conn, $playerName);

    if ($currentBestScore === null) {
        echo "Giocatore non trovato";
        return;
    }

    if ($newBestScore > $currentBestScore) {
        updateBestScore($conn, $playerName, $newBestScore);
        echo "Record aggiornato con successo";
    } else {
        echo "Nessun aggiornamento necessario";
    }
}

function getCurrentBestScore($conn, $playerName) {
    $query = "SELECT bestScore FROM partita WHERE name = ?";
    $stmt = mysqli_prepare($conn, $query);

    if (!$stmt) return null;

    mysqli_stmt_bind_param($stmt, 's', $playerName);
    mysqli_stmt_execute($stmt);
    $result = mysqli_stmt_get_result($stmt);

    if (mysqli_num_rows($result) === 0) {
        mysqli_stmt_close($stmt);
        return null;
    }

    $row = mysqli_fetch_assoc($result);
    mysqli_stmt_close($stmt);

    return $row['bestScore'];
}

function updateBestScore($conn, $playerName, $newBestScore) {
    $query = "UPDATE partita SET bestScore = ? WHERE name = ?";
    $stmt = mysqli_prepare($conn, $query);

    if (!$stmt) return;

    mysqli_stmt_bind_param($stmt, 'is', $newBestScore, $playerName);
    mysqli_stmt_execute($stmt);
    mysqli_stmt_close($stmt);
}

?>