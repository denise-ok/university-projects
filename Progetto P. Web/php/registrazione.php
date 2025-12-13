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

/* ========== Gestione registrazione ========== */

if (isset($_POST['register'])) {
    $newUser = $_POST['username'] ?? '';
    $newPass = $_POST['password'] ?? '';
    $confirmPass = $_POST['password2'] ?? '';

    validateRegistration($newUser, $newPass, $confirmPass);

    if (usernameExists($conn, $newUser)) {
        redirectWithError(1);
    }

    registerUser($conn, $newUser, $newPass);
}

mysqli_close($conn);

/* ========== Funzioni di validazione ========== */

function validateRegistration($username, $password, $confirmPassword) {
    if ($password !== $confirmPassword) {
        redirectWithError(2);
    }

    $pattern = "/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/";
    if (!preg_match($pattern, $password)) {
        redirectWithError(0);
    }
}

function usernameExists($conn, $username) {
    $query = "SELECT * FROM utente WHERE username = ?";
    $stmt = mysqli_prepare($conn, $query);

    if (!$stmt) return false;

    mysqli_stmt_bind_param($stmt, 's', $username);
    mysqli_stmt_execute($stmt);
    mysqli_stmt_store_result($stmt);

    $exists = mysqli_stmt_num_rows($stmt) > 0;

    mysqli_stmt_close($stmt);
    return $exists;
}

/* ========== Funzioni di registrazione ========== */

function registerUser($conn, $username, $password) {
    $hashPass = password_hash($password, PASSWORD_BCRYPT);

    mysqli_begin_transaction($conn);

    try {
        insertUser($conn, $username, $hashPass);
        insertPartitaRecord($conn, $username);
        mysqli_commit($conn);

        redirectToGame($username);

    } catch (Exception $e) {
        mysqli_rollback($conn);
        redirectWithRegistrationError();
    }
}

function insertUser($conn, $username, $hashedPassword) {
    $query = "INSERT INTO utente (username, password) VALUES (?, ?)";
    $stmt = mysqli_prepare($conn, $query);

    if (!$stmt) {
        throw new Exception("Errore inserimento utente");
    }

    mysqli_stmt_bind_param($stmt, 'ss', $username, $hashedPassword);

    if (!mysqli_stmt_execute($stmt)) {
        mysqli_stmt_close($stmt);
        throw new Exception("Errore inserimento utente");
    }

    mysqli_stmt_close($stmt);
}

function insertPartitaRecord($conn, $username) {
    $query = "INSERT INTO partita (name, bestScore) VALUES (?, 0)";
    $stmt = mysqli_prepare($conn, $query);

    if (!$stmt) {
        throw new Exception("Errore inserimento partita");
    }

    mysqli_stmt_bind_param($stmt, 's', $username);

    if (!mysqli_stmt_execute($stmt)) {
        mysqli_stmt_close($stmt);
        throw new Exception("Errore inserimento partita");
    }

    mysqli_stmt_close($stmt);
}

/* ========== Funzioni di redirect ========== */

function redirectWithError($errorCode) {
    echo "<script>
            sessionStorage.setItem('register_error', '$errorCode');
            window.location.href = '../html/registrazione.html';
          </script>";
    exit();
}

function redirectToGame($username) {
    echo "<script>
            sessionStorage.setItem('player_username', '$username');
            sessionStorage.setItem('player_bestscore', '0');
            window.location.href = '../html/game.html';
          </script>";
    exit();
}

function redirectWithRegistrationError() {
    echo "<script>
            alert('Errore durante la registrazione. Riprova.');
            window.location.href = '../html/registrazione.html';
          </script>";
    exit();
}
?>