#ifndef INFO_H
#define INFO_H

/* Librerie per thread e networking */
#include <pthread.h>        /* pthread_mutex_t */
#include <arpa/inet.h>      /* htonl(), ntohl() */
#include <sys/socket.h>     /* send(), recv() */

/* Librerie standard */
#include <stdbool.h>        /* bool */
#include <stdlib.h>         /* malloc(), exit() */
#include <string.h>         /* strcpy(), strcmp() */
#include <stdio.h>          /* printf(), fopen() */
#include <unistd.h>         /* close() */

#define BUFFER_SIZE 1024

/* Struttura che rappresenta una partita */
struct Partita {
    int tema;       /* 0 = scienze, 1 = storia */
    bool finish;    /* Indica se la partita è terminata */
    int score;      /* Punteggio ottenuto */
};

/* Struttura che rappresenta un utente */
struct Utente {
    char nickname[BUFFER_SIZE];  /* Nickname univoco */
    struct Partita *quiz;        /* Quiz giocati dall'utente */
    struct Utente *next;         /* Puntatore al prossimo utente */
};

/* Variabili globali */
struct Utente *classifica;  /* Lista utenti con punteggi (ordinata) */
struct Utente *database;    /* Lista di tutti i client registrati */
int players;                /* Numero di utenti connessi */

/* Mutex per l'accesso in mutua esclusione */
pthread_mutex_t m_classifica;
pthread_mutex_t m_database;
pthread_mutex_t m_players;

/* ========== Funzioni di inizializzazione ========== */

/* Inizializza mutex e variabili globali */
void inizializza() {
    pthread_mutex_init(&m_classifica, NULL);
    pthread_mutex_init(&m_database, NULL);
    pthread_mutex_init(&m_players, NULL);
    database = NULL;
    classifica = NULL;
    players = 0;
}

/* Stampa una linea di separazione */
void stampaPiu() {
    printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
}

/* ========== Funzioni per la gestione degli utenti ========== */

/* Alloca e inizializza un nuovo nodo utente */
struct Utente* alloca_nuovo_nodo(const char *nickname) {
    struct Utente *nuovoNodo = (struct Utente*)malloc(sizeof(struct Utente));
    if (nuovoNodo == NULL) {
        perror("Errore di allocazione nuovo nodo");
        exit(EXIT_FAILURE);
    }

    strcpy(nuovoNodo->nickname, nickname);
    
    nuovoNodo->quiz = (struct Partita*)malloc(sizeof(struct Partita));
    if (nuovoNodo->quiz == NULL) {
        perror("Errore di allocazione partita");
        free(nuovoNodo);
        exit(EXIT_FAILURE);
    }

    nuovoNodo->quiz->finish = false;
    nuovoNodo->quiz->score = 0;
    nuovoNodo->quiz->tema = -1;
    nuovoNodo->next = NULL;

    return nuovoNodo;
}

/* Inserisce un utente in testa alla lista */
struct Utente* inserisci(struct Utente **testa, const char *nome) {
    struct Utente *nuovoNodo = alloca_nuovo_nodo(nome);
    nuovoNodo->next = *testa;
    *testa = nuovoNodo;
    return nuovoNodo;
}

/* Inserisce un utente in ordine decrescente di punteggio */
void inserisciOrdinato(struct Utente **testa, struct Utente *u) {
    if (*testa == NULL || u->quiz->score > (*testa)->quiz->score) {
        u->next = *testa;
        *testa = u;
        return;
    }

    struct Utente *corrente = *testa;
    while (corrente->next != NULL && corrente->next->quiz->score >= u->quiz->score) {
        corrente = corrente->next;
    }

    u->next = corrente->next;
    corrente->next = u;
}

/* Estrae un utente dalla lista dato il nome */
struct Utente* estraiUtente(struct Utente **testa, const char *nome) {
    if (*testa == NULL) {
        return NULL;
    }

    struct Utente *corrente = *testa;
    struct Utente *precedente = NULL;

    /* Cerca l'utente nella lista */
    while (corrente != NULL && strcmp(corrente->nickname, nome) != 0) {
        precedente = corrente;
        corrente = corrente->next;
    }

    if (corrente == NULL) {
        return NULL;
    }

    /* Rimuove il nodo dalla lista */
    if (precedente == NULL) {
        *testa = corrente->next;
    } else {
        precedente->next = corrente->next;
    }

    corrente->next = NULL;
    return corrente;
}

/* ========== Funzioni di comunicazione ========== */

/* Invia un messaggio al socket specificato */
void invio(const char *buffer, int sock) {
    uint32_t message_length = strlen(buffer);
    uint32_t net_message_length = htonl(message_length);

    send(sock, &net_message_length, sizeof(uint32_t), 0);
    send(sock, buffer, message_length, 0);
}

/* Riceve un messaggio dal socket specificato */
int ricevo(char *buffer, int sock) {
    uint32_t message_length = 0;
    int bytes_read = recv(sock, &message_length, sizeof(message_length), 0);

    if (bytes_read <= 0) {
        return bytes_read;
    }

    message_length = ntohl(message_length);
    bytes_read = recv(sock, buffer, message_length, 0);
    return bytes_read;
}

/* ========== Funzioni per la lettura da file ========== */

/* Legge una riga specifica da un file */
void leggi_riga_da_file(const char *filename, int n_riga, char *riga) {
    FILE *file = fopen(filename, "r");
    if (!file) {
        perror("Errore nell'apertura del file");
        exit(EXIT_FAILURE);
    }

    int riga_corrente = 1;

    while (fgets(riga, BUFFER_SIZE, file) != NULL) {
        riga[strcspn(riga, "\n")] = '\0';

        if (riga_corrente == n_riga) {
            fclose(file);
            return;
        }
        riga_corrente++;
    }

    /* Riga non trovata */
    fclose(file);
    strcpy(riga, "La riga non esiste");
}

/* ========== Funzioni di visualizzazione ========== */

/* Stampa il numero e i nickname degli utenti connessi */
void stampaPartecipanti() {
    pthread_mutex_lock(&m_players);
    printf("Partecipanti(%d)\n", players);
    pthread_mutex_unlock(&m_players);

    pthread_mutex_lock(&m_database);
    struct Utente *u = database;
    while (u != NULL) {
        printf("-%s\n", u->nickname);
        u = u->next;
    }
    pthread_mutex_unlock(&m_database);
}

/* Stampa i punteggi per un tema specifico */
void stampaPerTema(int tema) {
    printf("\nPunteggio tema %d\n", tema + 1);

    pthread_mutex_lock(&m_classifica);
    struct Utente *u = classifica;
    while (u != NULL) {
        if (u->quiz->tema == tema) {
            printf("-%s %d\n", u->nickname, u->quiz->score);
        }
        u = u->next;
    }
    pthread_mutex_unlock(&m_classifica);
}

/* Stampa gli utenti che hanno completato un tema specifico */
void terminatoT(int tema) {
    printf("\nQuiz tema %d completato\n", tema + 1);

    pthread_mutex_lock(&m_classifica);
    struct Utente *u = classifica;
    while (u != NULL) {
        if (u->quiz && u->quiz->tema == tema && u->quiz->finish) {
            printf("-%s\n", u->nickname);
        }
        u = u->next;
    }
    pthread_mutex_unlock(&m_classifica);
}

#endif /* INFO_H */