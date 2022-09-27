#!/bin/bash


set -euo pipefail


# Configurable Parameters
readonly TESTS_ROOT="/homes/itaysnir/Kernel-networking-testsuite"
readonly INTERFACE_COUNT=1
readonly PFC="on"
readonly LRO="off"  
readonly GRO="on"
readonly GSO="on"
readonly TX_CACHE="off"
readonly RING=256
readonly SOCK_SIZE=$(( 256 * 1024 * 1024))
readonly IRQ_CPU=0


log_info() {
	local msg="$1"
	echo "[INFO]$msg"
}


log_error() {
	local msg="$1"
	echo "[ERROR]$msg"
}


load_config() {
    local setup_name="$1"
    local setup_config="config_${setup_name}.sh"
    echo "Loading config file: $setup_config"
    # shellcheck source=config_danger36.sh
    source "$(dirname "${BASH_SOURCE[0]}")/$setup_config"
}


set_local_interfaces() {
    local if 
    local ip
    local tmp_str

    local i
    for i in $(seq "$INTERFACE_COUNT"); do
	tmp_str="ip$i"
    	ip="${!tmp_str}"

	tmp_str="if$i"
	if="${!tmp_str}"

	log_info "Setting local interface $if on $ip.."
    	
	sudo ifconfig "$if" "$ip" netmask 255.255.255.0 mtu "$mtu"
	set +euo pipefail
	sudo ethtool -G "$if" rx "$RING" tx "$RING" &> /dev/null
	sudo ethtool -K "$if" lro "$LRO" &> /dev/null
	sudo ethtool -K "$if" gro "$GRO" &> /dev/null
	sudo ethtool -K "$if" gso "$GSO" &> /dev/null
	sudo ethtool -A "$if" rx "$PFC" tx "$PFC" &> /dev/null
	sudo ethtool -K "$if" tx-nocache-copy "$TX_CACHE" &> /dev/null
	set -euo pipefail
	
    done
}


set_remote_interfaces() {
    # It is crucial to add the loader machine within ~/.ssh/config
    # Moreover - execute visudo and add "<USER> ALL=(ALL) NOPASSWD: ALL"
    local dif
    local dip
    local tmp_str

    local i
    for i in $(seq "$INTERFACE_COUNT"); do
        tmp_str="dip$i"
        dip="${!tmp_str}"

        tmp_str="dif$i"
        dif="${!tmp_str}"

        log_info "Setting remote interface $dif on $dip.."

        ssh "$loader1" sudo ifconfig "$dif" "$dip" netmask 255.255.255.0 mtu "$mtu"
        set +euo pipefail
        ssh "$loader1" sudo ethtool -G "$dif" rx "$RING" tx "$RING" &> /dev/null
        ssh "$loader1" sudo ethtool -K "$dif" lro "$LRO" &> /dev/null
        ssh "$loader1" sudo ethtool -K "$dif" gro "$GRO" &> /dev/null
        ssh "$loader1" sudo ethtool -K "$dif" gso "$GSO" &> /dev/null
        ssh "$loader1" sudo ethtool -A "$dif" rx "$PFC" tx "$PFC" &> /dev/null
        ssh "$loader1" sudo ethtool -K "$dif" tx-nocache-copy "$TX_CACHE" &> /dev/null
        set -euo pipefail

    done
}


set_kernel_settings() {
	local PERCPU_FRACTION="/proc/sys/vm/percpu_pagelist_fraction"
	local NMI_WATCHDOG="/proc/sys/kernel/nmi_watchdog"
	local KERNEL_PANIC="/proc/sys/kernel/panic"
	local PERF_PARANOID="/proc/sys/kernel/perf_event_paranoid"
	local KPTR_RESTRICT="/proc/sys/kernel/kptr_restrict"	
	local NO_TURBO="/sys/devices/system/cpu/intel_pstate/no_turbo"

	log_info "Setting kernel settings.."
	
	sudo modprobe msr
	
	if [ -e "$PERCPU_FRACTION" ]; then
		sudo sh -c "echo 8 > $PERCPU_FRACTION"
		log_info "Set maximal percpu pages"
	fi

	if [ -e "$NMI_WATCHDOG" ]; then
		sudo sh -c "echo 0 > $NMI_WATCHDOG"
		log_info "NMI Watchdog disabled"
	fi

	if [ -e "$KERNEL_PANIC" ]; then
		sudo sh -c "echo 10 > $KERNEL_PANIC"
		log_info "System reboots after 10s upon panic"
	fi

	if [ -e "$PERF_PARANOID" ]; then
		echo -1 | sudo tee "$PERF_PARANOID" &> /dev/null
		log_info "Performance counters enabled"
	fi

	if [ -e "$KPTR_RESTRICT" ]; then
		echo 0 | sudo tee "$KPTR_RESTRICT" &> /dev/null
		log_info "Kernel pointers visibility enabled"
	fi

	if [ -e "$NO_TURBO" ]; then
		echo 1 | sudo tee "$NO_TURBO" &> /dev/null
		log_info "Turbo boost disabled"
	fi

	if [ -z "$(command -v wrmsr)" ]; then
	       	log_error "No msr tools found. Please issue: sudo apt install msr-tools"
	       	exit 1
	fi

	# Might not work on certain hosts..
	#sudo wrmsr -a 0x1a0 0x4000850089
	#log_info "Turbo boost 2 disabled"

	sudo sh -c "echo $SOCK_SIZE > /proc/sys/net/core/optmem_max"
	sudo sh -c "echo $SOCK_SIZE > /proc/sys/net/core/rmem_max"
	sudo sh -c "echo $SOCK_SIZE > /proc/sys/net/core/wmem_max"
	sudo sh -c "echo $SOCK_SIZE > /proc/sys/net/core/rmem_default"
	sudo sh -c "echo $SOCK_SIZE > /proc/sys/net/core/wmem_default"

}


set_cpu_affinity() {
	local setup_name="$1"
	local remote_tests_root
	remote_tests_root="/tmp/$(basename $TESTS_ROOT)"
	# Note: this function first uploads the tests scripts to the remote host
	ssh "$loader1" sudo rsync -av --exclude 'Results' --exclude '.git' "$setup_name:$TESTS_ROOT" "$(dirname $remote_tests_root)"
        log_info "Uploaded scripts to remote machine"

        $TESTS_ROOT/scripts/set_irq_affinity_cpulist.sh "$IRQ_CPU" "$if1" &> /dev/null
        log_info "Set local IRQ affinity to CPU ${IRQ_CPU}"

        ssh "$loader1" sudo "$remote_tests_root/scripts/set_irq_affinity.sh" "$dif1" &> /dev/null
        log_info "Set remote IRQ affinity"
}


set_interfaces(){
    set_local_interfaces
    set_remote_interfaces
}


main() {
    local setup_name="$1"
    load_config "$setup_name"
    set_interfaces
    set_kernel_settings
    set_cpu_affinity "$setup_name"
}


main "$1"
