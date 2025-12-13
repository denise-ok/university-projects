/* ========================================
   OPERAZIONI PRINCIPALI DEL DATABASE
   ======================================== */

/* ========== [1] Inserimento nuovo utente ========== 
   Crea un nuovo utente nel sistema con relativo documento e account
   
   Validazioni:
   - Documento deve essere in corso di validità
   - Password minimo 8 caratteri
   - Username minimo 3 caratteri
*/
DROP PROCEDURE IF EXISTS NuovoUtente;

DELIMITER $$
CREATE PROCEDURE NuovoUtente(
    IN p_CodFiscale VARCHAR(16),
    IN p_Nome VARCHAR(50),
    IN p_Cognome VARCHAR(50),
    IN p_DataNascita DATE,
    IN p_Telefono VARCHAR(10),
    IN p_Tipologia VARCHAR(15), 
    IN p_Numero VARCHAR(50),
    IN p_DataScadenza DATE, 
    IN p_EnteRilascio VARCHAR(50),
    IN p_NomeUtente VARCHAR(50), 
    IN p_Password VARCHAR(50),
    IN p_Risposta VARCHAR(50)
)
BEGIN 
    DECLARE documento_valido BOOLEAN;
    DECLARE credenziali_valide BOOLEAN;
    
    -- Verifica validità documento
    SET documento_valido = DATEDIFF(CURRENT_DATE, p_DataScadenza) < 0;
    
    -- Verifica lunghezza credenziali
    SET credenziali_valide = LENGTH(p_Password) > 8 AND LENGTH(p_NomeUtente) > 3;
    
    IF documento_valido AND credenziali_valide THEN
        -- Inserimento in ordine gerarchico per vincoli FK
        INSERT INTO Utente 
        VALUES (p_CodFiscale, p_Nome, p_Cognome, p_Telefono, p_DataNascita);
        
        INSERT INTO Documento 
        VALUES (p_Numero, p_Tipologia, p_EnteRilascio, p_DataScadenza, p_CodFiscale);
        
        INSERT INTO Account 
        VALUES (p_NomeUtente, p_Password, CURRENT_DATE, p_Risposta, p_CodFiscale, 1);
    ELSE 
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Errore: documento scaduto o credenziali non valide (password > 8 caratteri, username > 3 caratteri)';
    END IF;
END$$
DELIMITER ;

/* ========== [2] Inserimento nuovo contratto energia ========== 
   Aggiorna o inserisce una nuova fascia oraria nel contratto energetico
   
   Validazioni:
   - Nome non vuoto
   - Prezzi positivi
*/
DROP PROCEDURE IF EXISTS NuovoContratto;

DELIMITER $$
CREATE PROCEDURE NuovoContratto(
    IN p_Nome VARCHAR(30), 
    IN p_Inizio TIME, 
    IN p_Fine TIME, 
    IN p_PrezzoRin FLOAT, 
    IN p_CostoNonRin FLOAT,
    IN p_SceltaUtilizzo VARCHAR(30)
)
BEGIN
    IF LENGTH(p_Nome) > 0 AND p_PrezzoRin > 0 AND p_CostoNonRin > 0 THEN
        INSERT INTO FasciaOraria 
        VALUES (DEFAULT, p_Nome, p_Inizio, p_Fine, p_PrezzoRin, p_CostoNonRin, p_SceltaUtilizzo);
    ELSE 
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Errore: nome vuoto o prezzi non validi';
    END IF;
END$$
DELIMITER ;

/* ========== [3] Energia consumata/prodotta in un giorno ========== 
   Calcola il bilancio energetico giornaliero:
   - Valore positivo: energia autoprodotta > consumo
   - Valore negativo: necessario prelievo dalla rete
   
   @param to_check: Data da analizzare
   @param energia: OUTPUT - Bilancio energetico in kWh
*/
DROP PROCEDURE IF EXISTS energia_consumata$$

DELIMITER $$
CREATE PROCEDURE energia_consumata(
    IN to_check DATE, 
    OUT energia DOUBLE
)
BEGIN
    SET energia = (
        SELECT (SUM(E.Quantita) - SUM(I.EnergiaConsumata)) AS bilancio_energetico
        FROM EnergiaProdotta E
            INNER JOIN FasciaOraria F ON E.IdFascia = F.IdFascia
            INNER JOIN Interazione I ON I.IdFascia = F.IdFascia
        WHERE DAY(E.Timestamp) = DAY(to_check) 
          AND DAY(I.Inizio) = DAY(to_check)
    );
END$$
DELIMITER ;

/* Event scheduler per calcolo giornaliero automatico */
DROP EVENT IF EXISTS consumi_giorno$$

CREATE EVENT consumi_giorno
ON SCHEDULE EVERY 1 DAY
STARTS '2022-03-29 00:00:00'
DO
    CALL energia_consumata(CURRENT_DATE, @consumigg)$$

/* ========== [4] Consumo giornaliero condizionatori ========== 
   Calcola il consumo totale dei sistemi di climatizzazione per la giornata corrente
   
   @param consumo_giornaliero_: OUTPUT - Consumo totale in kWh
*/
DROP PROCEDURE IF EXISTS consumo_giornaliero_cond$$

