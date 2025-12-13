<?php
session_start();

/* ========== Configurazione database ========== */

define('DB_HOST', 'localhost');
define('DB_NAME', 'rosselli_596763');
define('DB_USER', 'root');
define('DB_PASS', '');

/* ========== Connessione al database ========== */

$conn = mysqli_connect(DB_HOST, DB_USER, DB_PASS, DB_NAME);

if (mysqli_connect_errno()) {
    die("Errore connessione: " . mysqli_connect_error());
}

/* ========== Gestione login ========== */

if (isset($_POST['login'])) {
    $inputUser = $_POST['username'] ?? '';
    $inputPass = $_POST['password'] ?? '';

    $user = getUserByUsername($conn, $inputUser);

    if ($user === null) {
        redirectWithError('../html/index.html', 1);
    }

    if (!password_verify($inputPass, $user['password'])) {
        redirectWithError('../html/index.html', 0);
    }

    handleSuccessfulLogin($conn, $inputUser);
}

mysqli_close($conn);

/* ========== Funzioni ========== */

function getUserByUsername($conn, $username) {
    $query = "SELECT * FROM utente WHERE username = ?";
    $stmt = mysqli_prepare($conn, $query);

    if (!$stmt) return null;

    mysqli_stmt_bind_param($stmt, 's', $username);
    mysqli_stmt_execute($stmt);
    $result = mysqli_stmt_get_result($stmt);

    $user = mysqli_num_rows($result) > 0 ? mysqli_fetch_assoc($result) : null;

    mysqli_stmt_close($stmt);
    return $user;
}

function getBestScore($conn, $username) {
    $query = "SELECT bestScore FROM partita WHERE name = ?";
    $stmt = mysqli_prepare($conn, $query);

    if (!$stmt) return 0;

    mysqli_stmt_bind_param($stmt, 's', $username);
    mysqli_stmt_execute($stmt);
    $result = mysqli_stmt_get_result($stmt);

    $bestScore = 0;

    if (mysqli_num_rows($result) > 0) {
        $row = mysqli_fetch_assoc($result);
        $bestScore = $row['bestScore'];
    } else {
        createPartitaRecord($conn, $username);
    }

    mysqli_stmt_close($stmt);
    return $bestScore;
}

function createPartitaRecord($conn, $username) {
    $query = "INSERT INTO partita (name, bestScore) VALUES (?, 0)";
    $stmt = mysqli_prepare($conn, $query);

    if ($stmt) {
        mysqli_stmt_bind_param($stmt, 's', $username);
        mysqli_stmt_execute($stmt);
        mysqli_stmt_close($stmt);
    }
}

function handleSuccessfulLogin($conn, $username) {
    $bestScore = getBestScore($conn, $username);

    echo "<script>
            sessionStorage.setItem('player_username', '$username');
            sessionStorage.setItem('player_bestscore', '$bestScore');
            window.location.href = '../html/game.html';
          </script>";
    exit();
}

function redirectWithError($url, $errorCode) {
    echo "<script>
            sessionStorage.setItem('login_error', '$errorCode');
            window.location.href = '$url';
          </script>";
    exit();
}
?>