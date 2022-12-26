CCFLAGS ?= -Wall -O2 -D_GNU_SOURCE -luring
all_targets = io_uring_zc_tx

.PHONY: liburing io_uring_zc_tx

all: $(all_targets)

clean:
	rm -f $(all_targets)

io_uring_zc_tx:
	$(CC) io_uring_zc_tx.c -o ./io_uring_zc_tx  ${CCFLAGS}

