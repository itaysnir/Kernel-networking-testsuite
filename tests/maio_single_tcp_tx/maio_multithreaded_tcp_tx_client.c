/****
An example of creating a TCP socket and sending Zero-Copy I/O
***/

#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <arpa/inet.h>
#include <sys/time.h>
#include "user_maio.h"

#define PAGE_CNT	512
#define CHUNK_NUM	2048
#define SWAP_32(x)  ( (( (x) >> 24 ) &0xff) | (( (x) << 8 ) &0xff0000) | (( (x) >> 8) &0xff00) | (( (x) << 24) &0xff000000) )

const int K_CLIENTS = 1;

uint32_t rem_ip = 0;
uint32_t port = 0;
int chunk_size = 0;
int timeout = 0;


void* maio_tx_thread(void *cache)
{
	/* create + connect */
	void *chunk[CHUNK_NUM];
	int idxs[K_CLIENTS];

	for(int i = 0; i < K_CLIENTS; ++i) {
		int idx = create_connected_socket(rem_ip, port);
		printf("Connected maio sock =%d to port %d\n", idx, port);
		idxs[i] = idx;
		init_tcp_ring(idx, cache);
		++port;
	}

	/* init ring */
	// init_tcp_ring(idx, cache);
	// init_tcp_ring(idx2, cache);

	/* prep mem for I/O */
	for (int i = 0; i < CHUNK_NUM; ++i) {
		chunk[i] = alloc_chunk(cache);
	}

	printf("send loop [%d]\n", chunk_size);
	int next_chunk = 0;

	uint64_t counter=0;
	time_t endtime = time(NULL) + timeout;

	while (time(NULL) < endtime) {
		for(int i = 0; i < K_CLIENTS; ++i) {
			send_buffer(idxs[i], chunk[next_chunk++], chunk_size, 1);
			counter++;
			if(next_chunk == CHUNK_NUM)
				next_chunk = 0;
		}
	};

	printf("Packets sent:%lu\n", counter);
}


int main(int argc, char *argv[])
{
	if (argc < 3)
	{
		fprintf(stderr, "Usage: %s <IP> <PORT> <CHUNK_SIZE> <TIMEOUT>\n", argv[0]);
		exit(1);
	}

	inet_pton(AF_INET, argv[1], &rem_ip);
	rem_ip = SWAP_32(rem_ip);
	port = atoi(argv[2]);
	chunk_size = atoi(argv[3]); // 16-64 KB are good values
	timeout = atoi(argv[4]);

	if (chunk_size > 16384)
	{
		printf("Maio crashes for large buffers.. exiting\n");
		exit(1);
	}

	/* Init Mem*/
	void *cache = init_hp_memory(PAGE_CNT / 2);
	printf("init memory and get page %p\n", cache);

	pthread_t thread_1;
	pthread_t thread_2;

	int result_1 = pthread_create(&thread_1, NULL, maio_tx_thread, cache);
	int result_2 = pthread_create(&thread_2, NULL, maio_tx_thread, cache);
	pthread_join(thread_1, NULL);
	pthread_join(thread_2, NULL);
	
	printf("Thread 1 returns: %d\n", result_1);
	printf("Thread 2 returns: %d\n", result_2);

	return 0;
}
