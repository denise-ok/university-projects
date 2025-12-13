#include <arpa/inet.h>
#include <netinet/in.h>

#include <sys/types.h>
#include <sys/socket.h>


#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
#include <pthread.h>
#include <signal.h>

#include "info.h"

#define BUFFER_SIZE 1024
#define PORT 12345

#define N_DOMANDE 5
#define N_TEMI 2
#define SHOW_SCORE "show score"
#define END_QUIZ "end quiz"


void menu(); //menu iniziale del server
void init(); //funzione che aggiorna la shell con le varie informazioni sui giocatori

bool verificaNickname(const char*); //funzione che determina la validità del nickname inserito 
bool QuizGiocabile(const char*,int); //funzione che determina se l'utente può giocare a un determinato tema

void quiz(int, const char*,int); //funzione che si occupa dello scambio di informazioni con il client duerante il gioco e di eventuali errori

void endQuiz(const char*, int); //funzione per la gestione del comando end quiz
void inviaPunteggi(int); //funzione per la gestione del comando show score


void *handler_client(void*arg){
    int client_sock=*(int*)arg;
    free(arg);

    
    pthread_mutex_lock(&m_players);
    players++;   //incremento il numero di giocatori
    pthread_mutex_unlock(&m_players);
   
    
    //mi registro per giocare
    char nome[BUFFER_SIZE] = {0}; 
    char buffer[BUFFER_SIZE] = {0};
    while(1){
        memset(buffer, 0, sizeof(buffer));
        int ret = ricevo(buffer, client_sock);  //ricevo il nickname scelto dall'utente   
        buffer[strcspn(buffer, "\n")] = '\0';

        if(ret <= 0){
            //printf("Il client %d si è disconnesso. \n", client_sock);
            close(client_sock);
            pthread_exit(NULL);
            break;
        }

        if(verificaNickname(buffer)){
            strcpy(nome,buffer);
            //se il nickname è valido invio ok
            memset(buffer, 0, sizeof(buffer));
            strcpy(buffer,"ok");
            invio(buffer, client_sock);
            break;

        } 
        
            memset(buffer, 0, sizeof(buffer));
            strcpy(buffer,"no");
            invio(buffer, client_sock);
            
    }
    
    //gioco effettivamente
    while(1){
        char buffer[BUFFER_SIZE] = {0};
        int n = 0;
        //attendo che il client mi invii il tema a cui vuole giocare/show score/end score
        int ret = ricevo(buffer,client_sock);
        
        if(ret <= 0){
            //printf("Il client %d si è disconnesso. \n", client_sock);
            endQuiz(nome, client_sock);
            break;
        }

        if(strcmp(buffer, END_QUIZ) == 0){
            endQuiz(nome, client_sock); //vado alla funzione che gestisce la fine del gioco
            break;
        }
      
        if(strcmp(buffer, SHOW_SCORE) == 0){
            inviaPunteggi(client_sock); //chiamo la funzione per inviare i punteggi attuali al client
            continue;
        }
        //se arrivo qui significa che l'utente ha selezionato un tema di gioco
        sscanf(buffer, "%d", &n); 
        n--;
                     
        if(!QuizGiocabile(nome, n)){ //verifico che il tema selezionato non sia già stato giocato
            memset(buffer,0, BUFFER_SIZE);
            strcpy(buffer, "Quiz già giocato. Riprova: ");
            invio(buffer, client_sock);
            continue;
        }else{
            //se ritengo che l'utente abbia selezionato un tema a cui può giocare,
            //comunico all'utente che può iniziare a giocare
            memset(buffer,0, BUFFER_SIZE);
            strcpy(buffer, "Inizia Quiz");
            
            invio(buffer, client_sock);
            
      
            init();
              
            quiz(client_sock, nome, n);  //funzione che mi permette di inviare domande al client e ricevere risposte      
           
            pthread_mutex_lock(&m_classifica);
            struct Utente *u = classifica;
            while(u != NULL){
                if(strcmp(u->nickname, nome) == 0 && u->quiz->tema == n){
                    break;
                }
                u = u->next;
            }  
            if(u != NULL){
                u->quiz->finish = true;
            }
          
            pthread_mutex_unlock(&m_classifica); 
            init();
        }    
        
        
    }
}


