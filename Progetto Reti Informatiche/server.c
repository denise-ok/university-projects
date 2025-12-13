/* Librerie per socket e networking */
#include <arpa/inet.h>      /* htons(), htonl(), ntohl() */
#include <netinet/in.h>     /* struct sockaddr_in */
#include <sys/socket.h>     /* socket(), bind(), listen(), accept() */

/* Librerie standard */
#include <stdlib.h>         /* malloc(), exit() */
#include <string.h>         /* strcpy(), strcmp(), memset() */
#include <unistd.h>         /* close() */
#include <stdio.h>          /* printf() */

/* Gestione thread e segnali */
#include <pthread.h>        /* pthread_create(), pthread_mutex_* */
#include <signal.h>         /* signal(), SIG_IGN */

#include "info.h"

#define BUFFER_SIZE 1024
#define PORT 12345
#define N_DOMANDE 5
#define N_TEMI 2
#define SHOW_SCORE "show score"
#define END_QUIZ "end quiz"

/* Prototipi delle funzioni */
void menu();
void init();
bool verificaNickname(const char*);
bool QuizGiocabile(const char*, int);
void quiz(int, const char*, int);
void endQuiz(const char*, int);
void inviaPunteggi(int);
void *handler_client(void*);

/* Thread handler per la gestione dei client */
void *handler_client(void *arg) {
    int client_sock = *(int*)arg;
    free(arg);

    /* Incrementa il contatore dei giocatori */
    pthread_mutex_lock(&m_players);
    players++;
    pthread_mutex_unlock(&m_players);

    char nome[BUFFER_SIZE] = {0};
    char buffer[BUFFER_SIZE] = {0};

    /* Fase di registrazione: verifica e accetta il nickname */
    while (1) {
        memset(buffer, 0, sizeof(buffer));
        int ret = ricevo(buffer, client_sock);

        if (ret <= 0) {
            close(client_sock);
            pthread_exit(NULL);
        }

        buffer[strcspn(buffer, "\n")] = '\0';

        if (verificaNickname(buffer)) {
            strcpy(nome, buffer);
            strcpy(buffer, "ok");
            invio(buffer, client_sock);
            break;
        }

        strcpy(buffer, "no");
        invio(buffer, client_sock);
    }

    /* Loop principale del gioco */
    while (1) {
        memset(buffer, 0, BUFFER_SIZE);
        int ret = ricevo(buffer, client_sock);

        if (ret <= 0) {
            endQuiz(nome, client_sock);
            break;
        }

        /* Gestione comando END_QUIZ */
        if (strcmp(buffer, END_QUIZ) == 0) {
            endQuiz(nome, client_sock);
            break;
        }

        /* Gestione comando SHOW_SCORE */
        if (strcmp(buffer, SHOW_SCORE) == 0) {
            inviaPunteggi(client_sock);
            continue;
        }

        /* Gestione selezione tema */
        int tema_scelto = atoi(buffer) - 1;

        if (!QuizGiocabile(nome, tema_scelto)) {
            strcpy(buffer, "Quiz già giocato. Riprova: ");
            invio(buffer, client_sock);
            continue;
        }

        strcpy(buffer, "Inizia Quiz");
        invio(buffer, client_sock);
        init();

        quiz(client_sock, nome, tema_scelto);

        /* Marca il quiz come completato */
        pthread_mutex_lock(&m_classifica);
        struct Utente *u = classifica;
        while (u != NULL) {
            if (strcmp(u->nickname, nome) == 0 && u->quiz->tema == tema_scelto) {
                u->quiz->finish = true;
                break;
            }
            u = u->next;
        }
        pthread_mutex_unlock(&m_classifica);
        init();
    }

    return NULL;
}

int main() {
    int server_fd, *client_fd;
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_len = sizeof(client_addr);
    pthread_t tid;

    signal(SIGPIPE, SIG_IGN);
    inizializza();

    /* Creazione del socket */
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
        perror("Errore nella creazione del socket");
        exit(EXIT_FAILURE);
    }

    /* Configurazione indirizzo server */
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(PORT);
    server_addr.sin_addr.s_addr = INADDR_ANY;

    /* Binding del socket */
    if (bind(server_fd, (struct sockaddr*)&server_addr, sizeof(server_addr)) == -1) {
        perror("Bind failed");
        close(server_fd);
        exit(EXIT_FAILURE);
    }

    /* Listen */
    if (listen(server_fd, 3) == -1) {
        perror("Listen failed");
        close(server_fd);
        exit(EXIT_FAILURE);
    }

    menu();

    /* Loop principale: accetta nuove connessioni */
    while (1) {
        client_fd = (int*)malloc(sizeof(int));
        *client_fd = accept(server_fd, (struct sockaddr*)&client_addr, &client_len);

        if (*client_fd == -1) {
            perror("Accept failed");
            free(client_fd);
            continue;
        }

        pthread_create(&tid, NULL, handler_client, client_fd);
    }

    close(server_fd);
    return 0;
}

/* Mostra il menu iniziale del server */
void menu() {
    system("clear");
    printf("Trivia Quiz\n");
    stampaPiu();
    printf("Temi:\n1-Scienze\n2-Storia\n");
    stampaPiu();
    stampaPartecipanti();
}

