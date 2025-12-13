/* ========================================
   OPERAZIONI PRINCIPALI DEL DATABASE
   ======================================== */

DELIMITER $$

/* ========== [1] Inserimento nuovo utente ========== 
   Crea un nuovo utente nel sistema con relativo documento e account
   
   Validazioni:
   - Documento deve essere in corso di validità
   - Password minimo 8 caratteri
   - Username minimo 3 caratteri
*/
DROP PROCEDURE IF EXISTS NuovoUtente$$

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
    SET documento_valido = (p_DataScadenza > CURRENT_DATE);
    
    -- Verifica lunghezza credenziali
    SET credenziali_valide = (LENGTH(p_Password) >= 8 AND LENGTH(p_NomeUtente) >= 3);
    
    IF documento_valido AND credenziali_valide THEN
        -- Inserimento in ordine gerarchico per vincoli FK
        INSERT INTO Utente (CodFiscale, Nome, Cognome, Telefono, DataNascita)
        VALUES (p_CodFiscale, p_Nome, p_Cognome, p_Telefono, p_DataNascita);
        
        INSERT INTO Documento (Numero, Tipologia, EnteRilascio, DataScadenza, CodFiscale)
        VALUES (p_Numero, p_Tipologia, p_EnteRilascio, p_DataScadenza, p_CodFiscale);
        
        INSERT INTO Account (NomeUtente, Password, DataCreazione, Risposta, CodFiscale, Attivo)
        VALUES (p_NomeUtente, p_Password, CURRENT_DATE, p_Risposta, p_CodFiscale, 1);
    ELSE 
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Errore: documento scaduto o credenziali non valide (password >= 8 caratteri, username >= 3 caratteri)';
    END IF;
END$$


/* ========== [2] Inserimento nuovo contratto energia ========== 
   Aggiorna o inserisce una nuova fascia oraria nel contratto energetico
   
   Validazioni:
   - Nome non vuoto
   - Prezzi positivi
*/
DROP PROCEDURE IF EXISTS NuovoContratto$$

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
        INSERT INTO FasciaOraria (IdFascia, Nome, Inizio, Fine, PrezzoRin, CostoNonRin, SceltaUtilizzo)
        VALUES (DEFAULT, p_Nome, p_Inizio, p_Fine, p_PrezzoRin, p_CostoNonRin, p_SceltaUtilizzo);
    ELSE 
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Errore: nome vuoto o prezzi non validi';
    END IF;
END$$


/* ========== [3] Energia consumata/prodotta in un giorno ========== 
   Calcola il bilancio energetico giornaliero:
   - Valore positivo: energia autoprodotta > consumo
   - Valore negativo: necessario prelievo dalla rete
   
   @param to_check: Data da analizzare
   @param energia: OUTPUT - Bilancio energetico in kWh
*/
DROP PROCEDURE IF EXISTS energia_consumata$$

CREATE PROCEDURE energia_consumata(
    IN to_check DATE, 
    OUT energia DOUBLE
)
BEGIN
    -- Evita errori con JOIN che moltiplicano le righe: calcolo separato di produzione e consumo
    SET energia =
        (
            SELECT COALESCE(SUM(E.Quantita), 0)
            FROM EnergiaProdotta E
            WHERE DATE(E.Timestamp) = to_check
        )
        -
        (
            SELECT COALESCE(SUM(I.EnergiaConsumata), 0)
            FROM Interazione I
            WHERE DATE(I.Inizio) = to_check
        );
END$$


/* Event scheduler per calcolo giornaliero automatico */
DROP EVENT IF EXISTS consumi_giorno$$

CREATE EVENT consumi_giorno
ON SCHEDULE EVERY 1 DAY
STARTS '2022-03-29 00:00:00'
DO
BEGIN
    CALL energia_consumata(CURRENT_DATE, @consumigg);
END$$


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
        SELECT COALESCE(SUM(I.EnergiaConsumata), 0)
        FROM Interazione I
        WHERE I.CodRegolazioneClima IS NOT NULL
          AND DATE(I.Inizio) = CURRENT_DATE
          AND DATE(I.Fine) = CURRENT_DATE
    );
END$$


/* Event scheduler per calcolo giornaliero automatico */
DROP EVENT IF EXISTS consumo_per_giorno$$

CREATE EVENT consumo_per_giorno
ON SCHEDULE EVERY 1 DAY
STARTS '2022-03-29 22:40:00'
DO
BEGIN
    CALL consumo_giornaliero_cond(@consumo);
END$$


/* ========== [5] Regolazione luce più frequente ========== 
   Identifica la configurazione di illuminazione più utilizzata
   
   @param luce_: OUTPUT - ID della regolazione illuminazione più frequente
*/
DROP PROCEDURE IF EXISTS regolazione_frequente$$
CREATE PROCEDURE regolazione_frequente(
    OUT luce_ INT
)
BEGIN
    SELECT I.CodRegolazioneIlluminazione
    INTO luce_
    FROM Interazione I
    WHERE I.CodRegolazioneIlluminazione IS NOT NULL
    GROUP BY I.CodRegolazioneIlluminazione
    ORDER BY COUNT(*) DESC, I.CodRegolazioneIlluminazione ASC
    LIMIT 1;
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
        SELECT COALESCE(SUM(I.EnergiaConsumata), 0)
        FROM Interazione I  
            INNER JOIN RegolazioneDispositivo RD 
                ON I.CodRegolazioneDispositivo = RD.CodRegolazione
            INNER JOIN Dispositivo D 
                ON RD.IdDispositivo = D.IdDispositivo
        WHERE D.IdDispositivo = _dispositivo
          AND DATE(I.Inizio) = to_check
          AND DATE(I.Fine) = to_check
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
    SELECT I.NomeUtente
    INTO account_
    FROM Interazione I
    WHERE YEAR(I.Inizio) = YEAR(CURRENT_DATE)
      AND MONTH(I.Inizio) = MONTH(CURRENT_DATE)
    GROUP BY I.NomeUtente
    ORDER BY COALESCE(SUM(I.EnergiaConsumata), 0) DESC, I.NomeUtente ASC
    LIMIT 1;
END$$


DELIMITER ;
