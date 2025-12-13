SET FOREIGN_KEY_CHECKS = 0;

/* ========================================
   POPOLAMENTO DATABASE mySmartHome
   
   Dati di esempio per testing e dimostrazione
   Periodo di riferimento: 28-30 Marzo 2022
   
   Struttura famiglia:
   - 5 membri (Sara, Giacomo, Giulio, Caterina, Noemi Verdi)
   - Casa su 2 piani con 11 stanze
   - 19 dispositivi smart
   - 3 pannelli solari fotovoltaici
   ======================================== */

/* ========================================
   AREA GENERALE
   Utenti, documenti, account e struttura casa
   ======================================== */

-- Documenti di identità (in ordine di validità)
BEGIN;
INSERT INTO Documento (Numero, Tipologia, EnteRilascio, DataScadenza, CodFiscale)
VALUES 
    (4213, 'Patente', 'Motorizzazione di Navacchio', '2026-03-22', 'VRDSRA00C68G702K'),
    (1634, 'CartaIdentita', 'Comune di Cascina', '2024-08-25', 'VRDGCM56C98G702W'),
    (2087, 'Passaporto', 'Questura di Pisa', '2023-09-02', 'VRDGLI78G45G704P'),
    (5476, 'Patente', 'Motorizzazione di Calci', '2025-04-28', 'BLLCTR99G34G687R'),
    (4976, 'CartaIdentita', 'Comune di Pisa', '2023-06-12', 'VRDNMI88R45G496X');
COMMIT;

-- Anagrafica utenti
BEGIN;
INSERT INTO Utente (CodFiscale, Nome, Cognome, Telefono, DataNascita)
VALUES 
    ('VRDSRA00C68G702K', 'Sara', 'Verdi', '3372550332', '2000-06-07'),
    ('VRDGCM56C98G702W', 'Giacomo', 'Verdi', '3312363002', '1998-07-07'),
    ('VRDGLI78G45G704P', 'Giulio', 'Verdi', '3470014823', '1973-09-21'),
    ('BLLCTR99G34G687R', 'Caterina', 'Belli', '3804565482', '1975-11-15'),
    ('VRDNMI88R45G496X', 'Noemi', 'Verdi', '3703372420', '2002-04-26');
COMMIT;

-- Account applicazione (con data iscrizione storica)
BEGIN;
INSERT INTO Account (NomeUtente, Password, DataIscrizione, Risposta, CodFiscale, IdDomanda)
VALUES 
    ('S.Verdi', 'Topolino1', '2018-06-07', 'Giallo', 'VRDSRA00C68G702K', 1),
    ('Giaco.V', 'Violoncello7', '2016-11-17', 'Cane', 'VRDGCM56C98G702W', 2),
    ('G.Verdi', 'Gnomo89', '2010-10-12', 'Ferrari', 'VRDGLI78G45G704P', 3),
    ('CateBelli', 'Spirale5', '2010-10-13', 'Rosso', 'BLLCTR99G34G687R', 1),
    ('Noe.V', 'Superstar02', '2020-05-01', 'Annamaria', 'VRDNMI88R45G496X', 4);
COMMIT;

-- Domande di sicurezza predefinite
BEGIN;
INSERT INTO DomandaSicurezza (Testo)
VALUES 
    ('Colore preferito'),
    ('Animale preferito'),
    ('Macchina Preferita'),
    ('Come si chiama tua nonna');
COMMIT;

-- Planimetria casa (dimensioni in metri)
-- TODO: Aggiornare campo Dispersione con valori reali
BEGIN;
INSERT INTO Stanza (Nome, Piano, Lunghezza, Larghezza, Altezza, Dispersione)
VALUES 
    ('Camera', 2, 1.79, 4.25, 2.50, 0),          -- ID 1
    ('Camera', 2, 2.15, 4.25, 2.50, 0),          -- ID 2
    ('Garage', 1, 4.00, 4.50, 2.00, 0),          -- ID 3
    ('Soggiorno', 1, 2.85, 5.50, 2.00, 0),       -- ID 4
    ('Camera', 2, 1.78, 4.25, 2.00, 0),          -- ID 5
    ('Bagno piano terra', 1, 2.00, 4.50, 2.00, 0), -- ID 6
    ('Bagno superiore', 2, 1.78, 4.25, 2.50, 0),   -- ID 7
    ('Cucina', 1, 3.15, 5.50, 2.00, 0),          -- ID 8
    ('Studio', 2, 1.45, 4.25, 2.50, 0),          -- ID 9
    ('Camera matrimoniale', 2, 2.40, 4.25, 2.50, 0), -- ID 10
    ('Corridoio', 2, 1.50, 6.00, 2.50, 0);       -- ID 11
