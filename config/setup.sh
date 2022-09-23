#!/bin/bash


set -euo pipefail


# Configurable Parameters
readonly LOCAL_MACHINE="danger35"
readonly INTERFACE_COUNT=2
readonly PFC="on"
readonly LRO="on"  # TODO: check this
readonly GRO="on"
readonly RING=256


log_info() {
	local msg="$1"
	echo "[INFO]$msg"
}


load_config() {
    # shellcheck source=config_danger35.sh
    source "$(dirname "${BASH_SOURCE[0]}")/config_${LOCAL_MACHINE}.sh"
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

	log_info "Setting local interface $if on $ip"
    	sudo ifconfig "$if" "$ip" netmask 255.255.255.0 mtu "$mtu"
    done
}


set_remote_interfaces() {
    # It is crucial to add the loader machine within ~/.ssh/config
#    ssh $loader1 sudo ifconfig "$dif1" "$dip1" netmask 255.255.255.0 mtu "$mtu"
	echo "done_remote"
}


set_interfaces(){
    set_local_interfaces
    set_remote_interfaces
}


main() {
    load_config
    set_interfaces
}


main
