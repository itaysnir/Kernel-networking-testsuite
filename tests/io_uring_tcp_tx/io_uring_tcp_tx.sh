#!/bin/bash


set -euo pipefail


readonly GENERIC_TEST="/homes/itaysnir/Kernel-networking-testsuite/scripts/generic_test.sh"
source "$GENERIC_TEST"


# Test Specific Config
readonly IO_URING_BINARY="$TESTS_ROOT/tests/io_uring_tcp_tx/io_uring_tcp_tx"
readonly CHUNK_SIZE=16384
readonly TIMEOUT=30
readonly BATCH=8


run_test() {
	local i="$1"
	local out_dir="$OUT_DIR-$i"
	local cmdline="taskset $CPU_0 $IO_URING_BINARY $dip1 $REMOTE_PORT $CHUNK_SIZE $TIMEOUT $BATCH"
	taskset 1 "$IO_URING_BINARY" $dip1 8080 $CHUNK_SIZE $TIMEOUT $BATCH &
	taskset 1 "$IO_URING_BINARY" $dip1 8081 $CHUNK_SIZE $TIMEOUT $BATCH &
	taskset 1 "$IO_URING_BINARY" $dip1 8082 $CHUNK_SIZE $TIMEOUT $BATCH &
	taskset 1 "$IO_URING_BINARY" $dip1 8083 $CHUNK_SIZE $TIMEOUT $BATCH &
	taskset 1 "$IO_URING_BINARY" $dip1 8084 $CHUNK_SIZE $TIMEOUT $BATCH &
	
	#shellcheck disable=SC2086
#	sudo -E "$PERF" stat -D $(( RAMP * MS_IN_SEC )) -a -C 0 -e duration_time,task-clock,cycles,instructions,cache-misses -x, -o "$out_dir/perf_stat.txt" --append ${cmdline} | tee -a "$OUT_DIR-$i/io_uring.txt"

#	sudo -E "$PERF" record -D $(( RAMP * MS_IN_SEC )) -a -C 0 -e duration_time,task-clock,cycles,instructions,cache-misses -d -T -o "$out_dir/perf.data" ${cmdline} | tee -a "$out_dir/io_uring.txt"
#	sudo -E "$PERF" script -i "$out_dir/perf.data" > "$out_dir/perf.txt"
}


main() {
	init_env
	run_test_multiple_times "simple_recv" 5
#	generate_plots	
}


main

