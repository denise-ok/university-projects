SET NAMES latin1;
SET FOREIGN_KEY_CHECKS = 0;

/* ========================================
   INIZIALIZZAZIONE DATABASE mySmartHome
   ======================================== */

BEGIN;
DROP DATABASE IF EXISTS `mySmartHome`;
CREATE DATABASE `mySmartHome`;
COMMIT;

USE `mySmartHome`;

/* ========================================
   AREA GENERALE
   Gestione utenti, account e struttura casa
   ======================================== */

CREATE TABLE `Utente` (
    `CodFiscale` VARCHAR(16) NOT NULL,
    `Nome` VARCHAR(50) NOT NULL,
    `Cognome` VARCHAR(50) NOT NULL,
    `Telefono` VARCHAR(10) NOT NULL,
    `DataNascita` DATE NOT NULL,
    
    PRIMARY KEY (`CodFiscale`)
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Documento` (
    `Numero` VARCHAR(50) NOT NULL,
    `Tipologia` VARCHAR(15) NOT NULL 
        CHECK (Tipologia IN ('CartaIdentita', 'Patente', 'Passaporto')),
    `EnteRilascio` VARCHAR(50) NOT NULL,
    `DataScadenza` DATE NOT NULL,
    `CodFiscale` VARCHAR(16) NOT NULL,

    PRIMARY KEY (`Numero`, `Tipologia`),
    FOREIGN KEY (`CodFiscale`) 
        REFERENCES `Utente`(`CodFiscale`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `DomandaSicurezza` (
    `IdDomanda` INT AUTO_INCREMENT NOT NULL,
    `Testo` VARCHAR(50) NOT NULL,

    PRIMARY KEY (`IdDomanda`)
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Account` (
    `NomeUtente` VARCHAR(50) NOT NULL,
    `Password` VARCHAR(50) NOT NULL,
    `DataIscrizione` DATE NOT NULL,
    `Risposta` VARCHAR(50) NOT NULL,
    `CodFiscale` VARCHAR(16) NOT NULL,
    `IdDomanda` INT NOT NULL,

    PRIMARY KEY (`NomeUtente`),
    FOREIGN KEY (`CodFiscale`) 
        REFERENCES `Utente`(`CodFiscale`) 
        ON DELETE CASCADE,
    FOREIGN KEY (`IdDomanda`) 
        REFERENCES `DomandaSicurezza`(`IdDomanda`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Stanza` (
    `IdStanza` INT AUTO_INCREMENT NOT NULL,
    `Nome` VARCHAR(30) NOT NULL,
    `Piano` VARCHAR(30) NOT NULL,
    `Lunghezza` FLOAT NOT NULL COMMENT 'Lunghezza in metri',
    `Larghezza` FLOAT NOT NULL COMMENT 'Larghezza in metri',
    `Altezza` FLOAT NOT NULL COMMENT 'Altezza in metri',
    `Dispersione` FLOAT NOT NULL COMMENT 'Coefficiente di dispersione termica',
    
    PRIMARY KEY (`IdStanza`)
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Finestra` (
    `IdFinestra` INT AUTO_INCREMENT NOT NULL,
    `Tipo` VARCHAR(13) NOT NULL 
        CHECK(Tipo IN ('Finestra', 'Portafinestra')),
    `Cardinale` VARCHAR(2) 
        CHECK(Cardinale IN ('N', 'NE', 'NW', 'S', 'SE', 'SW', 'E', 'W')),
    `IdStanza` INT NOT NULL,

    PRIMARY KEY (`IdFinestra`),
    FOREIGN KEY (`IdStanza`) 
        REFERENCES `Stanza`(`IdStanza`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Porta` (
    `IdPorta` INT AUTO_INCREMENT NOT NULL,
    `Interna` BOOLEAN COMMENT 'TRUE se porta interna, FALSE se esterna',
    `IdStanza` INT NOT NULL,

    PRIMARY KEY (`IdPorta`),
    FOREIGN KEY (`IdStanza`) 
        REFERENCES `Stanza`(`IdStanza`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Varco` (
    `IdPorta` INT NOT NULL,
    `IdStanza` INT NOT NULL,

    PRIMARY KEY (`IdPorta`, `IdStanza`),
    FOREIGN KEY (`IdPorta`) 
        REFERENCES `Porta`(`IdPorta`) 
        ON DELETE CASCADE,
    FOREIGN KEY (`IdStanza`) 
        REFERENCES `Stanza`(`IdStanza`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

/* ========================================
   AREA DISPOSITIVI
   Gestione smart plug e dispositivi IoT
   ======================================== */

CREATE TABLE `SmartPlug` (
    `Codice` INT AUTO_INCREMENT NOT NULL,
    `Stato` BOOLEAN NOT NULL COMMENT 'TRUE se accesa, FALSE se spenta',
    `IdStanza` INT NOT NULL,

    PRIMARY KEY (`Codice`), 
    FOREIGN KEY (`IdStanza`) 
        REFERENCES `Stanza`(`IdStanza`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Dispositivo` (
    `IdDispositivo` INT AUTO_INCREMENT NOT NULL, 
    `Nome` VARCHAR(50) NOT NULL,
    `TipoConsumo` VARCHAR(10) NOT NULL 
        CHECK(TipoConsumo IN ('Fisso', 'Variabile')),
    `Codice` INT NOT NULL,

    PRIMARY KEY (`IdDispositivo`), 
    FOREIGN KEY (`Codice`) 
        REFERENCES `SmartPlug`(`Codice`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Potenza` (
    `IdLivelloPotenza` INT AUTO_INCREMENT NOT NULL, 
    `Descrizione` INT NOT NULL COMMENT 'Livello di potenza (1, 2, 3, ...)',
    `ConsumoPerTempo` FLOAT NOT NULL COMMENT 'Consumo in kW/h',
    `IdDispositivo` INT NOT NULL,

    PRIMARY KEY (`IdLivelloPotenza`), 
    FOREIGN KEY (`IdDispositivo`) 
        REFERENCES `Dispositivo`(`IdDispositivo`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Programma` (
    `Codice` INT AUTO_INCREMENT NOT NULL, 
    `Nome` VARCHAR(20) NOT NULL,
    `DurataMedia` INT NOT NULL COMMENT 'Durata in secondi',
    `ConsumoMedio` FLOAT NOT NULL COMMENT 'Consumo medio in kW/h',
    `IdDispositivo` INT NOT NULL,

    PRIMARY KEY (`Codice`), 
    FOREIGN KEY (`IdDispositivo`) 
        REFERENCES `Dispositivo`(`IdDispositivo`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `RegolazioneDispositivo` (
    `CodRegolazione` INT AUTO_INCREMENT NOT NULL, 
    `IdDispositivo` INT NOT NULL,
    `Codice` INT COMMENT 'FK a Programma (per dispositivi a consumo fisso)',
    `IdLivelloPotenza` INT COMMENT 'FK a Potenza (per dispositivi a consumo variabile)',

    PRIMARY KEY (`CodRegolazione`), 
    FOREIGN KEY (`IdDispositivo`) 
        REFERENCES `Dispositivo`(`IdDispositivo`) 
        ON DELETE CASCADE,
    FOREIGN KEY (`Codice`) 
        REFERENCES `Programma`(`Codice`) 
        ON DELETE CASCADE,
    FOREIGN KEY (`IdLivelloPotenza`) 
        REFERENCES `Potenza`(`IdLivelloPotenza`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

/* ========================================
   AREA ENERGIA
   Gestione produzione e consumo energetico
   ======================================== */

CREATE TABLE `FasciaOraria` (
    `IdFascia` INT AUTO_INCREMENT NOT NULL,
    `Nome` VARCHAR(30) NOT NULL,
    `Inizio` TIME NOT NULL, 
    `Fine` TIME NOT NULL, 
    `PrezzoRin` FLOAT NOT NULL 
        CHECK(PrezzoRin > 0) 
        COMMENT 'Prezzo reimmissione in rete (€/kWh)',
    `CostoNonRin` FLOAT NOT NULL 
        CHECK(CostoNonRin > 0) 
        COMMENT 'Costo prelievo dalla rete (€/kWh)',
    `SceltaUtilizzo` VARCHAR(50) NOT NULL 
        CHECK(`SceltaUtilizzo` IN ('UtilizzareEnergiaAutoprodotta', 'ReimmettereNellaRete')),

    PRIMARY KEY (`IdFascia`) 
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Pannello` (
    `IdPannello` INT AUTO_INCREMENT NOT NULL, 
    `Superficie` FLOAT NOT NULL 
        CHECK(Superficie > 0) 
        COMMENT 'Superficie in m²',

    PRIMARY KEY (`IdPannello`)
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `EnergiaProdotta` (
    `IdEnergia` INT AUTO_INCREMENT NOT NULL, 
    `Timestamp` DATETIME NOT NULL,
    `Irraggiamento` FLOAT NOT NULL 
        CHECK(Irraggiamento >= 0) 
        COMMENT 'Irraggiamento solare in kW/m²', 
    `Quantita` FLOAT NOT NULL 
        CHECK(Quantita >= 0) 
        COMMENT 'Energia prodotta in kWh (calcolata da Irraggiamento × Superficie)',
    `IdPannello` INT NOT NULL,
    `IdFascia` INT NOT NULL,

    PRIMARY KEY (`IdEnergia`),
    FOREIGN KEY (`IdPannello`) 
        REFERENCES `Pannello`(`IdPannello`) 
        ON DELETE CASCADE,
    FOREIGN KEY (`IdFascia`) 
        REFERENCES `FasciaOraria`(`IdFascia`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

/* ========================================
   AREA COMFORT
   Gestione climatizzazione e illuminazione
   ======================================== */

CREATE TABLE `RegistroTemperatura` (
    `IdRegistroTemperatura` INT AUTO_INCREMENT NOT NULL,
    `Timestamp` DATETIME NOT NULL,
    `TemperaturaOut` FLOAT NOT NULL COMMENT 'Temperatura esterna in °C',
    `TemperaturaIn` FLOAT NOT NULL COMMENT 'Temperatura interna in °C',
    `Efficienza` FLOAT 
        CHECK(Efficienza >= 0) 
        COMMENT 'Coefficiente di efficienza energetica',
    `IdStanza` INT NOT NULL,

    PRIMARY KEY (`IdRegistroTemperatura`), 
    FOREIGN KEY (`IdStanza`) 
        REFERENCES `Stanza`(`IdStanza`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Condizionatore` (
    `IdCondizionatore` INT AUTO_INCREMENT NOT NULL,
    `Nome` VARCHAR(50),
    `IdStanza` INT NOT NULL,

    PRIMARY KEY (`IdCondizionatore`), 
    FOREIGN KEY (`IdStanza`) 
        REFERENCES `Stanza`(`IdStanza`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Luce` (
    `IdLuce` INT AUTO_INCREMENT NOT NULL,
    `Nome` VARCHAR(50) NOT NULL,
    `IdStanza` INT NOT NULL,

    PRIMARY KEY (`IdLuce`), 
    FOREIGN KEY (`IdStanza`) 
        REFERENCES `Stanza`(`IdStanza`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `RegolazioneClima` (
    `CodClima` INT AUTO_INCREMENT NOT NULL, 
    `Temperatura` FLOAT NOT NULL 
        CHECK (Temperatura BETWEEN 10 AND 30) 
        COMMENT 'Temperatura target in °C',
    `Umidita` FLOAT NOT NULL 
        CHECK (Umidita BETWEEN 30 AND 70) 
        COMMENT 'Umidità target in %',
    `Predefinita` BOOLEAN NOT NULL DEFAULT FALSE 
        COMMENT 'TRUE se è una configurazione predefinita',
    `Consumo` FLOAT NOT NULL COMMENT 'Consumo stimato in kW/h',
    `IdCondizionatore` INT NOT NULL,

    PRIMARY KEY (`CodClima`), 
    FOREIGN KEY (`IdCondizionatore`) 
        REFERENCES `Condizionatore`(`IdCondizionatore`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `RegolazioneIlluminazione` (
    `CodIlluminazione` INT AUTO_INCREMENT NOT NULL, 
    `Intensita` FLOAT NOT NULL COMMENT 'Intensità luminosa (1-10)',
    `TemperaturaColore` FLOAT NOT NULL COMMENT 'Temperatura colore in Kelvin',
    `Predefinita` BOOLEAN NOT NULL DEFAULT FALSE 
        COMMENT 'TRUE se è una configurazione predefinita',
    `Consumo` FLOAT NOT NULL COMMENT 'Consumo in kW/h',
    `IdLuce` INT NOT NULL,

    PRIMARY KEY (`CodIlluminazione`), 
    FOREIGN KEY (`IdLuce`) 
        REFERENCES `Luce`(`IdLuce`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Schedule` (
    `IdSchedule` INT AUTO_INCREMENT NOT NULL,
    `Durata` INT NOT NULL 
        CHECK (Durata BETWEEN 1 AND 24) 
        COMMENT 'Durata in ore',
    `PeriodoRipetizione` INT 
        COMMENT 'Periodo di ripetizione in ore (opzionale)',
    `CodClima` INT NOT NULL, 

    PRIMARY KEY (`IdSchedule`), 
    FOREIGN KEY (`CodClima`) 
        REFERENCES `RegolazioneClima`(`CodClima`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Interazione` (
    `IdInterazione` INT AUTO_INCREMENT NOT NULL,
    `Inizio` TIMESTAMP NOT NULL,
    `Fine` TIMESTAMP NOT NULL,
    `ComandoVocale` BOOLEAN NOT NULL DEFAULT FALSE 
        COMMENT 'TRUE se comando vocale, FALSE altrimenti',
    `EnergiaConsumata` FLOAT 
        CHECK(EnergiaConsumata >= 0) 
        COMMENT 'Energia consumata in kWh (ridondanza calcolata)',
    `IdFascia` INT,
    `NomeUtente` VARCHAR(50) NOT NULL,
    `IdSchedule` INT, 
    `CodRegolazioneDispositivo` INT,
    `CodRegolazioneClima` INT,
    `CodRegolazioneIlluminazione` INT, 

    PRIMARY KEY (`IdInterazione`), 
    FOREIGN KEY (`IdFascia`) 
        REFERENCES `FasciaOraria`(`IdFascia`) 
        ON DELETE CASCADE,
    FOREIGN KEY (`NomeUtente`) 
        REFERENCES `Account`(`NomeUtente`) 
        ON DELETE CASCADE,
    FOREIGN KEY (`IdSchedule`) 
        REFERENCES `Schedule`(`IdSchedule`) 
        ON DELETE CASCADE,
    FOREIGN KEY (`CodRegolazioneDispositivo`) 
        REFERENCES `RegolazioneDispositivo`(`CodRegolazione`) 
        ON DELETE CASCADE,
    FOREIGN KEY (`CodRegolazioneClima`) 
        REFERENCES `RegolazioneClima`(`CodClima`) 
        ON DELETE CASCADE,
    FOREIGN KEY (`CodRegolazioneIlluminazione`) 
        REFERENCES `RegolazioneIlluminazione`(`CodIlluminazione`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

CREATE TABLE `Notifica` (
    `IdNotifica` INT AUTO_INCREMENT NOT NULL,
    `Invio` TIMESTAMP NOT NULL,
    `Risposta` BOOLEAN NOT NULL DEFAULT FALSE 
        COMMENT 'TRUE se l\'utente ha accettato, FALSE altrimenti', 
    `Codice` INT NOT NULL COMMENT 'FK a Programma', 
    `NomeUtente` VARCHAR(50) NOT NULL,

    PRIMARY KEY (`IdNotifica`),
    FOREIGN KEY (`Codice`) 
        REFERENCES `Programma`(`Codice`) 
        ON DELETE CASCADE,
    FOREIGN KEY (`NomeUtente`) 
        REFERENCES `Account`(`NomeUtente`) 
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;

SET FOREIGN_KEY_CHECKS = 1;