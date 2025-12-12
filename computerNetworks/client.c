#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>


#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
#include <signal.h>
#include <errno.h>
#include <stdbool.h>




#define BUFFER_SIZE 1024
#define IP_SERVER "127.0.0.1"
#define N_DOMANDE 5
#define N_TEMI 2
#define SHOW_SCORE "show score"
#define END_QUIZ "end quiz"


bool menu(); //menù iniziale che permette di scegliere se avviare la sessione del gioco oppure no
char* menuGioco(); //menù di gioco da cui posso selezionare il tema che desiero giocare oppure end quiz/show score
void handle_sigpipe(int); //funzione che modifica il comportamento del segnale SIGPIPE
void mostraPunteggi(int); //funzione che svolge le azioni legate al comando show score
void invio(const char*, int); //funzione che gestisce l'invio dei messaggi al server ed eventuali errori
void ricevo(char*, int); //funzione che gestisce la ricezione di messaggi dal server ed eventuali errori

//In caso di sigpipe il processo termina. 
//Con questa funzione modifico il suo comportamento
//stampando un messaggio di errore
void handle_sigpipe(int sig){
    //modifico il contenuto della macro STDERR_FILENO che rappresenta il file descriptor dello standard error
    write(STDERR_FILENO, "Il server si è disconnesso...\n", 31); 
    return;
}



int main(int argc, char**argv){
    if(argc != 2){ //mi assicuro che il client venga mandato in esecuzione nel formato ./client <porta>
        printf("Client non lanciato correttamente.\n");
        exit(EXIT_FAILURE);
    }
   
    int sock = 0;
    struct sockaddr_in serv_addr;
    char buffer[BUFFER_SIZE] = {0};
    signal(SIGPIPE, handle_sigpipe); 

    if(!menu() == 2){
        return 0;
    }
 

    //CREAZIONE DEL SOCKET
    if((sock=socket(AF_INET, SOCK_STREAM,0)) == -1){
        printf("Socket creation error.\n");
        return -1;
    }

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(atoi(argv[1]));

    //convertire l'indirzzo IP da testo a binario
    if(inet_pton(AF_INET, IP_SERVER, &serv_addr.sin_addr) == -1){
        printf("Conversione indirizzo IP non valida.\n");
        return -1;
    }
    //Connessione al server
    if(connect(sock, (struct sockaddr*)&serv_addr, sizeof(serv_addr)) == -1){
        printf("Errore di connessione.\n");
        close(sock);
        exit(EXIT_FAILURE);
    }
    
    printf("\nTrivia Quiz\n");
    printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");

    //inizio con la mia registrazione
    printf("Scegli un nickname (deve essere univoco): \n");
    while(1){
        memset(buffer, 0, BUFFER_SIZE);
        
        //inserisco nickname da tastiera
        fgets(buffer, BUFFER_SIZE, stdin);
        buffer[strcspn(buffer, "\n")] = '\0';

        if(strcmp(buffer," ") == 0){
            printf("Nickname non valido. Riprova: \n");
            continue;
        }
        if(strlen(buffer) < 1){
            printf("Errore: inserire nuovamente il nickname: \n");
            continue;
        }
        
        //invio al server il nickname inserito         
        invio(buffer, sock); 
 
      
        
        //aspetto ok/no
        memset(buffer, 0, BUFFER_SIZE);
        ricevo(buffer, sock);
       
        if(strcmp(buffer, "ok") == 0){
            break;
        }
        printf("Nickname esitente, riprova: \n");
        
    }
    
    //dopo essermi correttamente registrato, inizio a giocare
    int i = N_TEMI;
    while(1){
        int n = 0;
        char buffer[BUFFER_SIZE] = {0};            
        printf("\n");

        strcpy(buffer, menuGioco()); //la funzione mi ritorna il tema scelto/show score/end quiz        
        
        //invio l'argomento del tema o show score o end quiz
        invio(buffer, sock);
        if(strcasecmp(buffer, SHOW_SCORE) == 0){
            //in questo caso l'utente ha digitato 'show score' perchè desidera vedere la classifica
            mostraPunteggi(sock); //funzione che si occupa di ricevere dal server i dati relativi alla classifica
            continue;
        }
        if(strcasecmp(buffer, END_QUIZ) == 0){
            //in questo caso l'utente ha digitato 'end quiz' e quindi sta scegliendo di terminare il gioco
            break;
        }
        //se sono qui significa che l'utente ha selezionato il tema 1 o 2
        n = atoi(buffer); //conversione da stringa a intero
        n--; //i temi sono numerati a partire da zero


        memset(buffer, 0, BUFFER_SIZE);
        ricevo(buffer, sock); //attendo risposta dal client: "Inizia quiz" oppure "Quiz già giocato. Riprova: "
       
        if(strcmp(buffer, "Quiz già giocato. Riprova: ") == 0){
            printf("%s\n",buffer);
            continue; 
        }
        
        if(n == 0){
            strcpy(buffer, "scienze");
        }
        else{
            strcpy(buffer, "storia");
        }
        printf("\nQuiz-%s\n", buffer);
        printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
        //a questo punto il server deve mandarmi le domande per il tema scelto
        for(int f = 0; f < N_DOMANDE; f++){
            memset(buffer, 0, BUFFER_SIZE);
            ricevo(buffer, sock); //ricevo domanda
            printf("%s\n",buffer);

            memset(buffer, 0, BUFFER_SIZE);
            printf("\nRisposta: ");
            while(1){
                fgets(buffer, BUFFER_SIZE, stdin); //digito la mia risposta
                buffer[strcspn(buffer, "\n")]='\0'; 
                if(strcmp(buffer, " ") != 0){
                    break;
                }
                printf("Risposta non valida. Riprova: \n");
            }
            
            invio(buffer, sock); //invio la mia risposta
            

            memset(buffer, 0,BUFFER_SIZE);
            ricevo(buffer,sock); //il server mi dice se la risposta è corretta o meno
            printf("%s\n\n", buffer);
            
        }
            
        i--;
    }       
   
    close(sock);
    return 0;


}


