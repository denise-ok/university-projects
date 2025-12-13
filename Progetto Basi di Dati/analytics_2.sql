USE `mySmartHome`;

/* ========================================
   ANALYTICS: Ottimizzazione consumi energetici
   
   Obiettivo: Identificare le fasce orarie con maggiore energia disponibile
   
   Formula: Energia Disponibile = Energia Prodotta - Energia Consumata
   
   Interpretazione risultati:
   - Valori POSITIVI: Surplus energetico (ottimale per utilizzo dispositivi)
   - Valori NEGATIVI: Deficit energetico (necessario prelievo dalla rete)
   
   Utilizzo: Programmare l'uso di dispositivi energivori nelle fasce
             con maggiore disponibilità per massimizzare l'autoconsumo
             e ridurre i costi in bolletta
   ======================================== */

SELECT 
    (P.EnergiaProdotta - U.EnergiaConsumata) AS EnergiaDisponibile, 
    P.Nome AS FasciaOraria
FROM 
    /* ====================
       Subquery 1: Energia prodotta per fascia oraria
       Aggrega la produzione dai pannelli solari
       ==================== */
    (
        SELECT 
            SUM(e.Quantita) AS EnergiaProdotta, 
            f.IdFascia, 
            f.Nome
        FROM EnergiaProdotta e
            INNER JOIN FasciaOraria f 
                ON f.IdFascia = e.IdFascia
        GROUP BY f.IdFascia, f.Nome
    ) AS P
    
    INNER JOIN
    
    /* ====================
       Subquery 2: Energia consumata per fascia oraria
       Aggrega i consumi dalle interazioni degli utenti
       ==================== */
    (
        SELECT 
            SUM(i.EnergiaConsumata) AS EnergiaConsumata, 
            f.IdFascia
        FROM Interazione i
            INNER JOIN FasciaOraria f 
                ON f.IdFascia = i.IdFascia 
        GROUP BY f.IdFascia
    ) AS U
    
    /* Join sullo stesso IdFascia per confrontare produzione e consumo */
    ON P.IdFascia = U.IdFascia

/* Ordina per energia disponibile decrescente: 
   Le fasce in cima sono le più vantaggiose per l'utilizzo */
ORDER BY EnergiaDisponibile DESC;

/* ========================================
   SUGGERIMENTI PRATICI:
   
   1. Le fasce con energia disponibile > 0 sono ideali per:
      - Avviare lavatrici, lavastoviglie
      - Caricare veicoli elettrici
      - Utilizzare elettrodomestici ad alto consumo
   
   2. Le fasce con energia disponibile < 0 indicano:
      - Necessità di prelievo dalla rete
      - Costi aggiuntivi in bolletta
      - Opportunità di ottimizzazione
   
   3. Per massimizzare il risparmio:
      - Programmare dispositivi nelle fasce positive
      - Evitare utilizzi intensivi nelle fasce negative
      - Considerare sistemi di accumulo per le ore notturne
   ======================================== */