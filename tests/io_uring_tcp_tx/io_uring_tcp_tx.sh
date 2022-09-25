#!/bin/bash


set -euo pipefail


# Configurable parameters
readonly TEST_NAME="$(basename -s .sh "$0")"
readonly SETUP_NAME="danger36"
readonly TESTS_ROOT="/homes/itaysnir/Kernel-networking-testsuite"
readonly PERF="/homes/itaysnir/linux-stable/tools/perf/perf"
readonly REPEAT_COUNT=3

# Test Specific Config
readonly IO_URING_BINARY="$TESTS_ROOT/tests/io_uring_tcp_tx/send_io_uring.t"
readonly REMOTE_IP="127.0.0.1"
readonly REMOTE_PORT=8080
readonly CHUNK_SIZE=32000
readonly TIMEOUT=10
readonly RAMP=5

# No need to touch these
readonly RESULTS_DIR="$TESTS_ROOT/Results"
readonly DATE="$(date +%y_%m_%d-%H:%M:%S)"
readonly OUT_DIR="$RESULTS_DIR/$TEST_NAME/$DATE"
readonly COLLECT_CPU="$TESTS_ROOT/data_collectors/collect_net_cpu.sh"
readonly COLLECT_SCRIPT="$TESTS_ROOT/data_collectors/collect.sh"
readonly COLLECT_PCM_SCRIPT="$TESTS_ROOT/data_collectors/collect_pcm.sh"
readonly MS_IN_SEC=1000
readonly IRQ_CPU=0


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
	
	$TESTS_ROOT/scripts/set_irq_affinity_cpulist.sh "$IRQ_CPU" "$if1" &> /dev/null
	log_info "IRQ affinity set to CPU ${IRQ_CPU}"
	# TODO: also add cpu affinity for remote host
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
	
	for i in $(seq "$REPEAT_COUNT"); do
		test_output="$OUT_DIR-$i/test_raw.txt"
		log_info "Running ${TEST_NAME}.. (iteration:$i)"
			
		run_test "$i" &>> "$test_output" &
		test_pid=$!

		sleep "$RAMP"	
		log_info "Collecting data.."
	
		$COLLECT_CPU "$if1" &>> "$OUT_DIR-$i/result_cpu.txt" &
		collect_cpu_pid=$!
		
		$COLLECT_SCRIPT &>> "$OUT_DIR-$i/result.txt" &
		collect_pid=$!

		$COLLECT_PCM_SCRIPT &>> "$OUT_DIR-$i/result_pcm.txt" &
		collect_pcm_pid=$!

		wait "$test_pid"
		wait "$collect_cpu_pid"
		wait "$collect_pid"
		wait "$collect_pcm_pid"
	done
}


finalize() {
	log_info "Test complete. Check results at:$OUT_DIR"
}


main() {
	init_env
	init_test
	run_test_multiple_times "$REPEAT_COUNT"
	finalize
}


main

