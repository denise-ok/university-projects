DELIMITER $$

/* ========================================
   FUNZIONI DI CALCOLO CONSUMO ENERGETICO
   ======================================== */

/* ========== Calcolo consumo dispositivi ========== 
   Calcola il consumo energetico di un dispositivo in base al tipo:
   - Dispositivi a potenza variabile: usa il ConsumoPerTempo
   - Dispositivi con programma fisso: usa il ConsumoMedio/DurataMedia
   
   @param dispositivo: ID del dispositivo
   @param inizio: Timestamp inizio utilizzo
   @param fine: Timestamp fine utilizzo
   @return: Consumo in kWh
*/
DROP FUNCTION IF EXISTS calcolo_consumo_dispositivi$$

CREATE FUNCTION calcolo_consumo_dispositivi(
    dispositivo INT, 
    inizio TIMESTAMP, 
    fine TIMESTAMP
) RETURNS FLOAT DETERMINISTIC 
BEGIN 
    DECLARE consumo DOUBLE DEFAULT 0;
    DECLARE ha_potenza_variabile INT DEFAULT 0;
    DECLARE durata_ore DOUBLE DEFAULT 0;

    -- Calcola durata in ore
    SET durata_ore = TIMESTAMPDIFF(SECOND, inizio, fine) / 3600;

    -- Verifica se il dispositivo ha potenza variabile (IdLivelloPotenza != NULL)
    SELECT SUM(IF(RD.Codice IS NULL, 1, 0)) INTO ha_potenza_variabile
    FROM RegolazioneDispositivo RD
    WHERE RD.IdDispositivo = dispositivo;
    
    IF ha_potenza_variabile > 0 THEN
        -- Dispositivo con potenza variabile
        -- Consumo = Consumo medio per tempo × durata
        SET consumo = (
            SELECT AVG(P.ConsumoPerTempo)
            FROM Potenza P
            WHERE P.IdDispositivo = dispositivo
        ) * durata_ore;
    ELSE
        -- Dispositivo con programma fisso
        -- Consumo = (Consumo medio / Durata media) × durata effettiva
        SET consumo = (
            SELECT AVG(P.ConsumoMedio / P.DurataMedia)
            FROM Programma P
            WHERE P.IdDispositivo = dispositivo
        ) * durata_ore;
    END IF;

    RETURN consumo;
END$$

/* ========== Calcolo consumo illuminazione ========== 
   Calcola il consumo di un elemento di illuminazione
   
   @param luce: ID della luce
   @param inizio: Timestamp inizio utilizzo
   @param fine: Timestamp fine utilizzo
   @return: Consumo in kWh
*/
DROP FUNCTION IF EXISTS consumo_luce$$

CREATE FUNCTION consumo_luce(
    luce INT, 
    inizio TIMESTAMP, 
    fine TIMESTAMP
) RETURNS DOUBLE DETERMINISTIC
BEGIN
    DECLARE durata_ore DOUBLE DEFAULT 0;
    DECLARE consumo DOUBLE DEFAULT 0;
    
    -- Calcola durata in ore
    SET durata_ore = TIMESTAMPDIFF(SECOND, inizio, fine) / 3600;
    
    -- Calcola consumo basato sulla regolazione
    -- Consumo = Consumo della regolazione × durata
    SET consumo = (
        SELECT RI.Consumo
        FROM RegolazioneIlluminazione RI
        WHERE RI.IdLuce = luce
    ) * durata_ore;
                    
    RETURN consumo;
END$$

/* ========== Calcolo consumo climatizzazione ========== 
   Calcola il consumo di un elemento di climatizzazione
   
   @param clima: ID del condizionatore
   @param inizio: Timestamp inizio utilizzo
   @param fine: Timestamp fine utilizzo
   @return: Consumo in kWh
*/
DROP FUNCTION IF EXISTS consumo_clima$$

CREATE FUNCTION consumo_clima(
    clima INT, 
    inizio TIMESTAMP, 
    fine TIMESTAMP
) RETURNS DOUBLE DETERMINISTIC
BEGIN
    DECLARE durata_ore DOUBLE DEFAULT 0;
    DECLARE consumo DOUBLE DEFAULT 0;
    
    -- Calcola durata in ore
    SET durata_ore = TIMESTAMPDIFF(SECOND, inizio, fine) / 3600;
    
    -- Calcola consumo basato sulla regolazione
    -- Consumo = Consumo della regolazione × durata
    SET consumo = (
        SELECT RC.Consumo
        FROM RegolazioneClima RC
        WHERE RC.IdCondizionatore = clima
    ) * durata_ore;

    RETURN consumo;
END$$

DELIMITER ;