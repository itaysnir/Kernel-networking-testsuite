CCFLAGS ?= -Wall -O2 -D_GNU_SOURCE
all_targets = recv_server 

.PHONY: recv_server

all: $(all_targets)

clean:
	rm -f $(all_targets)

recv_server:
	$(CC) recv_server.c -o ./recv_server  ${CCFLAGS}
