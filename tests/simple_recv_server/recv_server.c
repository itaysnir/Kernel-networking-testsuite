#include <stdio.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h> // read(), write(), close()
#include <arpa/inet.h>

#define IFACE_IP "10.1.4.35"
#define MAX_BUFFER_SZ 16384
#define SA struct sockaddr
   
// Function designed for chat between client and server.
void func(int connfd)
{
    char buff[MAX_BUFFER_SZ];
    int n;
    bzero(buff, MAX_BUFFER_SZ);

    // infinite loop for chat
    for (;;) {
  //      bzero(buff, MAX_BUFFER_SZ);
   
        // read the message from client and copy it in buffer
        n = recv(connfd, buff, sizeof(buff), 0);

	if (n == 0)
	{
		printf("exit..\n");
		exit(1);
	}
	

        // print buffer which contains the client contents
//        printf("%d bytes From client: %s\n", n, buff);
//        bzero(buff, MAX_BUFFER_SZ);
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
        exit(1);
    }
    else
        printf("Socket successfully created..\n");

    int one = 1;
    if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one)) < 0){
	    printf("setsockopt(SO_REUSEADDR) failed\n");
	    exit(1);
    }

    bzero(&servaddr, sizeof(servaddr));
   
    // assign IP, PORT
    servaddr.sin_family = AF_INET;
//    servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
    inet_aton(IFACE_IP, (struct in_addr*)&servaddr.sin_addr.s_addr);
    servaddr.sin_port = htons(server_port);
   
    // Binding newly created socket to given IP and verification
    if ((bind(sockfd, (SA*)&servaddr, sizeof(servaddr))) != 0) {
        printf("socket bind failed...\n");
        exit(0);
    }
    else
        printf("Socket successfully binded..\n");
   
    // Now server is ready to listen and verification
    if ((listen(sockfd, 10)) != 0) {
        printf("Listen failed...\n");
        exit(0);
    }
    else
        printf("Server listening..\n");
    len = sizeof(cli);
   
    // Accept the data packet from client and verification
    connfd = accept(sockfd, (SA*)&cli, (unsigned int*)&len);
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
