#!/usr/bin/python
from subprocess import Popen, PIPE
from sys import argv, exit
from time import sleep

def sample(t):
    p = Popen("sudo /scrap/borisp/pmu-tools/ocperf.py stat -e cycles,instructions,branches,branch-misses -e stalled-cycles-frontend -e cache-references,cache-misses -e LLC-loads,LLC-load-misses,LLC-stores,LLC-store-misses -e L1-dcache-loads,L1-dcache-load-misses,L1-dcache-stores,L1-dcache-store-misses -e mem-loads,mem-stores,node-loads,node-stores -e uncore_imc_0/cas_count_read/,uncore_imc_0/cas_count_write/ -C 1 -- sleep %d" % t, shell = True, stdout = PIPE, stderr = PIPE)
    output = p.stderr.read()

    return output

def main():
	print sample(int(argv[1]))

if __name__ == '__main__':
    if len(argv) != 2:
        exit('Usage: %s <sleep-time>' % argv[0])
    main()

