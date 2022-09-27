CC=gcc
CFLAGS=-I. -O2
DEPS=user_maio.h

.PHONY: maio_tcp_tx_client

%.o: %.c $(DEPS)
	$(CC) -std=c99 -c -g -o $@ $< $(CFLAGS)


maio_tcp_tx_client: maio_lib.o maio_tcp_tx_client.o
	$(CC) -std=c99 -o maio_tcp_tx_client maio_lib.o maio_tcp_tx_client.o

clean:
	rm -f *.o
