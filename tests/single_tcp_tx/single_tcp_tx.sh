#!/bin/bash


set -euo pipefail


readonly GENERIC_TEST="/homes/itaysnir/Kernel-networking-testsuite/scripts/generic_test.sh"
source "$GENERIC_TEST"


# Test Specific Config
readonly CHUNK_SIZE=16384
readonly TIMEOUT=30


run_test() {
        local i="$1"
        local cmdline="sudo netperf -H $dip1 -p $REMOTE_PORT -t TCP_STREAM -T 0,0 -l $TIMEOUT -- -m$CHUNK_SIZE -s16M"


	sudo netperf -H $dip1 -p $REMOTE_PORT -t TCP_STREAM -T 0,1 -l $TIMEOUT -- -m$CHUNK_SIZE -s16M &
	sudo netperf -H $dip1 -p $REMOTE_PORT -t TCP_STREAM -T 0,2 -l $TIMEOUT -- -m$CHUNK_SIZE -s16M &
	sudo netperf -H $dip1 -p $REMOTE_PORT -t TCP_STREAM -T 0,3 -l $TIMEOUT -- -m$CHUNK_SIZE -s16M &

	#shellcheck disable=SC2086
        sudo -E "$PERF" stat -D $(( RAMP * MS_IN_SEC )) -a -C 0 -e duration_time,task-clock,cycles,instructions,cache-misses -x, -o "$OUT_DIR-$i/perf_stat.txt" --append ${cmdline} | tee -a "$OUT_DIR-$i/single_tcp.txt"
}


main() {
	init_env
	run_test_multiple_times "netserver"
	generate_plots	
}


main

