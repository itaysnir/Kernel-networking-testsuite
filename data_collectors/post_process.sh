#!/bin/bash

export HOME=/homes/itaysnir
perf=/homes/markuze/copy/tools/perf/perf

function report_functions {
	echo " in report_functions"
	#sudo /homes/markuze/copy/tools/perf/perf report --stdio --max-stack 0 --percent-limit 0.01  >> $OUT_FILE/perf.txt
	perf_name=`date +"%y_%m_%d_%H.%M.%S"`
	sudo cp perf.data $OUT_FILE/$perf_name.data
	#sudo /homes/markuze/copy/tools/perf/perf mem report --stdio >> $OUT_FILE/perf.txt
	echo " out report_functions"
}

[ "$collect_functions" != "no" ] && report_functions
