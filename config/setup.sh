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
	echo "done_remote"
}


set_interfaces(){
    set_local_interfaces
    set_remote_interfaces
}


main() {
    local setup_name="$1"
    load_config "$setup_name"
    set_interfaces
}


main "$1"
