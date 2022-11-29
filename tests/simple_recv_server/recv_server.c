#include <stdio.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h> // read(), write(), close()
#define MAX 16384
#define PORT 8080
#define SA struct sockaddr
   
// Function designed for chat between client and server.
void func(int connfd)
{
    char buff[MAX];
    int n;
    bzero(buff, MAX);

    // infinite loop for chat
    for (;;) {
  //      bzero(buff, MAX);
   
        // read the message from client and copy it in buffer
        n = recv(connfd, buff, sizeof(buff), 0);

	if (n == 0)
	{
		printf("exit..\n");
		exit(1);
	}
	

        // print buffer which contains the client contents
//        printf("%d bytes From client: %s\n", n, buff);
//        bzero(buff, MAX);
//        n = 0;
	// copy server message in the buffer
//        while ((buff[n++] = getchar()) != '\n')
//            ;
   
        // and send that buffer to client
//        write(connfd, buff, sizeof(buff));
   
        // if msg contains "Exit" then server exit and chat ended.
//        if (strncmp("exit", buff, 4) == 0) {
//            printf("Server Exit...\n");
//            break;
//	    } 
    }
}
   
// Driver function
int main(int argc, char **argv)
{
    int sockfd, connfd, len;
    struct sockaddr_in servaddr, cli;

    if (argc != 2) {
            fprintf(stderr,"usage: %s <LISTEN_PORT>\n", argv[0]);
            exit(1);
        } 

    int server_port = atoi(argv[1]);
    // socket create and verification
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd == -1) {
        printf("socket creation failed...\n");
        exit(0);
    }
    else
        printf("Socket successfully created..\n");
    bzero(&servaddr, sizeof(servaddr));
   
    // assign IP, PORT
    servaddr.sin_family = AF_INET;
//    servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
    inet_aton("10.1.4.35", (struct in_addr*)&servaddr.sin_addr.s_addr);
    servaddr.sin_port = htons(server_port);
   
    // Binding newly created socket to given IP and verification
    if ((bind(sockfd, (SA*)&servaddr, sizeof(servaddr))) != 0) {
        printf("socket bind failed...\n");
        exit(0);
    }
    else
        printf("Socket successfully binded..\n");
   
    // Now server is ready to listen and verification
    if ((listen(sockfd, 5)) != 0) {
        printf("Listen failed...\n");
        exit(0);
    }
    else
        printf("Server listening..\n");
    len = sizeof(cli);
   
    // Accept the data packet from client and verification
    connfd = accept(sockfd, (SA*)&cli, &len);
    if (connfd < 0) {
        printf("server accept failed...\n");
        exit(0);
    }
    else
        printf("server accept the client...\n");
   
    // Function for chatting between client and server
    func(connfd);
   
    // After chatting close the socket
    close(sockfd);
}