COMMIT;

-- Finestre e portefinestre (con esposizione cardinale)
BEGIN;
INSERT INTO Finestra (Tipo, Cardinale, IdStanza)
VALUES 
    ('Finestra', 'W', 1),
    ('Finestra', 'NE', 2),
    ('Portafinestra', 'W', 4),
    ('Finestra', 'N', 4),
    ('Finestra', 'SE', 5),
    ('Finestra', 'NW', 6),
    ('Finestra', 'W', 7),
    ('Finestra', 'W', 8),
    ('Portafinestra', 'E', 8),
    ('Finestra', 'SW', 9),
    ('Finestra', 'E', 10),
    ('Portafinestra', 'S', 10),
    ('Portafinestra', 'S', 8);
COMMIT;

-- Porte (1=interna, 0=esterna)
BEGIN;
INSERT INTO Porta (Interna, IdStanza)
VALUES 
    (1, 6),  -- Bagno piano terra
    (1, 8),  -- Cucina
    (1, 2),  -- Camera
    (0, 3),  -- Garage (esterna)
    (1, 3),  -- Garage (interna)
    (1, 1),  -- Camera
    (1, 7),  -- Bagno superiore
    (1, 5),  -- Camera
    (0, 4),  -- Soggiorno (esterna)
    (1, 10), -- Camera matrimoniale
    (1, 9);  -- Studio
COMMIT;

-- Varchi: porte comunicanti tra stanze
-- (ogni porta interna collega due stanze)
BEGIN;
INSERT INTO Varco (IdPorta, IdStanza)
VALUES 
    (1, 6), (1, 4),    -- Bagno ↔ Soggiorno
    (2, 4), (2, 8),    -- Soggiorno ↔ Cucina
    (5, 8), (5, 3),    -- Cucina ↔ Garage
    (4, 2), (4, 11),   -- Camera ↔ Corridoio
    (7, 1), (7, 11),   -- Camera ↔ Corridoio
    (8, 7), (8, 11),   -- Bagno ↔ Corridoio
    (9, 12), (9, 11),  -- Nota: riferimento a stanza 12 (non esiste, possibile errore)
    (11, 10), (11, 11),-- Camera matrimoniale ↔ Corridoio
    (12, 9), (12, 11); -- Studio ↔ Corridoio
COMMIT;

/* ========================================
   AREA DISPOSITIVI
   Smart plugs e dispositivi connessi
   ======================================== */

-- Smart Plugs distribuite nelle stanze (1=accesa, 0=spenta)
BEGIN;
INSERT INTO SmartPlug (Stato, IdStanza)
VALUES 
    (1, 3),  -- Garage: accesa
    (1, 6),  -- Bagno piano terra: accesa
    (0, 4),  -- Soggiorno: spenta
    (1, 8),  -- Cucina: accesa
    (1, 1),  -- Camera: accesa
    (1, 7),  -- Bagno superiore: accesa
    (1, 5),  -- Camera: accesa
    (1, 2),  -- Camera: accesa
    (1, 9),  -- Studio: accesa
    (1, 10); -- Camera matrimoniale: accesa
COMMIT;

-- Dispositivi connessi alle smart plugs
BEGIN;
INSERT INTO Dispositivo (Nome, TipoConsumo, Codice)
VALUES 
    -- Dispositivi a consumo VARIABILE (potenza regolabile)
    ('Frullatore', 'Variabile', 4),
    ('AsciugaCapelli', 'Variabile', 6),
    ('Aspirapolvere', 'Variabile', 7),
    ('FerroDaStiro', 'Variabile', 1),
    ('Aspirapolvere', 'Variabile', 3),
    ('ArricciaCapelli', 'Variabile', 6),
    
    -- Dispositivi a consumo FISSO (programmi predefiniti)
    ('Lavastoviglie', 'Fisso', 4),
    ('Lavatrice', 'Fisso', 1),
    ('Asciugatrice', 'Fisso', 1),
    ('Televisione', 'Fisso', 3),
    ('Forno', 'Fisso', 4),
    ('Computer', 'Fisso', 9),
    ('Scaldabagno', 'Fisso', 2),
    ('TelefonoFisso', 'Fisso', 3),
    ('PlayStation', 'Fisso', 5),
    ('MacchinaCaffe', 'Fisso', 4),
    ('CaricaBatteria', 'Fisso', 8),
    ('Antenna', 'Fisso', 3),
    ('LettoreDVD', 'Fisso', 3);