/* Aggiorna la visualizzazione con tutte le informazioni */
void init() {
    menu();
    for (int i = 0; i < N_TEMI; i++) {
        stampaPerTema(i);
    }
    for (int i = 0; i < N_TEMI; i++) {
        terminatoT(i);
    }
    printf("------\n");
}

/* Verifica se il nickname è valido e lo inserisce nel database */
bool verificaNickname(const char *name) {
    pthread_mutex_lock(&m_database);
    
    struct Utente *u = database;
    while (u != NULL) {
        if (strcmp(u->nickname, name) == 0) {
            pthread_mutex_unlock(&m_database);
            return false;
        }
        u = u->next;
    }

    /* Nickname valido: inserisce nel database */
    inserisci(&database, name);
    pthread_mutex_unlock(&m_database);
    init();
    return true;
}

/* Verifica se l'utente può giocare al tema specificato */
bool QuizGiocabile(const char *name, int tema) {
    pthread_mutex_lock(&m_classifica);

    struct Utente *temp = classifica;
    while (temp != NULL) {
        if (strcmp(temp->nickname, name) == 0 && temp->quiz->tema == tema) {
            /* Tema già giocato */
            pthread_mutex_unlock(&m_classifica);
            return false;
        }
        temp = temp->next;
    }

    /* Tema non ancora giocato: inserisce nella classifica */
    struct Utente *nuovo = alloca_nuovo_nodo(name);
    nuovo->quiz->tema = tema;
    inserisciOrdinato(&classifica, nuovo);
    pthread_mutex_unlock(&m_classifica);
    return true;
}

/* Gestisce il quiz: invia domande e valuta risposte */
void quiz(int client_sock, const char *nome, int tema) {
    char domande[BUFFER_SIZE] = {0};
    char risposte[BUFFER_SIZE] = {0};
    char buffer[BUFFER_SIZE] = {0};

    int start_line = (tema == 1) ? 6 : 1;

    for (int i = 0; i < N_DOMANDE; i++) {
        int riga = start_line + i;

        /* Legge domanda e risposta dai file */
        leggi_riga_da_file("domande.txt", riga, domande);
        leggi_riga_da_file("risposte.txt", riga, risposte);

        if (strcmp(domande, "La riga non esiste") == 0 || 
            strcmp(risposte, "La riga non esiste") == 0) {
            perror("Errore nel prelievo da file");
            exit(EXIT_FAILURE);
        }

        /* Invia la domanda */
        invio(domande, client_sock);

        /* Riceve la risposta */
        memset(buffer, 0, BUFFER_SIZE);
        int ret = ricevo(buffer, client_sock);

        if (ret <= 0) {
            endQuiz(nome, client_sock);
            break;
        }

        /* Valuta la risposta */
        if (strcasecmp(buffer, risposte) == 0) {
            strcpy(buffer, "Risposta esatta");
            invio(buffer, client_sock);

            /* Aggiorna il punteggio */
            pthread_mutex_lock(&m_classifica);
            struct Utente *u = estraiUtente(&classifica, nome);
            struct Utente *s = estraiUtente(&classifica, nome);

            if (u->quiz->tema == tema) {
                u->quiz->score++;
            } else if (s != NULL && s->quiz->tema == tema) {
                s->quiz->score++;
            }

            inserisciOrdinato(&classifica, u);
            if (s != NULL) {
                inserisciOrdinato(&classifica, s);
            }
            pthread_mutex_unlock(&m_classifica);
            init();
        } else {
            strcpy(buffer, "Risposta sbagliata");
            invio(buffer, client_sock);
        }
    }
}

/* Gestisce la terminazione del quiz per un utente */
void endQuiz(const char *name, int client_sock) {
    /* Decrementa il contatore giocatori */
    pthread_mutex_lock(&m_players);
    players--;
    pthread_mutex_unlock(&m_players);

    /* Rimuove l'utente dal database */
    pthread_mutex_lock(&m_database);
    struct Utente *u = estraiUtente(&database, name);
    if (u != NULL) {
        free(u->quiz);
        free(u);
    }
    pthread_mutex_unlock(&m_database);

    /* Rimuove tutti i quiz giocati dall'utente */
    pthread_mutex_lock(&m_classifica);
    for (int i = 0; i < N_TEMI; i++) {
        struct Utente *n = estraiUtente(&classifica, name);
        if (n != NULL) {
            free(n->quiz);
            free(n);
        }
    }
    pthread_mutex_unlock(&m_classifica);

    init();
    close(client_sock);
    pthread_exit(NULL);
}

/* Invia i punteggi di tutti i giocatori per ciascun tema */
void inviaPunteggi(int client_sock) {
    pthread_mutex_lock(&m_classifica);

    for (int tema = 0; tema < N_TEMI; tema++) {
        struct Utente *u = classifica;
        
        while (u != NULL) {
            if (u->quiz->tema == tema) {
                char punteggio[BUFFER_SIZE];
                invio(u->nickname, client_sock);
                sprintf(punteggio, "%d", u->quiz->score);
                invio(punteggio, client_sock);
            }
            u = u->next;
        }
        
        invio("Fine", client_sock);
    }

    pthread_mutex_unlock(&m_classifica);
}