/* ========== Costanti ========== */

const ERROR_MESSAGES = {
    PASSWORD_FORMAT: "La password deve contenere almeno 8 caratteri, di cui una maiuscola, una minuscola, un numero intero e un carattere speciale.",
    USERNAME_EXISTS: "Riprova: username già utilizzato.",
    PASSWORDS_MISMATCH: "Le password non corrispondono."
};

const PASSWORD_REGEX = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;

/* ========== Stato ========== */

const validationState = {
    formatOk: false,
    passwordsMatch: false
};

/* ========== Inizializzazione ========== */

function init() {
    const btnReg = document.getElementById("button_login");
    btnReg.disabled = true;

    document.getElementById("password").addEventListener("keyup", validatePasswordFormat);
    document.getElementById("password2").addEventListener("keyup", validatePasswordsMatch);

    displayStoredError();
}

function displayStoredError() {
    const storedError = sessionStorage.getItem("register_error");
    if (storedError !== null) {
        showError(parseInt(storedError));
        sessionStorage.removeItem("register_error");
    }
}

/* ========== Gestione errori ========== */

function showError(errorCode) {
    const errorBox = document.getElementById("reg_error");
    errorBox.textContent = "";
    errorBox.style.display = "none";

    if (errorCode === -1) return;

    const errorMessages = [
        ERROR_MESSAGES.PASSWORD_FORMAT,
        ERROR_MESSAGES.USERNAME_EXISTS,
        ERROR_MESSAGES.PASSWORDS_MISMATCH
    ];

    if (errorCode >= 0 && errorCode < errorMessages.length) {
        const errorElement = createErrorElement(errorMessages[errorCode]);
        configureErrorBox(errorBox);
        errorBox.appendChild(errorElement);
        errorBox.style.display = "block";
    }
}

function createErrorElement(message) {
    const p = document.createElement("p");
    p.textContent = message;
    p.style.color = "rgb(234, 37, 37)";
    p.style.fontWeight = "bold";
    p.style.marginTop = "1px";
    p.style.zIndex = "4";
    return p;
}

function configureErrorBox(errorBox) {
    errorBox.style.flexGrow = "1";
    errorBox.style.minHeight = "0";
}

/* ========== Validazione ========== */

function validatePasswordFormat() {
    const password = document.getElementById("password").value;

    validationState.formatOk = PASSWORD_REGEX.test(password);

    if (validationState.formatOk) {
        clearErrorIfMatches(ERROR_MESSAGES.PASSWORD_FORMAT);
    } else {
        showError(0);
    }

    updateButtonState();
}

function validatePasswordsMatch() {
    const pwd1 = document.getElementById("password").value;
    const pwd2 = document.getElementById("password2").value;

    const bothFilled = pwd1 !== "" && pwd2 !== "";
    validationState.passwordsMatch = bothFilled && pwd1 === pwd2;

    if (validationState.passwordsMatch) {
        clearErrorIfMatches(ERROR_MESSAGES.PASSWORDS_MISMATCH);
    } else if (pwd2 !== "") {
        showError(2);
    }

    updateButtonState();
}

function clearErrorIfMatches(errorMessage) {
    const errorBox = document.getElementById("reg_error");
    if (errorBox.textContent === errorMessage) {
        showError(-1);
    }
}

function updateButtonState() {
    const btnReg = document.getElementById("button_login");
    btnReg.disabled = !(validationState.formatOk && validationState.passwordsMatch);
}