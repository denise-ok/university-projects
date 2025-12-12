#include <pthread.h>
#include <stdbool.h>

#define BUFFER_SIZE 1024

struct Partita{
    int tema; //tema scelto per la partita: nel mio caso indicherò con 0 'scienze' e con 1 'storia'
    bool finish; //indica se una partita è finita o meno 
    int score; //punti ottenuti giocando
    
};

struct Utente{
    char nickname[BUFFER_SIZE]; //nikname univoco con cui mi registro
    struct Partita *quiz; //quiz a cui l'utente ha partecipato
    struct Utente*next; //puntatore all'utente successivo
};



//lista utenti che hanno iniziato a giocare; 
//in questa lista lo stesso utente può essere presente più volte se ha giocato ha più temi
struct Utente* classifica; 

//lista che mi tiene conto di tutti i client registrati.
//Qui ciascun utente può essere presente una sola volta
struct Utente*database;

//ho bisogno dei semafori per l'accesso in mutua esclusione a ciascuna lista
pthread_mutex_t m_classifica;
pthread_mutex_t m_database;


int players; //contiene in numero di utenti connessi
pthread_mutex_t m_players; //semaforo per l'accesso in mutua esclusione alla variabile players


//funzione utilità per inizializzare tutti i mutex, le liste globali e la variabile globale players
void inizializza(){
    pthread_mutex_init(&m_classifica, NULL);
    pthread_mutex_init(&m_database, NULL);
    pthread_mutex_init(&m_players, NULL);
    database = NULL;
    classifica = NULL; 
    players = 0;
}

//funzione utilità che stampa una fila di + per limitare le varie sezioni
void stampaPiu(){
    printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
}


//funzione di utilità per allocare spazio di memoria necessario per creare un nuovo Utente
struct Utente* alloca_nuovo_nodo(const char* nickname){
    struct Utente* nuovoNodo = (struct Utente*)malloc(sizeof(struct Utente));
    if(nuovoNodo == NULL){
        perror("Errore di allocazione nuovo nodo \n");
        free(nuovoNodo);
        exit(EXIT_FAILURE);
    }
    strcpy(nuovoNodo->nickname, nickname);
    nuovoNodo->quiz = (struct Partita*)malloc(sizeof(struct Partita));
    if(nuovoNodo->quiz == NULL){
        perror("Errore di allocazione partita\n");
        free(nuovoNodo->quiz);
        exit(EXIT_FAILURE);

    }
    nuovoNodo->quiz->finish = false;
    nuovoNodo->quiz->score = 0;
    nuovoNodo->quiz->tema = -1;      
    nuovoNodo->next = NULL;
    return nuovoNodo;
}



//funzione di utilità per il semplice inserimento in testa a una lista
struct Utente* inserisci(struct Utente**testa, const char*nome){
    struct Utente* nuovoNodo = alloca_nuovo_nodo(nome);
    nuovoNodo->next = *testa;
    *testa = nuovoNodo;
    return nuovoNodo;  
   
}

//funzione di utilità per inserire in ordine decrescente di punteggio in una lista
void inserisciOrdinato(struct Utente** testa, struct Utente *u){
    if(*testa == NULL || u->quiz->score > (*testa)->quiz->score){  // lista vuota o nuovo utente con punteggio maggiore del primo utente
        u->next = *testa;
        *testa = u;
    }else{
        struct Utente* corrente = *testa;
        while(corrente->next != NULL && corrente->next->quiz->score >= u->quiz->score){
            corrente = corrente->next;
        }
        u->next = corrente->next;
        corrente->next = u;
    }
    
}


//funzione di utilità per estrarre un utente da una lista dato il nome
struct Utente* estraiUtente(struct Utente **testa, const char*nome){
    if(*testa == NULL){
        return NULL; //lista vuota
    }
    struct Utente *corrente = *testa; //puntatore al primo elemento
    struct Utente *precedente = NULL; //puntatore di appoggio che punterà all'elemento precedente (se c'è)
    