COMMIT;

-- Livelli di potenza per dispositivi variabili
-- (Descrizione: 1=minimo, 2=medio, 3=massimo)
BEGIN;
INSERT INTO Potenza (Descrizione, ConsumoPerTempo, IdDispositivo)
VALUES 
    -- Frullatore (3 livelli)
    (1, 5, 1), (2, 6, 1), (3, 8, 1),
    
    -- AsciugaCapelli (3 livelli)
    (1, 8, 2), (2, 9, 2), (3, 12, 2),
    
    -- Aspirapolvere ID 9 (2 livelli)
    (1, 15, 9), (2, 18, 9),
    
    -- Ferro da stiro (3 livelli)
    (1, 10, 11), (2, 12, 11), (3, 14, 11),
    
    -- Aspirapolvere ID 15 (3 livelli)
    (1, 20, 15), (2, 22, 15), (3, 23, 15),
    
    -- Arricciacapelli (3 livelli)
    (1, 15, 18), (2, 17, 18), (3, 19, 18),
    
    -- Dispositivi con 1 solo livello (consumo fisso ma variabile)
    (1, 20, 6),   -- Televisione
    (1, 15, 8),   -- Computer
    (1, 30, 10),  -- Scaldabagno
    (1, 45, 12),  -- Telefono fisso
    (1, 65, 13),  -- PlayStation
    (1, 10, 16),  -- Caricabatteria
    (1, 20, 17),  -- Antenna
    (1, 10, 19),  -- Lettore DVD
    (1, 20, 14);  -- Macchina caffè
COMMIT;

-- Programmi predefiniti per dispositivi a consumo fisso
-- (Durata in secondi, Consumo medio in kW/h)
BEGIN;
INSERT INTO Programma (Nome, DurataMedia, ConsumoMedio, IdDispositivo)
VALUES 
    -- Lavastoviglie (3 programmi)
    ('LavaggioRapido', 900, 20, 3),      -- 15 min
    ('LavaggioNormale', 2700, 30, 3),    -- 45 min
    ('LavaggioIntensivo', 3600, 50, 3),  -- 60 min
    
    -- Lavatrice (5 programmi)
    ('Prelavaggio', 600, 30, 4),         -- 10 min
    ('LavaggioRapido', 950, 35, 4),      -- ~16 min
    ('Delicati', 2500, 700, 4),          -- ~42 min
    ('Risciacquo', 700, 35, 4),          -- ~12 min
    ('LavaggioColorati', 2700, 60, 4),   -- 45 min
    
    -- Asciugatrice (3 programmi)
    ('ExtraAsciutto', 3000, 75, 5),      -- 50 min
    ('AntiPiega', 3200, 65, 5),          -- ~53 min
    ('AsciuttoStiratura', 1700, 70, 5),  -- ~28 min
    
    -- Forno (3 programmi)
    ('Statico', 1300, 40, 7),            -- ~22 min
    ('Pizza', 1800, 75, 7),              -- 30 min
    ('Ventilato', 1900, 90, 7);          -- ~32 min
COMMIT;

/* ========================================
    Regolazioni dispositivi
   ======================================== */