CREATE PROCEDURE consumo_giornaliero_cond(
    OUT consumo_giornaliero_ FLOAT
)
BEGIN
    SET consumo_giornaliero_ = (
        SELECT SUM(I.EnergiaConsumata) 
        FROM Interazione I
        WHERE I.CodRegolazioneClima IS NOT NULL
          AND DAY(I.Inizio) = DAY(CURRENT_DATE)
          AND DAY(I.Fine) = DAY(CURRENT_DATE)
    );
END$$

/* Event scheduler per calcolo giornaliero automatico */
DROP EVENT IF EXISTS consumo_per_giorno$$

CREATE EVENT consumo_per_giorno
ON SCHEDULE EVERY 1 DAY
STARTS '2022-03-29 22:40:00'
DO
    CALL consumo_giornaliero_cond(@consumo)$$

/* ========== [5] Regolazione luce più frequente ========== 
   Identifica la configurazione di illuminazione più utilizzata
   
   @param luce_: OUTPUT - ID della regolazione illuminazione più frequente
*/
DROP PROCEDURE IF EXISTS regolazione_frequente$$

CREATE PROCEDURE regolazione_frequente(
    OUT luce_ INT
)
BEGIN
    -- CTE per conteggio totale regolazioni
    WITH regolazione AS (
        SELECT I.CodRegolazioneIlluminazione, COUNT(*) AS TotRegolazioni
        FROM Interazione I
        WHERE I.CodRegolazioneIlluminazione IS NOT NULL   
        GROUP BY I.CodRegolazioneIlluminazione 
    )
    -- Trova la regolazione con il massimo utilizzo
    SELECT I2.CodRegolazioneIlluminazione INTO luce_
    FROM Interazione I2
    WHERE I2.CodRegolazioneIlluminazione IS NOT NULL
    GROUP BY I2.CodRegolazioneIlluminazione
    HAVING COUNT(*) > ALL(
        SELECT R.TotRegolazioni
        FROM regolazione R
        WHERE R.CodRegolazioneIlluminazione <> I2.CodRegolazioneIlluminazione
    );
END$$

/* ========== [6] Energia consumata da dispositivo in un giorno ========== 
   Calcola il consumo totale di un dispositivo specifico in una data
   
   @param _dispositivo: ID del dispositivo
   @param to_check: Data da analizzare
   @param energia: OUTPUT - Energia consumata in kWh
*/
DROP PROCEDURE IF EXISTS energia_dispositivo$$

CREATE PROCEDURE energia_dispositivo(
    IN _dispositivo INT, 
    IN to_check DATE, 
    OUT energia FLOAT
)
BEGIN
    SET energia = (
        SELECT SUM(I.EnergiaConsumata)
        FROM Interazione I  
            INNER JOIN RegolazioneDispositivo RD 
                ON I.CodRegolazioneDispositivo = RD.CodRegolazione
            INNER JOIN Dispositivo D 
                ON RD.IdDispositivo = D.IdDispositivo
        WHERE D.IdDispositivo = _dispositivo
          AND DAY(I.Inizio) = DAY(to_check) 
          AND DAY(I.Fine) = DAY(to_check)
          AND I.EnergiaConsumata IS NOT NULL
    );
END$$

/* ========== [7] Smart Plug inattive ========== 
   Elenca tutte le smart plug attualmente spente
*/
DROP PROCEDURE IF EXISTS sp_inattive$$

CREATE PROCEDURE sp_inattive()
BEGIN
    SELECT Codice
    FROM SmartPlug
    WHERE Stato = 0;
END$$

/* ========== [8] Account con maggior consumo mensile ========== 
   Identifica l'utente con il maggior consumo energetico nel mese corrente
   
   @param account_: OUTPUT - Username dell'account con maggior consumo
*/
DROP PROCEDURE IF EXISTS consumo_account_mese$$

CREATE PROCEDURE consumo_account_mese(
    OUT account_ VARCHAR(50)
)
BEGIN
    -- CTE per consumo totale per utente
    WITH consumo_energia AS (
        SELECT I1.NomeUtente, SUM(I1.EnergiaConsumata) AS consumo
        FROM Interazione I1
        WHERE MONTH(I1.Inizio) = MONTH(CURRENT_DATE)
          AND MONTH(I1.Fine) = MONTH(CURRENT_DATE)
        GROUP BY I1.NomeUtente
    )
    -- Trova l'utente con il massimo consumo
    SELECT I2.NomeUtente INTO account_
    FROM Interazione I2
    WHERE MONTH(I2.Inizio) = MONTH(CURRENT_DATE)
      AND MONTH(I2.Fine) = MONTH(CURRENT_DATE)
    GROUP BY I2.NomeUtente
    HAVING SUM(I2.EnergiaConsumata) > ALL(
        SELECT CE.consumo
        FROM consumo_energia CE
        WHERE CE.NomeUtente <> I2.NomeUtente
    );
END$$

DELIMITER ;