#!/bin/bash


set -euo pipefail


readonly GENERIC_TEST="/homes/itaysnir/Kernel-networking-testsuite/scripts/generic_test.sh"
# shellcheck source="/homes/itaysnir/Kernel-networking-testsuite/scripts/generic_test.sh"
source "$GENERIC_TEST"

# Test Specific Config
readonly MAIO_BINARY="$TESTS_ROOT/tests/maio_single_tcp_tx/maio_tcp_tx_client"
readonly CHUNK_SIZE=16384
readonly TIMEOUT=30


init_maio() {
	local huge_path="/mnt/huge"

	sudo sh -c "echo 2048 > /proc/sys/vm/nr_hugepages"
	sudo sh -c "echo 0 > /proc/sys/kernel/hung_task_timeout_secs"
	sudo mkdir -p "$huge_path"
	sudo mount -t hugetlbfs none "$huge_path"

	log_info "MAIO - huge pages enabled"
}


run_test() {
	local i="$1"
	local out_dir="$OUT_DIR-$i"
	local cmdline="sudo $MAIO_BINARY $TIMEOUT"

	taskset 1 "$MAIO_BINARY" $dip1 8080 $CHUNK_SIZE "$TIMEOUT" &

	#shellcheck disable=SC2086
	#sudo -E "$PERF" stat -D $(( RAMP * MS_IN_SEC )) -a -C 0 -e duration_time,task-clock,cycles,instructions,cache-misses -x, -o "$out_dir/perf_stat.txt" --append ${cmdline} | tee -a "$out_dir/maio.txt"

#	sudo -E "$PERF" record -D $(( RAMP * MS_IN_SEC )) -a -C 0 -e duration_time,task-clock,cycles,instructions,cache-misses -d -T -o "$out_dir/perf.data" ${cmdline} | tee -a "$out_dir/io_uring.txt"
#	sudo -E "$PERF" script -i "$out_dir/perf.data" > "$out_dir/perf.txt"
}


main() {
	init_env
	init_maio
	run_test_multiple_times "simple_recv" 1
	#generate_plots	
}


main