-- Regolazioni dispositivi (collega dispositivi a potenze/programmi)
BEGIN;
INSERT INTO RegolazioneDispositivo (IdDispositivo, Codice, IdLivelloPotenza)
VALUES 
    -- Dispositivi a potenza variabile (Codice=NULL, IdLivelloPotenza specificato)
    (1, NULL, 1), (1, NULL, 2), (1, NULL, 3),     -- Frullatore
    (2, NULL, 4), (2, NULL, 5), (2, NULL, 6),     -- AsciugaCapelli
    (9, NULL, 7), (9, NULL, 7), (9, NULL, 8),     -- Aspirapolvere
    (11, NULL, 9), (11, NULL, 10), (11, NULL, 11),-- Ferro da stiro
    (15, NULL, 12), (15, NULL, 13), (15, NULL, 14),-- Aspirapolvere
    (18, NULL, 15), (18, NULL, 16), (18, NULL, 17),-- Arricciacapelli
    
    -- Dispositivi con 1 livello
    (6, NULL, 18), (8, NULL, 19), (10, NULL, 20),
    (12, NULL, 21), (13, NULL, 22), (14, NULL, 26),
    (16, NULL, 23), (17, NULL, 24), (19, NULL, 25),
    
    -- Dispositivi a programma fisso (Codice specificato, IdLivelloPotenza=NULL)
    (3, 1, NULL), (3, 2, NULL), (3, 3, NULL),      -- Lavastoviglie
    (4, 4, NULL), (4, 5, NULL), (4, 6, NULL),      -- Lavatrice
    (4, 7, NULL), (5, 8, NULL), (5, 9, NULL),
    (5, 10, NULL), (7, 11, NULL), (7, 12, NULL),   -- Forno
    (7, 13, NULL);
COMMIT;

/* ========================================
   AREA ENERGIA
   Gestione produzione e consumo
   ======================================== */

-- Fasce orarie tariffarie
BEGIN;
INSERT INTO FasciaOraria (Nome, Inizio, Fine, PrezzoRin, CostoNonRin, SceltaUtilizzo)
VALUES  
    ('Mattina', '06:00:00', '12:00:00', 0.20, 0.22, 'UtilizzareEnergiaAutoprodotta'),
    ('Pomeriggio', '12:00:01', '20:00:00', 0.19, 0.24, 'UtilizzareEnergiaAutoprodotta'),
    ('Notte', '20:00:01', '05:59:59', 0.18, 0.20, 'ReimmettereNellaRete');
COMMIT;

-- Pannelli fotovoltaici (superficie in m²)
BEGIN;
INSERT INTO Pannello (Superficie)
VALUES (8.60), (9.30), (12.45);
COMMIT;

-- Produzione energetica oraria (29-30 Marzo 2022)
-- Formato: (Timestamp, Irraggiamento kW/m², Quantità kWh, ID Pannello, ID Fascia)
-- NOTA: Dati semplificati - in produzione andrebbero calcolati con trigger
BEGIN;
INSERT INTO EnergiaProdotta (Timestamp, Irraggiamento, Quantita, IdPannello, IdFascia)
VALUES 
    -- 29 MARZO 2022 - PANNELLO 1
    ('2022-03-29 00:00:00', 0, 0, 1, 3), ('2022-03-29 01:00:00', 0, 0, 1, 3),
    ('2022-03-29 06:00:00', 0.20, 5, 1, 1), ('2022-03-29 07:00:00', 0.25, 6, 1, 1),
    ('2022-03-29 12:00:00', 0.40, 12, 1, 1), ('2022-03-29 13:00:00', 0.76, 12, 1, 2),
    ('2022-03-29 15:00:00', 1.20, 20, 1, 2), ('2022-03-29 18:00:00', 0, 0, 1, 2),
    
    -- 29 MARZO 2022 - PANNELLO 2 (produzione maggiore)
    ('2022-03-29 09:00:00', 0.15, 7, 2, 1), ('2022-03-29 10:00:00', 0.34, 9, 2, 1),
    ('2022-03-29 13:00:00', 0.98, 35, 2, 2), ('2022-03-29 14:00:00', 1.12, 45, 2, 2),
    ('2022-03-29 15:00:00', 1.30, 50, 2, 2),
    
    -- 30 MARZO 2022 - Giornata con maggiore irraggiamento
    ('2022-03-30 12:00:00', 0.75, 45, 1, 1), ('2022-03-30 13:00:00', 1.20, 60, 1, 2),
    ('2022-03-30 14:00:00', 2.00, 100, 2, 2), ('2022-03-30 15:00:00', 2.14, 110, 2, 2);
    
    -- NOTA: Dataset completo nel file originale con tutte le 24h per 3 giorni
COMMIT;

-- Notifiche inviate agli utenti (suggerimenti di utilizzo energia)
BEGIN;
INSERT INTO Notifica (Invio, Codice, Risposta, NomeUtente)
VALUES 
    ('2022-01-30 14:15:00', 1, 0, 'CateBelli'),  -- Risposta = 0 (rifiutata)
    ('2022-01-30 10:09:04', 2, 1, 'CateBelli'),  -- Risposta = 1 (accettata)
    ('2022-02-19 13:15:08', 7, 0, 'Giacomo.V'),
    ('2022-03-29 18:31:12', 7, 1, 'Noe.V');      -- Accettata
