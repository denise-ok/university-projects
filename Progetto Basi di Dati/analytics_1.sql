/* ========================================
   ANALYTICS: Association Rule Learning
   
   Algoritmo: APRIORI
   Obiettivo: Scoprire pattern di utilizzo dei dispositivi
   
   Il sistema identifica regole di associazione del tipo:
   "Se viene usato il dispositivo X, allora viene spesso usato anche Y"
   
   Metriche utilizzate:
   - SUPPORT: Frequenza con cui un itemset appare nelle transazioni
   - CONFIDENCE: Probabilità che Y venga usato quando viene usato X
   
   Esempio pratico:
   Se confidence(Lavatrice => Asciugatrice) = 0.8
   significa che l'80% delle volte che si usa la lavatrice,
   si usa anche l'asciugatrice entro il timeout specificato
   ======================================== */

-- Aumenta il limite per la concatenazione di gruppi
SET SESSION group_concat_max_len = 5000;

USE `mySmartHome`;

/* ========================================
   CONFIGURAZIONE PARAMETRI ALGORITMO
   ======================================== */

-- Timeout in minuti: se passano più di X minuti tra due interazioni,
-- vengono considerate transazioni separate
SET @max_timeout = 200;

-- Soglia di supporto minimo: un itemset deve comparire almeno
-- questo numero di volte per essere considerato "frequente"
SET @support_treshold = 2;

-- Soglia di confidenza minima: una regola deve avere almeno
-- questa confidenza per essere considerata "forte"
SET @confidence = 0.6;

/* ========================================
   FASE 1: Creazione tabella TRANSAZIONI
   
   Struttura: Tabella pivot con:
   - Una riga per transazione
   - Una colonna per dispositivo (D1, D2, D3, ...)
   - Valore 1 se dispositivo usato, 0 altrimenti
   ======================================== */

-- Genera dinamicamente lista colonne dispositivi
SELECT GROUP_CONCAT(CONCAT('`D', IdDispositivo, '`', ' INT DEFAULT 0')) 
INTO @lista_dispositivi 
FROM Dispositivo;

-- Crea statement SQL dinamico per tabella pivot
SET @pivot_table = CONCAT(
    'CREATE TABLE Transazioni(',
    ' ID INT AUTO_INCREMENT PRIMARY KEY, ', 
    @lista_dispositivi, 
    ') ENGINE = InnoDB DEFAULT CHARSET = latin1;'
);

DROP TABLE IF EXISTS `Transazioni`;
PREPARE myquery FROM @pivot_table;
EXECUTE myquery;

/* ========================================
   FASE 2: Popolamento tabella TRANSAZIONI
   
   Logica:
   1. Scorri le interazioni ordinate per timestamp
   2. Se passa più di @max_timeout minuti, crea nuova transazione
   3. Altrimenti aggiungi dispositivo alla transazione corrente
   ======================================== */

DROP PROCEDURE IF EXISTS FillTransazioni;
DELIMITER $$
CREATE PROCEDURE FillTransazioni()
BEGIN
    DECLARE IdDispositivo INT;
    DECLARE InizioInterazione TIMESTAMP;
    DECLARE UltimaInterazione TIMESTAMP;
    DECLARE primoInserimento INT DEFAULT 1;
    DECLARE finito INT DEFAULT 0;

    -- Cursore che scorre le interazioni ordinate cronologicamente
    DECLARE cursore CURSOR FOR
        SELECT d.IdDispositivo, i.Inizio
        FROM `Interazione` i 
        INNER JOIN `RegolazioneDispositivo` rd 
            ON i.CodRegolazioneDispositivo = rd.CodRegolazione
        INNER JOIN `Dispositivo` d 
            ON d.IdDispositivo = rd.IdDispositivo
        ORDER BY i.Inizio;

    -- Handler per fine cursore
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET finito = 1;
    
    OPEN cursore;

    scan: LOOP
        FETCH cursore INTO IdDispositivo, InizioInterazione;
        
        -- Esci se cursore terminato
        IF finito = 1 THEN 
            LEAVE scan;
        END IF;

        -- Crea nuova transazione se:
        -- - È la prima interazione
        -- - È passato il timeout dalla precedente
        IF primoInserimento OR 
           TIMESTAMPDIFF(MINUTE, UltimaInterazione, InizioInterazione) > @max_timeout THEN
            INSERT INTO `Transazioni` () VALUES();
        END IF;

        -- Marca dispositivo come usato (1) nella transazione corrente
        SET @sql_text = CONCAT(
            'UPDATE `Transazioni` SET `D', IdDispositivo, '` = 1 ',
            'WHERE `ID` = ', LAST_INSERT_ID()
        );
        PREPARE stmt FROM @sql_text;
        EXECUTE stmt;

        -- Aggiorna stato per prossima iterazione
        SET primoInserimento = 0;
        SET UltimaInterazione = InizioInterazione;

    END LOOP scan;
    CLOSE cursore;
