DELIMITER $$

/* ========================================
   PROCEDURA: Inserimento nuova interazione
   
   Gestisce l'inserimento di una nuova interazione utente con:
   - Dispositivi (codice < 50)
   - Climatizzazione (codice 50-99)
   - Illuminazione (codice >= 100)
   
   La procedura calcola automaticamente:
   - Consumo energetico
   - Fascia oraria di appartenenza
   - Timestamp di fine (per dispositivi con programma fisso)
   ======================================== */

DROP PROCEDURE IF EXISTS InserimentoInterazione$$

CREATE PROCEDURE InserimentoInterazione(
    IN p_inizio TIMESTAMP, 
    IN p_fine TIMESTAMP, 
    IN p_ComandoVocale BOOLEAN, 
    IN p_nomeUtente VARCHAR(50), 
    IN p_codiceRegolazione INT
)
BEGIN
    /* Variabili locali */
    DECLARE v_consumo FLOAT DEFAULT 0;
    DECLARE v_durata_ore FLOAT DEFAULT 0;
    DECLARE v_fine_calcolata TIMESTAMP DEFAULT '0000-00-00 00:00:00';
    DECLARE v_fascia INT DEFAULT 0;
    DECLARE v_usa_fine_utente BOOLEAN DEFAULT FALSE;
    
    /* ========================================
       CONVENZIONE CODICI REGOLAZIONE:
       - Codici < 50: Dispositivi
       - Codici 50-99: Climatizzazione  
       - Codici >= 100: Illuminazione
       ======================================== */
    
    /* ==================== DISPOSITIVI (< 50) ==================== */
    IF p_codiceRegolazione < 50 THEN
        
        -- Determina se il dispositivo ha potenza variabile o programma fisso
        -- Potenza variabile: Codice IS NULL (usa IdLivelloPotenza)
        -- Programma fisso: Codice IS NOT NULL
        
        IF (SELECT Codice 
            FROM RegolazioneDispositivo 
            WHERE CodRegolazione = p_codiceRegolazione) IS NULL THEN
            
            /* --- DISPOSITIVO CON POTENZA VARIABILE --- */
            -- L'utente controlla durata e potenza
            -- Consumo = Potenza × Durata effettiva
            
            SET v_consumo = (
                SELECT ConsumoPerTempo
                FROM Potenza
                WHERE IdLivelloPotenza = (
                    SELECT IdLivelloPotenza 
                    FROM RegolazioneDispositivo 
                    WHERE CodRegolazione = p_codiceRegolazione
                )
            ) * (TIMESTAMPDIFF(SECOND, p_inizio, p_fine) / 3600);
            
            SET v_usa_fine_utente = TRUE;
            SET v_fine_calcolata = p_fine;
            
        ELSE
            /* --- DISPOSITIVO CON PROGRAMMA FISSO --- */
            -- Il programma ha durata predefinita
            -- Consumo calcolato dal programma
            
            -- Recupera durata del programma (convertita in ore)
            SET v_durata_ore = (
                SELECT DurataMedia 
                FROM Programma
                WHERE Codice = (
                    SELECT Codice
                    FROM RegolazioneDispositivo
                    WHERE CodRegolazione = p_codiceRegolazione
                )
            ) / 3600;
            
            -- Calcola timestamp di fine automatico
            SET v_fine_calcolata = p_inizio + INTERVAL v_durata_ore HOUR;
            
            -- Calcola consumo tramite funzione dedicata
            SET v_consumo = calcolo_consumo_dispositivi(
                (SELECT IdDispositivo 
                 FROM RegolazioneDispositivo
                 WHERE CodRegolazione = p_codiceRegolazione),
                p_inizio,
                v_fine_calcolata
            );
        END IF;

        -- Determina la fascia oraria di appartenenza
        SET v_fascia = (
            SELECT F.IdFascia
            FROM FasciaOraria F
            WHERE HOUR(p_inizio) >= HOUR(F.Inizio) 
              AND HOUR(IF(v_usa_fine_utente, p_fine, v_fine_calcolata)) <= HOUR(F.Fine)
        );

        -- Inserimento interazione dispositivo
        IF p_codiceRegolazione IN (SELECT CodRegolazione FROM RegolazioneDispositivo) THEN
            INSERT INTO Interazione(
                Inizio, Fine, ComandoVocale, EnergiaConsumata, 
                IdFascia, NomeUtente, CodRegolazioneDispositivo
            )
            VALUES (
                CURRENT_TIMESTAMP, 
                IF(v_usa_fine_utente, p_fine, v_fine_calcolata),
                p_ComandoVocale,
                v_consumo,
                v_fascia,
                p_nomeUtente,
                p_codiceRegolazione
            );
        END IF;
        
    /* ==================== ILLUMINAZIONE (>= 100) ==================== */
    ELSEIF p_codiceRegolazione >= 100 THEN
        
        -- Calcola consumo tramite funzione dedicata
        SET v_consumo = consumo_luce(
            (SELECT RI.IdLuce
             FROM RegolazioneIlluminazione RI
             WHERE RI.CodIlluminazione = p_codiceRegolazione),
            p_inizio,
            p_fine
        );
        
        -- Determina la fascia oraria
        SET v_fascia = (
            SELECT F.IdFascia
            FROM FasciaOraria F
            WHERE HOUR(p_inizio) >= HOUR(F.Inizio) 
              AND HOUR(p_fine) <= HOUR(F.Fine)
        );

        -- Inserimento interazione illuminazione
        INSERT INTO Interazione(
            Inizio, Fine, ComandoVocale, EnergiaConsumata, 
            IdFascia, NomeUtente, CodRegolazioneIlluminazione
        )
        VALUES (
            CURRENT_TIMESTAMP,
            p_fine,
            p_ComandoVocale,
            v_consumo,
            v_fascia,
            p_nomeUtente,
            p_codiceRegolazione
        );
        
    /* ==================== CLIMATIZZAZIONE (50-99) ==================== */
    ELSEIF p_codiceRegolazione >= 50 AND p_codiceRegolazione < 100 THEN
        
        -- Calcola consumo tramite funzione dedicata
        SET v_consumo = consumo_clima(
            (SELECT RC.IdCondizionatore
             FROM RegolazioneClima RC
             WHERE RC.CodClima = p_codiceRegolazione),
            p_inizio,
            p_fine
        );
        
        -- Determina la fascia oraria
        SET v_fascia = (
            SELECT F.IdFascia
            FROM FasciaOraria F
            WHERE HOUR(p_inizio) >= HOUR(F.Inizio) 
              AND HOUR(p_fine) <= HOUR(F.Fine)
        );

        -- Inserimento interazione climatizzazione
        INSERT INTO Interazione(
            Inizio, Fine, ComandoVocale, EnergiaConsumata, 
            IdFascia, NomeUtente, CodRegolazioneClima
        )
        VALUES (
            CURRENT_TIMESTAMP,
            p_fine,
            p_ComandoVocale,
            v_consumo,
            v_fascia,
            p_nomeUtente,
            p_codiceRegolazione
        );
    END IF;
END$$

DELIMITER ;