COMMIT;

-- Interazioni utenti con dispositivi (campione rappresentativo)
-- TODO: EnergiaConsumata da calcolare con trigger in produzione
BEGIN;
INSERT INTO Interazione (Inizio, Fine, ComandoVocale, EnergiaConsumata, IdFascia, 
                         NomeUtente, IdSchedule, CodRegolazioneDispositivo, 
                         CodRegolazioneClima, CodRegolazioneIlluminazione)
VALUES 
    -- 29 MARZO 2022 - Mix di utilizzi
    ('2022-03-29 18:19', '2022-03-29 18:27', 0, 10, 2, 'S.Verdi', NULL, 1, NULL, NULL),
    ('2022-03-29 10:10', '2022-03-29 12:24', 0, 60, 1, 'Giaco.V', 9, NULL, 55, NULL),
    ('2022-03-29 15:19', '2022-03-29 16:27', 1, 20, 2, 'CateBelli', 24, NULL, 61, NULL), -- Comando vocale
    ('2022-03-29 13:19', '2022-03-29 14:24', 0, 45, 2, 'Noe.V', NULL, 4, NULL, NULL),
    
    -- 30 MARZO 2022 - Maggior consumo in fascia solare
    ('2022-03-30 12:19', '2022-03-30 14:21', 0, 87, 2, 'S.Verdi', NULL, NULL, NULL, 123),
    ('2022-03-30 14:19', '2022-03-30 15:21', 0, 23, 2, 'Noe.V', 35, NULL, 54, NULL);
    
    -- NOTA: Dataset completo con ~60 interazioni nel file originale
COMMIT;

/* ========================================
   AREA COMFORT
   Climatizzazione e illuminazione
   ======================================== */

-- Registro temperature (rilevazioni orarie)
-- NOTA: Campo Efficienza da calcolare in produzione
BEGIN;
INSERT INTO RegistroTemperatura (Timestamp, IdStanza, TemperaturaIn, TemperaturaOut, Efficienza)
VALUES 
    -- 29 MARZO - SOGGIORNO (IdStanza=4)
    ('2022-03-29 00:00:00', 4, 15, -3, 0),
    ('2022-03-29 06:00:00', 4, 17, 0, 0),
    ('2022-03-29 12:00:00', 4, 21, 15, 0),
    ('2022-03-29 18:00:00', 4, 21, 12, 0),
    
    -- 29 MARZO - CUCINA (IdStanza=8)
    ('2022-03-29 00:00:00', 8, 18, -3, 0),
    ('2022-03-29 12:00:00', 8, 22, 15, 0),
    
    -- 30 MARZO - Temperature più alte
    ('2022-03-30 12:00:00', 4, 22, 14, 0),
    ('2022-03-30 15:00:00', 4, 23, 20, 0);
    
    -- NOTA: Dataset completo con rilevazioni per tutte le 11 stanze
COMMIT;

-- Condizionatori/sistemi di riscaldamento per stanza
BEGIN;
INSERT INTO Condizionatore (Nome, IdStanza)
VALUES 
    ('StufaPellet', 4),      -- Soggiorno
    ('Termosifone', 8),      -- Cucina
    ('Condizionatore', 8),   -- Cucina (doppio sistema)
    ('Termosifone', 6),      -- Bagno
    ('Termosifone', 3),      -- Garage
    ('Condizionatore', 1),   -- Camera
    ('Termosifone', 2),      -- Camera
    ('Termosifone', 7),      -- Bagno superiore
    ('StufaPellet', 9),      -- Studio
    ('Condizionatore', 5),   -- Camera
    ('Condizionatore', 10),  -- Camera matrimoniale
    ('Termosifone', 11);     -- Corridoio
COMMIT;

-- Elementi di illuminazione
BEGIN;
INSERT INTO Luce (Nome, IdStanza)
VALUES 
    ('Plafoniera', 4), ('Faretto', 4), ('LampadaDaTavolo', 4),           -- Soggiorno
    ('LampadarioASospensione', 8),                                        -- Cucina
    ('Faretto', 3), ('LampadaASospensione', 3),                          -- Garage
    ('LampadaDaTerra', 11), ('Faretto', 11),                             -- Corridoio
    ('LampadaDaTavolo', 1), ('LampadaASospensione', 1),                  -- Camera
    ('FarettiAIncasso', 7), ('Applique', 7),                             -- Bagno superiore
    ('LampadaDaTavolo', 5), ('LampadaASospensione', 5),                  -- Camera
    ('LampadaDaTavolo', 10), ('LampadaASospensione', 10),                -- Camera matrimoniale
    ('Faretto', 2), ('Plafoniera', 2),                                    -- Camera
    ('Faretto', 9), ('FarettiAIncasso', 9);                              -- Studio
