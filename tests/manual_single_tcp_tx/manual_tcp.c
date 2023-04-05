#include <stdio.h> 
#include <stdlib.h> 
#include <errno.h> 
#include <string.h> 
#include <netdb.h> 
#include <sys/types.h> 
#include <netinet/in.h> 
#include <netinet/tcp.h>
#include <sys/socket.h> 
#include <sys/time.h>    
#include <unistd.h>
#include <arpa/inet.h>


struct ring_elt {
  struct ring_elt *next;  /* next element in the ring */
  char *buffer_base;      /* in case we have to free it at somepoint */
  char *buffer_ptr;       /* the aligned and offset pointer */
  void *completion_ptr;   /* a pointer to information for async completion */
  /* these are for sendfile calls and at some point we should consider
     using a union but it isn't really all that much extra space */
  struct iovec *hdtrl;            /* a pointer to a header/trailer
                                     that we do not initially use and
                                     so should be set to NULL when the
                                     ring is setup. */
  off_t offset;                   /* the offset from the beginning of
                                     the file for this send */
  size_t length;                  /* the number of bytes to send -
                                     this is redundant with the
                                     send_size variable but I decided
                                     to include it anyway */
  int fildes;                     /* the file descriptor of the source
                                     file */
  int flags;                      /* the flags to pass to sendfile() -
                                     presently unused and should be
                                     set to zero when the ring is
                                     setup. */
};


static unsigned long gettimeofday_s(void)
{
	struct timeval tv;

	gettimeofday(&tv, NULL);
	return tv.tv_sec;
}


    int main(int argc, char *argv[])
    {
        int sockfd;  
	int sent_len = 0;
        struct hostent *he;
        struct sockaddr_in their_addr; /* connector's address information */

        if (argc != 5) {
            fprintf(stderr,"usage: %s <REMOTE_IP> <PORT> <CHUNK_SIZE> <TIMEOUT>\n", argv[0]);
            exit(1);
        }

        if ((he=gethostbyname(argv[1])) == NULL) {  /* get the host info */
            herror("gethostbyname");
            exit(1);
        }

	int port = atoi(argv[2]);
	int chunk_size = atoi(argv[3]);
	int timeout = atoi(argv[4]);

        if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
            perror("socket");
            exit(1);
        }


	struct ring_elt *prev_link = NULL;
       	struct ring_elt *temp_link = NULL;
	struct ring_elt *first_link = NULL;
	int alignment = 16;

	for (int i = 1 ; i <= 2048 ; i++)
	{
		temp_link = (struct ring_elt *)malloc(sizeof(struct ring_elt));
		temp_link->completion_ptr = NULL;
		if (i == 1){
			first_link = temp_link;
		}
		
		temp_link->buffer_base = (char *)malloc(chunk_size + alignment); 
		memset(temp_link->buffer_base, 0, chunk_size + alignment);

		temp_link->buffer_ptr = (char *)(( (long)temp_link->buffer_base + (long)alignment -1 ) & ~((long)alignment - 1));
		
		char *bufptr = temp_link->buffer_ptr;
		memset(bufptr, 'A', chunk_size);	
		
		temp_link->next = prev_link;
		prev_link = temp_link;	
	}	
	
	if (first_link)
	{
		// make this a circular list
		first_link->next = temp_link;
	}
		


 	size_t sk_buf_size = 16777216;
	int one = 1;

	setsockopt(sockfd, SOL_SOCKET, SO_SNDBUF, (void *)&sk_buf_size, sizeof(one));
	setsockopt(sockfd, SOL_SOCKET, SO_RCVBUF, (void *)&sk_buf_size, sizeof(one));
	setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, (void *)&one, sizeof(one));
	setsockopt(sockfd, SOL_IP, IP_RECVERR, (void *)&one, sizeof(one)); // just enable
	// setsockopt(sockfd, SOL_TCP, TCP_NODELAY, (void *)&one, sizeof(one));
	
	struct sockaddr_in local_addr;
	memset(&local_addr, 0, sizeof(struct sockaddr_in));
	local_addr.sin_family = AF_INET;
	local_addr.sin_port = 0;
	inet_aton("0.0.0.0", (struct in_addr*)&local_addr.sin_addr.s_addr);

	bind(sockfd, (struct sockaddr*)&local_addr, sizeof(local_addr));

        their_addr.sin_family = AF_INET;      /* host byte order */
        their_addr.sin_port = htons(port);    /* short, network byte order */
        their_addr.sin_addr = *((struct in_addr *)he->h_addr);
        bzero(&(their_addr.sin_zero), 8);     /* zero the rest of the struct */

        if (connect(sockfd, (struct sockaddr *)&their_addr, \
                                              sizeof(struct sockaddr)) == -1) {
            perror("connect");
            exit(1);
        }

	temp_link = first_link;

	uint64_t endwait = gettimeofday_s() + timeout;

	while (gettimeofday_s() < endwait) {
		sent_len = send(sockfd, temp_link->buffer_ptr, chunk_size, 0);
		if (sent_len != chunk_size)
		{
			printf("Invalid Sent length:%d\n", sent_len);
			exit(1);
		}
		temp_link = temp_link->next;
	}

        close(sockfd);

        return 0;
    }
