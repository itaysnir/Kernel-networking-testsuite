#!/bin/bash


set -euo pipefail


# Configurable parameters
readonly TEST_NAME="$(basename -s .sh "$0")"
readonly TESTS_ROOT="/homes/itaysnir/Kernel-networking-testsuite"
readonly PERF="/homes/itaysnir/linux-stable/tools/perf/perf"
readonly REPEAT_COUNT=3
readonly REMOTE_PORT=8080
readonly RAMP=15

# No need to touch these
readonly SETUP_NAME="$(hostname -s)"
readonly RESULTS_DIR="$TESTS_ROOT/Results"
readonly DATE="$(date +%y_%m_%d-%H:%M:%S)"
readonly OUT_DIR="$RESULTS_DIR/$TEST_NAME/$DATE"
readonly COLLECT_CPU="$TESTS_ROOT/data_collectors/collect_net_cpu.sh"
readonly COLLECT_SCRIPT="$TESTS_ROOT/data_collectors/collect.sh"
readonly COLLECT_PCM_SCRIPT="$TESTS_ROOT/data_collectors/collect_pcm.sh"
readonly WATCH_SCRIPT="$TESTS_ROOT/data_collectors/itay_watch.sh"
readonly MS_IN_SEC=1000
readonly CPU_0="0x00000001"


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

#	if [ ! -e "$PERF" ]; then
#                log_error "Missing perf on path: $PERF. Issue: make -C <kernel-source>/tools/ perf_install prefix=/usr/"
#                exit 1
#        fi

       # if [ ! -d "$PCM"]; then
       #        log_error "Missing PCM on path:"
       #	exit 1
       # fi

	# shellcheck source=/homes/itaysnir/Kernel-networking-testsuite/config/config_danger36.sh
	source "$TESTS_ROOT/config/config_${SETUP_NAME}.sh"
	$TESTS_ROOT/config/setup.sh "$SETUP_NAME"
	log_info "Local configurations set"
}


kill_listening_process(){
	local remote_port="$1"
	local pids
	
	set +euo pipefail
	pids=$(ssh "$loader1" pgrep -f $remote_port)
	if [ -n "$pids" ]; then
		ssh "$loader1" "sudo kill -9 $pids"	
		sleep 0.5
		log_info "Killed processes listening on remote port $remote_port"
	fi
	set -euo pipefail
}


run_nc() {
	if [ -z "$(ssh $loader1 command -v nc)" ]; then 
		log_error "No nc on the remote machine. Try: sudo apt install nc"
		exit 1
	fi

	kill_listening_process "$REMOTE_PORT"

	# Running at backround is mandatory
	ssh $loader1 "taskset $CPU_0 nc -l -s $dip1 -p $REMOTE_PORT &" &
	log_info "Successfully launched nc server on $dip1:$REMOTE_PORT"
	sleep 3
}


__run_netserver_inner(){
	local port="$1"
	local affinity="$2"

	# TODO: add assertion check that the remote recv server do exist

	kill_listening_process "$port"
	sleep 1
	
	ssh $loader1 "taskset $affinity sudo netserver -p $port &" &
        log_info "Launched netserver on $dip1:$port"

}


run_netserver() {
	local servers_count="$1"
	local port="$REMOTE_PORT"
	local affinity=0x1

        if [ -z "$(ssh $loader1 command -v netserver)" ]; then
                log_error "No netserver on the remote machine. Try: sudo apt install netserver"
                exit 1
        fi

	kill_listening_process "netserver"
	sleep 2

	for i in $(seq 0 $((servers_count - 1)) ); do
		__run_netserver_inner "$port" "$affinity"
		port=$((port + 1))	
		affinity=$((affinity * 2))
	done	

	sleep 2

}


__run_simple_recv_inner(){
	local port="$1"
	local affinity="$2"

	local server_path="/tmp/Kernel-networking-testsuite/tests/simple_recv_server/recv_server"
	# TODO: add assertion check that the remote recv server do exist

	kill_listening_process "$port"
	sleep 1
	
        ssh $loader1 "taskset $affinity $server_path $port &" & 
	log_info "Launched simple recv server on $dip1:$port. Core affinity:$affinity"
}



run_simple_recv(){
	local servers_count="$1"
	local port="$REMOTE_PORT"
	local affinity=0x1
	
	kill_listening_process "recv_server"
	sleep 2

	for i in $(seq 0 $((servers_count - 1)) ); do
		__run_simple_recv_inner "$port" "$affinity"
		port=$((port + 1))	
		affinity=$((affinity * 2))
	done	

	sleep 2
}

run_test_multiple_times() {
	local remote_server="$1"  # Remote server type
	local servers_count="$2"
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
	
		if [[ "$remote_server" == "nc" ]]; then
			run_nc
		
		elif [[ "$remote_server" == "netserver" ]]; then
			run_netserver "$servers_count"

		elif [[ "$remote_server" == "simple_recv" ]]; then
			run_simple_recv "$servers_count"

		else
			log_error "Invalid remote server type: $remote_server"
			exit 1
		fi

		log_info "Sending packets.."
		run_test "$i" &>> "$test_output" &
		test_pid=$!

		sleep "$RAMP"	
		
		log_info "Collecting data.."
		$COLLECT_CPU "$if1" "$test_dir" &>> "$test_dir/result.txt" &
		collect_cpu_pid=$!
		
		$COLLECT_SCRIPT &>> "$test_dir/result.txt" &
		collect_pid=$!

		$COLLECT_PCM_SCRIPT &>> "$test_dir/result_pcm.txt" &
		collect_pcm_pid=$!

		cd "$TESTS_ROOT/data_collectors"
		$WATCH_SCRIPT 5 &>> "$test_dir/result_watch.txt" &
		watch_pid=$!
		cd -

		sleep "$TIMEOUT"
		log_info "Done sending packets"

		wait "$collect_cpu_pid"
		wait "$collect_pid"
		wait "$collect_pcm_pid"
		wait "$watch_pid"
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

