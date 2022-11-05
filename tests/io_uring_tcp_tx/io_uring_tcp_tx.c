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


void *buff;


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
	struct iovec iov = {
		.iov_base = buff,
		.iov_len = chunk_size,
	};
	struct io_uring ring;
	struct io_uring_cqe *cqe;
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

//	sockfd = socket(AF_INET, SOCK_STREAM, 0);
	sockfd = socket(AF_INET, SOCK_DGRAM, 0);
	if (sockfd < 0) {
		perror("socket");
		return 1;
	}

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

		io_uring_prep_send(sqe, sockfd, iov.iov_base, iov.iov_len, 0);
		sqe->user_data = 1 + m;
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
	
	ret = do_send(argv[1], atoi(argv[2]), atoi(argv[3]), atoi(argv[4]), atoi(argv[5]));
	if (ret) {
		fprintf(stderr, "test failed\n");
		return ret;
	}

	return 0;
}