    while(corrente != NULL && strcmp(corrente->nickname, nome) != 0){
        precedente = corrente;
        corrente = corrente->next;
    }
    if(corrente == NULL){ //nodo non trovato
        return NULL;
    }
    if(precedente == NULL){//nodo da rimuovere è il primo in lista
        *testa = corrente->next;
    }else{
        //nodo interno o in coda
        precedente->next = corrente->next;
    }
    corrente->next = NULL;
    return corrente;
}


//funzione utilità per iniviare informazioni da server a client
void invio(const char* buffer, int sock){
    uint32_t net_message_length = 0;
    int message_length = strlen(buffer);
    net_message_length = htonl(message_length); //conversione da formato host a formato network
    send(sock, &net_message_length, sizeof(uint32_t),0); //invio la lunghezza del messaggio
    send(sock, buffer, message_length,0); //invio il messaggio effettivo

}

//funzione utilità per info da ricevere  dal client
int ricevo(char*buffer, int sock){
    uint32_t  message_length = 0;
    int bytes_read = recv(sock, &message_length, sizeof(message_length),0); //ricevo la lunghezza del messaggio
    message_length = ntohl(message_length); //conversione da formato network a formato host
    if(bytes_read <= 0){
        return bytes_read;
    }
    bytes_read = recv(sock,buffer, message_length, 0); //ricevo l'effettivo messaggio
    return bytes_read;
}


//funzione di utilità che, dato il nome del file, il numero di riga
//e un buffer, va a leggere nel file le informazioni che sono presenti alla riga specificata
//e le salva nel buffer
void leggi_riga_da_file(const char* filename, int n_riga, char* riga){
    FILE* file = fopen(filename, "r"); 
    if(!file){
        perror("Errore nell'apertura del file");
        exit(EXIT_FAILURE);
    }

    int temp = 1; //variabile di appoggio per indicare a quale riga siamo attualmente

    while(fgets(riga, BUFFER_SIZE,file) != NULL){ //prelevo sequenzialmente le righe dal file
        riga[strcspn(riga, "\n")]='\0';
        if(temp == n_riga){ //controllo se la riga appena prelevata è quella che voglio
            riga[strcspn(riga, "\n")] = '\0';  //rimuove il newline
            fclose(file);
           return;
        }
        temp++;
    }
    //in questo caso la riga indicata da n_riga non esiste
    fclose(file);
    strcpy(riga, "La riga non esiste");
}

//stampa il numero e i nickname degli utenti connessi
void stampaPartecipanti(){
    pthread_mutex_lock(&m_players);
    printf("Partecipanti(%d)\n", players);
    pthread_mutex_unlock(&m_players);
    
    pthread_mutex_lock(&m_database);
    struct Utente* u = database;
    while(u != NULL){
        printf("-%s\n", u->nickname);
        u = u->next;
    }
    pthread_mutex_unlock(&m_database);
}

//funzione che stampa i giocatori che stanno partecipando al quiz 
// con il loro attuale punteggio in base al tema
void stampaPerTema(int tema){
    tema++;
    printf("\nPunteggio tema %d\n", tema);
    tema--;
   
    pthread_mutex_lock(&m_classifica);
    struct Utente *u = classifica;
    while(u != NULL){
        if(u->quiz->tema == tema){
            printf("-%s %d \n", u->nickname, u->quiz->score);
        }
        u = u->next;
    }
    
    pthread_mutex_unlock(&m_classifica);  
  
}

//stampa la lista di utenti che ha finito di giocare al quiz di uno specifico tema
void terminatoT(int tema){
    tema++;
    printf("\nQuiz tema %d completato\n", tema);
    tema--;
    pthread_mutex_lock(&m_classifica);
    struct Utente* u = classifica;  
    while(u != NULL){
        if(u->quiz && u->quiz->tema == tema && u->quiz->finish){
            printf("-%s \n", u->nickname);
        }
        u = u->next;
    }
   
    pthread_mutex_unlock(&m_classifica);
    
}

