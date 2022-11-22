CCFLAGS ?= -Wall -O2 -D_GNU_SOURCE
all_targets = manual_tcp_tx

.PHONY: manual_tcp_tx

all: $(all_targets)

clean:
	rm -f $(all_targets)

manual_tcp_tx:
	$(CC) manual_tcp.c -o ./manual_tcp  ${CCFLAGS}