int main(){
    int server_fd, *client_fd;
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_len = sizeof(client_addr);
    pthread_t tid;
    signal(SIGPIPE, SIG_IGN);
    inizializza(); //inizializzo mutex e variabili globali
    

    //creazione del socket
    if((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == -1){
        perror("Errore nella creazione del socket.\n");
        exit(EXIT_FAILURE);
    }
    //assegnazione indirizzo Ip e porta
    server_addr.sin_family= AF_INET;
    server_addr.sin_port=htons(PORT);
    server_addr.sin_addr.s_addr=INADDR_ANY;

    //binding del socket
    if((bind(server_fd, (struct sockaddr*)&server_addr, sizeof(server_addr))) == -1){
        perror("Bind failed.\n");
        close(server_fd);
        exit(EXIT_FAILURE);
    }

    //listen
    if(listen(server_fd,3) == -1){
        perror("Listen failed.\n");
        close(server_fd);
        exit(EXIT_FAILURE);
    }
   
    
    menu();
    while(1){
       
        //Accetta una connessione
        client_fd = (int*)malloc(sizeof(int));
        *client_fd = accept(server_fd, (struct sockaddr*)&client_addr, &client_len);
        if(*client_fd == -1){
            perror("Accept failed");
            free(client_fd);
            continue;
        }
       
      
        //creo un thread per gestire il client
        pthread_create(&tid, NULL, handler_client, client_fd);
 
       
    }
    close(server_fd);
    return 0;
}

//menù iniziale del server, ogni volta che viene chiamato pulisce la
//shell da qualsiasi cosa ci sia stat precedentemente.
//stampa i temi dei quiz, il numero di pertecipanti e la lista dei nomi
void menu(){
    system("clear");
    printf("Trivia Quiz\n");
    stampaPiu();
    printf("Temi:\n1-Scienze\n2-Storia\n");
    stampaPiu();
    stampaPartecipanti();
}

//funzione che richiama menu(), stampa le classifiche in base al tema
// e una lista per ciascun tema di chi ha concluso il quiz 
void init(){
    menu();
    for(int i=0; i<N_TEMI; i++){
        stampaPerTema(i);
    }
    for(int i=0; i<N_TEMI; i++){
        terminatoT(i);
    }
    printf("------\n");
}



//funzione che verifica la validità del nickname inserito.
//se valido lo inserisce nella lista globale database
bool verificaNickname(const char*name){
    bool ritorno = true;
    pthread_mutex_lock(&m_database);
    struct Utente *u = database;
    while(u != NULL){
        if(strcmp(u->nickname, name) == 0){
           break;
       }
       u = u->next;
    } 
     
    if(u == NULL){
        //inserisco sempre in testa tanto non sono interessato all'ordine
        inserisci(&database, name);
        pthread_mutex_unlock(&m_database); 
        init();    
    }else{
        pthread_mutex_unlock(&m_database); 
        //il nickname il questo caso è un duplicato e quindi non va bene
        ritorno = false;
    }
    return ritorno;         
}



//funzione che va a verificare se l'utente ha già giocato o meno ad uno specifico tema
bool QuizGiocabile(const char*name,int tema){
    pthread_mutex_lock(&m_classifica);
    struct Utente*temp = classifica;
    while(temp != NULL){
        if(strcmp(temp->nickname,name) == 0){
            if(temp->quiz->tema == tema){ //in questo caso l'utente ha già giocato a quel quiz
                break;
            }
            //mentre se è presente il nome ma con un tema diverso il quiz è sempre giocabile   
            
        }
        temp = temp->next;
    }
    
     if(temp == NULL){
        //se non ho l'utente il lista, ovvero è la prima volta che gioca
        //se ha già giocato ma ad un tema diverso
        //=>inserisco in lista classifica
        struct Utente* nuovo = alloca_nuovo_nodo(name);
        nuovo->quiz->tema = tema;
        inserisciOrdinato(&classifica, nuovo);
        pthread_mutex_unlock(&m_classifica);
        return true;
        
    }
    else {
        pthread_mutex_unlock(&m_classifica);
        //in questo caso l'utente ha gia giocato a quel tema
        return false;
    }

}


//funzione che si occupa del gioco effettivo, ovvero dello scambio di informazioni con il client
//a cui invia le domande e da cui riceve risposte e va a determinare se le risposte date sono corrette o meno.
//In caso di risposte corrette si occupa anche di incrementare il punteggio
void quiz(int client_sock, const char*nome, int tema){
    char domande[BUFFER_SIZE] = {0};
    char risposte[BUFFER_SIZE] = {0};
    char buffer[BUFFER_SIZE] = {0};


    int start_line = (tema==1) ? 6 : 1; //seleziono la prima riga da leggere nel file in base al tema scelto
    int i = 0;
    while(i < N_DOMANDE){
        int riga_d = start_line + i; //numero di riga da cui parto a leggere le risposte nel file domande
        int riga_r = start_line + i; //numero di riga da cui parto a leggere le risposte nel file risposte
        
        //leggo la domanda e la risposta
        leggi_riga_da_file("domande.txt", riga_d, domande);
        leggi_riga_da_file("risposte.txt", riga_r, risposte);
        if(strcmp(domande, "La riga non esiste") == 0 || strcmp(risposte, "La riga non esiste") == 0){
            perror("Errore nel prelievo da file");
            exit(EXIT_FAILURE);
        }
        //invio la domanda al client
        invio(domande, client_sock);

        //attendo risposta del client 
        memset(buffer, 0, BUFFER_SIZE);
        int ret = ricevo(buffer, client_sock);
        if(ret <= 0){
            //printf("Il client %d si è disconnesso. \n", client_sock);
            //chiamo la endQuiz perchè devo eliminare i dati presenti fino 
            //ad ora sulla mia partita/e ed effettuare la chiusura del socket e 
            //la terminazione del thread che gestisce il client
            endQuiz(nome, client_sock); 
            break;
        }

        //controllo la risposta
        if(strcasecmp(buffer, risposte) == 0){
            memset(buffer, 0, BUFFER_SIZE);
            strcpy(buffer, "Risposta esatta");
            invio(buffer, client_sock);

            //poiché la risposta è corretta devo aggiornare il punteggio e riordinare la lista
            pthread_mutex_lock(&m_classifica);
            //l'utente può gicare fino a due partite(una per tema) quindi per essere sicuro di aver
            // estratto il nodo corretto fo due estrazioni e guardo il valore del tema
            struct Utente *u = estraiUtente(&classifica, nome);  
            struct Utente *s = estraiUtente(&classifica, nome); //se era presente una sola partita questo avle NULL
            if(u->quiz->tema != tema && s != NULL && s->quiz->tema == tema){ 
                s->quiz->score++;
            }else{
                u->quiz->score++;
            } 
            inserisciOrdinato(&classifica, u); 
            if(s != NULL){
                inserisciOrdinato(&classifica, s);
            }
            pthread_mutex_unlock(&m_classifica);
            init();
            
        }else{
            memset(buffer, 0, BUFFER_SIZE);
            strcpy(buffer, "Risposta sbagliata");
            invio(buffer, client_sock);
        }
        i++;
    }
    
}


//funzione che gestisce il comando end quiz:
//se l'utente digita 'end quiz' significa che sta chiudendo la sua sessione di gioco
//devo quindi deallocare tutte le strutture dedicate alle sue informazioni,
//chiudere il socket di comunicazione ed il thread per la sua gestione
void endQuiz(const char*name, int client_sock){
    // elimino l'utente dalla lista database
    pthread_mutex_lock(&m_players);
    players--;
    pthread_mutex_unlock(&m_players);
    pthread_mutex_lock(&m_database);
    struct Utente* u = estraiUtente(&database, name);
    if(u != NULL){
        free(u->quiz); //libero la memoria relativa alla struttura Partita
        free(u); //libero la memoria relativa alla struttura Utente
    }
    pthread_mutex_unlock(&m_database);

    //elimino tutti i quiz giocati dall'utente
    pthread_mutex_lock(&m_classifica);
    // chiamo due volte la funzione poichè un utente può aver 
    // giocato al massimo due temi e quindi essere due volte in lista.
    // Se c'era una sola volta al massimo la seconda chiamata restituisce NULL ma non è un problema  
    struct Utente *n = estraiUtente(&classifica, name);
    if(n != NULL){
        free(n->quiz);
        free(n);
    }

    struct Utente* nuovo = estraiUtente(&classifica, name); 
    if(nuovo != NULL){
        free(nuovo->quiz);
        free(nuovo);
    }
    pthread_mutex_unlock(&m_classifica);
    init();
    close(client_sock); //chiudo il socket con il client
    pthread_exit(NULL); //termino il thread di gestion del client
}

//funzione che gestisce il comando show score:
//per ciascun tema scorro la lista e invio al client 
//i giocatori con il loro punteggio in ordine di punteggio
void inviaPunteggi(int client_sock){
    int i = 0;
    char risposta[BUFFER_SIZE] = {0};
    pthread_mutex_lock(&m_classifica);
    while(i < N_TEMI){ //per ciascun tema
        struct Utente *u = classifica;
        while(u != NULL){ //scorro tutta la lista classifica
            if(u->quiz->tema == i){ //se il tema coincide con quello che voglio stampare
                char nome[BUFFER_SIZE] = {0};
                char punteggio[BUFFER_SIZE] = {0};
                strcpy(nome, u->nickname);
               
                invio(nome, client_sock); //invio al client il nome
                sprintf(punteggio, "%d", u->quiz->score); //conversione da intero a striga
                invio(punteggio, client_sock); //invio al client il punteggio
            }
            u = u->next;
        }
        i++; 
        strcpy(risposta, "Fine");
        invio(risposta, client_sock); //invio al client la parola fine quando non ho più temi per cui inviare una classifica 
    }  

    pthread_mutex_unlock(&m_classifica); 
}


