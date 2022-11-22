CCFLAGS ?= -Wall -O2 -D_GNU_SOURCE -luring
all_targets = io_uring_tcp_tx

.PHONY: liburing io_uring_tcp_tx

all: $(all_targets)

clean:
	rm -f $(all_targets)

io_uring_tcp_tx:
	$(CC) io_uring_tcp_tx.c -o ./io_uring_tcp_tx  ${CCFLAGS}
