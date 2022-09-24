#!/bin/bash


set -euo pipefail


# Configurable parameters
readonly TEST_NAME="io_uring_tcp_tx"
readonly SETUP_NAME="danger36"
readonly TESTS_ROOT="/homes/itaysnir/Kernel-networking-testsuite"
readonly PERF="/homes/itaysnir/linux-stable/tools/perf/perf"
readonly REPEAT_COUNT=3

# No need to touch these
readonly RESULTS_DIR="$TESTS_ROOT/Results"
readonly DATE="$(date +%y_%m_%d-%H:%M:%S)"
readonly OUT_DIR="$RESULTS_DIR/$TEST_NAME/$DATE"


initialize(){
	if [ ! -d "$OUT_DIR" ]; then
		mkdir -p "$OUT_DIR"
	fi

	# shellcheck source=/homes/itaysnir/Kernel-networking-testsuite/config/config_danger36.sh
	source "$TESTS_ROOT/config/config_${SETUP_NAME}.sh"
	$TESTS_ROOT/config/setup.sh $SETUP_NAME
}


run_test() {
	echo "meow!"
}


run_test_multiple_times() {
	local test_output
	for i in $(seq "$REPEAT_COUNT"); do
		test_output="$OUT_DIR/test_${i}_raw.txt"
		run_test &>> "$test_output" &
	done
}

main() {
	initialize
	run_test_multiple_times "$REPEAT_COUNT"
}

main