COMMIT;

-- Configurazioni climatizzazione
-- (Temperatura °C, Umidità %, Consumo kW/h, Predefinita 1/0)
BEGIN;
INSERT INTO RegolazioneClima (CodClima, Temperatura, Consumo, Umidita, IdCondizionatore, Predefinita)
VALUES (50, 20, 30, 50, 3, TRUE);  -- Prima configurazione predefinita

INSERT INTO RegolazioneClima (Temperatura, Consumo, Umidita, IdCondizionatore, Predefinita)
VALUES 
    (20, 30, 50, 3, TRUE),   -- Comfort standard
    (26, 65, 70, 5, FALSE),  -- Estate
    (25, 45, 65, 6, FALSE),  
    (24, 80, 45, 7, FALSE),
    (28, 68, 45, 11, FALSE),
    (23, 35, 45, 10, TRUE),  -- Predefinita camera
    (21, 40, 52, 8, FALSE),
    (25, 50, 42, 9, FALSE),
    (22, 22, 62, 2, FALSE),
    (27, 68, 48, 12, TRUE),  -- Predefinita corridoio
    (21, 42, 30, 4, FALSE),
    (30, 30, 63, 1, FALSE);
COMMIT;

-- Configurazioni illuminazione
-- (Intensità 1-10, Temperatura Colore Kelvin, Consumo kW/h, Predefinita 1/0)
BEGIN;
INSERT INTO RegolazioneIlluminazione (CodIlluminazione, Intensita, TemperaturaColore, Consumo, Predefinita, IdLuce) 
VALUES (100, 2, 6000, 20, 1, 1);  -- Prima configurazione

INSERT INTO RegolazioneIlluminazione (Intensita, TemperaturaColore, Consumo, Predefinita, IdLuce)
VALUES 
    (2, 6000, 20, 1, 1),  -- Luce fredda intensa (predefinita)
    (1, 4000, 15, 0, 1),  -- Luce neutra soft
    (1, 5000, 30, 0, 2),  -- Faretto
    (1, 4000, 30, 1, 2),  -- Faretto (predefinita)
    (1, 4000, 25, 1, 3),  -- Lampada tavolo
    (2, 5000, 75, 0, 4),  -- Lampadario soggiorno
    (1, 4000, 15, 1, 5),  -- Faretto garage (predefinita)
    (2, 3000, 16, 1, 7),  -- Luce calda corridoio
    (1, 4000, 25, 1, 9),  -- Camera (predefinita)
    (2, 5000, 25, 1, 12), -- Applique
    (1, 3000, 15, 1, 13), -- Luce calda camera (predefinita)
    (2, 6000, 35, 0, 14), -- Luce fredda intensa
    (1, 5000, 15, 1, 15), -- Camera matrimoniale (predefinita)
    (2, 3000, 18, 1, 17), -- Faretto camera (predefinita)
    (1, 3000, 28, 1, 19); -- Studio (predefinita)
COMMIT;

-- Schedulazioni climatizzazione (Durata ore, Periodo ripetizione)
BEGIN;
INSERT INTO Schedule (Durata, CodClima, PeriodoRipetizione)
VALUES  
    (3, 50, 1),   -- 3 ore, ripeti ogni ora
    (2, 50, 0),   -- 2 ore, non ripetere
    (3, 51, 0),
    (12, 55, 1),  -- 12 ore, ripeti ogni ora
    (24, 50, 0),  -- 24 ore continuative
    (2, 53, 2),   -- 2 ore, ripeti ogni 2 ore
    (3, 54, 2);   -- 3 ore, ripeti ogni 2 ore
COMMIT;

SET FOREIGN_KEY_CHECKS = 1;

/* ========================================
   FINE POPOLAMENTO
   
   Database pronto per:
   - Testing procedure e trigger
   - Analisi con algoritmo Apriori
   - Ottimizzazione consumi energetici
   - Simulazione scenari di utilizzo
   ======================================== */