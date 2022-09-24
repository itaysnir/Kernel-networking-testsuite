#!/bin/bash


set -euo pipefail


readonly TIME=5
readonly BASE="$(dirname "$0")"


collect_net_cpu() {
    local if="$1"

    "$BASE"/pylib/sample_cpu.py $(( "$TIME" * 4 )) &
    "$BASE"/pylib/sample_eth.py $(( "$TIME" * 4 )) "$if" &

    wait
}


main() {
	collect_net_cpu "$1" 
}

main "$1"


