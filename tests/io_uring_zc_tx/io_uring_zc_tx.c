/* SPDX-License-Identifier: MIT */
/*
 * Simple test case showing using send and recv through io_uring
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <pthread.h>
#include <assert.h>
#include <netinet/ip.h>
#include "liburing.h"


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


#define ZC_TAG 0xfffffffULL
#define NR_REQS 128 
#define MAX_CQES 256 
#define SOCK_SIZE 2097152 
#define CHECK_BATCH(ring, got, cqes, count, expected) do {\
		got = io_uring_peek_batch_cqe((ring), cqes, count);\
		if (got != expected) {\
					printf("Got %d CQs, expected %d\n", got, expected);\
					goto err;\
				}\
} while(0)


static char payload[IP_MAXPACKET] __attribute__((aligned(4096)));

static bool cfg_fixed_files = 1;
void *buff;
struct ring_elt *prev_link = NULL;
struct ring_elt *temp_link = NULL;
struct ring_elt *first_link = NULL;
int alignment = 256;


static inline struct io_uring_cqe *wait_cqe_fast(struct io_uring *ring)
{
	struct io_uring_cqe *cqe;
	unsigned head;
	int ret;

	io_uring_for_each_cqe(ring, head, cqe)
		return cqe;

	ret = io_uring_wait_cqe(ring, &cqe);
	if (ret){
		perror("wait_cqe_fast");
		exit(1);	
	}
	return cqe;
}

static int do_send(const char* host, int port, int chunk_size, int timeout, int batch)
{
//	struct io_uring_cqe *cqes[MAX_CQES];
	struct sockaddr_in saddr;
	struct io_uring ring;
	struct io_uring_cqe *cqe;
	struct io_uring_sqe *sqe;
	int sockfd, ret;

	ret = io_uring_queue_init(MAX_CQES * 2, &ring, IORING_SETUP_COOP_TASKRUN);
	if (ret) {
		fprintf(stderr, "queue init failed: %d\n", ret);
		return 1;
	}

	/*
	struct io_uring_notification_slot b[1] = {{.tag = ZC_TAG}};
	if (io_uring_register_notifications(&ring, 1, b) != 0)
	{
		fprintf(stderr, "io_uring: notification register failed\n");
		return 1;
	}
	*/

	memset(&saddr, 0, sizeof(saddr));
	saddr.sin_family = AF_INET;
	saddr.sin_port = htons(port);
	inet_pton(AF_INET, host, &saddr.sin_addr);
	

	sockfd = socket(AF_INET, SOCK_STREAM, 0);
	if (sockfd < 0) {
		perror("socket");
		return 1;
	}

	size_t sk_buf_size = SOCK_SIZE;
        int one = 1;
        setsockopt(sockfd, SOL_SOCKET, SO_SNDBUF, (void *)&sk_buf_size, sizeof(one));
        setsockopt(sockfd, SOL_SOCKET, SO_RCVBUF, (void *)&sk_buf_size, sizeof(one));
        setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, (void *)&one, sizeof(one));
        setsockopt(sockfd, SOL_IP, IP_RECVERR, (void *)&one, sizeof(one));

	struct sockaddr_in local_addr;
        memset(&local_addr, 0, sizeof(struct sockaddr_in));
        local_addr.sin_family = AF_INET;
        local_addr.sin_port = 0;
        inet_aton("0.0.0.0", (struct in_addr*)&local_addr.sin_addr.s_addr);
        bind(sockfd, (struct sockaddr*)&local_addr, sizeof(local_addr));


	ret = connect(sockfd, (struct sockaddr *)&saddr, sizeof(saddr));
	if (ret < 0) {
		perror("connect");
		return 1;
	}


	if (cfg_fixed_files)
	{
		if (io_uring_register_files(&ring, &sockfd, 1) < 0)
		{
			perror("io_uring: files registration");
			return 1;
		}
	}	

	/*
	struct iovec iov;
	iov.iov_base = payload;
	iov.iov_len = chunk_size;
	
	ret = io_uring_register_buffers(&ring, &iov, 1);
	if (ret != 0)
	{
		perror("io_uring: buffer registration");
	}
	*/
	
	if (io_uring_register_ring_fd(&ring) < 0)
	{
		perror("io_uring: ring registration");
		return 1;
	}		

	uint64_t packets = 0;
	uint64_t bytes = 0 ;
	time_t endwait = time(NULL) + timeout;
	
	while (time(NULL) < endwait){
	
	for (int m = 0 ; m < batch; m++)
	{
		sqe = io_uring_get_sqe(&ring);
		if (!sqe)
		{
			perror("get_sqe");
			return 1;
		}
		
		sqe->user_data = 1;
		io_uring_prep_send_zc(sqe, sockfd, temp_link->buffer_ptr, chunk_size, 0, 0);	
		temp_link = temp_link->next;
	/*	
		sqe->user_data = 1;
		io_uring_prep_send_zc(sqe, sockfd, payload, chunk_size, 0, 0);
	*/	
		if (cfg_fixed_files)
		{
			sqe->fd = 0;
			sqe->flags |= IOSQE_FIXED_FILE;
		}		
	}


	ret = io_uring_submit(&ring);
	if (ret != batch) {
		fprintf(stderr, "submit failed, only submitted: %d\n", ret);
		goto err;
	}

	for (int i = 0; i < batch ; i++)
	{
		cqe = wait_cqe_fast(&ring);
	
		// printf("res:%d flags:%d\n", cqe->res, cqe->flags);

		if (cqe->res == 0) // ZC notifier cqe 
		{
			//assert(cqe->flags & IORING_CQE_F_NOTIF);
			// assert(!(cqe->flags & IORING_CQE_F_MORE));
			i--;
		//	io_uring_cqe_seen(&ring, cqe);
		}
	
		else if (cqe->user_data != 1)
		{
			printf("invalid cqe user data\n");
			exit(1);	
		}
				
		else if (cqe->res > 0) // real cqe
		{
			// assert(cqe->flags & IORING_CQE_F_MORE); // a cqe notific is about to be received
			packets++;
			bytes += cqe->res;
		}
	
		else
		{
			printf("send failed:%d\n", cqe->res);
			exit(1);
		}

		io_uring_cqe_seen(&ring, cqe);
	}


	/* ORIGINAL CODE
	int retval;	
	uint32_t completed_requests = 0;
	while (completed_requests != MAX_CQES)
	{
		retval = io_uring_wait_cqe_nr(&ring, cqes, batch);
		if (retval < 0)
		{
			fprintf(stderr, "wait_cqe_nr failed\n");
			goto err;
		}
		completed_requests += batch;
		io_uring_cq_advance(&ring, batch);	
	}
	*/

	}

	printf("packets:%lu bytes:%lu\n", packets, bytes);

	close(sockfd);
	return 0;
err:
	close(sockfd);
	return 1;
}


int allocate_send_buffers(int chunk_size)
{
	for (int i = 0; i < IP_MAXPACKET; i++)
	{
		payload[i] = 'a' + (i % 26);
	}

	for (int i = 1 ; i <= MAX_CQES ; i++)
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
                first_link->next = temp_link;
        }
	temp_link = first_link;

	return 0;
}

int main(int argc, char *argv[])
{
	int ret;

	if (argc != 6) {
		fprintf(stderr, "Usage: %s <REMOTE_IP> <REMOTE_PORT> <CHUNK_SIZE> <TIMEOUT> <BATCH_SIZE>\n", argv[0]);
		return 0;
	}

	allocate_send_buffers(atoi(argv[3]));
	
	ret = do_send(argv[1], atoi(argv[2]), atoi(argv[3]), atoi(argv[4]), atoi(argv[5]));
	if (ret) {
		fprintf(stderr, "test failed\n");
		return ret;
	}

	return 0;
}
