/* Librerie per socket e networking */
#include <arpa/inet.h>      /* inet_pton(), htons() */
#include <sys/socket.h>     /* socket(), connect(), send(), recv() */
#include <netinet/in.h>     /* struct sockaddr_in */

/* Librerie standard */
#include <stdlib.h>         /* malloc(), exit(), atoi() */
#include <string.h>         /* strcpy(), strcmp(), memset() */
#include <unistd.h>         /* close() */
#include <stdio.h>          /* printf(), fgets() */
#include <stdbool.h>        /* bool, true, false */

/* Gestione segnali ed errori */
#include <signal.h>         /* signal(), SIGPIPE */
#include <errno.h>          /* errno, EPIPE, ECONNRESET */

#define BUFFER_SIZE 1024
#define IP_SERVER "127.0.0.1"
#define N_DOMANDE 5
#define N_TEMI 2
#define SHOW_SCORE "show score"
#define END_QUIZ "end quiz"

/* Prototipi delle funzioni */
bool menu();
char* menuGioco();
void handle_sigpipe(int);
void mostraPunteggi(int);
void invio(const char*, int);
void ricevo(char*, int);

/* Gestisce il segnale SIGPIPE */
void handle_sigpipe(int sig) {
    write(STDERR_FILENO, "Il server si è disconnesso...\n", 31);
}

int main(int argc, char **argv) {
    if (argc != 2) {
        printf("Uso: ./client <porta>\n");
        exit(EXIT_FAILURE);
    }

    int sock;
    struct sockaddr_in serv_addr;
    char buffer[BUFFER_SIZE] = {0};

    signal(SIGPIPE, handle_sigpipe);

    /* Menu iniziale */
    if (!menu()) {
        return 0;
    }

    /* Creazione del socket */
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
        printf("Errore nella creazione del socket\n");
        return -1;
    }

    /* Configurazione indirizzo server */
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(atoi(argv[1]));

    if (inet_pton(AF_INET, IP_SERVER, &serv_addr.sin_addr) == -1) {
        printf("Conversione indirizzo IP non valida\n");
        return -1;
    }

    /* Connessione al server */
    if (connect(sock, (struct sockaddr*)&serv_addr, sizeof(serv_addr)) == -1) {
        printf("Errore di connessione\n");
        close(sock);
        exit(EXIT_FAILURE);
    }

    printf("\nTrivia Quiz\n");
    printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");

    /* Fase di registrazione: scelta del nickname */
    printf("Scegli un nickname (deve essere univoco): \n");
    while (1) {
        memset(buffer, 0, BUFFER_SIZE);

        fgets(buffer, BUFFER_SIZE, stdin);
        buffer[strcspn(buffer, "\n")] = '\0';

        if (strlen(buffer) < 1 || strcmp(buffer, " ") == 0) {
            printf("Nickname non valido. Riprova: \n");
            continue;
        }

        invio(buffer, sock);

        memset(buffer, 0, BUFFER_SIZE);
        ricevo(buffer, sock);

        if (strcmp(buffer, "ok") == 0) {
            break;
        }

        printf("Nickname esistente, riprova: \n");
    }

    /* Loop principale del gioco */
    while (1) {
        char buffer[BUFFER_SIZE] = {0};
        printf("\n");

        strcpy(buffer, menuGioco());
        invio(buffer, sock);

        /* Gestione comando SHOW_SCORE */
        if (strcasecmp(buffer, SHOW_SCORE) == 0) {
            mostraPunteggi(sock);
            continue;
        }

        /* Gestione comando END_QUIZ */
        if (strcasecmp(buffer, END_QUIZ) == 0) {
            break;
        }

        /* Tema selezionato */
        int tema = atoi(buffer) - 1;

        memset(buffer, 0, BUFFER_SIZE);
        ricevo(buffer, sock);

        if (strcmp(buffer, "Quiz già giocato. Riprova: ") == 0) {
            printf("%s\n", buffer);
            continue;
        }

        /* Inizia il quiz */
        const char *nome_tema = (tema == 0) ? "scienze" : "storia";
        printf("\nQuiz-%s\n", nome_tema);
        printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");

        /* Risponde alle domande */
        for (int f = 0; f < N_DOMANDE; f++) {
            memset(buffer, 0, BUFFER_SIZE);
            ricevo(buffer, sock);
            printf("%s\n", buffer);

            /* Inserimento risposta */
            printf("\nRisposta: ");
            while (1) {
                memset(buffer, 0, BUFFER_SIZE);
                fgets(buffer, BUFFER_SIZE, stdin);
                buffer[strcspn(buffer, "\n")] = '\0';

                if (strcmp(buffer, " ") != 0) {
                    break;
                }
                printf("Risposta non valida. Riprova: \n");
            }

            invio(buffer, sock);

            /* Riceve feedback dal server */
            memset(buffer, 0, BUFFER_SIZE);
            ricevo(buffer, sock);
            printf("%s\n\n", buffer);
        }
    }

    close(sock);
    return 0;
}