END$$
DELIMITER ;

-- Esegui popolamento
CALL FillTransazioni();

/* ========================================
   FASE 3: Creazione tabella ITEMSETS
   
   Struttura:
   - ID: Identificatore univoco riga
   - IdItemset: Raggruppa dispositivi dello stesso itemset
   - IdDispositivo: Dispositivo nell'itemset
   - SupportCount: Numero di occorrenze nelle transazioni
   ======================================== */

DROP TABLE IF EXISTS `ItemsSets`;
CREATE TABLE `ItemsSets`(
    ID INT AUTO_INCREMENT PRIMARY KEY,
    IdItemset INT,
    IdDispositivo INT,
    SupportCount INT
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

/* ========================================
   FASE 4: APRIORI - Prima iterazione (k=1)
   
   Crea itemset con singoli dispositivi che superano
   la soglia di supporto minimo
   ======================================== */

DROP PROCEDURE IF EXISTS CreateItems;
DELIMITER $$
CREATE PROCEDURE CreateItems()
BEGIN
    DECLARE finito INT DEFAULT 0;
    DECLARE IdDispositivo INT;
    DECLARE currentItemsetId INT DEFAULT 1;

    -- Cursore su tutti i dispositivi
    DECLARE cursore CURSOR FOR
        SELECT d.IdDispositivo
        FROM `Dispositivo` d;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET finito = 1;
    
    OPEN cursore;
    
    scan: LOOP
        FETCH cursore INTO IdDispositivo;

        IF finito = 1 THEN LEAVE scan; END IF;
        
        -- Conta occorrenze dispositivo nelle transazioni
        SET @columnDispositivo = CONCAT('D', IdDispositivo);
        SET @stmt = CONCAT(
            'SET @count = (SELECT COUNT(*) FROM `Transazioni` WHERE ',
            @columnDispositivo, ' = 1);'
        );
        PREPARE query FROM @stmt;
        EXECUTE query;

        -- Se non supera soglia supporto, salta questo dispositivo
        IF @count < @support_treshold THEN
            ITERATE scan;
        END IF;

        -- Determina ID itemset corrente
        SET currentItemsetId = (SELECT MAX(IdItemset) FROM `ItemsSets`) + 1;
        IF currentItemsetId IS NULL THEN
            SET currentItemsetId = 1;
        END IF;

        -- Inserisci dispositivo nei large itemsets
        INSERT INTO `ItemsSets` (ID, IdItemset, IdDispositivo, SupportCount) 
        VALUES (DEFAULT, currentItemsetId, IdDispositivo, @count);

    END LOOP scan;
    CLOSE cursore;
END$$
DELIMITER ;

/* ========================================
   FASE 5: APRIORI - Iterazioni successive (k≥2)
   
   Genera itemset di dimensione k combinando quelli di dimensione k-1
   mediante prodotto cartesiano
   ======================================== */

DROP PROCEDURE IF EXISTS UpdateItems;
DELIMITER $$
CREATE PROCEDURE UpdateItems(k INT)
BEGIN
    DECLARE IdDispositivo1 INT;
    DECLARE IdDispositivo2 INT;
    DECLARE currentItemsetId INT DEFAULT 1;
    DECLARE finito INT DEFAULT 0;

    -- Prodotto cartesiano tra dispositivi negli itemsets
    -- per generare tutte le possibili coppie
    DECLARE cursore CURSOR FOR
        SELECT d.IdDispositivo, f.IdDispositivo 
        FROM `ItemsSets` d, `ItemsSets` f
        WHERE d.IdDispositivo <> f.IdDispositivo;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET finito = 1;
    
    OPEN cursore;
    
    scan: LOOP
        FETCH cursore INTO IdDispositivo1, IdDispositivo2;

        IF finito = 1 THEN LEAVE scan; END IF;
        
        -- Conta transazioni che contengono ENTRAMBI i dispositivi
        SET @columnDispositivo1 = CONCAT('D', IdDispositivo1);
        SET @columnDispositivo2 = CONCAT('D', IdDispositivo2);
        SET @stmt = CONCAT(
            'SET @count = (SELECT COUNT(*) FROM `Transazioni` WHERE ',
            @columnDispositivo1, ' = 1 AND ',
            @columnDispositivo2, ' = 1);'
        );
        PREPARE query FROM @stmt;
        EXECUTE query;

        -- Se coppia non supera soglia supporto, scarta
        IF @count < @support_treshold THEN
            ITERATE scan;
        END IF;
        
        -- Determina ID itemset corrente
        SET currentItemsetId = (SELECT MAX(IdItemset) FROM `ItemsSets`) + 1;
        IF currentItemsetId IS NULL THEN
            SET currentItemsetId = 1;
        END IF;

        -- Inserisci coppia di dispositivi come nuovo itemset
        INSERT INTO `ItemsSets` (ID, IdItemset, IdDispositivo, SupportCount) 
        VALUES (DEFAULT, currentItemsetId, IdDispositivo1, @count);
        INSERT INTO `ItemsSets` (ID, IdItemset, IdDispositivo, SupportCount) 
        VALUES (DEFAULT, currentItemsetId, IdDispositivo2, @count);

    END LOOP scan;
    CLOSE cursore;
END$$
DELIMITER ;

/* ========================================
   FASE 6: Dispatcher per popolamento itemsets
   ======================================== */

DROP PROCEDURE IF EXISTS FillItems;
DELIMITER $$
CREATE PROCEDURE FillItems(k INT)
BEGIN
    -- Prima iterazione: itemsets singoli
    IF k <= 2 THEN
        CALL CreateItems();
    -- Iterazioni successive: combinazioni
    ELSEIF k = 3 THEN
        CALL UpdateItems(k);
    END IF;
END$$
DELIMITER ;

/* ========================================
   FASE 7: Estrazione REGOLE DI ASSOCIAZIONE
   
   Formula: confidence(X => Y) = support(X ∪ Y) / support(X)
   
   Interpretazione:
   confidence = 0.8 significa che nell'80% dei casi in cui
   viene usato X, viene usato anche Y
   ======================================== */

DROP TABLE IF EXISTS `Regole`;
CREATE TABLE `Regole`(
    ID INT AUTO_INCREMENT PRIMARY KEY,
    IdAntecedente INT COMMENT 'Dispositivo X nella regola X=>Y',
    IdConseguente INT COMMENT 'Dispositivo Y nella regola X=>Y'
);

DROP PROCEDURE IF EXISTS CreateRules;
DELIMITER $$
CREATE PROCEDURE CreateRules()
BEGIN
    DECLARE finito INT DEFAULT 0;
    DECLARE IdDispositivo1 INT DEFAULT 0;
    DECLARE IdDispositivo2 INT DEFAULT 0;
    DECLARE ItemsetSupport INT DEFAULT 0;

    -- Seleziona solo itemsets con almeno 2 dispositivi
    -- (non ha senso creare regole da itemset singoli)
    DECLARE cursore CURSOR FOR
        SELECT j.IdDispositivo, j.SupportCount
        FROM `itemssets` j
        WHERE j.IdItemset IN (
            SELECT i.IdItemset
            FROM `itemssets` i
            GROUP BY i.IdItemset
            HAVING COUNT(*) >= 2
        );
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET finito = 1;
    
    OPEN cursore;
    
    scan: LOOP
        -- Recupera coppia di dispositivi e loro supporto congiunto
        FETCH cursore INTO IdDispositivo1, ItemsetSupport;
        FETCH cursore INTO IdDispositivo2, ItemsetSupport;

        IF finito = 1 THEN LEAVE scan; END IF;
    
        -- Recupera supporto individuale di ciascun dispositivo
        SET @IdDispositivo1Support = (
            SELECT i.SupportCount 
            FROM `ItemsSets` i 
            WHERE i.IdDispositivo = IdDispositivo1 
            LIMIT 1
        );
        SET @IdDispositivo2Support = (
            SELECT i.SupportCount 
            FROM `ItemsSets` i 
            WHERE i.IdDispositivo = IdDispositivo2 
            LIMIT 1
        );
    
        -- Calcola confidence(Dispositivo1 => Dispositivo2)
        -- Formula: support(D1 ∪ D2) / support(D1)
        IF ItemsetSupport / @IdDispositivo1Support > @confidence THEN
            INSERT INTO `Regole` (ID, IdAntecedente, IdConseguente) 
            VALUES (DEFAULT, IdDispositivo1, IdDispositivo2);
        END IF;

        -- Calcola confidence(Dispositivo2 => Dispositivo1)
        -- Formula: support(D1 ∪ D2) / support(D2)
        IF ItemsetSupport / @IdDispositivo2Support > @confidence THEN
            INSERT INTO `Regole` (ID, IdAntecedente, IdConseguente) 
            VALUES (DEFAULT, IdDispositivo2, IdDispositivo1);
        END IF;
        
    END LOOP scan;
    CLOSE cursore;
END$$
DELIMITER ;

/* ========================================
   FASE 8: Esecuzione completa ALGORITMO APRIORI
   ======================================== */

DROP PROCEDURE IF EXISTS Apriori;
DELIMITER $$
CREATE PROCEDURE Apriori()
BEGIN
    DECLARE k INT DEFAULT 2;
    DECLARE tot INT;
    
    -- Numero totale di dispositivi = numero max di iterazioni
    SET tot = (SELECT COUNT(*) FROM Dispositivo);
    
    -- Loop principale: genera itemsets di dimensione crescente
    apriori: LOOP
        IF k > tot THEN LEAVE apriori; END IF;
        
        -- Genera itemsets di dimensione k
        CALL FillItems(k);
        
        SET k = k + 1;
    END LOOP apriori; 

    -- Estrai regole forti dagli itemsets frequenti
    CALL CreateRules();
END$$
DELIMITER ;

-- Esegui algoritmo completo
CALL Apriori();

/* ========================================
   VISUALIZZAZIONE RISULTATI
   ======================================== */

-- Transazioni generate (matrice dispositivi × utilizzi)
SELECT * FROM `Transazioni`;

-- Itemsets frequenti scoperti
SELECT * FROM `ItemsSets`;

-- Regole di associazione forti
-- Per interpretare: IdAntecedente => IdConseguente
-- significa "quando si usa dispositivo X, si usa anche Y"
SELECT * FROM `Regole`;

/* ========================================
   UTILIZZO PRATICO DEI RISULTATI:
   
   1. AUTOMAZIONI SMART HOME
      - Se regola (Lavatrice => Asciugatrice), suggerisci
        di avviare asciugatrice quando finisce lavatrice
   
   2. OTTIMIZZAZIONE ENERGETICA
      - Raggruppa utilizzi di dispositivi correlati
        nelle fasce orarie con più energia disponibile
   
   3. NOTIFICHE INTELLIGENTI
      - "Hai avviato il forno, vuoi accendere anche
        la cappa?" (se esiste regola Forno => Cappa)
   
   4. ANALISI COMPORTAMENTALI
      - Identifica routine degli utenti
      - Rileva cambiamenti nei pattern di utilizzo
   ======================================== */