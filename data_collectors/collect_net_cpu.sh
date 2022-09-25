#!/bin/bash


set -euo pipefail


readonly TIME=5
readonly BASE="$(dirname "$0")"


collect_net_cpu() {
    local if="$1"
    local out_dir="$2"

    "$BASE"/pylib/sample_cpu.py $(( "$TIME" * 4 )) | tee -a "$out_dir/cpu.txt" &
    "$BASE"/pylib/sample_eth.py $(( "$TIME" * 4 )) "$if" | tee -a "$out_dir/eth.txt" &

    wait
}


main() {
	collect_net_cpu "$1" "$2"
}

main "$1" "$2"


