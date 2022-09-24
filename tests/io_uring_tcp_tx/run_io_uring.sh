#!/bin/bash


set -euo pipefail


# Configurable parameters
readonly TEST_NAME="io_uring_tcp_tx"
readonly SETUP_NAME="danger36"
readonly TESTS_ROOT="/homes/itaysnir/Kernel-networking-testsuite"
readonly PERF="/homes/itaysnir/linux-stable/tools/perf/perf"
readonly REPEAT_COUNT=3

# Test Specific Config
readonly IO_URING_BINARY="$TESTS_ROOT/tests/io_uring_tcp_tx/send_recv.t"
readonly REMOTE_IP="127.0.0.1"
readonly REMOTE_PORT=8080
readonly CHUNK_SIZE=32000
readonly TIMEOUT=5
readonly RAMP=3

# No need to touch these
readonly RESULTS_DIR="$TESTS_ROOT/Results"
readonly DATE="$(date +%y_%m_%d-%H:%M:%S)"
readonly OUT_DIR="$RESULTS_DIR/$TEST_NAME/$DATE"
readonly COLLECT_SCRIPT="$TESTS_ROOT/data_collectors/collect.sh"
readonly COLLECT_PCM_SCRIPT="$TESTS_ROOT/data_collectors/collect_pcm.sh"


log_info() {
	local msg=$1
	echo "[INFO]$msg"
}


log_error() {
	local msg=$1
	echo "[ERROR]$msg"
}


init_env() {
	if [ ! -d "$OUT_DIR" ]; then
		mkdir -p "$OUT_DIR"
	fi

	# shellcheck source=/homes/itaysnir/Kernel-networking-testsuite/config/config_danger36.sh
	source "$TESTS_ROOT/config/config_${SETUP_NAME}.sh"
	$TESTS_ROOT/config/setup.sh $SETUP_NAME
}


init_test() {
	if [ -z "$(command -v ncat)" ]; then 
		log_error "No ncat on the machine. Try: sudo apt install ncat"
	fi
	
	if [ -z "$(pgrep -x ncat)" ]; then
		"$(command -v ncat)" -e "$(command -v cat)" -k -l "$REMOTE_PORT" &
		log_info "Successfully launched ncat echo server on $REMOTE_IP:$REMOTE_PORT"
		sleep 0.5
	else 
		log_info "ncat already running"
	fi
}


run_test() {
	local cmd="$IO_URING_BINARY $REMOTE_IP $REMOTE_PORT $CHUNK_SIZE $TIMEOUT"
	log_info "Running: $cmd"
	$cmd
}


run_test_multiple_times() {
	local test_output
	for i in $(seq "$REPEAT_COUNT"); do
		test_output="$OUT_DIR/test_${i}_raw.txt"
		log_info "Running $TEST_NAME.. (iteration:$i)"
		run_test &>> "$test_output" &
	
		sleep "$RAMP"	
		
		log_info "Collecting data.."
		$COLLECT_SCRIPT &>> "$OUT_DIR/result_${i}.txt"
		$COLLECT_PCM_SCRIPT &>> "$OUT_DIR/result_pcm_${i}.txt"

		wait $!


	done
}


main() {
	init_env
	init_test
	run_test_multiple_times "$REPEAT_COUNT"
}

main

