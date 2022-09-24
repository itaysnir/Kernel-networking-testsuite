#!/bin/bash


set -euo pipefail


# Configurable parameters
readonly TESTS_ROOT="/homes/itaysnir/Kernel-networking-testsuite"
readonly SETUP_NAME="danger36"

# No need to touch these
readonly RESULTS_DIR="$TESTS_ROOT/Results"
readonly DATE="$(date +%y_%m_%d-%H:%M:%S)"


initialize(){
	if [ ! -d "$RESULTS_DIR" ]; then
		mkdir -p "$RESULTS_DIR"
	fi

	# shellcheck source=/homes/itaysnir/Kernel-networking-testsuite/config/config_danger36.sh
	source "$TESTS_ROOT/config/config_${SETUP_NAME}.sh"
	$TESTS_ROOT/config/setup.sh $SETUP_NAME
}


main() {
	initialize
}

main

