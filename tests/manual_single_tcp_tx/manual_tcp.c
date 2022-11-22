#include <stdio.h> 
    #include <stdlib.h> 
    #include <errno.h> 
    #include <string.h> 
    #include <netdb.h> 
    #include <sys/types.h> 
    #include <netinet/in.h> 
    #include <sys/socket.h> 
    #include <unistd.h>
    #include <arpa/inet.h>


    #define PORT 8080    /* the port client will be connecting to */
    #define CHUNK 16384

    int main(int argc, char *argv[])
    {
        int sockfd;  
        struct hostent *he;
        struct sockaddr_in their_addr; /* connector's address information */

        if (argc != 2) {
            fprintf(stderr,"usage: %s <hostname>\n", argv[0]);
            exit(1);
        }

        if ((he=gethostbyname(argv[1])) == NULL) {  /* get the host info */
            herror("gethostbyname");
            exit(1);
        }

        if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
            perror("socket");
            exit(1);
        }

	void *big_buf = malloc(CHUNK);
	memset(big_buf, 'A', CHUNK);

 	size_t sk_buf_size = 16777216;
	int reuse_addr = 1;

	setsockopt(sockfd, SOL_SOCKET, SO_SNDBUF, (void *)&sk_buf_size, sizeof(int));
	setsockopt(sockfd, SOL_SOCKET, SO_RCVBUF, (void *)&sk_buf_size, sizeof(int));
	setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, (void *)&reuse_addr, sizeof(int));
	setsockopt(sockfd, SOL_IP, IP_RECVERR, (void *)&reuse_addr, sizeof(int)); // just enable

	
	struct sockaddr_in local_addr;
	memset(&local_addr, 0, sizeof(struct sockaddr_in));
	local_addr.sin_family = AF_INET;
	local_addr.sin_port = 0;
	inet_aton("0.0.0.0", (struct in_addr*)&local_addr.sin_addr.s_addr);

	bind(sockfd, (struct sockaddr*)&local_addr, sizeof(local_addr));

        their_addr.sin_family = AF_INET;      /* host byte order */
        their_addr.sin_port = htons(PORT);    /* short, network byte order */
        their_addr.sin_addr = *((struct in_addr *)he->h_addr);
        bzero(&(their_addr.sin_zero), 8);     /* zero the rest of the struct */

        if (connect(sockfd, (struct sockaddr *)&their_addr, \
                                              sizeof(struct sockaddr)) == -1) {
            perror("connect");
            exit(1);
        }
	while (1) {
		if (sendto(sockfd, big_buf, CHUNK, 0, (struct sockaddr *)&their_addr, sizeof(struct sockaddr)) == -1){
                      perror("send");
		      exit (1);
		}
		write(1, "After the send function \n", 30);
	}

        close(sockfd);

        return 0;
    }