//funzione che mostra il menù iniziale che permette 
//all'utente di scegliere se avviare la connesseione con il server
//per iniziare a giocare oppure se disconnettersi
bool menu(){
    system("clear");
    bool ritorno = true;
    int n = 0;
    char buffer[BUFFER_SIZE] = {0};
    printf("Trivia Quiz\n");
    printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
    printf("Menù:\n1-Comincia una sessione di Trivia\n2-Esci\n");
    printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
    printf("La tua scelta: ");
    while(1){
        fgets(buffer, BUFFER_SIZE, stdin);
        buffer[strcspn(buffer, "\n")] = '\0';
        if(strcmp(buffer,"1") == 0 || strcmp(buffer,"2") == 0){
            n =  atoi(buffer);
            if(n == 2){
                ritorno = false; 
            }
            break;
        }
        printf("Opzione non valida. Riprovare\n");
        memset(buffer, 0, BUFFER_SIZE);

    }
    //while(getchar() != '\n' && !feof(stdin)); 
    return ritorno;
}



//funzione che fornisce il menù di gioco da cui posso selezionare 
// il tema che desiero giocare oppure end quiz/show score 
char* menuGioco(){
    printf("Quiz disponibili\n");
    printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
    printf("1-scienze\n2-storia\n");
    printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
    printf("('%s' per mostrare punteggi ,'%s' per terminare il gioco)\n", SHOW_SCORE, END_QUIZ);
    printf("\nLa tua scelta è: ");
    
    static char buffer[BUFFER_SIZE] = {0};
    while(1){
        fgets(buffer, BUFFER_SIZE, stdin); //posso digitare da tastiera una delle opzioni: 1/2/show score/end quiz
        buffer[strcspn(buffer, "\n")] = '\0';  
        if(strcasecmp(buffer, END_QUIZ) == 0  || strcasecmp(buffer, SHOW_SCORE) == 0 ||  strcasecmp(buffer, "1") == 0 || strcasecmp(buffer, "2") == 0 ){
            break;
        }   
        printf("Opzione non valida. Riprovare\n"); //se ho digitato qualsiasi cosa non sia specificato mi chiede di reinserire
        memset(buffer, 0, BUFFER_SIZE);
    }

    return buffer;
    
}


//funzione che serve per comunicare con il server e farsi inviare le classifiche dei giocatori
void mostraPunteggi(int sock){
    int i = 1;
    while(i <= N_TEMI){
        printf("Classifica tema %d\n", i);
        while(1){
            char nome[BUFFER_SIZE] = {0};
            char punteggio[BUFFER_SIZE] = {0};
            int score = 0;
            ricevo(nome, sock); //ricevo il nome oppure fine se ho terminato con i dati relativi ad un determinato tema
            if(strcmp(nome, "Fine") == 0){
                break;
            }
           
            ricevo(punteggio, sock); //se in nome non c'era fine a questo punto ricevo il punteggio
            sscanf(punteggio, "%d", &score); //converto da char* a intero
            printf("-%s %d \n", nome, score);
        }
        i++;
    }
}

//funzione utilità per iniviare informazioni da client a server
void invio(const char* buffer, int sock){
    
    uint32_t net_message_length = 0;
    int message_length = strlen(buffer);
    net_message_length = htonl(message_length); //converto in formato network
    int ret = send(sock, &net_message_length, sizeof(uint32_t), 0); //invio la dimensione del messaggio
    if(ret == -1 && (errno == EPIPE || errno == ECONNRESET)){ //gestione casi di errore nell'invio
        close(sock);
        return;
    }
 
    ret = send(sock, buffer, message_length , 0); //invio il messaggio effettivo
    if(ret == -1 && (errno == EPIPE || errno == ECONNRESET)){
        close(sock);
        return;
    }
    

}
  

//funzione utilità per informazioni da ricevere dal server
void ricevo(char*buffer, int sock){
    uint32_t  message_length = 0;
    ssize_t bytes_read=recv(sock, &message_length, sizeof(message_length),0); //ricevo la dimensione del messaggio
    if(bytes_read == -1){ //caso di errore da gestire
        close(sock);
        exit(EXIT_FAILURE);
        return;
    }
    message_length = ntohl(message_length); //converto da formato network a formato host
    bytes_read = recv(sock,buffer, message_length, 0); //ricevo l'effettivo messaggio
    if(bytes_read == -1){
        close(sock);
        exit(EXIT_FAILURE);
        return;
    }
}
