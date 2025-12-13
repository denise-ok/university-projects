/* ========== Costanti ========== */

const ERROR_MESSAGES = [
    "Riprova: Password non corretta.",
    "Riprova: Utente inesistente."
];

/* ========== Inizializzazione ========== */

function init() {
    const errorCode = getStoredErrorCode();
    showError(errorCode);
}

function getStoredErrorCode() {
    const storedError = sessionStorage.getItem("login_error");

    if (storedError !== null) {
        sessionStorage.removeItem("login_error");
        return parseInt(storedError);
    }

    return -1;
}

/* ========== Gestione errori ========== */

function showError(errorCode) {
    const errorContainer = document.getElementById("log_error");

    if (!errorContainer) return;

    errorContainer.textContent = "";

    if (errorCode < 0 || errorCode >= ERROR_MESSAGES.length) return;

    const errorElement = createErrorElement(ERROR_MESSAGES[errorCode]);
    errorContainer.appendChild(errorElement);
}

function createErrorElement(message) {
    const p = document.createElement("p");
    p.innerText = message;
    p.style.color = "rgb(234, 37, 37)";
    p.style.fontWeight = "bold";
    p.style.marginTop = "10px";
    return p;
}