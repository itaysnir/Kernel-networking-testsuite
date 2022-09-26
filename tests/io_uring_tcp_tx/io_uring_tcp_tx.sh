#!/bin/bash


set -euo pipefail


# Configurable parameters
readonly TEST_NAME="$(basename -s .sh "$0")"
readonly SETUP_NAME="danger36"
readonly TESTS_ROOT="/homes/itaysnir/Kernel-networking-testsuite"
readonly PERF="/homes/itaysnir/linux-stable/tools/perf/perf"
readonly REPEAT_COUNT=3

# Test Specific Config
readonly IO_URING_BINARY="$TESTS_ROOT/tests/io_uring_tcp_tx/io_uring_tcp_tx"
readonly REMOTE_IP="10.1.4.35"
readonly REMOTE_PORT=8080
readonly CHUNK_SIZE=32000
readonly TIMEOUT=30
readonly RAMP=5

# No need to touch these
readonly RESULTS_DIR="$TESTS_ROOT/Results"
readonly DATE="$(date +%y_%m_%d-%H:%M:%S)"
readonly OUT_DIR="$RESULTS_DIR/$TEST_NAME/$DATE"
readonly COLLECT_CPU="$TESTS_ROOT/data_collectors/collect_net_cpu.sh"
readonly COLLECT_SCRIPT="$TESTS_ROOT/data_collectors/collect.sh"
readonly COLLECT_PCM_SCRIPT="$TESTS_ROOT/data_collectors/collect_pcm.sh"
readonly MS_IN_SEC=1000


log_info() {
	local msg=$1
	echo "[INFO]$msg"
}


log_error() {
	local msg=$1
	echo "[ERROR]$msg"
}


init_env() {
	local i
	for i in $(seq "$REPEAT_COUNT"); do
		if [ ! -d "$OUT_DIR-$i" ]; then
			mkdir -p "$OUT_DIR-$i"
		fi
	done
	
	# shellcheck source=/homes/itaysnir/Kernel-networking-testsuite/config/config_danger36.sh
	source "$TESTS_ROOT/config/config_${SETUP_NAME}.sh"
	$TESTS_ROOT/config/setup.sh "$SETUP_NAME"
	log_info "Local configurations set"
}


run_nc() {
	local pids

	if [ -z "$(ssh $loader1 command -v nc)" ]; then 
		log_error "No nc on the remote machine. Try: sudo apt install nc"
		exit 1
	fi

	set +euo pipefail
	pids=$(ssh "$loader1" pgrep -f $REMOTE_PORT)
	if [ -n "$pids" ]; then
		ssh "$loader1" "sudo kill -9 $pids"	
		sleep 0.5
		log_info "Killed processes listening on remote port $REMOTE_PORT"
	fi
	set -euo pipefail

	if [ -z "$(ssh $loader1 pgrep -x nc)" ]; then
		ssh $loader1 "nc -l -s $REMOTE_IP -p $REMOTE_PORT &" &
		log_info "Successfully launched nc server on $REMOTE_IP:$REMOTE_PORT"
		sleep 0.5
	else 
		log_info "nc already running on $REMOTE_IP:$REMOTE_PORT"
	fi
}


run_test() {
	local i="$1"
	local cmdline="sudo $IO_URING_BINARY $REMOTE_IP $REMOTE_PORT $CHUNK_SIZE $TIMEOUT"
	#shellcheck disable=SC2086
	sudo -E "$PERF" stat -D $(( RAMP * MS_IN_SEC )) -a -C 0 -e duration_time,task-clock,cycles,instructions,cache-misses -x, -o "$OUT_DIR-$i/perf_stat.txt" --append ${cmdline} | tee -a "$OUT_DIR-$i/io_uring.txt"

	dmesg | tail -n 90 >> "$OUT_DIR-$i/dmesg.txt"
}


run_test_multiple_times() {
	local test_pid
	local collect_cpu_pid
	local collect_pid
	local collect_pcm_pid
	local test_output
	local test_dir
	
	for i in $(seq "$REPEAT_COUNT"); do
		test_dir="$OUT_DIR-$i"
		test_output="$test_dir/test_raw.txt"
		log_info "Running ${TEST_NAME}.. (iteration:$i)"
			
		run_nc

		run_test "$i" &>> "$test_output" &
		test_pid=$!

		sleep "$RAMP"	
		log_info "Collecting data.."
	
		$COLLECT_CPU "$if1" "$test_dir" &> /dev/null &
		collect_cpu_pid=$!
		
		$COLLECT_SCRIPT &>> "$test_dir/result.txt" &
		collect_pid=$!

		$COLLECT_PCM_SCRIPT &>> "$test_dir/result_pcm.txt" &
		collect_pcm_pid=$!

		wait "$test_pid"
		wait "$collect_cpu_pid"
		wait "$collect_pid"
		wait "$collect_pcm_pid"
	done
}


generate_plots() {
	local setup_csv="$TESTS_ROOT/Results/$TEST_NAME/setup.csv"
	local filter_csv="$TESTS_ROOT/Results/$TEST_NAME/filter.csv"
	local filter_csv_1="$filter_csv.1"

	log_info "Test complete. Generating plots.."
	$TESTS_ROOT/process/parse.py "$TESTS_ROOT/Results/$TEST_NAME" &> /dev/null

	$TESTS_ROOT/process/filter.py "$setup_csv" > "$filter_csv"

	head -n 1 "$filter_csv" > "$filter_csv_1"

	log_info "Check results at:$OUT_DIR"
}


main() {
	init_env
	run_test_multiple_times "$REPEAT_COUNT"
	generate_plots	
}


main

