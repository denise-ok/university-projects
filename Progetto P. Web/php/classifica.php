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

/* ========== Recupero classifica ========== */

$leaderboard = getLeaderboard($conn);

if ($leaderboard !== null) {
    header('Content-Type: application/json');
    echo json_encode($leaderboard);
}

mysqli_close($conn);

/* ========== Funzioni ========== */

function getLeaderboard($conn) {
    $query = "SELECT name, bestScore 
              FROM partita
              ORDER BY bestScore DESC
              LIMIT 10";

    $result = mysqli_query($conn, $query);

    if (!$result || mysqli_num_rows($result) === 0) {
        return null;
    }

    return buildLeaderboardArray($result);
}

function buildLeaderboardArray($result) {
    $leaderboard = [];

    while ($record = mysqli_fetch_assoc($result)) {
        $leaderboard[] = [
            'name'  => $record['name'],
            'score' => $record['bestScore']
        ];
    }

    return $leaderboard;
}

?>