/* Menu iniziale: scelta tra iniziare il gioco o uscire */
bool menu() {
    system("clear");
    char buffer[BUFFER_SIZE] = {0};

    printf("Trivia Quiz\n");
    printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
    printf("Menù:\n1-Comincia una sessione di Trivia\n2-Esci\n");
    printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
    printf("La tua scelta: ");

    while (1) {
        fgets(buffer, BUFFER_SIZE, stdin);
        buffer[strcspn(buffer, "\n")] = '\0';

        if (strcmp(buffer, "1") == 0) {
            return true;
        }
        if (strcmp(buffer, "2") == 0) {
            return false;
        }

        printf("Opzione non valida. Riprovare: ");
        memset(buffer, 0, BUFFER_SIZE);
    }
}

/* Menu di gioco: scelta del tema o comandi speciali */
char* menuGioco() {
    static char buffer[BUFFER_SIZE] = {0};

    printf("Quiz disponibili\n");
    printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
    printf("1-scienze\n2-storia\n");
    printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
    printf("('%s' per mostrare punteggi, '%s' per terminare il gioco)\n", 
           SHOW_SCORE, END_QUIZ);
    printf("\nLa tua scelta è: ");

    while (1) {
        fgets(buffer, BUFFER_SIZE, stdin);
        buffer[strcspn(buffer, "\n")] = '\0';

        if (strcasecmp(buffer, END_QUIZ) == 0 || 
            strcasecmp(buffer, SHOW_SCORE) == 0 ||
            strcmp(buffer, "1") == 0 || 
            strcmp(buffer, "2") == 0) {
            break;
        }

        printf("Opzione non valida. Riprovare: ");
        memset(buffer, 0, BUFFER_SIZE);
    }

    return buffer;
}

/* Riceve e mostra i punteggi dal server */
void mostraPunteggi(int sock) {
    for (int tema = 1; tema <= N_TEMI; tema++) {
        printf("Classifica tema %d\n", tema);

        while (1) {
            char nome[BUFFER_SIZE] = {0};
            char punteggio[BUFFER_SIZE] = {0};

            ricevo(nome, sock);

            if (strcmp(nome, "Fine") == 0) {
                break;
            }

            ricevo(punteggio, sock);
            int score = atoi(punteggio);
            printf("-%s %d\n", nome, score);
        }
    }
}

/* Invia un messaggio al server */
void invio(const char *buffer, int sock) {
    uint32_t message_length = strlen(buffer);
    uint32_t net_message_length = htonl(message_length);

    int ret = send(sock, &net_message_length, sizeof(uint32_t), 0);
    if (ret == -1 && (errno == EPIPE || errno == ECONNRESET)) {
        close(sock);
        return;
    }

    ret = send(sock, buffer, message_length, 0);
    if (ret == -1 && (errno == EPIPE || errno == ECONNRESET)) {
        close(sock);
        return;
    }
}

/* Riceve un messaggio dal server */
void ricevo(char *buffer, int sock) {
    uint32_t message_length = 0;
    ssize_t bytes_read = recv(sock, &message_length, sizeof(message_length), 0);

    if (bytes_read == -1) {
        close(sock);
        exit(EXIT_FAILURE);
    }

    message_length = ntohl(message_length);
    bytes_read = recv(sock, buffer, message_length, 0);

    if (bytes_read == -1) {
        close(sock);
        exit(EXIT_FAILURE);
    }
}