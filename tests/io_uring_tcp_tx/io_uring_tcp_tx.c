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



void *buff;
struct ring_elt *prev_link = NULL;
struct ring_elt *temp_link = NULL;
struct ring_elt *first_link = NULL;
int alignment = 16;

#define CHUNK 16384
#define CHECK_BATCH(ring, got, cqes, count, expected) do {\
		got = io_uring_peek_batch_cqe((ring), cqes, count);\
		if (got != expected) {\
					printf("Got %d CQs, expected %d\n", got, expected);\
					goto err;\
				}\
} while(0)


static int do_send(const char* host, int port, int chunk_size, int timeout, int batch)
{
	struct io_uring_cqe *cqes[512];

	buff = malloc(chunk_size);
	if (!buff) {
		fprintf(stderr, "do_send: malloc failed\n");
		return 1;
	}
	
	memset(buff, 0x41, chunk_size);

	struct sockaddr_in saddr;
//	struct iovec iov = {
//		.iov_base = buff,
//		.iov_len = chunk_size,
//	};
	struct io_uring ring;
//	struct io_uring_cqe *cqe;
	struct io_uring_sqe *sqe;
	int sockfd, ret;

	ret = io_uring_queue_init(batch * 2, &ring, 0);
	if (ret) {
		fprintf(stderr, "queue init failed: %d\n", ret);
		return 1;
	}

	memset(&saddr, 0, sizeof(saddr));
	saddr.sin_family = AF_INET;
	saddr.sin_port = htons(port);
	inet_pton(AF_INET, host, &saddr.sin_addr);

	sockfd = socket(AF_INET, SOCK_STREAM, 0);
	//sockfd = socket(AF_INET, SOCK_DGRAM, 0);
	if (sockfd < 0) {
		perror("socket");
		return 1;
	}

	size_t sk_buf_size = 16777216;
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

	time_t endwait = time(NULL) + timeout;
	uint64_t counter=0;	
	
	while (time(NULL) < endwait){

	for (int m = 0 ; m < batch ; m++)
	{
		sqe = io_uring_get_sqe(&ring);
		if (!sqe)
		{
			perror("get_sqe");
			return 1;
		}

		// io_uring_prep_send(sqe, sockfd, iov.iov_base, iov.iov_len, 0);
		io_uring_prep_send(sqe, sockfd, temp_link->buffer_ptr, CHUNK, 0);

		sqe->user_data = 1 + m;
		temp_link = temp_link->next;
	}


	ret = io_uring_submit(&ring);
	if (ret < batch ) {
		fprintf(stderr, "submit failed, only submitted: %d\n", ret);
		goto err;
	}

	// Currently, only examines the first cqe of the batch
/*
	ret = io_uring_wait_cqe_nr(&ring, &cqe, batch);
	if (cqe->res == -EINVAL) {
		fprintf(stdout, "send not supported, skipping\n");
		close(sockfd);
		return 0;
	}
	if (cqe->res != iov.iov_len) {
		fprintf(stderr, "failed cqe: %d\n", cqe->res);
		goto err;
	}

*/
	unsigned got;
	
	CHECK_BATCH(&ring, got, cqes, batch, batch);

	// io_uring_cq_advance(&ring, batch);
	counter++;

	}

	printf("Packets sent:%lu\n", counter);
	close(sockfd);
	return 0;
err:
	close(sockfd);
	return 1;
}


int main(int argc, char *argv[])
{
	int ret;

	if (argc != 6) {
		fprintf(stderr, "Usage: %s <REMOTE_IP> <REMOTE_PORT> <CHUNK_SIZE> <TIMEOUT> <BATCH_SIZE>\n", argv[0]);
		return 0;
	}

	// Set send buffers
	for (int i = 1 ; i <= atoi(argv[5]); i++)
        {
                temp_link = (struct ring_elt *)malloc(sizeof(struct ring_elt));
                temp_link->completion_ptr = NULL;
                if (i == 1){
                        first_link = temp_link;
                }

                temp_link->buffer_base = (char *)malloc(CHUNK + alignment);
                memset(temp_link->buffer_base, 0, CHUNK + alignment);

                temp_link->buffer_ptr = (char *)(( (long)temp_link->buffer_base + (long)alignment -1 ) & ~((long)alignment - 1));

                char *bufptr = temp_link->buffer_ptr;
                memset(bufptr, 'A', CHUNK);

                temp_link->next = prev_link;
                prev_link = temp_link;
        }
        if (first_link)
        {
                // make this a circular list
                first_link->next = temp_link;
        }
	temp_link = first_link;
	
	ret = do_send(argv[1], atoi(argv[2]), atoi(argv[3]), atoi(argv[4]), atoi(argv[5]));
	if (ret) {
		fprintf(stderr, "test failed\n");
		return ret;
	}

	return 0;
}
