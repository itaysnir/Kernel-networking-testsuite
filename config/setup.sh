#!/bin/bash


set -euo pipefail


# Configurable Parameters
readonly INTERFACE_COUNT=2
readonly PFC="on"
readonly LRO="off"  # TODO: check this
readonly GRO="on"
readonly GSO="on"
readonly TX_CACHE="off"
readonly RING=256

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
    echo "The config is:$setup_config"
    # shellcheck source=config_danger35.sh
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
#    ssh $loader1 sudo ifconfig "$dif1" "$dip1" netmask 255.255.255.0 mtu "$mtu"
	log_info "Setting remote interface (TODO)"
}


set_kernel_settings() {
	local PERCPU_FRACTION="/proc/sys/vm/percpu_pagelist_fraction"
	local NMI_WATCHDOG="/proc/sys/kernel/nmi_watchdog"
	local KERNEL_PANIC="/proc/sys/kernel/panic"
	local PERF_PARANOID="/proc/sys/kernel/perf_event_paranoid"
	local KPTR_RESTRICT="/proc/sys/kernel/kptr_restrict"	
	local NO_TURBO="/sys/devices/system/cpu/intel_pstate/no_turbo"

	log_info "Setting kernel settings.."
	
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
		echo -1 | sudo tee "$PERF_PARANOID"
		log_info "Performance counters enabled"
	fi

	if [ -e "$KPTR_RESTRICT" ]; then
		echo 0 | sudo tee "$KPTR_RESTRICT"
		log_info "Kernel pointers visibility enabled"
	fi

	if [ -e "$NO_TURBO" ]; then
		echo 1 | sudo tee "$NO_TURBO"
		log_info "Turbo boost disabled"
	fi

	if [ -z "$(command -v wrmsr)" ]; then
	       	log_error "No msr tools found. Please issue: sudo apt install msr-tools"
	       	exit 1
	fi


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
}


main "$1"
