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
#include "helpers.h"

// Itay additions
#define IO_URING_CHUNK (2<<20)
#define CHUNK (16<<12)
#define CHUNK_NUM 2000
#define MAX CHUNK*CHUNK_NUM
#define SA struct sockaddr

void *buff;


static int do_send(const char* host, int port, int chunk_size, int timeout)
{
	buff = malloc(chunk_size);
	if (!buff) {
		fprintf(stderr, "do_send: malloc failed\n");
		return 1;
	}
	struct sockaddr_in saddr;
	struct iovec iov = {
		.iov_base = buff,
		.iov_len = chunk_size,
	};
	struct io_uring ring;
	struct io_uring_cqe *cqe;
	struct io_uring_sqe *sqe;
	int sockfd, ret;

	ret = io_uring_queue_init(1, &ring, 0);
	if (ret) {
		fprintf(stderr, "queue init failed: %d\n", ret);
		return 1;
	}

	memset(&saddr, 0, sizeof(saddr));
	saddr.sin_family = AF_INET;
	saddr.sin_port = htons(port);
	inet_pton(AF_INET, host, &saddr.sin_addr);

	sockfd = socket(AF_INET, SOCK_STREAM, 0);
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

	sqe = io_uring_get_sqe(&ring);
	io_uring_prep_send(sqe, sockfd, iov.iov_base, iov.iov_len, 0);
	sqe->user_data = 1;

	ret = io_uring_submit(&ring);
	if (ret <= 0) {
		fprintf(stderr, "submit failed: %d\n", ret);
		goto err;
	}

	ret = io_uring_wait_cqe(&ring, &cqe);
	if (cqe->res == -EINVAL) {
		fprintf(stdout, "send not supported, skipping\n");
		close(sockfd);
		return 0;
	}
	if (cqe->res != iov.iov_len) {
		fprintf(stderr, "failed cqe: %d\n", cqe->res);
		goto err;
	}
	counter++;
	}

	printf("Packets sent:%lu\n", counter);
	close(sockfd);
	return 0;
err:
	close(sockfd);
	return 1;
}

static int test(const char *host, int port, int chunk_size, int timeout)
{
	do_send(host, port, chunk_size, timeout);
	return 0;
}

int main(int argc, char *argv[])
{
	int ret;

	if (argc != 5) {
		fprintf(stderr, "Usage: %s <REMOTE_IP> <REMOTE_PORT> <CHUNK_SIZE> <TIMEOUT>\n", argv[0]);
		return 0;
	}
	
	ret = test(argv[1], atoi(argv[2]), atoi(argv[3]), atoi(argv[4]));
	if (ret) {
		fprintf(stderr, "test sqthread=0 failed\n");
		return ret;
	}

	return 0;
}
