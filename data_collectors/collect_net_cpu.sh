#!/bin/bash


time=5
base=`dirname $0`

echo "<$OUT_FILE>"
function collect_net_cpu {
    echo " in collect cpu" >&2
    $base/pylib/sample_cpu.py $[$time*4]      | tee -a $OUT_FILE/cpu.txt &
    echo if1 $if1
    $base/pylib/sample_eth.py $[$time*4] $if1 | tee -a $OUT_FILE/eth.txt &
    echo " out collect cpu" >&2
}

[ "$collect_net_cpu" != "no" ] && collect_net_cpu

echo "Data collected"
